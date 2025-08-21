FROM alpine:3.18

RUN apk add --no-cache bash curl jq bc

COPY resource-autoscaler.sh /usr/local/bin/resource-autoscaler.sh
RUN chmod +x /usr/local/bin/resource-autoscaler.sh

CMD ["/usr/local/bin/resource-autoscaler.sh"]