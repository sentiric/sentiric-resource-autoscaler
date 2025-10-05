#!/bin/bash
echo "📊 Test Sonuçları Analizi..."

# Log dosyası
LOG_FILE=${1:-load-test-*.log}

echo "=== DOCKER CONTAINER STATS ==="
docker stats --no-stream

echo ""
echo "=== AUTO-SCALER LOGS ==="
docker logs sentiric-resource-autoscaler-resource-autoscaler-1 | tail -20

echo ""
echo "=== RESOURCE USAGE SUMMARY ==="
if [ -f "$LOG_FILE" ]; then
    echo "📈 CPU Kullanımı:"
    grep "CPU" "$LOG_FILE" | tail -5
    
    echo ""
    echo "💾 Bellek Kullanımı:"
    grep "MEM" "$LOG_FILE" | tail -5
    
    echo ""
    echo "🔄 Scaling Olayları:"
    grep -E "(SCALED|🔄|⬆️)" "$LOG_FILE"
fi