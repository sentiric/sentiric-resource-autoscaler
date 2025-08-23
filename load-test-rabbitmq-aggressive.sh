#!/bin/bash
echo "🚀 RabbitMQ AGGRESİF Yük Testi Başlatılıyor..."

RABBITMQ_USER="sentiric"
RABBITMQ_PASS="sentiric_pass"

# Çok daha fazla mesaj
echo "📨 Çok yoğun mesaj gönderimi (1,000 mesaj/kuyruk)..."
for i in {1..5}; do
    # Kuyruk oluştur
    curl -s -u $RABBITMQ_USER:$RABBITMQ_PASS -X PUT \
        "http://localhost:15672/api/queues/%2F/test_queue_$i" \
        -H "Content-Type: application/json" \
        -d '{"auto_delete":false,"durable":true}' > /dev/null
    
    # ÇOK DAHA FAZLA mesaj gönder
    for j in {1..1000}; do
        curl -s -u $RABBITMQ_USER:$RABBITMQ_PASS -X POST \
            "http://localhost:15672/api/exchanges/%2F/amq.default/publish" \
            -H "Content-Type: application/json" \
            -d "{\"properties\":{},\"routing_key\":\"test_queue_$i\",\"payload\":\"Test message $j from producer $i - $(date)\",\"payload_encoding\":\"string\"}" > /dev/null &
    done
    echo "✅ Kuyruk $i için 1000 mesaj gönderiliyor..."
done

# Consumer'ları çalıştır (mesajları tüket)
echo "👥 Consumer'lar başlatılıyor..."
for i in {1..3}; do
    curl -s -u $RABBITMQ_USER:$RABBITMQ_PASS -X POST \
        "http://localhost:15672/api/queues/%2F/test_queue_$i/get" \
        -H "Content-Type: application/json" \
        -d '{"count":500,"ackmode":"ack_requeue_false","encoding":"auto"}' > /dev/null &
done

echo "✅ RabbitMQ agresif yük testi tamamlandı"