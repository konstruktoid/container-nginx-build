FROM konstruktoid/alpine:latest@sha256:3f47343c0873bce996c9bd6d336b44e41faa77b86558a90e213eb8da644199de

LABEL org.opencontainers.image.title="nginx" \
      org.opencontainers.image.description="Nginx HTTP and reverse proxy server" \
      org.opencontainers.image.authors="Thomas Sjögren <konstruktoid@users.noreply.github.com>" \
      org.opencontainers.image.source="https://github.com/konstruktoid/container-nginx-build" \
      org.opencontainers.image.url="http://nginx.org/" \
      org.opencontainers.image.base.name="docker.io/konstruktoid/alpine:latest"

COPY files/default.conf /etc/nginx/http.d/default.conf

# --no-cache leaves no index behind, so there is no /var/cache/apk to remove.
RUN apk --no-cache add curl nginx && \
    mkdir -p /run/nginx && \
    chown -R nginx:nginx /run/nginx /var/lib/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

HEALTHCHECK --interval=1m --timeout=3s --start-period=15s \
  CMD ["curl", "--fail", "--silent", "--show-error", "http://127.0.0.1/healthz"]

EXPOSE 80 443

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/usr/sbin/nginx"]
CMD ["-g", "daemon off;"]
