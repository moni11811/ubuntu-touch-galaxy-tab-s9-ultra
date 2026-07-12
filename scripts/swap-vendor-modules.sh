#!/bin/bash
set -e
PARTS=${PARTS:-"./partitions"}
BUILT=${BUILT:-$(ls -d ./workdir/tmp/system/{usr/,}lib/modules/* 2>/dev/null | head -1)}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

[ -f "$PARTS/vendor_dlkm.img" ] || { echo "no $PARTS/vendor_dlkm.img"; exit 1; }
[ -d "$BUILT" ] || { echo "no built modules at $BUILT"; exit 1; }
[ -f "$PARTS/vendor_dlkm.img.stock" ] || cp "$PARTS/vendor_dlkm.img" "$PARTS/vendor_dlkm.img.stock"

fsck.erofs --extract="$WORK" "$PARTS/vendor_dlkm.img.stock"
MODS="$WORK/lib/modules"
CTX=$(getfattr -n security.selinux --only-values "$MODS/smcinvoke_dlkm.ko" 2>/dev/null | tr -d '\0')
[ -n "$CTX" ] || CTX="u:object_r:vendor_file:s0"

swapped=""
for ko in $(find "$BUILT" -name '*.ko'); do
    n=$(basename "$ko")
    if [ -f "$MODS/$n" ]; then
        cp -f "$ko" "$MODS/$n"; chown 0:0 "$MODS/$n"; chmod 0644 "$MODS/$n"
        setfattr -n security.selinux -v "$CTX" "$MODS/$n" 2>/dev/null || true
        swapped="$swapped $n"
    fi
done
echo "swapped:$swapped"
rm -f "$PARTS/vendor_dlkm.img"
mkfs.erofs -zlz4 -T0 "$PARTS/vendor_dlkm.img" "$WORK"
ls -la "$PARTS/vendor_dlkm.img"
