# LeanOS context

Last updated: 2026-10-17
Status: Steps 1-5 complete. Debian 13 boots on our kernel with APT (53 MB idle). Next: security baseline.

## Project
- New LeanOS project, separate from any earlier work.
- Repo: ~/LeanOS (Git). Host OS: Arch. Test environment: VirtualBox.
- Goal: lightweight, secure, developer-friendly Linux distro.
- Idle RAM targets: under 700 MB preferred, under 900 MB required, 1 GB ceiling.
- Build order: kernel -> userspace/shell/tools -> init, login, networking -> disk install + APT/catalogue -> security -> **custom desktop last**.

## Decisions
- Kernel: Linux 6.18.57 (6.18 LTS), local version `-leanos`.
- Kernel source: kernel/src (not committed). Build output: kernel/build (not committed).
- Kernel config saved: kernel/configs/vbox-6.18.57.config (defconfig + kvm_guest.config + menuconfig).
- Userspace: static BusyBox 1.37.0 (config: userspace/busybox.config), built into userspace/rootfs (not committed).
- Boot: GRUB (BIOS) ISO built by build-iso.sh, config in iso/boot/grub/grub.cfg.
- VM must be Linux / Other Linux (64-bit), EFI off, no hard disk. Audio off.

## Progress
- [x] Step 1: kernel fetched, configured, built (bzImage).
- [x] Step 2: BusyBox initramfs, boots to a shell in QEMU.
- [x] Step 3: bootable ISO, boots to a shell in VirtualBox.
- [ ] Step 4 (IN PROGRESS): real system.
  - [x] 4.1 BusyBox init + inittab + login + non-root user (userspace/overlay)
  - [x] 4.2 networking: DHCP on eth0 via udhcpc
  - [x] 4.3 no default passwords (LEANOS_DEV=1 for test passwords), root console login blocked
  - [x] 4.4 install to disk: ext4 root on /dev/sda1 + GRUB (build-disk.sh), boots in VirtualBox
- [ ] Later: APT + software catalogue, firewall and security, RAM tuning, kernel config trimming, custom desktop.

## Measurements
- QEMU, 512 MB VM, bare kernel + BusyBox: 13 MB used, 449 MB free.
- VirtualBox VM (1471 MB total), same image: 17 MB used, 1450 MB free.
- Both are floors: no init, login, networking, audio or desktop yet.
- VirtualBox, BusyBox init + getty/login + user: 18 MB used (login costs about 1 MB).
- VirtualBox, with DHCP networking: 19 MB used.

## Notes
- grub.cfg currently has `nomodeset`. The earlier black screen was caused by a 32-bit VM, not the display driver, so test removing `nomodeset` later (the desktop needs the real display driver).
- Kernel config is still the untrimmed defconfig (includes i915, e1000e, Wi-Fi, NFS, many Ethernet drivers). Trim later once the system is stable and RAM can be measured.
- VM RAM setting should be 1024 MB (it was 1536 MB), to match the 1 GB design ceiling.
- Test passwords (root/leanos) are generated at build time into rootfs/etc/shadow (not committed). BusyBox is setuid root for su; tighten in the security pass.

## Commands
```bash
# kernel
cd ~/LeanOS/kernel/src && make O=../build -j"$(nproc)" bzImage

# initramfs
cd ~/LeanOS/userspace && ./build-initramfs.sh

# ISO
~/LeanOS/build-iso.sh   # outputs ~/LeanOS/leanos.iso
```

## Resume point
Next: Step 5 (package management).
- VM network adapter must be Intel PRO/1000 MT Desktop (82540EM) on NAT; the kernel has e1000 built in but not PCnet.
- BusyBox wget does not verify TLS certificates; use only for testing until APT is available.
- Disk workflow: build-initramfs.sh -> build-disk.sh (leanos.img) -> VBoxManage convertfromraw to leanos-disk.vdi, attached on the AHCI controller. VM: 1024 MB, EFI off, audio off, Intel PRO/1000 NIC, Hard Disk first in boot order.
- Measured: VirtualBox 1024 MB VM, ext4 root on disk, init + login + DHCP: 16 MB used, 32 MB of disk used.
- Normal users cannot poweroff (needs root); add sudo/doas later.

## Step 5 result (Debian rootfs)
- Main system is now a minimal Debian 13 (trixie) rootfs built by build-debian.sh (debootstrap, systemd, dbus, systemd-networkd/resolved, sudo). Root is locked; user leanos has sudo.
- Disk: ROOTFS=debian-rootfs OUT=leanos-debian.img SIZE=4G ./build-disk.sh, then VBoxManage convertfromraw to leanos-debian.vdi.
- Measured (1024 MB VM): 53 MB used, 92 MB cache; boot 5.5 s (2.4 s kernel + 3.2 s userspace). APT works.
- debootstrap needs dbus in the package list; chroot calls need PATH=/usr/sbin:/usr/bin:/sbin:/bin.
- The BusyBox system (userspace/, build-initramfs.sh, build-iso.sh) stays as a minimal reference variant.
- Next: security baseline (firewall, automatic security updates, remove setuid shortcuts), trim kernel config, remove nomodeset, software catalogue, then the custom desktop.
