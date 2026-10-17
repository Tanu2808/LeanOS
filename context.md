# LeanOS context

Last updated: 2026-10-17
Status: Steps 1-3 complete. Step 4 PAUSED.

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
- [ ] Step 4 (PAUSED): real system.
  - 4.1 BusyBox init + inittab + login + non-root user (draft in paused/step4-overlay, not committed)
  - 4.2 networking (DHCP on VirtualBox NIC)
  - 4.3 users/permissions cleanup (replace test passwords)
  - 4.4 install to a virtual disk (persistent rootfs)
- [ ] Later: APT + software catalogue, firewall and security, RAM tuning, kernel config trimming, custom desktop.

## Measurements
- QEMU, 512 MB VM, bare kernel + BusyBox: 13 MB used, 449 MB free.
- VirtualBox VM (1471 MB total), same image: 17 MB used, 1450 MB free.
- Both are floors: no init, login, networking, audio or desktop yet.

## Notes
- grub.cfg currently has `nomodeset`. The earlier black screen was caused by a 32-bit VM, not the display driver, so test removing `nomodeset` later (the desktop needs the real display driver).
- Kernel config is still the untrimmed defconfig (includes i915, e1000e, Wi-Fi, NFS, many Ethernet drivers). Trim later once the system is stable and RAM can be measured.
- VM RAM setting should be 1024 MB (it was 1536 MB), to match the 1 GB design ceiling.
- Test passwords in the paused Step 4 draft are throwaway and must be replaced before committing anything real.

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
Resume at Step 4.1 (BusyBox init, inittab, login, non-root user). Draft files are in paused/step4-overlay.
