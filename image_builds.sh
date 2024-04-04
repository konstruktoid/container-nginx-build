#!/bin/bash

set -eu
set -o pipefail

CONTAINER_TOOL=""

if ! command -v docker; then
  CONTAINER_TOOL="$(which podman)"
else
  CONTAINER_TOOL="$(which docker)"
fi

${CONTAINER_TOOL} build --tag busyboximage:latest -f Dockerfile.busybox .
${CONTAINER_TOOL} run -ti -v "$(pwd)":/tmp/busybox busyboximage

BUSYBOX_IMAGE=""

for busybox_release in $(find . -name "busybox-[1-9]*-[1-9]*.txz" -type f -exec stat -c '%Y %n' {} \; |\
  sort -r | head -n1 | awk '{print $NF}' | sed 's/^\.\///g'); do
  BUSYBOX_IMAGE="${busybox_release}"
done

if [ -n "${BUSYBOX_IMAGE}" ]; then
  echo "Got ${BUSYBOX_IMAGE}."
  sed -i.bak "s/ADD.*/ADD \.\/${BUSYBOX_IMAGE} \//" Dockerfile
  ${CONTAINER_TOOL} build --tag ghcr.io/konstruktoid/nginx:busybox -f Dockerfile .
else
  echo "No Busybox image found. Exiting."
  exit 1
fi

{
echo "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">
<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">
<head>
  <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"/>
  <title>Static NGINX in Busybox container</title>
  <style>
    body {
      background-color: #fff;
      font-family: Sans-Serif;
    }
  </style>
</head>
<body>
<p>
Static NGINX running in limited Busybox container
</p>
<p>"
for VERSIONS in $(grep _VERSION= build_files/* | awk -F ':' '{print $NF}' | sed 's/=/: /g' | tr -d '"' | uniq); do
echo "${VERSIONS}<br />"
done
echo "</p>
<p>
<a href=\"https://github.com/konstruktoid\">konstruktoid</a>
</p>
</body>
</html>"
} > html/index.html

rm -v 'Dockerfile.bak'
