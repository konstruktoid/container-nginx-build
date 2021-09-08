#!/bin/bash

set -eu
set -o pipefail

BASEDIR="$(pwd)"
BUILDDIR="${BASEDIR}/buildarea"
NGINX_VERSION="1.21.3"
OPENSSL_VERSION="1.1.1l"
OPENSSL_SHA256="0b7a3e5e59c34827fe0c3a74b7ec8baef302b98fa80088d7f9153aa16fa76bd1"

mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}" || exit 1

wget https://nginx.org/download/nginx-"${NGINX_VERSION}".{tar.gz,tar.gz.asc}

for key in maxim.key mdounin.key nginx_signing.key sb.key; do
  curl -sSL "https://nginx.org/keys/${key}" | gpg --import
done

gpg --verify "nginx-${NGINX_VERSION}".tar.gz.asc || exit 1

tar -xf "nginx-${NGINX_VERSION}".tar.gz

ln -s "nginx-${NGINX_VERSION}" nginx
cd nginx || exit 1

wget "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"

echo "${OPENSSL_SHA256} openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c - || exit 1

tar -xf "openssl-${OPENSSL_VERSION}".tar.gz

./configure --prefix=/opt/nginx \
            --build="static-$(date +%s)" \
            --with-cc-opt="-static -static-libgcc" \
            --with-ld-opt="-static" \
            --with-openssl=./openssl-"${OPENSSL_VERSION}" \
            --without-http-cache \
            --without-http_access_module \
            --without-http_auth_basic_module \
            --without-http_autoindex_module \
            --without-http_browser_module \
            --without-http_empty_gif_module \
            --without-http_fastcgi_module \
            --without-http_geo_module \
            --without-http_grpc_module \
            --without-http_gzip_module \
            --without-http_limit_conn_module \
            --without-http_limit_req_module \
            --without-http_map_module \
            --without-http_memcached_module \
            --without-http_mirror_module \
            --without-http_proxy_module \
            --without-http_referer_module \
            --without-http_rewrite_module \
            --without-http_scgi_module \
            --without-http_split_clients_module \
            --without-http_ssi_module \
            --without-http_upstream_hash_module \
            --without-http_upstream_ip_hash_module \
            --without-http_upstream_keepalive_module \
            --without-http_upstream_least_conn_module \
            --without-http_upstream_random_module \
            --without-http_upstream_zone_module \
            --without-http_userid_module \
            --without-http_uwsgi_module \
            --without-mail_imap_module \
            --without-mail_pop3_module \
            --without-mail_smtp_module \
            --without-select_module \
            --without-stream_access_module \
            --without-stream_geo_module \
            --without-stream_limit_conn_module \
            --without-stream_map_module \
            --without-stream_return_module \
            --without-stream_set_module \
            --without-stream_split_clients_module \
            --without-stream_upstream_hash_module \
            --without-stream_upstream_least_conn_module \
            --without-stream_upstream_random_module \
            --without-stream_upstream_zone_module

make -j1
