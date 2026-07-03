#!/bin/bash
# ==============================================================================
# FIRMWARE PATCHER - Uses QuantumROM patching logic for ported ROM compatibility
# ==============================================================================
# Purpose:
#   Patches ALL applicable partitions (vendor, product, system_ext) from a stock
#   Samsung firmware to work with a ported/GSI ROM. Disables encryption, removes
#   security restrictions, and patches SELinux policies.
#
#   This is typically needed when porting a ROM from a different device
#   (OEM port mode). Only existing partitions are patched; missing ones are
#   silently skipped.
#
# Usage:
#   Mode 1 (directory): sudo ./patch_vendor.sh --dir <extracted_firmware_directory>
#   Mode 2 (super img): sudo ./patch_vendor.sh --super <super.img> <output_directory>
#
#   --dir mode patches the firmware directory in-place (vendor, product, system,
#         system_ext). All QuantumROM patches are applied where directories exist.
#   --super mode extracts all partitions from a super image, patches each one,
#         and saves the patched partition images to <output_directory>/.
#
# Dependencies:
#   - QuantumROM scripts (android/QuantumROM/)
#   - lpunpack, lpmake (from tools/)
#   - grep, sed, find, file, blkid
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUANTUM_ROM_DIR="$(cd "$SCRIPT_DIR/../android/QuantumROM" && pwd)"
LPTOOLS_DIR="$(cd "$SCRIPT_DIR/../tools/lpunpack_and_lpmake" && pwd)"

source_quantum_rom() {
    if [ ! -d "$QUANTUM_ROM_DIR" ]; then
        echo "Error: QuantumROM directory not found at $QUANTUM_ROM_DIR"
        exit 1
    fi
    if [ ! -f "$QUANTUM_ROM_DIR/scripts/QuantumRom.sh" ]; then
        echo "Error: QuantumRom.sh not found in $QUANTUM_ROM_DIR/scripts/"
        exit 1
    fi
    local ORIG_DIR="$(pwd)"
    cd "$QUANTUM_ROM_DIR"
    source "scripts/QuantumRom.sh"
    cd "$ORIG_DIR"
}

# Convert sparse to raw
ensure_raw() {
    local IMG="$1"
    if file -b -L "$IMG" | grep -q "sparse image"; then
        echo "  -> Converting sparse to raw..."
        simg2img "$IMG" "$IMG.raw"
        mv "$IMG.raw" "$IMG"
    fi
}

# Detect filesystem type
detect_fs() {
    local IMG="$1"
    blkid -o value -s TYPE "$IMG" 2>/dev/null || echo "ext4"
}

# Repack a mounted directory into an image
repack_partition() {
    local MOUNT_DIR="$1"
    ORIG_IMG="$2"
    OUTPUT_IMG="$3"
    local PARTITION="$4"

    local FS_TYPE=$(detect_fs "$ORIG_IMG")
    local SIZE=$(stat --format="%s" "$ORIG_IMG")

    echo "  -> Repacking $PARTITION as $FS_TYPE..."
    mkdir -p "$(dirname "$OUTPUT_IMG")"

    if [ "$FS_TYPE" = "erofs" ]; then
        mkfs.erofs -z lz4hc,9 -T 0 --mount-point "/$PARTITION" "$OUTPUT_IMG" "$MOUNT_DIR" 2>/dev/null
    else
        if command -v make_ext4fs &>/dev/null; then
            make_ext4fs -l "$SIZE" -S "$MOUNT_DIR/file_contexts" -a "$PARTITION" "$OUTPUT_IMG" "$MOUNT_DIR" 2>/dev/null || \
            mke2fs -t ext4 -d "$MOUNT_DIR" "$OUTPUT_IMG" "$SIZE" 2>/dev/null || \
            cp "$ORIG_IMG" "$OUTPUT_IMG"
        else
            mke2fs -t ext4 -d "$MOUNT_DIR" "$OUTPUT_IMG" "$SIZE" 2>/dev/null || \
            cp "$ORIG_IMG" "$OUTPUT_IMG"
        fi
    fi
}

# Apply QuantumROM patches on a firmware directory structure
# Skips missing directories silently.
apply_patches() {
    local FIRMWARE_DIR="$1"

    echo ""
    echo "=== Firmware Patching ==="
    echo "Target: $FIRMWARE_DIR"

    local HAD_PATCHES=0

    # Vendor patches: security (FBE, FDE, FRP, TLC ICC)
    if [ -d "$FIRMWARE_DIR/vendor" ]; then
        echo "  -> Patching vendor (security, encryption, TLC ICC)..."
        DISABLE_SECURITY "$FIRMWARE_DIR"
        HAD_PATCHES=1
    fi

    # System_ext patches: SELinux policies
    if [ -d "$FIRMWARE_DIR/system_ext" ] || [ -d "$FIRMWARE_DIR/system/system_ext" ]; then
        echo "  -> Patching system_ext (SELinux policies)..."
        PATCH_SELINUX "$FIRMWARE_DIR"
        HAD_PATCHES=1
    elif [ -d "$FIRMWARE_DIR/system" ]; then
        # PATCH_SELINUX also handles system, run if system exists
        echo "  -> Patching system (SELinux policies)..."
        PATCH_SELINUX "$FIRMWARE_DIR"
        HAD_PATCHES=1
    fi

    if [ "$HAD_PATCHES" -eq 0 ]; then
        echo "  -> No patchable partitions found."
        return 1
    fi

    echo "=== Firmware patching complete ==="
    return 0
}

usage() {
    echo "Usage:"
    echo "  $0 --dir <extracted_firmware_directory>"
    echo "  $0 --super <super.img> <output_directory>"
    exit 1
}

if [ "$#" -lt 2 ]; then
    usage
fi

case "$1" in
    --dir)
        FIRMWARE_DIR="$2"
        source_quantum_rom
        apply_patches "$FIRMWARE_DIR" || true
        ;;

    --super)
        SUPER_IMG="$2"
        OUTPUT_DIR="$3"

        if [ -z "$OUTPUT_DIR" ]; then
            echo "Error: --super requires an output directory as second argument."
            exit 1
        fi
        if [ ! -f "$SUPER_IMG" ]; then
            echo "Error: Super image not found: $SUPER_IMG"
            exit 1
        fi

        mkdir -p "$OUTPUT_DIR"
        OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

        WORK_DIR=$(mktemp -d)
        FIRMWARE_DIR="$WORK_DIR/firmware"
        mkdir -p "$FIRMWARE_DIR"

        echo "==> Extracting partitions from super image..."
        "$LPTOOLS_DIR/lpunpack" "$SUPER_IMG" "$WORK_DIR"

        source_quantum_rom

        # Define partition map: partition_name -> mount_point
        PARTITIONS=()
        [ -f "$WORK_DIR/vendor.img" ] && PARTITIONS+=("vendor")
        [ -f "$WORK_DIR/product.img" ] && PARTITIONS+=("product")
        [ -f "$WORK_DIR/system_ext.img" ] && PARTITIONS+=("system_ext")
        [ -f "$WORK_DIR/odm.img" ] && PARTITIONS+=("odm")

        if [ ${#PARTITIONS[@]} -eq 0 ]; then
            echo "Error: No partition images found in super."
            rm -rf "$WORK_DIR"
            exit 1
        fi

        # Mount all partition images into firmware directory
        echo "==> Mounting partitions..."
        MOUNTED=()
        for PART in "${PARTITIONS[@]}"; do
            local IMG="$WORK_DIR/$PART.img"
            local MNT="$FIRMWARE_DIR/$PART"
            mkdir -p "$MNT"

            ensure_raw "$IMG"

            echo "  -> Mounting $PART..."
            if mount -o loop "$IMG" "$MNT" 2>/dev/null; then
                MOUNTED+=("$PART")
            else
                echo "  -> Skipping $PART (mount failed, non-filesystem image?)"
            fi
        done

        # For system_ext, also check alternate locations
        if [ -f "$WORK_DIR/system_ext.img" ]; then
            local IMG="$WORK_DIR/system_ext.img"
            local MNT="$FIRMWARE_DIR/system_ext"
            if [ ! -d "$MNT" ]; then
                mkdir -p "$MNT"
                ensure_raw "$IMG"
                mount -o loop "$IMG" "$MNT" 2>/dev/null && \
                    MOUNTED+=("system_ext") || true
            fi
        fi

        # Apply patches on the combined firmware directory structure
        apply_patches "$FIRMWARE_DIR" || true

        # Unmount and repack patched partitions
        echo "==> Repacking patched partitions..."
        for PART in "${MOUNTED[@]}"; do
            local MNT="$FIRMWARE_DIR/$PART"

            echo "  -> Unmounting $PART..."
            umount "$MNT" 2>/dev/null || true

            local ORIG_IMG="$WORK_DIR/$PART.img"
            local OUTPUT_IMG="$OUTPUT_DIR/$PART.img"

            repack_partition "$MNT" "$ORIG_IMG" "$OUTPUT_IMG" "$PART"
        done

        echo ""
        echo "==> Patched partition images saved to: $OUTPUT_DIR/"
        ls -lh "$OUTPUT_DIR/"*.img 2>/dev/null || echo "  (no images created)"

        rm -rf "$WORK_DIR"
        ;;

    *)
        usage
        ;;
esac
