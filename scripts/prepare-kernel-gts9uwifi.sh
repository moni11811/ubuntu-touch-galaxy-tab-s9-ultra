#!/bin/bash
# Prepare the halium kernel tree for gts9uwifi (SM-X910):
#  1. Import the Samsung Goodix Berlin touchscreen driver from the SM-X910
#     kernel source (github.com/samsung-gts9u, pinned commit) — the X710
#     source drop only contains the STM driver used by the smaller Tab S9.
#  2. Hook it into drivers/Makefile and drivers/Kconfig (Samsung LEGO style).
#  3. Add the halium-gts9uwifi.config fragment: Goodix on, STM off, and the
#     forced kernel cmdline with the Ultra panel GTS9U_ANA38407_AMSA46AS02
#     (the X710 tree forces GTS9_ANA38407_AMSA10FA01, which would leave the
#     Ultra display black).
# Idempotent: safe to run repeatedly.
set -e

KERNEL_DIR="$1"
[ -d "$KERNEL_DIR" ] || { echo "usage: $0 <kernel-dir> [goodix-src-dir]"; exit 1; }

GOODIX_REF_REPO="https://github.com/samsung-gts9u/android_kernel_samsung_sm8550.git"
GOODIX_REF_COMMIT="a82404d967be6319df038f5091fb35aeae83d6c6"
GOODIX_SRC="${2:-}"

if [ -z "$GOODIX_SRC" ]; then
    REF_DIR="${TMPDIR:-/tmp}/gts9u-kernel-ref"
    if [ ! -d "$REF_DIR/.git" ]; then
        git clone --depth 1 --filter=blob:none --sparse -b lineage-23.2 "$GOODIX_REF_REPO" "$REF_DIR"
        git -C "$REF_DIR" sparse-checkout set drivers/input/touchscreen/goodix
    fi
    git -C "$REF_DIR" rev-parse HEAD | grep -q "$GOODIX_REF_COMMIT" || \
        echo "WARNING: goodix reference tree is not at pinned commit $GOODIX_REF_COMMIT"
    GOODIX_SRC="$REF_DIR/drivers/input/touchscreen/goodix"
fi

[ -f "$GOODIX_SRC/berlin/goodix_ts_core.c" ] || { echo "goodix source not found at $GOODIX_SRC"; exit 1; }

# 1. driver import
mkdir -p "$KERNEL_DIR/drivers/input/touchscreen/goodix"
cp -r "$GOODIX_SRC/berlin" "$KERNEL_DIR/drivers/input/touchscreen/goodix/"

# 2. build hooks (same pattern Samsung LEGO uses for the other vendor dirs)
MK="$KERNEL_DIR/drivers/Makefile"
KC="$KERNEL_DIR/drivers/Kconfig"
grep -q 'touchscreen/goodix/berlin' "$MK" || \
    sed -i 's|^obj-y += input/touchscreen/stm/fts1ba90a/ .*|&\nobj-y += input/touchscreen/goodix/berlin/ # gts9uwifi Goodix Berlin touch|' "$MK"
grep -q 'goodix/berlin/Kconfig' "$KC" || \
    sed -i 's|^source "drivers/input/touchscreen/stm/fts1ba90a/Kconfig" .*|&\nsource "drivers/input/touchscreen/goodix/berlin/Kconfig" # gts9uwifi Goodix Berlin touch|' "$KC"
grep -q 'touchscreen/goodix/berlin' "$MK" || { echo "failed to hook drivers/Makefile"; exit 1; }
grep -q 'goodix/berlin/Kconfig' "$KC" || { echo "failed to hook drivers/Kconfig"; exit 1; }

# 3. config fragment
cat > "$KERNEL_DIR/arch/arm64/configs/halium-gts9uwifi.config" <<'EOF'
# SM-X910 (gts9uwifi, Tab S9 Ultra) overrides on top of halium.config.
# Touch: Goodix Berlin (the Ultra digitizer); the X710 STM controller is absent.
CONFIG_TOUCHSCREEN_GOODIX_BRL=m
# CONFIG_TOUCHSCREEN_STM_FTS1BA90A is not set
# Forced cmdline with the Ultra panel (GTS9U_ANA38407_AMSA46AS02, lcd_id 800004
# as reported by the SM-X910 bootloader).
CONFIG_CMDLINE="console=ttynull nokaslr stack_depot_disable=on kasan.stacktrace=off kvm-arm.mode=protected cgroup_disable=pressure video=vfb:640x400,bpp=32,memsize=3072000 printk.devkmsg=on firmware_class.path=/vendor/firmware_mnt/image,/android/vendor/firmware,/android/odm/firmware bootconfig loop.max_part=7 msm_drm.dsi_display0=GTS9U_ANA38407_AMSA46AS02: msm_drm.lcd_id=800004 sec_common_fn.lcd_id=800004 net.ifnames=0"
EOF

echo "kernel tree prepared for gts9uwifi"
