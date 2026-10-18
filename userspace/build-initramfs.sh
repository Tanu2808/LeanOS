#!/bin/sh
# Packs rootfs/ + overlay/ into an initramfs.
# Test passwords come from LEANOS_ROOT_PW / LEANOS_USER_PW (default: root / leanos).
set -e
cd "$(dirname "$0")"
rm -f rootfs/init
cp -a overlay/. rootfs/
printf 'root:%s:19000:0:99999:7:::\nleanos:%s:19000:0:99999:7:::\n' \
  "$(openssl passwd -6 "${LEANOS_ROOT_PW:-root}")" \
  "$(openssl passwd -6 "${LEANOS_USER_PW:-leanos}")" > rootfs/etc/shadow
chmod 600 rootfs/etc/shadow
chmod u+s rootfs/bin/busybox   # needed for su; see notes
cd rootfs
find . | cpio -o -H newc -R 0:0 | gzip > ../initramfs.cpio.gz
ls -lh ../initramfs.cpio.gz
