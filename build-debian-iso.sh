#!/bin/bash
set -Eeuo pipefail
cd "$(dirname "$0")"

ROOTFS="$PWD/debian-rootfs"
OUT="$PWD/leanos-debian-live-fixed.iso"
WORK="$PWD/.iso-build"
KERNEL="$PWD/kernel/build/arch/x86/boot/bzImage"
BUSYBOX="$PWD/userspace/rootfs/bin/busybox"

if [[ ! -x "$BUSYBOX" ]]; then
    BUSYBOX="$PWD/userspace/rootfs/usr/bin/busybox"
fi

for file in "$KERNEL" "$BUSYBOX" "$ROOTFS/sbin/init"; do
    if [[ ! -e "$file" ]]; then
        echo "Missing required input: $file" >&2
        exit 1
    fi
done

for tool in mke2fs grub-mkrescue xorriso cpio gzip; do
    command -v "$tool" >/dev/null || {
        echo "Missing tool: $tool" >&2
        exit 1
    }
done

if [[ -e "$OUT" ]]; then
    echo "Refusing to overwrite $OUT" >&2
    exit 1
fi

rm -rf "$WORK"
mkdir -p "$WORK"/{iso/boot/grub,initrd/bin,initrd/dev,initrd/proc,initrd/sys,initrd/newroot}
cp "$KERNEL" "$WORK/iso/boot/bzImage"

# Build a compact ext4 filesystem containing the Debian system.
sudo mke2fs -q -t ext4 -F -d "$ROOTFS" \
    "$WORK/iso/rootfs.ext4" 650M

# Create a minimal initramfs to locate the ISO and mount its root filesystem.
cp "$BUSYBOX" "$WORK/initrd/bin/busybox"
chmod 755 "$WORK/initrd/bin/busybox"

for app in sh mount sleep mkdir switch_root losetup mdev; do
    ln -s busybox "$WORK/initrd/bin/$app"
done

cat > "$WORK/initrd/init" <<'INIT'
#!/bin/sh
export PATH=/bin
mount -t devtmpfs devtmpfs /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys

i=0
while [ "$i" -lt 30 ]; do
    for dev in /dev/sr0 /dev/sr1 /dev/cdrom; do
        if mount -t iso9660 -o ro "$dev" /bootiso 2>/dev/null; then
            if [ -f /bootiso/rootfs.ext4 ]; then
                mkdir -p /newroot
                mdev -s
                losetup /dev/loop0 /bootiso/rootfs.ext4 || {
                    echo "Could not attach root filesystem to /dev/loop0."
                    exec sh
                }
                if mount -t ext4 -o rw /dev/loop0 /newroot; then
                    # Keep the ISO mount available for the lifetime of the system.
                    mkdir -p /newroot/bootiso
                    mount --move /bootiso /newroot/bootiso
                    exec switch_root /newroot /sbin/init
                fi
                echo "Failed to mount rootfs.ext4."
                umount /bootiso
            else
                umount /bootiso
            fi
        fi
    done
    sleep 1
    i=$((i + 1))
done

echo "Could not find or mount the LeanOS ISO root filesystem."
exec sh
INIT
chmod 755 "$WORK/initrd/init"

# Add BusyBox applets and pack the initramfs.
(
    cd "$WORK/initrd"
    find . -print0 | cpio --null -o --format=newc 2>/dev/null |
        gzip -1 > "$WORK/iso/boot/initramfs.cpio.gz"
)

cat > "$WORK/iso/boot/grub/grub.cfg" <<'GRUB'
set timeout=3
set default=0

menuentry "LeanOS Debian (live test)" {
    linux /boot/bzImage console=tty0
    initrd /boot/initramfs.cpio.gz
}
GRUB

grub-mkrescue -o "$OUT" "$WORK/iso"
ls -lh "$OUT"
echo "Created: $OUT"
