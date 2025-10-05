FROM alpine:3.18

# Gerekli paketleri kurun
RUN apk add --no-cache bash curl jq bc coreutils

# Script'i kopyala
COPY resource-autoscaler.sh /usr/local/bin/resource-autoscaler.sh

# Script'i çalıştırılabilir yap ve satır sonlarını düzelt
RUN chmod +x /usr/local/bin/resource-autoscaler.sh && \
    sed -i 's/\r$//' /usr/local/bin/resource-autoscaler.sh

# Entrypoint olarak script'i ayarla
ENTRYPOINT ["/usr/local/bin/resource-autoscaler.sh"]