#!/bin/sh
set -eu

root=${1:?Usage: check-ownership.sh ROOTFS}
bad=$(find "$root" -xdev \( -uid 1000 -o -gid 1000 \) \
    ! -path "$root/home/leanos" \
    ! -path "$root/home/leanos/*" \
    -print -quit)

if [ -n "$bad" ]; then
    echo "ERROR: unexpected UID/GID 1000 outside /home/leanos: $bad" >&2
    exit 1
fi

echo "Ownership check passed."
