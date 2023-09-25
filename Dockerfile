FROM konstruktoid/alpine:latest

LABEL maintainer='Thomas Sjögren <konstruktoid@users.noreply.github.com>' \
      vcs-url='git@github.com:konstruktoid/container-nginx-build.git'

RUN apk --no-cache add curl nginx && \
    rm -rf /var/cache/apk/ && \
    mkdir -p /run/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

HEALTHCHECK --interval=5m --timeout=3s \
   CMD curl -f 127.0.0.1 || exit 1

EXPOSE 80 443

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/usr/sbin/nginx"]
CMD ["-g", "daemon off;"]
