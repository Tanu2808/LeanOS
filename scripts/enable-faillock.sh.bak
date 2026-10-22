#!/bin/sh
# Runs inside the Debian rootfs (chroot). Adds pam_faillock to common-auth/common-account.
set -e
f=/etc/pam.d/common-auth
grep -q pam_faillock "$f" && exit 0
sed -i 's|^auth[[:space:]]*\[success=1 default=ignore\][[:space:]]*pam_unix.so.*|auth\trequisite\tpam_faillock.so preauth\n&\nauth\t[default=die]\tpam_faillock.so authfail\nauth\tsufficient\tpam_faillock.so authsucc|' "$f"
echo 'account required pam_faillock.so' >> /etc/pam.d/common-account
