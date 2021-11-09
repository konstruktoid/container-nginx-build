#!/bin/bash
# Based on https://github.com/docker-library/busybox/blob/master/stable/

set -eux
set -o pipefail

BUSYBOX_VERSION="1.34.1"
BUSYBOX_SHA256="415fbd89e5344c96acf449d94a6f956dbed62e18e835fc83e064db33a34bd549"
BUSYBOX_TAR="busybox-${BUSYBOX_VERSION}.tar.bz2"
BUILDROOT_VERSION="2021.05"
BUILDROOT_TAR="buildroot-${BUILDROOT_VERSION}.tar.bz2"
BASEDIR="$(pwd)"
BUILDDIR="${BASEDIR}/buildarea"
BUILDROOT_DIR="/usr/src/buildroot"
BUILDOUTPUT="/tmp/busybox"

GCC_MULTIARCH="$(gcc -print-multiarch)"
BUILD_DATE="$(date -u +%y%m%d%H%M)"

if [ -d "${BUILDDIR}" ]; then
  echo "Removing ${BUILDDIR}."
  rm -rv "${BUILDDIR}"
fi

if [ -d "${BUILDROOT_DIR}" ]; then
  echo "Removing ${BUILDROOT_DIR}."
  rm -rv "${BUILDROOT_DIR}"
fi

if [ -d "${BASEDIR}/buildroot" ]; then
  echo "Removing {BASEDIR}/buildroot."
  rm -rv "${BASEDIR}/buildroot"
fi

echo "Downloading GPG keys."

gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 0xAB07D806D2CE741FB886EE50B025BA8B59C36319
gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 0xC9E9416F76E610DBD09D040F47B70C55ACC9965B

echo "Downloading https://busybox.net/downloads/${BUSYBOX_TAR}."

curl --progress-bar -fL -o busybox.tar.bz2 "https://busybox.net/downloads/${BUSYBOX_TAR}"
curl --progress-bar -fL -o busybox.tar.bz2.sig "https://busybox.net/downloads/${BUSYBOX_TAR}.sig"

echo "Downloading https://buildroot.org/downloads/${BUILDROOT_TAR}"

curl --progress-bar -fL -o buildroot.tar.bz2 "https://buildroot.org/downloads/${BUILDROOT_TAR}"
curl --progress-bar -fL -o buildroot.tar.bz2.sign "https://buildroot.org/downloads/${BUILDROOT_TAR}.sign"

echo "Verifying files."

gpg --verify busybox.tar.bz2.sig busybox.tar.bz2

echo "${BUSYBOX_SHA256} busybox.tar.bz2" | sha256sum -c - || exit 1

if gpg --verify buildroot.tar.bz2.sign; then
  BUILDROOT_SHA1="$(gpg -d buildroot.tar.bz2.sign | \
    grep -E "^SHA1:\s[0-9a-f].{39}\s.*${BUILDROOT_TAR}$" | awk '{print $2}')"
  echo "${BUILDROOT_SHA1} buildroot.tar.bz2" | sha1sum -c - || exit 1
else
  echo "${BUILDROOT_TAR} verification failed."
  exit 1
fi

mkdir -vp "${BUILDDIR}"
mkdir -vp "${BUILDROOT_DIR}"
mkdir -vp "${BUILDOUTPUT}"

tar -xf busybox.tar.bz2 -C "${BUILDDIR}" --strip-components 1
tar -xf buildroot.tar.bz2 -C "${BUILDROOT_DIR}" --strip-components 1

rm -v busybox.tar.bz2*
rm -v buildroot.tar.bz2*

cd "${BUILDROOT_DIR}" || exit 1

echo "Create and use Buildroot config."
make allnoconfig
cp /tmp/buildroot_config .config
make -C "${BUILDROOT_DIR}" FORCE_UNSAFE_CONFIGURE=1 -j 1 toolchain

# cp "${BUILDROOT_DIR}/.config" "${BUILDOUTPUT}/buildroot_config-${BUILD_DATE}"

export PATH="${BUILDROOT_DIR}/output/host/usr/bin:$PATH"

cd "${BUILDDIR}" || exit 1

echo "Create and use Busybox config."
make allnoconfig
cp /tmp/busybox_config .config

CROSS_COMPILE="$(basename ${BUILDROOT_DIR}/output/host/usr/*-buildroot-linux-uclibc*)"
export CROSS_COMPILE="${CROSS_COMPILE}-"

make -j 1 busybox

# cp "${BUILDDIR}/.config" "${BUILDOUTPUT}/busybox_config-${BUILD_DATE}"

./busybox date | grep ' UTC ' || exit 1

mkdir -vp ./rootfs/bin ./rootfs/dev ./rootfs/proc
mkdir -vp ./rootfs/etc ./rootfs/lib  "./rootfs/lib/${GCC_MULTIARCH}"

cp ./busybox ./rootfs/bin/busybox

ln -sT lib ./rootfs/lib64
cd ./rootfs/bin || exit 1

for APPLET in chown chmod ln mkdir sh; do
  ln -s busybox "${APPLET}"
done

cd ../../ || exit 1
cp "${BUILDROOT_DIR}/system/skeleton/etc/group" "${BUILDROOT_DIR}/system/skeleton/etc/passwd" "${BUILDROOT_DIR}/system/skeleton/etc/shadow" ./rootfs/etc/

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
        printf "mkdir -vp %s\n", $1
      }
      printf "chmod %s %s\n", $3, $1
    }
' "${BUILDROOT_DIR}/system/device_table.txt" | sh -eux

echo "Creating NGINX specific stuff."

mkdir -vp ./rootfs/opt/nginx/logs ./rootfs/var/www/html
chown -R 65534:65534 ./rootfs/opt/nginx ./rootfs/var/www/html
ln -sf /dev/stdout ./rootfs/opt/nginx/logs/access.log
ln -sf /dev/stderr ./rootfs/opt/nginx/logs/error.log

export XZ_OPT=-9e
LC_ALL=C tar --numeric-owner -cJf "busybox-${BUSYBOX_VERSION}-${BUILD_DATE}.txz" -C "${BUILDDIR}/rootfs" --transform='s,^./,,' .
cp "${BUILDDIR}/busybox-${BUSYBOX_VERSION}-${BUILD_DATE}.txz" "${BUILDOUTPUT}"
