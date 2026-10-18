# LeanOS

A lightweight, secure, developer-friendly Linux distribution built from scratch.
Reuses the Linux kernel, BusyBox, and APT. The custom desktop comes last.

Idle RAM targets: under 700 MB preferred, under 900 MB required, 1 GB ceiling.
Progress and decisions are tracked in [context.md](context.md).

## Status
Kernel, BusyBox initramfs, and a GRUB boot ISO work in VirtualBox. Next: init, login, networking.

## Build (Arch Linux host)
    sudo pacman -S base-devel bc cpio flex bison openssl libelf pahole perl python git ncurses xz grub xorriso mtools
    # 1. kernel: fetch Linux 6.18.57 into kernel/src, use kernel/configs/vbox-6.18.57.config as .config
    # 2. userspace: build static BusyBox 1.37.0 into userspace/rootfs, then ./userspace/build-initramfs.sh
    # 3. ./build-iso.sh  ->  leanos.iso

Test in VirtualBox: Linux / Other Linux (64-bit), 1024 MB RAM, EFI off, no hard disk, ISO attached.
