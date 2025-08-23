#!/bin/bash
echo "🚀 CPU Stress Test Başlatılıyor..."

# PostgreSQL'e CPU yükü bindir
echo "🐘 PostgreSQL CPU stress test..."
docker exec -d sentiric-resource-autoscaler-postgres-1 \
    bash -c "while true; do psql -U sentiric -d sentiric_db -c 'SELECT sqrt(random()) * sqrt(random()) * sqrt(random()) FROM generate_series(1,1000000);' > /dev/null 2>&1; done" &

# Redis'e CPU yükü bindir
echo "🧠 Redis CPU stress test..."
docker exec -d sentiric-resource-autoscaler-redis-1 \
    bash -c "while true; do redis-cli EVAL 'local sum = 0; for i=1,1000000 do sum = sum + math.sqrt(i) end; return sum' 0 > /dev/null; done" &

# Qdrant'a CPU yükü bindir
echo "🔍 Qdrant CPU stress test..."
docker exec -d sentiric-resource-autoscaler-qdrant-1 \
    bash -c "while true; do curl -s http://localhost:6333/collections/test_collection > /dev/null; done" &

echo "✅ CPU stress testleri başlatıldı"
echo "⏰ 30 saniye sonra durdurulacak..."

# 30 saniye bekle
sleep 30

# Stress testleri durdur
echo "🛑 Stress testleri durduruluyor..."
docker exec sentiric-resource-autoscaler-postgres-1 pkill -f "psql"
docker exec sentiric-resource-autoscaler-redis-1 pkill -f "redis-cli"
docker exec sentiric-resource-autoscaler-qdrant-1 pkill -f "curl"

echo "✅ CPU stress test tamamlandı"