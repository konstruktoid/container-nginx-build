# Nginx

```sh
"nginx [engine x] is an HTTP and reverse proxy server, a mail proxy server,
and a generic TCP/UDP proxy server, originally written by Igor Sysoev."
```

Website: <http://nginx.org/>

_Please note that because of the changes to [Docker Automated Builds](https://docs.docker.com/docker-hub/builds/)
many Docker images are now outdated and a manual build is required and recommended._

## Build and run instuctions

```sh
$ docker build --no-cache -t konstruktoid/nginx:latest -f Dockerfile .
$ docker run --cap-drop=all --cap-add={chown,dac_override,net_bind_service,setgid,setuid} --name nginx -d -p 80:80 konstruktoid/nginx
c7cd68ec16bf3b480591f441dedf6612d2fbd69f216d432a01208bfa9dacc103
$ docker ps --quiet | xargs docker inspect --format '{{ .Id }}: Health={{ .State.Health.Status }}'
c7cd68ec16bf3b480591f441dedf6612d2fbd69f216d432a01208bfa9dacc103: Health=healthy
$ docker inspect --format='{{.Config.Healthcheck}}' konstruktoid/nginx
{[CMD-SHELL curl -f http://127.0.0.1/ || exit 1] 5m0s 3s 0}
```

There's also a concept version with a static NGINX server running on a limited
Busybox in the
[busybox branch](https://github.com/konstruktoid/Nginx_Build/tree/busybox).

### Docker image size comparison

```console
0.73M   busybox:1.33.1
0.73M   busybox:1.33.1-uclibc
0.8M    busybox:1.33.1-musl
1.84M   konstruktoid/nginx:busybox
2.71M   busybox:1.33.1-glibc
6.34M   konstruktoid/nginx:latest
9.36M   nginx:1.20.0-alpine
9.38M   nginx:1.20-alpine
9.38M   nginx:1.20.1-alpine
9.38M   nginx:1.21.0-alpine
```
