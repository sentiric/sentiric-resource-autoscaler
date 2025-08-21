#!/bin/bash

WATCH_CONTAINERS=${WATCH_CONTAINERS:-"api-gateway,sip-gateway"}
MAX_MEMORY_MB=${MAX_MEMORY_MB:-256}
CPU_THRESHOLD=${CPU_THRESHOLD:-80}
CHECK_INTERVAL=${CHECK_INTERVAL:-10}
SCALE_FACTOR=${SCALE_FACTOR:-1.5}
DOCKER_SOCK="/var/run/docker.sock"

echo "🚀 Oto-scale başladı (${WATCH_CONTAINERS})"

# Docker API fonksiyonları
docker_api() {
    local endpoint="$1"
    curl -s --unix-socket "$DOCKER_SOCK" "http://localhost/$endpoint"
}

get_container_id() {
    local name="$1"
    docker_api "containers/json" | jq -r --arg name "$name" '.[] | select(.Names[] | contains($name)) | .Id'
}

get_container_stats() {
    local id="$1"
    docker_api "containers/$id/stats?stream=false"
}

get_container_info() {
    local id="$1"
    docker_api "containers/$id/json"
}

update_container_resources() {
    local id="$1" cpu_quota="$2" memory="$3"
    local data="{}"
    
    if [ -n "$cpu_quota" ]; then
        data=$(echo "$data" | jq --arg cpu "$cpu_quota" '. + {CpuQuota: $cpu|tonumber}')
    fi
    
    if [ -n "$memory" ]; then
        data=$(echo "$data" | jq --arg mem "$memory" '. + {Memory: $mem|tonumber}')
    fi
    
    curl -s --unix-socket "$DOCKER_SOCK" -X POST \
        -H "Content-Type: application/json" \
        -d "$data" \
        "http://localhost/containers/$id/update" >/dev/null 2>&1
}

# Önceki değerleri saklamak için
declare -A prev_cpu_usage
declare -A prev_system_usage

while true; do
    output=""
    IFS=',' read -ra containers <<< "$WATCH_CONTAINERS"
    
    for container_prefix in "${containers[@]}"; do
        # Container ID'yi bul
        container_id=$(get_container_id "$container_prefix")
        if [ -z "$container_id" ] || [ "$container_id" = "null" ]; then
            output="${output}❌${container_prefix}:BULUNAMADI "
            continue
        fi
        
        # Stats al
        stats=$(get_container_stats "$container_id")
        info=$(get_container_info "$container_id")
        
        # CPU ve Memory kullanımı
        cpu_usage=$(echo "$stats" | jq '.cpu_stats.cpu_usage.total_usage')
        system_usage=$(echo "$stats" | jq '.cpu_stats.system_cpu_usage')
        memory_usage=$(echo "$stats" | jq '.memory_stats.usage')
        memory_limit=$(echo "$stats" | jq '.memory_stats.limit')
        
        # MB cinsinden
        memory_usage_mb=$(echo "scale=2; $memory_usage / 1024 / 1024" | bc)
        memory_limit_mb=$(echo "scale=2; $memory_limit / 1024 / 1024" | bc)
        
        # CPU yüzdesi hesapla
        cpu_delta=$(echo "$cpu_usage - ${prev_cpu_usage[$container_id]:-0}" | bc)
        system_delta=$(echo "$system_usage - ${prev_system_usage[$container_id]:-0}" | bc)
        
        if [ $system_delta -gt 0 ] && [ $cpu_delta -gt 0 ]; then
            cpu_percent=$(echo "scale=2; ($cpu_delta / $system_delta) * 100" | bc)
        else
            cpu_percent=0
        fi
        
        prev_cpu_usage[$container_id]=$cpu_usage
        prev_system_usage[$container_id]=$system_usage
        
        # Mevcut limitler
        current_cpu_limit=$(echo "$info" | jq '.HostConfig.NanoCpus')
        current_memory_limit=$(echo "$info" | jq '.HostConfig.Memory')
        
        scale_actions=""
        
        # CPU Scale kontrolü
        if [ $(echo "$cpu_percent > $CPU_THRESHOLD" | bc -l) -eq 1 ] && [ "$current_cpu_limit" != "null" ]; then
            new_cpu_limit=$(echo "$current_cpu_limit * $SCALE_FACTOR" | bc | cut -d'.' -f1)
            update_container_resources "$container_id" "$new_cpu_limit" ""
            scale_actions="${scale_actions}⬆️ CPU($(echo "scale=2; $new_cpu_limit / 1000000000" | bc))"
        fi
        
        # Memory Scale kontrolü
        if [ $(echo "$memory_usage_mb > $MAX_MEMORY_MB" | bc -l) -eq 1 ] && [ "$current_memory_limit" != "null" ]; then
            new_memory_limit=$(echo "$current_memory_limit * $SCALE_FACTOR" | bc | cut -d'.' -f1)
            update_container_resources "$container_id" "" "$new_memory_limit"
            scale_actions="${scale_actions}⬆️ MEM($(echo "scale=0; $new_memory_limit / 1024 / 1024" | bc)MB)"
        fi
        
        status="✅ "
        [ -n "$scale_actions" ] && status="🔄"
        
        output="${output}${status}${container_prefix}:${cpu_percent}%/${memory_usage_mb}MB${scale_actions} "
    done
    
    # Tüm container'ları tek satırda göster
    echo "[$(date +'%H:%M:%S')] ${output}"
    sleep $CHECK_INTERVAL
done