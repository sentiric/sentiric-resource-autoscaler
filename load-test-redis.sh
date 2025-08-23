#!/bin/bash
echo "🚀 Redis Yük Testi Başlatılıyor..."

# Config yükle
source ./load-test-config.sh

# Değişkenler
REDIS_CONTAINER="sentiric-resource-autoscaler-redis-1"

# Yoğun yazma işlemleri
echo "📝 Yoğun yazma işlemleri..."
for i in {1..2000}; do
  docker exec $REDIS_CONTAINER redis-cli SET "key:$i" "value:$(date +%s%N)" > /dev/null
  if (( $i % 500 == 0 )); then
    echo "⏩ $i key yazıldı..."
  fi
done

# Yoğun okuma işlemleri
echo "📖 Yoğun okuma işlemleri..."
for i in {1..1000}; do
  docker exec $REDIS_CONTAINER redis-cli GET "key:$((RANDOM % 2000 + 1))" > /dev/null
done

echo "✅ Redis yük testi tamamlandı"