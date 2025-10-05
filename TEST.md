# Docker Container Yük Testi ve Auto-Scaling Test Dokümanı

## 📋 Genel Bakış

Bu doküman, `sentiric-resource-autoscaler` projesi için kapsamlı yük testi senaryolarını içerir. Testler, PostgreSQL, RabbitMQ, Redis ve Qdrant container'larının auto-scaling davranışını validate etmek için tasarlanmıştır.

## 🎯 Test Edilecek Servisler

- **PostgreSQL**: Veritabanı yük testi
- **RabbitMQ**: Mesaj kuyruğu yük testi  
- **Redis**: Bellek tabanlı önbellek yük testi
- **Qdrant**: Vektör veritabanı yük testi
- **Resource Autoscaler**: Otomatik ölçeklendirme testi

## ⚙️ Ön Gereksinimler

```bash
# Gerekli araçları kurun
sudo apt-get update
sudo apt-get install -y postgresql-client redis-tools jq

# Test script'lerini çalıştırılabilir yapın
chmod +x load-test-*.sh
```

## 📊 Test Senaryoları

### 1. PostgreSQL Yük Testi

**Dosya: `load-test-postgres.sh`**

### 2. RabbitMQ Yük Testi

**Dosya: `load-test-rabbitmq.sh`**

### 3. Redis Yük Testi

**Dosya: `load-test-redis.sh`**

### 4. Qdrant Yük Testi

**Dosya: `load-test-qdrant.sh`**

### 5. Komple Yük Testi

**Dosya: `load-test-all.sh`**

## 📈 Test Sonrası Analiz

### Performans Metrikleri Toplama

**Dosya: `analyze-results.sh`**

## 🚀 Test Çalıştırma

```bash
# Önce monitoring başlat
./monitor-resources.sh

# Sonra testleri çalıştır (yeni terminalde)
./load-test-postgres.sh
./load-test-rabbitmq.sh
./load-test-redis.sh
./load-test-qdrant.sh

# Veya hepsini birden
./load-test-all.sh

# Sonuç analizi
./analyze-results.sh
```

## 📋 Beklenen Çıktılar

1. **Auto-Scaling Etkinliği**: CPU/Memory threshold aşıldığında scaling işlemleri
2. **Performans Metrikleri**: Container resource kullanım istatistikleri
3. **Hata Logları**: Olası hata durumları ve çözüm önerileri
4. **Scaling Kararları**: Resource autoscaler'ın karar logları

## 🔧 Sorun Giderme

```bash
# Container loglarını izle
docker logs -f sentiric-resource-autoscaler-resource-autoscaler-1

# Resource kullanımını gerçek zamanlı izle
docker stats

# Belirli container detayları
docker inspect <container_name>
```

---
# 1. Önce LOG_LEVEL=all yap
docker compose down
# docker-compose.yml'da LOG_LEVEL=all yap
docker compose up -d

# 2. Logları izlemeye başla
docker logs -f sentiric-resource-autoscaler-resource-autoscaler-1

# 3. Agresif testleri çalıştır
./load-test-cpu.sh
./load-test-memory.sh
./load-test-redis-aggressive.sh
./load-test-rabbitmq-aggressive.sh

# 4. Resource usage'ı izle
watch -n 2 'docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"'
