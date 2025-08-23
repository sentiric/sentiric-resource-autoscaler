#!/bin/bash
echo "🚀 PostgreSQL Yük Testi Başlatılıyor..."

# Config yükle
if [ -f ./load-test-config.sh ]; then
    source ./load-test-config.sh
fi

# Değişkenler (default values)
PG_CONTAINER="sentiric-resource-autoscaler-postgres-1"
PG_USER=${POSTGRES_USER:-postgres}  # postgres kullanıcısını deneyelim
PG_PASSWORD=${POSTGRES_PASSWORD:-postgres}
PG_DB=${POSTGRES_DB:-postgres}

echo "📊 Using: User=$PG_USER, DB=$PG_DB"

# Önce PostgreSQL'in hazır olup olmadığını kontrol et
echo "⏳ PostgreSQL hazırlanıyor..."
until docker exec $PG_CONTAINER pg_isready -U $PG_USER -d $PG_DB; do
    echo "PostgreSQL hazır değil, bekleniyor..."
    sleep 2
done

# Test verisi oluştur (şifre ile connection)
echo "🧪 Test veritabanı ve tabloları oluşturuluyor..."
docker exec -i $PG_CONTAINER bash -c "
export PGPASSWORD='$PG_PASSWORD'
psql -U $PG_USER -d $PG_DB << 'EOSQL'
CREATE TABLE IF NOT EXISTS load_test_users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100),
    email VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS load_test_metrics (
    id SERIAL PRIMARY KEY,
    metric_name VARCHAR(100),
    metric_value NUMERIC(10,2),
    recorded_at TIMESTAMP DEFAULT NOW()
);
EOSQL
"

# Paralel yük testi
echo "⚡ Paralel yük testi başlatılıyor..."
for i in {1..3}; do
  (
    echo "Thread $i çalışıyor..."
    for j in {1..20}; do
      docker exec -i $PG_CONTAINER bash -c "
export PGPASSWORD='$PG_PASSWORD'
psql -U $PG_USER -d $PG_DB << 'SQL'
INSERT INTO load_test_users (username, email) 
VALUES ('user_${i}_${j}', 'user_${i}_${j}@test.com');

INSERT INTO load_test_metrics (metric_name, metric_value)
VALUES ('cpu_usage', $RANDOM % 100),
       ('memory_usage', $RANDOM % 1024),
       ('response_time', $RANDOM % 500);
SQL
"
    done
  ) &
done

wait
echo "✅ PostgreSQL yük testi tamamlandı"