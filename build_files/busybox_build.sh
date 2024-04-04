#!/bin/bash
# Based on https://github.com/docker-library/busybox/blob/master/stable/

set -eux
set -o pipefail

BUSYBOX_VERSION="1.36.1"
BUSYBOX_SHA256="b8cc24c9574d809e7279c3be349795c5d5ceb6fdf19ca709f80cde50e47de314"
BUSYBOX_TAR="busybox-${BUSYBOX_VERSION}.tar.bz2"
BUILDROOT_VERSION="2024.02.1"
BUILDROOT_TAR="buildroot-${BUILDROOT_VERSION}.tar.gz"
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

curl -fsSL "http://buildroot.org/~jacmet/pubkey.gpg" | gpg --import

echo "Downloading https://busybox.net/downloads/${BUSYBOX_TAR}."

curl -fsSL -o busybox.tar.bz2 "https://busybox.net/downloads/${BUSYBOX_TAR}"

echo "Downloading https://buildroot.org/downloads/${BUILDROOT_TAR}"

curl -fsSL -o buildroot.tar.gz "https://buildroot.org/downloads/${BUILDROOT_TAR}"
curl -fsSL -o buildroot.tar.gz.sign "https://buildroot.org/downloads/${BUILDROOT_TAR}.sign"

echo "Verifying files."

echo "${BUSYBOX_SHA256} busybox.tar.bz2" | sha256sum -c - || exit 1

if gpg --verify buildroot.tar.gz.sign; then
  BUILDROOT_SHA1="$(gpg -d buildroot.tar.gz.sign | \
    grep -E "^SHA1:\s[0-9a-f].{39}\s.*${BUILDROOT_TAR}$" | awk '{print $2}')"
  echo "${BUILDROOT_SHA1} buildroot.tar.gz" | sha1sum -c - || exit 1
else
  echo "${BUILDROOT_TAR} verification failed."
  exit 1
fi

mkdir -vp "${BUILDDIR}"
mkdir -vp "${BUILDROOT_DIR}"
mkdir -vp "${BUILDOUTPUT}"

tar -xf busybox.tar.bz2 -C "${BUILDDIR}" --strip-components 1
tar -xf buildroot.tar.gz -C "${BUILDROOT_DIR}" --strip-components 1

rm -v busybox.tar.bz2*
rm -v buildroot.tar.gz*

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
