# Nginx

```text
"nginx [engine x] is an HTTP and reverse proxy server, a mail proxy server,
and a generic TCP/UDP proxy server, originally written by Igor Sysoev."
```

Website: <https://nginx.org/>

## Build and run

The image runs as the unprivileged `nginx` user and listens on 8080, so it
needs no added capabilities. Access and error logs are symlinked to stdout and
stderr so the container runtime collects them.

```sh
$ docker build --no-cache -t konstruktoid/nginx:latest -f Dockerfile .
$ docker run --cap-drop=all --name nginx -d -p 127.0.0.1:8080:8080 \
    konstruktoid/nginx
$ curl --silent http://127.0.0.1:8080/healthz
ok
```

The host port is what decides where the site is served from; publish it as
`-p 80:8080` to answer on 80 without giving the container anything extra.

### Serving on port 80 inside the container

If the container itself has to bind 80 - a host network namespace, for
instance - mount a configuration that listens there and add the one capability
that needs. The `HEALTHCHECK` baked into the image asks for 8080, so it has to
be pointed at the new port too, otherwise the container never turns healthy:

```sh
$ docker run --cap-drop=all --cap-add=NET_BIND_SERVICE \
    --health-cmd='curl --fail --silent --show-error http://127.0.0.1/healthz' \
    -v ./my-default.conf:/etc/nginx/http.d/default.conf:ro \
    --name nginx -d -p 80:80 konstruktoid/nginx
```

Publishing the unprivileged port instead, as `-p 80:8080`, gets the same result
on the host without the capability, and is the better option unless the
container shares the host's network namespace.

## Default site

`files/default.conf` replaces the stock Alpine default site, which returns 404
for every request. It serves the packaged `/var/lib/nginx/html` root and adds a
`/healthz` endpoint that returns `200 ok`. The `HEALTHCHECK` uses that
endpoint; without it there is nothing on the stock image a `curl --fail` check
can succeed against.

Mount your own configuration over `/etc/nginx/http.d/default.conf` to replace it.

Only 8080 is `EXPOSE`d and the shipped configuration only listens there.
Serving TLS needs your own config and certificates mounted in, on a port above
1024, and that port published.

The `user nginx;` directive is removed from `nginx.conf` during the build: it
only applies when the master process starts as root, and would otherwise log a
warning on every start.

## Reproducibility

The base image is pinned by digest, so `FROM` always resolves to the same
layers. The Alpine packages installed on top of it are deliberately *not*
version pinned: the image exists to carry the newest patched `nginx` and
`curl`. Two builds a week apart will therefore contain different package
versions and produce different image digests.

Dependabot moves the base image digest forward; nothing freezes the packages.
If you need a fixed set, build once and refer to the result by digest instead
of by tag.

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
