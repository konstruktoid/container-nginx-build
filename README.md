# Static NGINX on Busybox

This is some sort of concept and will run a statically built
[NGINX](https://www.nginx.com/) server with almost no options enabled
on a [Busybox](https://busybox.net) binary compiled without most applets.

## Build the images

If you want to skip the manual build and run steps required, you can just
jump to the "Start the NGINX container" section.

`bash ./image_builds.sh` will perform all build and run steps if you've made
some changes you would like too test. Note that the `html/index.html` file
will be overwritten as well.

_Please note that because of the changes to [Docker Automated Builds](https://docs.docker.com/docker-hub/builds/)
many Docker images are now outdated and a manual build is required and recommended._

### Build the Busybox image

```sh
docker build --tag busyboximage:latest -f Dockerfile.busybox .
docker run --rm -ti -v "$(pwd)":/tmp/busybox busyboximage
```

Where `"$(pwd)"` is the host directory where the created Busybox image
will be stored.

### Build the NGINX image

Update the `Dockerfile` with the link to the Busybox image created above,
e.g `ADD ./busybox-1.36.1-2404041842.txz /`.

```sh
docker build --tag nginx:busybox -f Dockerfile .
```

## Start the NGINX container

```sh
docker run --cap-drop=all --cap-add={chown,dac_override,net_bind_service,setgid,setuid} -v "$(pwd)/config_files":/opt/nginx/conf:ro -v "$(pwd)/html":/var/www/html:ro --name nginx -d -p 80:80 ghcr.io/konstruktoid/nginx:busybox
```

Where `"$(pwd)/html"` should be replaced with the directory containing your
website and `"$(pwd)/config_files"` should be the folder with the NGINX
configuration files.

Verify that it is working with `curl 127.0.0.1` or similar.
