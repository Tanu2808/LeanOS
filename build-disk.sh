#!/bin/sh
# Builds leanos.img (2 GB raw disk, ext4 root + GRUB). Run ./userspace/build-initramfs.sh first.
set -e
cd "$(dirname "$0")"
IMG=leanos.img
rm -f "$IMG"
truncate -s 2G "$IMG"
echo 'start=2048, type=83, bootable' | sfdisk "$IMG" >/dev/null
LOOP=$(sudo losetup -fP --show "$IMG")
cleanup() { sudo umount mnt 2>/dev/null || true; sudo losetup -d "$LOOP" 2>/dev/null || true; }
trap cleanup EXIT
sudo mkfs.ext4 -q -L leanos-root "${LOOP}p1"
mkdir -p mnt
sudo mount "${LOOP}p1" mnt
# tar keeps ownership, device nodes and the setuid bit (chown would clear it)
sudo tar -C userspace/rootfs --owner=0 --group=0 -cf - . | sudo tar -C mnt -xpf -
sudo mkdir -p mnt/boot/grub mnt/home/leanos
sudo chown 1000:1000 mnt/home/leanos
sudo cp kernel/build/arch/x86/boot/bzImage mnt/boot/bzImage
sudo rm -f mnt/init
sudo tee mnt/boot/grub/grub.cfg >/dev/null << 'CFG'
set timeout=2
set root=(hd0,msdos1)
menuentry "LeanOS" {
    linux /boot/bzImage root=/dev/sda1 rw console=tty0 nomodeset
}
CFG
sudo grub-install --target=i386-pc --boot-directory=mnt/boot "$LOOP"
sync
echo "Built $IMG"
