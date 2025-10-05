#!/bin/bash
echo "🚀 Qdrant Yük Testi Başlatılıyor..."

# Değişkenler
QDRANT_CONTAINER="sentiric-resource-autoscaler-qdrant-1"
QDRANT_HOST="localhost"
QDRANT_PORT=6333

# curl ile Qdrant API testi
echo "📡 Qdrant API testi..."

# Koleksiyon oluştur
echo "🆕 Koleksiyon oluşturuluyor..."
curl -X PUT "http://localhost:6333/collections/test_collection" \
    -H "Content-Type: application/json" \
    -d '{
        "vectors": {
            "size": 4,
            "distance": "Cosine"
        }
    }'

# Vektörler ekle
echo "📊 Vektörler ekleniyor..."
for i in {1..50}; do
    curl -X PUT "http://localhost:6333/collections/test_collection/points?wait=true" \
        -H "Content-Type: application/json" \
        -d "{
            \"points\": [
                {
                    \"id\": $i,
                    \"vector\": [$(echo "scale=4; $RANDOM/32767" | bc), $(echo "scale=4; $RANDOM/32767" | bc), $(echo "scale=4; $RANDOM/32767" | bc), $(echo "scale=4; $RANDOM/32767" | bc)],
                    \"payload\": {\"color\": \"red\", \"value\": $i}
                }
            ]
        }" > /dev/null 2>&1
done

# Arama testi
echo "🔍 Arama testi yapılıyor..."
for i in {1..10}; do
    curl -X POST "http://localhost:6333/collections/test_collection/points/search" \
        -H "Content-Type: application/json" \
        -d "{
            \"vector\": [0.1, 0.2, 0.3, 0.4],
            \"limit\": 3
        }" > /dev/null 2>&1
done

# İstatistikleri al
echo "📈 Qdrant istatistikleri:"
curl -s "http://localhost:6333/collections/test_collection" | jq '.'

echo "✅ Qdrant yük testi tamamlandı"