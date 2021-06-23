FROM konstruktoid/ubuntu as nginx-build

LABEL maintainer='Thomas Sjögren <konstruktoid@users.noreply.github.com>' \
      vcs-url='git@github.com:konstruktoid/Nginx_Build.git'

USER root

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install build-essential ca-certificates gnupg libbz2-dev \
      libpcre3-dev libssl-dev libxml2-dev libxslt1-dev wget zlib1g-dev && \
    useradd -m  --user-group --shell /bin/bash builder && \
    chown -R builder:builder /home/builder && \
    rm -rf /var/lib/apt/lists/* \
      /usr/share/doc /usr/share/doc-base \
      /usr/share/man /usr/share/locale /usr/share/zoneinfo

USER builder
WORKDIR /home/builder

COPY ./build_files/nginx_build.sh ./nginx_build.sh
RUN bash ./nginx_build.sh

FROM scratch

LABEL maintainer='Thomas Sjögren <konstruktoid@users.noreply.github.com>' \
      vcs-url='git@github.com:konstruktoid/Nginx_Build.git'

USER root

ADD ./busybox-1.33.1-2106231943.txz /
COPY --from=nginx-build /home/builder/buildarea/nginx/objs/nginx /opt/nginx/bin/nginx
COPY ./config_files/mime.types ./config_files/nginx.conf /opt/nginx/conf/

RUN ln -s /opt/nginx/conf /etc/nginx && \
    mkdir -p /opt/nginx/logs /var/www/html && \
    chown -R 65534:65534 /opt/nginx /var/www/html && \
    ln -sf /dev/stdout /opt/nginx/logs/access.log && \
    ln -sf /dev/stderr /opt/nginx/logs/error.log

EXPOSE 80 443

USER nobody
WORKDIR /opt/nginx

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/opt/nginx/bin/nginx"]
CMD ["-g", "daemon off;"]
