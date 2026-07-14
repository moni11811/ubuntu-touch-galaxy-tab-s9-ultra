#!/bin/bash
set -xe

# gts9uwifi (SM-X910) Ubuntu Touch build.
# WORKDIR can point at a fast filesystem (e.g. inside WSL) holding downloads/.
WORKDIR="${WORKDIR:-workdir}"

[ -d build ] || git clone -b personal/azkali/vendor-modules-aarch64 https://gitlab.com/Azkali/halium-generic-adaptation-build-tools.git build

[ -d "$WORKDIR/downloads/kernel-samsung-gts9wifi" ] || \
    git clone -b android13-5.15-halium https://gitlab.com/azkali-samsung/gts9/ubports/kernel-samsung-gts9wifi.git \
        "$WORKDIR/downloads/kernel-samsung-gts9wifi"

for tree in graphics-kernel display-drivers mm-drivers mmrm-driver securemsm-kernel audio-kernel wlan bt-kernel camera-kernel eva-kernel; do
    [ -d "$WORKDIR/downloads/vendor/qcom/opensource/$tree" ] || \
        git clone -b android13-5.15-halium "https://gitlab.com/azkali-samsung/gts9/ubports/$tree.git" \
            "$WORKDIR/downloads/vendor/qcom/opensource/$tree"
done

# SM-X910: import Goodix Berlin touch + Ultra panel cmdline into the kernel tree
./scripts/prepare-kernel-gts9uwifi.sh "$WORKDIR/downloads/kernel-samsung-gts9wifi"

find overlay ramdisk-overlay vendor-ramdisk-overlay -type d -exec chmod o+rx {} +
find overlay -type f -exec chmod o+r {} +

export ROOTFS_URL="${ROOTFS_URL:-https://ci.ubports.com/job/ubuntu-touch-rootfs/job/ubports%252F24.04-2.x/lastSuccessfulBuild/artifact/ubuntu-touch-android9plus-rootfs-arm64.tar.gz}"
export OTA_CHANNEL="${OTA_CHANNEL:-24.04-2.x/arm64/android9plus/rc}"

./build/build.sh -b "$WORKDIR" "$@"
./build/prepare-fake-ota.sh ./out/device_gts9uwifi_usrmerge.tar.xz ota
./build/system-image-from-ota.sh ota/ubuntu_command out
mv out/rootfs.img out/ubuntu.img

# Stock SM-X910 dynamic partition images (extracted from official X910XXS5CYG1
# firmware with scripts/import-stock-partitions.sh). The X710 firmware tarball
# used by the reference gts9wifi port MUST NOT be used here.
for img in system_ext.img system_dlkm.img product.img vendor.img vendor_dlkm.img odm.img; do
    [ -f "partitions/$img" ] || { echo "missing partitions/$img — run scripts/import-stock-partitions.sh first"; exit 1; }
done
./scripts/swap-vendor-modules.sh
