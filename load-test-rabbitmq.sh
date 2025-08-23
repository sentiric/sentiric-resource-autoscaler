#!/bin/bash
echo "🚀 RabbitMQ Yük Testi Başlatılıyor..."

# Config yükle
source ./load-test-config.sh

# Değişkenler
RABBITMQ_USER=$RABBITMQ_DEFAULT_USER
RABBITMQ_PASS=$RABBITMQ_DEFAULT_PASS

echo "📊 Using: User=$RABBITMQ_USER"

# RabbitMQ management API ile test
echo "📊 RabbitMQ management API ile test ediliyor..."

# Kuyruk oluştur ve mesaj gönder
echo "📨 Kuyruk oluşturuluyor ve mesajlar gönderiliyor..."
for i in {1..3}; do
    # Kuyruk oluştur
    curl -s -u $RABBITMQ_USER:$RABBITMQ_PASS -X PUT \
        "http://localhost:15672/api/queues/%2F/test_queue_$i" \
        -H "Content-Type: application/json" \
        -d '{"auto_delete":false,"durable":true}' > /dev/null
    
    # Mesaj gönder
    for j in {1..30}; do
        curl -s -u $RABBITMQ_USER:$RABBITMQ_PASS -X POST \
            "http://localhost:15672/api/exchanges/%2F/amq.default/publish" \
            -H "Content-Type: application/json" \
            -d "{\"properties\":{},\"routing_key\":\"test_queue_$i\",\"payload\":\"Test message $j from producer $i\",\"payload_encoding\":\"string\"}" > /dev/null
    done
    echo "✅ Kuyruk $i için 30 mesaj gönderildi"
done

echo "✅ RabbitMQ yük testi tamamlandı"