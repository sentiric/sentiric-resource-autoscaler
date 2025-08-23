#!/bin/bash
# load-test-config.sh
# Environment variables yükleniyor

# .env dosyasını yükle
if [ -f ../.env ]; then
    # Docker Compose formatındaki .env dosyasını yükle
    while IFS= read -r line; do
        # Yorum satırlarını ve boş satırları atla
        if [[ ! "$line" =~ ^# ]] && [[ ! -z "$line" ]]; then
            # Değişkeni export et
            export "$line"
        fi
    done < ../.env
elif [ -f .env ]; then
    while IFS= read -r line; do
        if [[ ! "$line" =~ ^# ]] && [[ ! -z "$line" ]]; then
            export "$line"
        fi
    done < .env
fi

# Debug için
echo "🔍 Loaded environment:"
echo "POSTGRES_USER: ${POSTGRES_USER:-not set}"
echo "POSTGRES_DB: ${POSTGRES_DB:-not set}"
echo "----------------------------------------"