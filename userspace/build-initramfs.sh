#!/bin/sh
# Packs rootfs/ into an initramfs. Run from ~/LeanOS/userspace
set -e
cp init rootfs/init && chmod +x rootfs/init
cd rootfs
find . | cpio -o -H newc -R 0:0 | gzip > ../initramfs.cpio.gz
ls -lh ../initramfs.cpio.gz
