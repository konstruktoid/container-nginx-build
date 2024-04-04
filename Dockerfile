FROM ubuntu:jammy as nginx-build

LABEL maintainer='Thomas Sjögren <konstruktoid@users.noreply.github.com>' \
      vcs-url='git@github.com:konstruktoid/container-nginx-build.git'

USER root

RUN apt-get update && \
    apt-get --assume-yes upgrade && \
    apt-get --assume-yes install build-essential ca-certificates curl file \
      gnupg libbz2-dev libpcre3-dev libssl-dev libxml2-dev libxslt1-dev wget \
      zlib1g-dev && \
    useradd -m --user-group --shell /bin/bash builder && \
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

ADD ./busybox-1.36.1-2404041842.txz /
COPY --from=nginx-build /home/builder/buildarea/nginx/objs/nginx /opt/nginx/bin/nginx
COPY ./config_files/mime.types ./config_files/nginx.conf /opt/nginx/conf/

EXPOSE 80 443

USER nobody
WORKDIR /opt/nginx

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/opt/nginx/bin/nginx"]
CMD ["-g", "daemon off;"]
