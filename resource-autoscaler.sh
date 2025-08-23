#!/bin/bash

WATCH_CONTAINERS=${WATCH_CONTAINERS:-"api-gateway,sip-gateway"}
# MAX_MEMORY_MB=${MAX_MEMORY_MB:-256} # Artık kullanılmıyor
CPU_THRESHOLD=${CPU_THRESHOLD:-80}
MEMORY_THRESHOLD_PERCENT=${MEMORY_THRESHOLD_PERCENT:-90} # YENİ: Bellek eşiği yüzdesi
CHECK_INTERVAL=${CHECK_INTERVAL:-15}
SCALE_FACTOR=${SCALE_FACTOR:-1.5}
COOLDOWN_PERIOD=${COOLDOWN_PERIOD:-60} # YENİ: Saniye cinsinden soğuma süresi
DOCKER_SOCK="/var/run/docker.sock"
LOG_LEVEL=${LOG_LEVEL:-"changes"} # "all" veya "changes"

echo "🚀 Oto-scale başladı (${WATCH_CONTAINERS})"
echo "📊 Log seviyesi: ${LOG_LEVEL}"

# Docker API fonksiyonları
docker_api() {
    local endpoint="$1"
    # Timeout ekleyerek Docker soketinin yanıt vermemesi durumunu yönetelim
    curl -s --max-time 5 --unix-socket "$DOCKER_SOCK" "http://localhost/$endpoint"
}

get_container_id() {
    local name="$1"
    # YENİ: Daha esnek eşleştirme. Örn: 'dialplan-service' -> 'sentiric-dev-core-dialplan-service-1'
    docker_api "containers/json" | jq -r --arg name "$name" '.[] | select(.Names[] | test($name + "(-[0-9]+)?$")) | .Id' | head -n 1
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
    
    # Güncelleme işleminin sonucunu kontrol et
    response_code=$(curl -s -o /dev/null -w "%{http_code}" --unix-socket "$DOCKER_SOCK" -X POST \
        -H "Content-Type: application/json" \
        -d "$data" \
        "http://localhost/containers/$id/update")
    
    if [ "$response_code" -ne 200 ]; then
        echo "[$(date +'%H:%M:%S')] ❌ HATA: Konteyner güncellenemedi. ID: $id, HTTP Kodu: $response_code"
    fi
}

# Önceki değerleri ve cooldown zamanlarını saklamak için
declare -A prev_cpu_usage
declare -A prev_system_usage
declare -A prev_cpu_percent
declare -A prev_memory_usage
declare -A prev_scale_actions
declare -A cooldown_timestamps

while true; do
    output=""
    has_changes=false
    has_scale_actions=false
    IFS=',' read -ra containers <<< "$WATCH_CONTAINERS"
    
    for container_prefix in "${containers[@]}"; do
        container_id=$(get_container_id "$container_prefix")
        if [ -z "$container_id" ] || [ "$container_id" = "null" ]; then
            output="${output}❌${container_prefix}:BULUNAMADI "
            has_changes=true
            continue
        fi
        
        stats=$(get_container_stats "$container_id")
        info=$(get_container_info "$container_id")
        
        cpu_usage=$(echo "$stats" | jq '.cpu_stats.cpu_usage.total_usage')
        system_usage=$(echo "$stats" | jq '.cpu_stats.system_cpu_usage')
        memory_usage=$(echo "$stats" | jq '.memory_stats.usage')
        
        memory_usage_mb=$(echo "scale=2; $memory_usage / 1024 / 1024" | bc)
        
        cpu_delta=$(echo "$cpu_usage - ${prev_cpu_usage[$container_id]:-0}" | bc)
        system_delta=$(echo "$system_usage - ${prev_system_usage[$container_id]:-0}" | bc)
        
        num_cpus=$(echo "$stats" | jq '.cpu_stats.online_cpus // 1')

        if [ "$system_delta" -gt 0 ] && [ "$cpu_delta" -gt 0 ]; then
             cpu_percent=$(echo "scale=2; ($cpu_delta / $system_delta) * $num_cpus * 100" | bc)
        else
            cpu_percent=0
        fi

        cpu_diff=$(echo "scale=2; $cpu_percent - ${prev_cpu_percent[$container_id]:-0}" | bc | awk '{if ($1 < 0) print -$1; else print $1}')
        mem_diff=$(echo "scale=2; $memory_usage_mb - ${prev_memory_usage[$container_id]:-0}" | bc | awk '{if ($1 < 0) print -$1; else print $1}')
        
        if [ $(echo "$cpu_diff > 1" | bc -l) -eq 1 ] || [ $(echo "$mem_diff > 1" | bc -l) -eq 1 ]; then
            has_changes=true
        fi
        
        prev_cpu_usage[$container_id]=$cpu_usage
        prev_system_usage[$container_id]=$system_usage
        prev_cpu_percent[$container_id]=$cpu_percent
        prev_memory_usage[$container_id]=$memory_usage_mb
        
        current_cpu_limit=$(echo "$info" | jq '.HostConfig.CpuQuota')
        current_memory_limit=$(echo "$info" | jq '.HostConfig.Memory')
        
        scale_actions=""

        # Cooldown kontrolü
        now=$(date +%s)
        last_scale_time=${cooldown_timestamps[$container_id]:-0}
        if (( now - last_scale_time < COOLDOWN_PERIOD )); then
             output="${output}❄️ ${container_prefix}:${cpu_percent}%/${memory_usage_mb}MB "
             continue # Soğuma periyodunda ise bu konteyneri atla
        fi
        
        # CPU Scale kontrolü
        if [ $(echo "$cpu_percent > $CPU_THRESHOLD" | bc -l) -eq 1 ] && [ "$current_cpu_limit" != "null" ] && [ "$current_cpu_limit" -gt 0 ]; then
            new_cpu_limit=$(echo "$current_cpu_limit * $SCALE_FACTOR" | bc | cut -d'.' -f1)
            update_container_resources "$container_id" "$new_cpu_limit" ""
            scale_actions="${scale_actions}⬆️ CPU"
            has_scale_actions=true; has_changes=true; cooldown_timestamps[$container_id]=$now
        fi
        
        # Bellek Scale kontrolü (YENİ MANTIK)
        if [ "$current_memory_limit" != "null" ] && [ "$current_memory_limit" -gt 0 ]; then
            memory_threshold_bytes=$(echo "$current_memory_limit * $MEMORY_THRESHOLD_PERCENT / 100" | bc | cut -d'.' -f1)
            if [ "$memory_usage" -gt "$memory_threshold_bytes" ]; then
                new_memory_limit=$(echo "$current_memory_limit * $SCALE_FACTOR" | bc | cut -d'.' -f1)
                update_container_resources "$container_id" "" "$new_memory_limit"
                scale_actions="${scale_actions}⬆️ MEM"
                has_scale_actions=true; has_changes=true; cooldown_timestamps[$container_id]=$now
            fi
        fi

        status="✅ "
        [ -n "$scale_actions" ] && status="🔄"
        
        if [ "${prev_scale_actions[$container_id]}" != "$scale_actions" ]; then
            has_changes=true
        fi
        prev_scale_actions[$container_id]=$scale_actions
        
        output="${output}${status}${container_prefix}:${cpu_percent}%/${memory_usage_mb}MB${scale_actions} "
    done
    
    if [ "$LOG_LEVEL" = "all" ] || [ "$has_changes" = true ]; then
        echo "[$(date +'%H:%M:%S')] ${output}"
    fi
    
    sleep "$CHECK_INTERVAL"
done