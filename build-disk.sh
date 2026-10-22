#!/bin/sh
# Builds a bootable raw disk image (ext4 root + GRUB).
#   ROOTFS  directory to install   (default: userspace/rootfs, the BusyBox system)
#   OUT     image file             (default: leanos.img)
#   SIZE    image size             (default: 2G)
# Debian: ROOTFS=debian-rootfs OUT=leanos-debian.img SIZE=4G ./build-disk.sh
set -e
cd "$(dirname "$0")"
ROOTFS=${ROOTFS:-userspace/rootfs}
OUT=${OUT:-leanos.img}
SIZE=${SIZE:-2G}
rm -f "$OUT"
truncate -s "$SIZE" "$OUT"
echo 'start=2048, type=83, bootable' | sfdisk "$OUT" >/dev/null
LOOP=$(sudo losetup -fP --show "$OUT")
cleanup() { sudo umount mnt 2>/dev/null || true; sudo losetup -d "$LOOP" 2>/dev/null || true; }
trap cleanup EXIT
sudo mkfs.ext4 -q -L leanos-root "${LOOP}p1"
mkdir -p mnt
sudo mount "${LOOP}p1" mnt
sudo tar -C "$ROOTFS" --numeric-owner --xattrs --xattrs-include="*" --acls -cf - . | sudo tar -C mnt --numeric-owner --xattrs --xattrs-include="*" --acls -xpf -
sudo mkdir -p mnt/boot/grub
[ -d mnt/home/leanos ] || sudo mkdir -p mnt/home/leanos
sudo cp kernel/build/arch/x86/boot/bzImage mnt/boot/bzImage
[ -f kernel/known-good/bzImage ] && sudo cp kernel/known-good/bzImage mnt/boot/bzImage.known-good
sudo rm -f mnt/init
sudo tee mnt/boot/grub/grub.cfg >/dev/null << 'CFG'
set timeout=2
set root=(hd0,msdos1)
menuentry "LeanOS" {
    linux /boot/bzImage root=/dev/sda1 rw console=tty0
}
menuentry "LeanOS (safe graphics)" {
    linux /boot/bzImage root=/dev/sda1 rw console=tty0 nomodeset
}
menuentry "LeanOS (previous kernel)" {
    linux /boot/bzImage.known-good root=/dev/sda1 rw console=tty0
}
CFG
sudo grub-install --target=i386-pc --boot-directory=mnt/boot "$LOOP"
sync
echo "Built $OUT"
