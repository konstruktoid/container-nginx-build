# Static NGINX on Busybox

This is just some sort of concept and will run a statically built
[NGINX](https://www.nginx.com/) server with almost no options enabled
on a [Busybox](https://busybox.net) binary compiled without most functions.

## Build the images

If you want to skip the manual build and run steps required, you can just
`bash ./image_builds.sh` and then jump to the "Start the NGINX container"
section.

### Build the Busybox image

```sh
docker build --tag busyboximage:latest -f Dockerfile.busybox .
docker run --rm -ti -v "$(pwd)":/tmp/busybox busyboximage
```

Where `"$(pwd)"` is the host directory where the created Busybox image
will be stored.

### Build the NGINX image

Update the `Dockerfile` with the link to the Busybox image created above,
e.g `ADD ./busybox-1.33.1-2106220844.txz /`.

```sh
docker build --tag konstruktoid/nginx:busybox -f Dockerfile .
```

## Start the NGINX container

```sh
docker run --cap-drop=all --cap-add={chown,dac_override,net_bind_service,setgid,setuid} -v "$(pwd)/html":/var/www/html:ro --name nginx -d -p 80:80 konstruktoid/nginx:busybox
```

Where `"$(pwd)/html"` should be replaced with the directory containing your
website.

Verify that it is working with `curl 127.0.0.1` or similar.
