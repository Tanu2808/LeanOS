#!/bin/sh
# Builds a minimal Debian 13 (trixie) root filesystem in debian-rootfs/.
# Needs: debootstrap, debian-archive-keyring, sudo.
# Password: set LEANOS_USER_PW, use LEANOS_DEV=1 (password "leanos"), or you will be prompted.
set -e
cd "$(dirname "$0")"
ROOT=debian-rootfs
MIRROR=${MIRROR:-http://deb.debian.org/debian}

[ "$LEANOS_DEV" = 1 ] && LEANOS_USER_PW=${LEANOS_USER_PW:-leanos}
if [ -z "$LEANOS_USER_PW" ]; then
  printf 'leanos user password: '; stty -echo; read LEANOS_USER_PW; stty echo; echo
fi

sudo rm -rf "$ROOT"
sudo debootstrap --cache-dir="$PWD/.debcache" --variant=minbase \
  --include=systemd-sysv,dbus,systemd-resolved,udev,sudo,iproute2,iputils-ping,ca-certificates,kmod,procps,nano,libpam-systemd,nftables,unattended-upgrades \
  trixie "$ROOT" "$MIRROR"

# identity and mounts
echo leanos | sudo tee "$ROOT/etc/hostname" >/dev/null
printf '127.0.0.1 localhost\n127.0.1.1 leanos\n' | sudo tee "$ROOT/etc/hosts" >/dev/null
echo '/dev/sda1 / ext4 defaults 0 1' | sudo tee "$ROOT/etc/fstab" >/dev/null

# package sources: main archive, updates, security
sudo rm -f "$ROOT"/etc/apt/sources.list "$ROOT"/etc/apt/sources.list.d/*
printf 'deb %s trixie main\ndeb %s trixie-updates main\ndeb http://security.debian.org/debian-security trixie-security main\n' \
  "$MIRROR" "$MIRROR" | sudo tee "$ROOT/etc/apt/sources.list" >/dev/null

# networking: DHCP via systemd-networkd, DNS via systemd-resolved
sudo mkdir -p "$ROOT/etc/systemd/network"
printf '[Match]\nName=en* eth*\n\n[Network]\nDHCP=yes\n' | sudo tee "$ROOT/etc/systemd/network/20-wired.network" >/dev/null
sudo ln -sf ../run/systemd/resolve/stub-resolv.conf "$ROOT/etc/resolv.conf"
sudo chroot "$ROOT" /usr/bin/env PATH=/usr/sbin:/usr/bin:/sbin:/bin systemctl enable systemd-networkd systemd-resolved

# users: root is locked, leanos administers with sudo
sudo chroot "$ROOT" /usr/bin/env PATH=/usr/sbin:/usr/bin:/sbin:/bin useradd -m -s /bin/bash -G sudo leanos
echo "leanos:$LEANOS_USER_PW" | sudo chroot "$ROOT" /usr/bin/env PATH=/usr/sbin:/usr/bin:/sbin:/bin chpasswd
sudo chroot "$ROOT" /usr/bin/env PATH=/usr/sbin:/usr/bin:/sbin:/bin passwd -l root

sudo cp -a debian-overlay/. "$ROOT/"
sudo chroot "$ROOT" /usr/bin/env PATH=/usr/sbin:/usr/bin:/sbin:/bin systemctl enable nftables
sudo cp scripts/enable-faillock.sh "$ROOT/tmp/" && sudo chroot "$ROOT" /usr/bin/env PATH=/usr/sbin:/usr/bin:/sbin:/bin sh /tmp/enable-faillock.sh && sudo rm -f "$ROOT/tmp/enable-faillock.sh"
sudo chroot "$ROOT" /usr/bin/env PATH=/usr/sbin:/usr/bin:/sbin:/bin apt-get clean
echo "Debian rootfs ready: $ROOT ($(sudo du -sh "$ROOT" | cut -f1))"
