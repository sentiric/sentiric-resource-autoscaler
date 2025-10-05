## 🚀 Cloud e2 Serisi için Optimize Edilmiş Ayarlar

### 1. **e2-micro (1 vCPU, 1GB RAM)** - En Düşük Seviye
```yaml
environment:
  - WATCH_CONTAINERS=postgres,rabbitmq,redis,qdrant
  - CPU_THRESHOLD=70               # Daha düşük threshold (sınırlı kaynak)
  - MEMORY_THRESHOLD_PERCENT=80    # Daha agresif memory management
  - CHECK_INTERVAL=20              # Daha uzun check interval (CPU tasarrufu)
  - SCALE_FACTOR=1.3               # Daha küçük scale artışları
  - COOLDOWN_PERIOD=120            # Daha uzun cooldown
  - MAX_MEMORY_MB=768              # 1GB RAM'in %75'i
  - MIN_MEMORY_MB=64               # Minimum memory
  - MAX_CPU_QUOTA=50000            # 1 vCPU = 100000, %50 sınır
  - MIN_CPU_QUOTA=10000            # Minimum CPU
  - LOG_LEVEL=changes              # Sadece değişiklikleri logla
  - STATS_HISTORY_COUNT=3          # Daha az history (memory tasarrufu)
```

### 2. **e2-small (2 vCPU, 2GB RAM)** - Orta Seviye
```yaml
environment:
  - WATCH_CONTAINERS=postgres,rabbitmq,redis,qdrant
  - CPU_THRESHOLD=75               # Standart threshold
  - MEMORY_THRESHOLD_PERCENT=82    # Balanced memory threshold
  - CHECK_INTERVAL=15              # Standart check interval
  - SCALE_FACTOR=1.4               # Orta seviye scale
  - COOLDOWN_PERIOD=90             # Standart cooldown
  - MAX_MEMORY_MB=1536             # 2GB RAM'in %75'i
  - MIN_MEMORY_MB=128              # Minimum memory
  - MAX_CPU_QUOTA=80000            # 2 vCPU = 200000, %40 sınır
  - MIN_CPU_QUOTA=15000            # Minimum CPU
  - LOG_LEVEL=changes              # Sadece değişiklikleri logla
  - STATS_HISTORY_COUNT=4          # Orta seviye history
```

### 3. **e2-medium (2 vCPU, 4GB RAM)** - Önerilen Başlangıç
```yaml
environment:
  - WATCH_CONTAINERS=postgres,rabbitmq,redis,qdrant
  - CPU_THRESHOLD=78               # Biraz daha yüksek threshold
  - MEMORY_THRESHOLD_PERCENT=85    # Standart memory threshold
  - CHECK_INTERVAL=15              # Standart check interval
  - SCALE_FACTOR=1.5               # Standart scale faktör
  - COOLDOWN_PERIOD=75             # Biraz daha kısa cooldown
  - MAX_MEMORY_MB=3072             # 4GB RAM'in %75'i
  - MIN_MEMORY_MB=256              # Daha yüksek minimum memory
  - MAX_CPU_QUOTA=120000           # 2 vCPU = 200000, %60 sınır
  - MIN_CPU_QUOTA=20000            # Minimum CPU
  - LOG_LEVEL=changes              # Sadece değişiklikleri logla
  - STATS_HISTORY_COUNT=5          # Standart history
```

### 4. **e2-standard-2 (2 vCPU, 8GB RAM)** - Production için
```yaml
environment:
  - WATCH_CONTAINERS=postgres,rabbitmq,redis,qdrant
  - CPU_THRESHOLD=80               # Production threshold
  - MEMORY_THRESHOLD_PERCENT=87    # Yüksek memory threshold
  - CHECK_INTERVAL=10              # Daha sık check
  - SCALE_FACTOR=1.6               # Daha agresif scale
  - COOLDOWN_PERIOD=60             # Daha kısa cooldown
  - MAX_MEMORY_MB=6144             # 8GB RAM'in %75'i
  - MIN_MEMORY_MB=512              # Yüksek minimum memory
  - MAX_CPU_QUOTA=160000           # 2 vCPU = 200000, %80 sınır
  - MIN_CPU_QUOTA=30000            # Daha yüksek minimum CPU
  - LOG_LEVEL=changes              # Sadece değişiklikleri logla
  - STATS_HISTORY_COUNT=6          # Daha fazla history
```

## 📊 e2 Serisi Özellik Tablosu

| Makine Tipi | vCPU | RAM  | MAX_MEMORY_MB | MAX_CPU_QUOTA | Önerilen Kullanım |
|-------------|------|------|---------------|---------------|-------------------|
| e2-micro    | 1    | 1GB  | 768           | 50000         | Geliştirme/Test   |
| e2-small    | 2    | 2GB  | 1536          | 80000         | Küçük Uygulamalar |
| e2-medium   | 2    | 4GB  | 3072          | 120000        | Production Başlangıç |
| e2-standard-2 | 2  | 8GB  | 6144          | 160000        | Production        |

## 🎯 Container Bazlı Optimize Ayarlar

**Docker Compose Örneği:**
```yaml
resource-autoscaler:
  build: 
    context: ../sentiric-resource-autoscaler
  env_file: ["${ENV_FILE_PATH}"]     
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
  environment:
    - WATCH_CONTAINERS=postgres,rabbitmq,redis,qdrant
    - CPU_THRESHOLD=75
    - MEMORY_THRESHOLD_PERCENT=85
    - CHECK_INTERVAL=15
    - SCALE_FACTOR=1.5
    - COOLDOWN_PERIOD=90
    - MAX_MEMORY_MB=3072    # e2-medium için
    - MIN_MEMORY_MB=256     # e2-medium için
    - MAX_CPU_QUOTA=120000  # e2-medium için
    - MIN_CPU_QUOTA=20000   # e2-medium için
    - LOG_LEVEL=changes
    - STATS_HISTORY_COUNT=5
  deploy:
    resources:
      limits:
        memory: "512M"      # Autoscaler'ın kendi limiti
        cpus: "0.5"
      reservations:
        memory: "256M"
        cpus: "0.25"
```

## 🔧 Environment Bazlı Config Template

**`autoscaler-config.sh`**:
```bash
#!/bin/bash
# Machine type detection and auto-config
MACHINE_TYPE=${MACHINE_TYPE:-"e2-medium"}

case $MACHINE_TYPE in
    "e2-micro")
        export CPU_THRESHOLD=70
        export MEMORY_THRESHOLD_PERCENT=80
        export MAX_MEMORY_MB=768
        export MAX_CPU_QUOTA=50000
        ;;
    "e2-small")
        export CPU_THRESHOLD=75
        export MEMORY_THRESHOLD_PERCENT=82
        export MAX_MEMORY_MB=1536
        export MAX_CPU_QUOTA=80000
        ;;
    "e2-medium")
        export CPU_THRESHOLD=78
        export MEMORY_THRESHOLD_PERCENT=85
        export MAX_MEMORY_MB=3072
        export MAX_CPU_QUOTA=120000
        ;;
    "e2-standard-2")
        export CPU_THRESHOLD=80
        export MEMORY_THRESHOLD_PERCENT=87
        export MAX_MEMORY_MB=6144
        export MAX_CPU_QUOTA=160000
        ;;
    *)
        echo "Unknown machine type: $MACHINE_TYPE"
        exit 1
        ;;
esac

echo "Configured for $MACHINE_TYPE:"
echo "CPU_THRESHOLD=$CPU_THRESHOLD"
echo "MEMORY_THRESHOLD_PERCENT=$MEMORY_THRESHOLD_PERCENT"
echo "MAX_MEMORY_MB=$MAX_MEMORY_MB"
echo "MAX_CPU_QUOTA=$MAX_CPU_QUOTA"
```

## 🚀 Kullanım

```bash
# Environment variable ile machine type belirle
export MACHINE_TYPE="e2-medium"
docker compose up -d

# Veya direkt compose dosyasında
environment:
  - MACHINE_TYPE=e2-medium
```

Bu ayarlar, her e2 makine tipinin kaynak kapasitesine göre optimize edilmiştir. Production için `e2-medium` veya üzeri önerilir. 🎯