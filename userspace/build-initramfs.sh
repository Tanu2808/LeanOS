#!/bin/sh
# Packs rootfs/ + overlay/ into an initramfs.
# Passwords: set LEANOS_ROOT_PW and LEANOS_USER_PW, or you will be prompted.
# LEANOS_DEV=1 uses the insecure test passwords root/leanos (development only).
set -e
cd "$(dirname "$0")"
if [ "$LEANOS_DEV" = 1 ]; then
  LEANOS_ROOT_PW=${LEANOS_ROOT_PW:-root}; LEANOS_USER_PW=${LEANOS_USER_PW:-leanos}
fi
if [ -z "$LEANOS_ROOT_PW" ]; then printf 'root password: '; stty -echo; read LEANOS_ROOT_PW; stty echo; echo; fi
if [ -z "$LEANOS_USER_PW" ]; then printf 'leanos user password: '; stty -echo; read LEANOS_USER_PW; stty echo; echo; fi
rm -f rootfs/init
cp -a overlay/. rootfs/
printf 'root:%s:19000:0:99999:7:::\nleanos:%s:19000:0:99999:7:::\n' \
  "$(printf '%s' "$LEANOS_ROOT_PW" | openssl passwd -6 -stdin)" \
  "$(printf '%s' "$LEANOS_USER_PW" | openssl passwd -6 -stdin)" > rootfs/etc/shadow
chmod 600 rootfs/etc/shadow
chmod u+s rootfs/bin/busybox
cd rootfs
find . | cpio -o -H newc -R 0:0 | gzip > ../initramfs.cpio.gz
ls -lh ../initramfs.cpio.gz
