#!/bin/bash
echo "🎯 Tüm Servisler için Komple Yük Testi Başlatılıyor..."

# Config yükle
source ./load-test-config.sh

# Log dosyası
LOG_FILE="load-test-$(date +%Y%m%d-%H%M%S).log"
echo "📝 Loglar: $LOG_FILE"

echo "📊 Environment Variables:"
echo "POSTGRES_USER: $POSTGRES_USER"
echo "RABBITMQ_USER: $RABBITMQ_DEFAULT_USER"
echo "----------------------------------------"

# Resource kullanımını izle
monitor_resources() {
    echo "📊 Resource kullanımı izleniyor..."
    while true; do
        echo "=== $(date) ===" >> $LOG_FILE
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" >> $LOG_FILE
        echo "" >> $LOG_FILE
        sleep 10
    done
}

# İzlemeyi arka planda başlat
monitor_resources &
MONITOR_PID=$!

# Tüm testleri paralel çalıştır
echo "⚡ Tüm yük testleri paralel çalıştırılıyor..."
./load-test-postgres.sh >> $LOG_FILE 2>&1 &
./load-test-rabbitmq.sh >> $LOG_FILE 2>&1 &
./load-test-redis.sh >> $LOG_FILE 2>&1 &
./load-test-qdrant.sh >> $LOG_FILE 2>&1 &

# Tüm testlerin bitmesini bekle
wait

# İzlemeyi durdur
kill $MONITOR_PID

echo "✅ Tüm yük testleri tamamlandı!"
echo "📊 Log dosyası: $LOG_FILE"

# Auto-scaling sonuçlarını göster
echo "🎯 Auto-Scaling Sonuçları:"
docker logs sentiric-resource-autoscaler-resource-autoscaler-1 | grep -E "(SCALED|🔄|⬆️)" | tail -10