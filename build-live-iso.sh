#!/bin/bash
# Builds leanos-live-v2.iso: GRUB + BusyBox initramfs + rootfs.ext4 (read-only) + tmpfs overlay.
set -eo pipefail
cd "$(dirname "$0")"
OUT=${OUT:-leanos-live-v2.iso}
KERNEL=${KERNEL:-kernel/build/arch/x86/boot/bzImage}
ROOTFS=${ROOTFS:-debian-rootfs}
[ ! -e "$OUT" ] || { echo "refusing to overwrite $OUT"; exit 1; }
[ -f "$KERNEL" ] && [ -d "$ROOTFS" ] && [ -x userspace/rootfs/bin/busybox ] || { echo "missing kernel, rootfs or busybox"; exit 1; }
STAGE=live-stage; WORK=live-work
rm -rf "$STAGE" "$WORK"
mkdir -p "$STAGE/boot/grub" "$WORK"/initramfs/{bin,dev,proc,sys,ro,rw,bootiso,newroot}

# 1. root filesystem image, filled from the rootfs directory (no mount needed)
USED=$(sudo du -sm "$ROOTFS" | cut -f1)
truncate -s "$(( USED * 115 / 100 + 64 ))M" "$WORK/rootfs.ext4"
sudo mke2fs -q -t ext4 -m 0 -L leanos-live -d "$ROOTFS" "$WORK/rootfs.ext4"

# 2. initramfs: find the media, loop-mount the image read-only, overlay a tmpfs, switch root
cp userspace/rootfs/bin/busybox "$WORK/initramfs/bin/"
cat > "$WORK/initramfs/init" << 'INIT'
#!/bin/busybox sh
/bin/busybox --install -s /bin
export PATH=/bin
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
echo "LeanOS live: looking for the boot media..."
found=0
for try in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  for d in /dev/sr0 /dev/sr1 /dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/nvme0n1; do
    [ -b "$d" ] || continue
    if mount -t iso9660 -o ro "$d" /bootiso 2>/dev/null; then
      if [ -f /bootiso/rootfs.ext4 ]; then found=1; break 2; fi
      umount /bootiso
    fi
  done
  sleep 1
done
if [ "$found" != 1 ]; then echo "ERROR: boot media with rootfs.ext4 not found"; exec sh; fi
losetup -r /dev/loop0 /bootiso/rootfs.ext4 || { echo "ERROR: losetup failed"; exec sh; }
mount -t ext4 -o ro /dev/loop0 /ro || { echo "ERROR: cannot mount rootfs.ext4"; exec sh; }
mount -t tmpfs -o size=50% tmpfs /rw
mkdir -p /rw/up/etc /rw/work
echo "# live system: root is an overlay" > /rw/up/etc/fstab
mount -t overlay overlay -o lowerdir=/ro,upperdir=/rw/up,workdir=/rw/work /newroot || { echo "ERROR: overlay failed"; exec sh; }
mkdir -p /newroot/mnt/live-media /newroot/mnt/live-ro /newroot/mnt/live-rw
mount -o move /bootiso /newroot/mnt/live-media
mount -o move /ro /newroot/mnt/live-ro
mount -o move /rw /newroot/mnt/live-rw
mount -o move /dev /newroot/dev
mount -o move /proc /newroot/proc
mount -o move /sys /newroot/sys
exec switch_root /newroot /sbin/init
INIT
chmod +x "$WORK/initramfs/init"
( cd "$WORK/initramfs" && find . | cpio -o -H newc -R 0:0 2>/dev/null | gzip -9 ) > "$STAGE/boot/initramfs.gz"

# 3. ISO tree + GRUB menu
cp "$KERNEL" "$STAGE/boot/bzImage"
mv "$WORK/rootfs.ext4" "$STAGE/rootfs.ext4"
cat > "$STAGE/boot/grub/grub.cfg" << 'CFG'
set timeout=3
menuentry "LeanOS live" {
    linux /boot/bzImage console=ttyS0,115200 console=tty0
    initrd /boot/initramfs.gz
}
menuentry "LeanOS live (safe graphics)" {
    linux /boot/bzImage console=tty0 nomodeset
    initrd /boot/initramfs.gz
}
CFG
grub-mkrescue -o "$OUT" "$STAGE" 2>&1 | tail -3
[ -f "$OUT" ] || { echo "ERROR: ISO was not created"; exit 1; }
ls -lh "$OUT"
