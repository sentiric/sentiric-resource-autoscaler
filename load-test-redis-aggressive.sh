#!/bin/bash
echo "🚀 Redis AGGRESİF Yük Testi Başlatılıyor..."

REDIS_CONTAINER="sentiric-resource-autoscaler-redis-1"

# ÇOK DAHA YOĞUN yazma işlemleri
echo "📝 Çok yoğun yazma işlemleri (50,000 key)..."
for i in {1..50000}; do
  docker exec $REDIS_CONTAINER redis-cli SET "key:$i" "value:$(date +%s%N)" > /dev/null
  if (( $i % 5000 == 0 )); then
    echo "⏩ $i key yazıldı..."
  fi
done

# ÇOK YOĞUN okuma işlemleri
echo "📖 Çok yoğun okuma işlemleri (20,000 read)..."
for i in {1..20000}; do
  docker exec $REDIS_CONTAINER redis-cli GET "key:$((RANDOM % 50000 + 1))" > /dev/null
done

# Büyük data yükleme
echo "💾 Büyük data yükleme (1MB values)..."
for i in {1..100}; do
  docker exec $REDIS_CONTAINER bash -c "
    dd if=/dev/urandom bs=1024 count=1024 2>/dev/null | base64 -w 0 | head -c 1048576 > /tmp/large_data.txt
    redis-cli SET large_data:$i \"\$(cat /tmp/large_data.txt)\"
  "
  echo "✅ 1MB data $i yüklendi"
done

echo "✅ Redis agresif yük testi tamamlandı"