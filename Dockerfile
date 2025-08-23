### File: `sentiric-resource-autoscaler/Dockerfile`

FROM alpine:3.18

# GÜNCELLEME: dos2unix aracını ekliyoruz.
RUN apk add --no-cache bash curl jq bc dos2unix

COPY resource-autoscaler.sh /usr/local/bin/resource-autoscaler.sh

# GÜNCELLEME: Script üzerinde dos2unix çalıştırarak satır sonlarını garantiliyoruz.
RUN dos2unix /usr/local/bin/resource-autoscaler.sh && \
    chmod +x /usr/local/bin/resource-autoscaler.sh

CMD ["/usr/local/bin/resource-autoscaler.sh"]