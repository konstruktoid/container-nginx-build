# Nginx

```text
"nginx [engine x] is an HTTP and reverse proxy server, a mail proxy server,
and a generic TCP/UDP proxy server, originally written by Igor Sysoev."
```

Website: <http://nginx.org/>

## Build and run

Access and error logs are symlinked to stdout and stderr so the container
runtime collects them.

```sh
$ docker build --no-cache -t konstruktoid/nginx:latest -f Dockerfile .
$ docker run --cap-drop=all \
    --cap-add={chown,dac_override,net_bind_service,setgid,setuid} \
    --name nginx -d -P konstruktoid/nginx
$ docker inspect --format='{{.Config.Healthcheck}}' konstruktoid/nginx
```

The master process starts as root to bind port 80 and drops to the `nginx` user
for the workers, hence the capabilities above. To run without them, override the
listen directive to a port above 1024 and add `--user nginx`. The `user`
directive in `nginx.conf` is then ignored with a warning, which is expected.

The `HEALTHCHECK` baked into the image asks for port 80, so that variant needs
the check pointed at the new port as well, otherwise the container never turns
healthy:

```sh
$ docker run --cap-drop=all --user nginx \
    --health-cmd='curl --fail --silent --show-error http://127.0.0.1:8080/healthz' \
    -v ./my-default.conf:/etc/nginx/http.d/default.conf:ro \
    --name nginx -d -p 8080:8080 konstruktoid/nginx
```

## Default site

`files/default.conf` replaces the stock Alpine default site, which returns 404
for every request. It serves the packaged `/var/lib/nginx/html` root and adds a
`/healthz` endpoint that returns `200 ok`:

```sh
$ curl -s http://127.0.0.1/healthz
ok
```

The `HEALTHCHECK` uses that endpoint. Without it there is nothing on the stock
image a `curl --fail` check can succeed against.

Mount your own configuration over `/etc/nginx/http.d/default.conf` to replace it.

Both 80 and 443 are `EXPOSE`d, but the shipped configuration only listens on
80. Serving TLS needs your own config and certificates mounted in.

## Busybox variant

There's also a concept version with a static NGINX server running on a limited
Busybox in the
[busybox branch](https://github.com/konstruktoid/container-nginx-build/tree/busybox).

## Development

`.pre-commit-config.yaml` runs gitleaks, hadolint, actionlint and
markdownlint:

```sh
pre-commit run --all-files
```
