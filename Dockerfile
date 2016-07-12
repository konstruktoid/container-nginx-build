FROM konstruktoid/alpine:latest

RUN apk update && \
    apk upgrade && \
    apk --update add curl nginx && \
    rm -rf /var/cache/apk/ && \
    mkdir -p /run/nginx

# HEALTHCHECK --interval=5m --timeout=3s \
#    CMD curl -f http://127.0.0.1/ || exit 1

EXPOSE 80 443

ENTRYPOINT ["/usr/sbin/nginx"]
CMD ["-g", "daemon off;"]
