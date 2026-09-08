FROM konstruktoid/alpine:latest@sha256:3a1ce60835cb22f26e58e8a1c06fdb77a9acda710c5f9d343b1c35b62d2a6c6f

LABEL org.opencontainers.image.title="nginx" \
      org.opencontainers.image.description="Nginx HTTP and reverse proxy server" \
      org.opencontainers.image.authors="Thomas Sjögren <konstruktoid@users.noreply.github.com>" \
      org.opencontainers.image.source="https://github.com/konstruktoid/container-nginx-build" \
      org.opencontainers.image.url="https://nginx.org/" \
      org.opencontainers.image.base.name="docker.io/konstruktoid/alpine:latest"

COPY files/default.conf /etc/nginx/http.d/default.conf

# --no-cache leaves no index behind, so there is no /var/cache/apk to remove.
# The packages are deliberately unpinned: the image exists to carry the newest
# patched package set. See "Reproducibility" in README.md.
#
# The "user nginx;" directive in the stock nginx.conf only applies when the
# master process starts as root. This image does not, so the directive is
# dropped instead of emitting a warning on every start.
# hadolint ignore=DL3018
RUN apk --no-cache add curl nginx && \
    mkdir -p /run/nginx && \
    chown -R nginx:nginx /run/nginx /var/lib/nginx && \
    sed -i '/^user[[:space:]]\+nginx;/d' /etc/nginx/nginx.conf && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

HEALTHCHECK --interval=1m --timeout=3s --start-period=15s \
  CMD ["curl", "--fail", "--silent", "--show-error", "http://127.0.0.1:8080/healthz"]

# 8080, not 80: the image runs as the unprivileged nginx user, which cannot
# bind a privileged port. Publish it as -p 80:8080 to serve on 80 on the host.
EXPOSE 8080

STOPSIGNAL SIGQUIT

USER nginx

ENTRYPOINT ["/usr/sbin/nginx"]
CMD ["-g", "daemon off;"]
