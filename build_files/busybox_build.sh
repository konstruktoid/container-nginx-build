#!/bin/bash
# Based on https://github.com/docker-library/busybox/blob/master/stable/glibc/Dockerfile.builder

set -eux
set -o pipefail

BUSYBOX_VERSION="1.33.1"
BUSYBOX_SHA256="12cec6bd2b16d8a9446dd16130f2b92982f1819f6e1c5f5887b6db03f5660d28"
BUILDROOT_VERSION="2021.05"
BUSYBOX_TAR="busybox-${BUSYBOX_VERSION}.tar.bz2"
BASEDIR="$(pwd)"
BUILDDIR="${BASEDIR}/buildarea"
BUILDROOT_DIR="${BASEDIR}/buildroot"
BUILDOUTPUT="/tmp/busybox"

GCC_MULTIARCH="$(gcc -print-multiarch)"

if [ -d "${BUILDDIR}" ]; then
  echo "Removing ${BUILDDIR}."
  rm -rf "${BUILDDIR}"
fi

if [ -d "${BUILDROOT_DIR}" ]; then
  echo "Removing ${BUILDROOT_DIR}."
  rm -rf "${BUILDROOT_DIR}"
fi

if [ ! -d "${BUILDOUTPUT}" ]; then
  echo "Creating ${BUILDOUTPUT}."
  mkdir -p "${BUILDOUTPUT}"
fi

echo "Downloading GPG keys."

gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 0xC9E9416F76E610DBD09D040F47B70C55ACC9965B

echo "Downloading https://busybox.net/downloads/${BUSYBOX_TAR}."

curl --progress-bar -fL -o busybox.tar.bz2.sig "https://busybox.net/downloads/${BUSYBOX_TAR}.sig"
curl --progress-bar -fL -o busybox.tar.bz2 "https://busybox.net/downloads/${BUSYBOX_TAR}"

echo "Verifying files."

echo "${BUSYBOX_SHA256} *busybox.tar.bz2" | sha256sum -c - || exit 1
gpg --batch --verify busybox.tar.bz2.sig busybox.tar.bz2

mkdir -p "${BUILDDIR}"

tar -xf busybox.tar.bz2 -C "${BUILDDIR}" --strip-components 1
rm busybox.tar.bz2*

cd "${BUILDDIR}" || exit 1

echo "Create and use busybox config."
make allnoconfig
cp /tmp/busybox_config .config
make -j 1 busybox

./busybox date | grep ' UTC ' || exit 1

mkdir -p ./rootfs/bin ./rootfs/dev ./rootfs/proc

cp ./busybox ./rootfs/bin/busybox

mkdir -p ./rootfs/etc ./rootfs/lib  "./rootfs/lib/${GCC_MULTIARCH}"
ln -sT lib ./rootfs/lib64
cd ./rootfs/bin || exit 1

for APPLET in chown chmod ln mkdir sh; do
  ln -s busybox "${APPLET}"
done

cd ../../ || exit 1

for file in system/device_table.txt system/skeleton/etc/group system/skeleton/etc/passwd system/skeleton/etc/shadow; do
  dir="$(dirname "$file")"
  mkdir -p "../buildroot/$dir"
  curl -fl -o "../buildroot/$file" "https://git.busybox.net/buildroot/plain/$file?id=${BUILDROOT_VERSION}"
  [ -s "../buildroot/$file" ]
done

mkdir -p ./rootfs/etc ./rootfs/opt/nginx/logs ./rootfs/var/www/html
chown -R 65534:65534 ./rootfs/opt/nginx ./rootfs/var/www/html
ln -sf /dev/stdout ./rootfs/opt/nginx/logs/access.log
ln -sf /dev/stderr ./rootfs/opt/nginx/logs/error.log

cp ../buildroot/system/skeleton/etc/group ../buildroot/system/skeleton/etc/passwd ../buildroot/system/skeleton/etc/shadow ./rootfs/etc/

# cve-2019-5021, https://github.com/docker-library/official-images/pull/5880#issuecomment-490681907
grep -e '^root::' ./rootfs/etc/shadow
sed -ri -e 's/^root::/root:*:/' ./rootfs/etc/shadow
grep -E '^root:[*]:' ./rootfs/etc/shadow
# set expected permissions, etc too (https://git.busybox.net/buildroot/tree/system/device_table.txt)
awk '
    !/^#/ {
      if ($2 != "d" && $2 != "f") {
        printf "error: unknown type \"%s\" encountered in line %d: %s\n", $2, NR, $0 > "/dev/stderr"
        exit 1
      }
      sub(/^\/?/, "rootfs/", $1)
      if ($2 == "d") {
        printf "mkdir -p %s\n", $1
      }
      printf "chmod %s %s\n", $3, $1
    }
' ../buildroot/system/device_table.txt | sh -eux

date="$(date -u +%y%m%d%H%M)"

export XZ_OPT=-9e
LC_ALL=C tar --numeric-owner -cJf "busybox-${BUSYBOX_VERSION}-${date}.txz" -C "${BUILDDIR}/rootfs" --transform='s,^./,,' .
# cp "$BUILDDIR/.config" "${BUILDOUTPUT}/busybox_config-${date}"
cp "${BUILDDIR}/busybox-${BUSYBOX_VERSION}-${date}.txz" "${BUILDOUTPUT}"
