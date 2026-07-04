#!/bin/bash
# ==============================================================================
# SYSTEM BRANDING SCRIPT - Inject APK, pfetch, and repack metadata
# ==============================================================================
# Purpose:
#   Modifies a system image (raw or mounted dir) to inject branding:
#   - ASRControl companion APK
#   - pfetch system info binary
#   - build.prop repack metadata (immutable attribution)
#
# Usage:
#   sudo ./brand_system.sh --dir <mounted_system_dir> [--apk <path>] [--gsi-name <name>]
#   sudo ./brand_system.sh --image <system.img> [--apk <path>] [--gsi-name <name>]
#
#   --dir     : Path to an already-mounted/extracted system directory
#   --image   : Path to a raw system image (ext4 or EROFS) — mounts it, brands, repacks
#   --apk     : Path to ASRControl APK (optional, skips if not found)
#   --gsi-name: GSI/ROM name for build.prop metadata
# ==============================================================================

set -e

script_dir=$(dirname "$(readlink -f "$0")")

ASR_APK_URL="https://github.com/minhmc2007/minhmc2007/releases/download/v0.0.1/app-debug.apk"
PFETCH_URL="https://raw.githubusercontent.com/dylanaraps/pfetch/refs/heads/master/pfetch"

inject_branding() {
    local sysroot="$1"
    local apk_path="$2"
    local gsi_name="$3"

    # --- APK Injection ---
    if [ -n "$apk_path" ] && [ -f "$apk_path" ]; then
        local target_dir="$sysroot/system/app/ASRControl"
        if [ ! -d "$target_dir" ]; then
            target_dir="$sysroot/app/ASRControl"
            mkdir -p "$target_dir"
        fi
        if [ ! -d "$target_dir" ]; then
            mkdir -p "$target_dir"
        fi
        cp "$apk_path" "$target_dir/ASRControl.apk"
        chmod 755 "$target_dir"
        chmod 644 "$target_dir/ASRControl.apk"
        echo "--> ASRControl APK injected."
    else
        echo "--> Skipping APK injection (no APK provided)."
    fi

    # --- pfetch Injection ---
    local bin_dir="$sysroot/system/bin"
    if [ ! -d "$bin_dir" ]; then
        bin_dir="$sysroot/bin"
    fi
    if [ ! -d "$bin_dir" ]; then
        mkdir -p "$bin_dir"
    fi

    if command -v wget &>/dev/null; then
        wget -q -O "$bin_dir/pfetch" "$PFETCH_URL" || true
    fi
    if [ -f "$bin_dir/pfetch" ]; then
        chmod 755 "$bin_dir/pfetch"
        echo "--> pfetch injected."
    fi

    # --- build.prop Modification ---
    local prop_file="$sysroot/system/build.prop"
    if [ ! -f "$prop_file" ]; then
        prop_file="$sysroot/build.prop"
    fi

    if [ -f "$prop_file" ]; then
        # IMMUTABLE SIGNATURE: This must NOT be removed/overwritten by forks
        sed -i "s|ro\.build\.id=.*|ro.build.display.id=Built.By.Minh2077.Script|g" "$prop_file"
        if ! grep -q "ro.repack.author" "$prop_file"; then
            echo "" >> "$prop_file"
            echo "ro.repack.version=v1.0" >> "$prop_file"
            echo "ro.repack.author=Minhmc2077" >> "$prop_file"
            echo "ro.repack.gsi=${gsi_name:-Unknown}" >> "$prop_file"
            echo "ro.repack.asr_control=true" >> "$prop_file"
            echo "ro.repack.extras=pfetch" >> "$prop_file"
        fi
        echo "--> build.prop branded."
    else
        echo "--> Warning: build.prop not found, skipping prop injection."
    fi
}

# ============================================================
# Main
# ============================================================

MODE=""
SYSROOT=""
IMG_PATH=""
APK_PATH=""
GSI_NAME=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dir) MODE="dir"; SYSROOT="$2"; shift 2 ;;
        --image) MODE="img"; IMG_PATH="$2"; shift 2 ;;
        --apk) APK_PATH="$2"; shift 2 ;;
        --gsi-name) GSI_NAME="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ "$MODE" = "dir" ]; then
    if [ -z "$SYSROOT" ] || [ ! -d "$SYSROOT" ]; then
        echo "Error: --dir requires a valid directory path"
        exit 1
    fi
    inject_branding "$SYSROOT" "$APK_PATH" "$GSI_NAME"

elif [ "$MODE" = "img" ]; then
    if [ -z "$IMG_PATH" ] || [ ! -f "$IMG_PATH" ]; then
        echo "Error: --image requires a valid image file"
        exit 1
    fi

    work_dir="brand_work_$$"
    mkdir -p "$work_dir/mnt"

    fs_type=$(blkid -o value -s TYPE "$IMG_PATH" 2>/dev/null || echo "unknown")
    if [ "$fs_type" = "unknown" ]; then
        if file "$IMG_PATH" | grep -q "EROFS"; then fs_type="erofs"; fi
    fi
    echo "==> Filesystem: $fs_type"

    if [ "$fs_type" = "ext4" ]; then
        mount -o loop "$IMG_PATH" "$work_dir/mnt"
        inject_branding "$work_dir/mnt" "$APK_PATH" "$GSI_NAME"
        umount "$work_dir/mnt"

    elif [ "$fs_type" = "erofs" ]; then
        mkdir -p "$work_dir/extracted"
        fsck.erofs --extract="$work_dir/extracted" "$IMG_PATH"
        inject_branding "$work_dir/extracted" "$APK_PATH" "$GSI_NAME"
        mkfs.erofs -zlz4hc "$IMG_PATH.new" "$work_dir/extracted"
        mv "$IMG_PATH.new" "$IMG_PATH"

    else
        echo "Error: Unsupported filesystem type: $fs_type"
        rm -rf "$work_dir"
        exit 1
    fi

    rm -rf "$work_dir"
    echo "--> Branding complete: $IMG_PATH"

else
    echo "Usage: sudo $0 --dir <dir> [--apk <apk>] [--gsi-name <name>]"
    echo "       sudo $0 --image <img> [--apk <apk>] [--gsi-name <name>]"
    exit 1
fi
