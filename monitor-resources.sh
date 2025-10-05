#!/bin/bash
echo "📊 Container Resource Monitoring Başlatılıyor..."

watch -n 5 '
echo "=== $(date) ==="
echo "🐳 CONTAINER RESOURCE USAGE:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | head -10
echo ""
echo "🔍 AUTO-SCALER ACTIVITY:"
docker logs sentiric-resource-autoscaler-resource-autoscaler-1 2>&1 | tail -5
echo ""
echo "📈 RABBITMQ QUEUES:"
curl -s -u guest:guest "http://localhost:15672/api/queues" | jq -r ".[].name" | head -5
'
