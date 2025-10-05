#!/bin/bash

# Debug için: Script'in çalıştığını göster
echo "$(date '+%Y-%m-%d %H:%M:%S') - Script başlatıldı" >&2

# Environment variables'ları logla
echo "Environment Variables:" >&2
env | grep -E '(WATCH|CPU|MEMORY|LOG)' >&2

# Enhanced Docker Container Auto-Scaler
# Features: CPU/Memory scaling, cooldown periods, multiple thresholds, detailed logging

set -o errexit
set -o nounset
set -o pipefail

# Configuration with default values
WATCH_CONTAINERS=${WATCH_CONTAINERS:-""}
CPU_THRESHOLD=${CPU_THRESHOLD:-80}
MEMORY_THRESHOLD_PERCENT=${MEMORY_THRESHOLD_PERCENT:-90}
CHECK_INTERVAL=${CHECK_INTERVAL:-15}
SCALE_FACTOR=${SCALE_FACTOR:-1.5}
COOLDOWN_PERIOD=${COOLDOWN_PERIOD:-60}
MAX_MEMORY_MB=${MAX_MEMORY_MB:-4096}
MAX_CPU_QUOTA=${MAX_CPU_QUOTA:-100000}
MIN_MEMORY_MB=${MIN_MEMORY_MB:-64}
MIN_CPU_QUOTA=${MIN_CPU_QUOTA:-10000}
DOCKER_SOCK="/var/run/docker.sock"
LOG_LEVEL=${LOG_LEVEL:-"changes"}
LOG_TIMESTAMP_FORMAT="%Y-%m-%d %H:%M:%S"
STATS_HISTORY_COUNT=${STATS_HISTORY_COUNT:-3}

# Color codes for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global arrays for state management
declare -A PREV_CPU_USAGE
declare -A PREV_SYSTEM_USAGE
declare -A CPU_HISTORY
declare -A MEMORY_HISTORY
declare -A COOLDOWN_TIMESTAMPS
declare -A CONTAINER_IDS_CACHE
declare -A SCALE_COUNTERS

log_message() {
    local level=$1
    local message=$2
    local color=$NC
    
    case $level in
        "ERROR") color=$RED ;;
        "SUCCESS") color=$GREEN ;;
        "WARNING") color=$YELLOW ;;
        "INFO") color=$BLUE ;;
    esac
    
    if [[ "$LOG_LEVEL" == "all" ]] || [[ "$level" == "ERROR" ]] || 
       [[ "$LOG_LEVEL" == "changes" && "$level" != "INFO" ]]; then
        echo -e "${color}[$(date +"$LOG_TIMESTAMP_FORMAT")] $level: $message${NC}"
    fi
}

validate_environment() {
    if [[ ! -S "$DOCKER_SOCK" ]]; then
        log_message "ERROR" "Docker socket not found at $DOCKER_SOCK"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_message "ERROR" "jq command is required but not installed"
        exit 1
    fi
    
    if [[ -z "$WATCH_CONTAINERS" ]]; then
        log_message "WARNING" "WATCH_CONTAINERS is empty. No containers to monitor."
    fi
}

docker_api() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    
    local curl_cmd=("curl" "-s" "--max-time" "10" "--unix-socket" "$DOCKER_SOCK")
    
    if [[ -n "$data" ]]; then
        curl_cmd+=("-H" "Content-Type: application/json" "-d" "$data")
    fi
    
    curl_cmd+=("-X" "$method" "http://localhost/$endpoint")
    
    "${curl_cmd[@]}"
}

get_container_id() {
    local name="$1"
    
    # Use cache to reduce API calls
    if [[ -n "${CONTAINER_IDS_CACHE[$name]:-}" ]]; then
        echo "${CONTAINER_IDS_CACHE[$name]}"
        return
    fi
    
    local id=$(docker_api "containers/json" | \
               jq -r --arg name "$name" '.[] | select(.Names[] | contains($name)) | .Id' | \
               head -n 1)
    
    if [[ -n "$id" && "$id" != "null" ]]; then
        CONTAINER_IDS_CACHE[$name]="$id"
    fi
    
    echo "$id"
}

get_container_stats() {
    local id="$1"
    docker_api "containers/$id/stats?stream=false"
}

get_container_info() {
    local id="$1"
    docker_api "containers/$id/json"
}

calculate_moving_average() {
    local container_id="$1"
    local metric_type="$2"
    local current_value="$3"
    
    # Initialize history array if not exists
    if [[ -z "${CPU_HISTORY[$container_id]:-}" ]]; then
        CPU_HISTORY[$container_id]=""
        MEMORY_HISTORY[$container_id]=""
    fi
    
    local history_array
    local history_var="${metric_type}_HISTORY[$container_id]"
    
    # Add current value to history
    if [[ -z "${!history_var:-}" ]]; then
        history_array="$current_value"
    else
        history_array="${!history_var},$current_value"
    fi
    
    # Limit history size
    local history_count=$(echo "$history_array" | tr ',' '\n' | wc -l)
    if [[ $history_count -gt $STATS_HISTORY_COUNT ]]; then
        history_array=$(echo "$history_array" | cut -d',' -f2-)
    fi
    
    # Update history
    eval "$history_var='$history_array'"
    
    # Calculate average
    local sum=0
    local count=0
    IFS=',' read -ra values <<< "$history_array"
    for value in "${values[@]}"; do
        sum=$(echo "$sum + $value" | bc -l)
        count=$((count + 1))
    done
    
    if [[ $count -gt 0 ]]; then
        echo "scale=2; $sum / $count" | bc -l
    else
        echo "$current_value"
    fi
}

update_container_resources() {
    local id="$1"
    local cpu_quota="$2"
    local memory="$3"
    local container_name="$4"
    
    local data="{}"
    local update_type=""
    
    if [[ -n "$cpu_quota" ]]; then
        cpu_quota=$(echo "$cpu_quota" | bc -l | cut -d'.' -f1)
        cpu_quota=$(( cpu_quota > MAX_CPU_QUOTA ? MAX_CPU_QUOTA : cpu_quota ))
        cpu_quota=$(( cpu_quota < MIN_CPU_QUOTA ? MIN_CPU_QUOTA : cpu_quota ))
        
        data=$(echo "$data" | jq --arg cpu "$cpu_quota" '. + {CpuQuota: ($cpu | tonumber)}')
        update_type="CPU"
    fi
    
    if [[ -n "$memory" ]]; then
        memory=$(( memory > MAX_MEMORY_MB * 1024 * 1024 ? MAX_MEMORY_MB * 1024 * 1024 : memory ))
        memory=$(( memory < MIN_MEMORY_MB * 1024 * 1024 ? MIN_MEMORY_MB * 1024 * 1024 : memory ))
        
        data=$(echo "$data" | jq --arg mem "$memory" '. + {Memory: ($mem | tonumber)}')
        update_type="${update_type:+${update_type}+}MEM"
    fi
    
    local response=$(docker_api "containers/$id/update" "POST" "$data" 2>&1)
    local response_code=$?
    
    if [[ $response_code -eq 0 ]]; then
        SCALE_COUNTERS[$container_name]=$((${SCALE_COUNTERS[$container_name]:-0} + 1))
        log_message "SUCCESS" "Scaled $container_name ($update_type): CPU=${cpu_quota:-N/A}, MEM=${memory:-N/A}"
    else
        log_message "ERROR" "Failed to update $container_name: $response"
    fi
}

monitor_container() {
    local container_prefix="$1"
    local container_id=$(get_container_id "$container_prefix")
    
    if [[ -z "$container_id" ]] || [[ "$container_id" == "null" ]]; then
        log_message "WARNING" "Container not found: $container_prefix"
        echo "❌$container_prefix:BULUNAMADI"
        return
    fi
    
    local stats=$(get_container_stats "$container_id")
    if [[ -z "$stats" ]]; then
        log_message "WARNING" "No stats available for: $container_prefix"
        echo "⚠️$container_prefix:STATS_YOK"
        return
    fi

    local info=$(get_container_info "$container_id")
    
    # Parse metrics
    local cpu_usage=$(echo "$stats" | jq '.cpu_stats.cpu_usage.total_usage // 0')
    local system_usage=$(echo "$stats" | jq '.cpu_stats.system_cpu_usage // 0')
    local memory_usage=$(echo "$stats" | jq '.memory_stats.usage // 0')
    local num_cpus=$(echo "$stats" | jq '.cpu_stats.online_cpus // 1')
    local memory_limit=$(echo "$info" | jq '.HostConfig.Memory // 0')
    
    # Calculate CPU percentage
    local cpu_delta=$((cpu_usage - ${PREV_CPU_USAGE[$container_id]:-0}))
    local system_delta=$((system_usage - ${PREV_SYSTEM_USAGE[$container_id]:-0}))
    
    local cpu_percent=0
    if [[ $system_delta -gt 0 ]] && [[ $cpu_delta -gt 0 ]]; then
        cpu_percent=$(echo "scale=2; ($cpu_delta / $system_delta) * $num_cpus * 100" | bc -l)
    fi
    
    # Use moving average for stability
    local avg_cpu_percent=$(calculate_moving_average "$container_id" "CPU" "$cpu_percent")
    local memory_usage_mb=$(echo "scale=2; $memory_usage / 1024 / 1024" | bc -l)
    local avg_memory_mb=$(calculate_moving_average "$container_id" "MEMORY" "$memory_usage_mb")
    
    # Store previous values
    PREV_CPU_USAGE[$container_id]=$cpu_usage
    PREV_SYSTEM_USAGE[$container_id]=$system_usage
    
    # Check cooldown period
    local now=$(date +%s)
    local last_scale_time=${COOLDOWN_TIMESTAMPS[$container_id]:-0}
    local time_since_last_scale=$((now - last_scale_time))
    
    if [[ $time_since_last_scale -lt $COOLDOWN_PERIOD ]]; then
        echo "❄️$container_prefix:${avg_cpu_percent}%/${avg_memory_mb}MB"
        return
    fi
    
    # Get current limits
    local current_cpu_limit=$(echo "$info" | jq '.HostConfig.CpuQuota // 0')
    local current_memory_limit=$memory_limit
    
    # Check scaling conditions
    local scale_actions=""
    
    # CPU scaling
    if [[ $(echo "$avg_cpu_percent > $CPU_THRESHOLD" | bc -l) -eq 1 ]] && 
       [[ $current_cpu_limit -gt 0 ]] && [[ $current_cpu_limit -lt $MAX_CPU_QUOTA ]]; then
        local new_cpu_limit=$(echo "$current_cpu_limit * $SCALE_FACTOR" | bc -l | cut -d'.' -f1)
        update_container_resources "$container_id" "$new_cpu_limit" "" "$container_prefix"
        scale_actions="${scale_actions}⬆️CPU"
        COOLDOWN_TIMESTAMPS[$container_id]=$now
    fi
    
    # Memory scaling
    if [[ $current_memory_limit -gt 0 ]] && [[ $current_memory_limit -lt $((MAX_MEMORY_MB * 1024 * 1024)) ]]; then
        local memory_threshold_bytes=$(echo "$current_memory_limit * $MEMORY_THRESHOLD_PERCENT / 100" | bc -l | cut -d'.' -f1)
        
        if [[ $memory_usage -gt $memory_threshold_bytes ]]; then
            local new_memory_limit=$(echo "$current_memory_limit * $SCALE_FACTOR" | bc -l | cut -d'.' -f1)
            update_container_resources "$container_id" "" "$new_memory_limit" "$container_prefix"
            scale_actions="${scale_actions}⬆️MEM"
            COOLDOWN_TIMESTAMPS[$container_id]=$now
        fi
    fi
    
    local status="✅"
    [[ -n "$scale_actions" ]] && status="🔄"
    
    echo "${status}$container_prefix:${avg_cpu_percent}%/${avg_memory_mb}MB${scale_actions}"
}

main() {
    log_message "INFO" "🚀 Enhanced Auto-Scaler Started"
    log_message "INFO" "📊 Monitoring: ${WATCH_CONTAINERS}"
    log_message "INFO" "⚙️  CPU: ${CPU_THRESHOLD}% | MEM: ${MEMORY_THRESHOLD_PERCENT}% | Cooldown: ${COOLDOWN_PERIOD}s"
    log_message "INFO" "📈 Limits: CPU(${MIN_CPU_QUOTA}-${MAX_CPU_QUOTA}) MEM(${MIN_MEMORY_MB}-${MAX_MEMORY_MB}MB)"
    
    validate_environment
    
    while true; do
        local output=""
        local has_changes=false
        
        IFS=',' read -ra containers <<< "$WATCH_CONTAINERS"
        
        for container_prefix in "${containers[@]}"; do
            local result=$(monitor_container "$container_prefix")
            output="${output}${result} "
            
            # Check if there were changes
            if [[ "$result" == *"🔄"* ]] || [[ "$result" == *"❌"* ]] || [[ "$result" == *"⚠️"* ]]; then
                has_changes=true
            fi
        done
        
        # Log output based on log level
        if [[ "$LOG_LEVEL" == "all" ]] || [[ "$has_changes" == true ]]; then
            log_message "INFO" "Status: $output"
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

# Handle script termination
trap 'log_message "INFO" "Auto-scaler stopped"; exit 0' SIGINT SIGTERM

main "$@"