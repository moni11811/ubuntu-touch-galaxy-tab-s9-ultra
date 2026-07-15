#!/bin/bash
# Populate ./partitions with stock SM-X910 dynamic-partition images extracted
# from the official X910XXS5CYG1 firmware (lpunpack of AP super.img).
# Usage: scripts/import-stock-partitions.sh <extracted-super-parts-dir>
set -e
SRC="${1:?usage: $0 <dir with lpunpack output of stock SM-X910 super>}"
mkdir -p partitions
for img in system_ext.img system_dlkm.img product.img vendor.img vendor_dlkm.img odm.img; do
    [ -f "$SRC/$img" ] || { echo "missing $SRC/$img"; exit 1; }
    cp -f "$SRC/$img" "partitions/$img"
done
rm -f partitions/vendor_dlkm.img.stock
ls -la partitions/
