#!/bin/bash
echo "🚀 Memory Stress Test Başlatılıyor..."

# Redis'e büyük memory yükü
echo "🧠 Redis memory stress test..."
for i in {1..50}; do
    docker exec sentiric-resource-autoscaler-redis-1 \
        redis-cli SET "large_memory_$i" "$(dd if=/dev/urandom bs=1024 count=1024 2>/dev/null | base64 -w 0)" > /dev/null
    echo "✅ 1MB memory data $i yüklendi"
done

# PostgreSQL'e büyük tablo
echo "🐘 PostgreSQL memory stress test..."
docker exec -i sentiric-resource-autoscaler-postgres-1 bash -c "
export PGPASSWORD='sentiric_pass'
psql -U sentiric -d sentiric_db << 'SQL'
CREATE TABLE IF NOT EXISTS memory_stress_test (
    id SERIAL PRIMARY KEY,
    large_data TEXT
);

INSERT INTO memory_stress_test (large_data)
SELECT repeat('X', 1024 * 1024) 
FROM generate_series(1, 20);
SQL
"

echo "✅ Memory stress test tamamlandı"