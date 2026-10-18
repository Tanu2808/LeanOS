#!/bin/sh
set -e
cd "$(dirname "$0")"
cp kernel/build/arch/x86/boot/bzImage iso/boot/bzImage
cp userspace/initramfs.cpio.gz iso/boot/initramfs.cpio.gz
grub-mkrescue -o leanos.iso iso
ls -lh leanos.iso
