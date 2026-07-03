#!/bin/bash
# ==============================================================================
# REPACK SUPER LITE - AUTOMATED PARTITION OPTIMIZER
# ==============================================================================
# Purpose:
#   1. Extracts a Samsung/Android Super Partition.
#   2. Aggressively debloats the 'Product' partition (Removes app/priv-app).
#   3. Replaces the 'System' partition with a Custom ROM (GSI/Port).
#   4. Compresses System & Product using EROFS (LZ4HC) for maximum efficiency.
#   5. Calculates the largest possible size for 'System' based on device limits.
#
# Usage:
#   sudo ./repacksuper_lite.sh <Source_Super_Path> <Custom_System_Path> <Output_Path> [Custom_Vendor_Image]
#   sudo ./repacksuper_lite.sh -P <Patched_Dir> <Source_Super_Path> <Custom_System_Path> <Output_Path>
#
# Options:
#   -P <Patched_Dir>  : Directory containing pre-patched partition images
#                        (vendor.img, product.img, system_ext.img, odm.img).
#                        These override the partitions extracted from the stock super.
#   Custom_Vendor_Image (positional): Path to a single pre-patched vendor.img.
#
# Author: Minhmc2077 
# License: GPL3
# ==============================================================================

# --- 1. INITIALIZATION & SAFETY CHECKS ---

# Ensure we are running with root privileges (Required for mounting)
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script requires root privileges to mount filesystems."
  echo "Please run with sudo."
  exit 1
fi

script_dir=$(dirname $(readlink -f "$0"))
lptools_path="$script_dir/../tools/lpunpack_and_lpmake"

# Define required system tools
system_required="simg2img tar unxz lz4 unzip gzip jq file mkfs.erofs rsync stat"

# Check for existence of lpunpack/lpmake binaries
if [ ! -f "$lptools_path/lpunpack" ] || [ ! -f "$lptools_path/lpmake" ]; then
    echo "Error: Local LPTools not found at $lptools_path."
    echo "Please ensure 'lpunpack' and 'lpmake' are in the 'lpunpack_and_lpmake' directory."
    exit 1
fi

# Check for required system packages
for tool in $system_required; do
  if ! command -v "$tool" &> /dev/null; then
    echo "Error: System tool '$tool' is missing."
    echo "Please install dependencies (e.g., sudo apt install erofs-utils android-sdk-libsparse-utils)."
    exit 1
  fi
done

# Set up Colors for Output
RED=$(printf '\033[1;31m')
GREEN=$(printf '\033[1;32m')
CYAN=$(printf '\033[1;36m')
YELLOW=$(printf '\033[1;33m')
NC=$(printf '\033[0m')

# Helper: Convert Bytes to Human Readable Format
bytes_to_human() {
    local b=${1:-0}; local d=''; local s=0; local S=(Bytes KB MB GB TB)
    while ((b > 1024)); do
        d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
        b=$((b / 1024))
        let s++
    done
    echo "$b$d ${S[$s]}"
}

# --- 2. ARGUMENT PARSING ---

patched_dir=""
custom_vendor_img=""

# Parse -P flag if present
if [ "$1" = "-P" ]; then
    patched_dir="$2"
    shift 2
fi

src_input="$1"
custom_system_img="$2"
output_name="$3"
# 4th positional arg still supported for backward compatibility
if [ -z "$patched_dir" ] && [ -n "$4" ]; then
    custom_vendor_img="$4"
fi

if [ -z "$src_input" ] || [ -z "$custom_system_img" ]; then
    echo "Usage: sudo $0 [-P <Patched_Dir>] <Source_Super> <Custom_System_Image> <Output_Filename> [Custom_Vendor_Image]"
    exit 1
fi
if [ -z "$output_name" ]; then output_name="super_new.img"; fi

# Define Workspaces
rps_dir="$script_dir/repacksuper"
super_dir="$rps_dir/super"
work_dir="$rps_dir/work"
stock_super_raw="$rps_dir/super.raw"

# Clean previous runs
rm -rf "$rps_dir"
mkdir -p "$rps_dir" "$super_dir" "$work_dir"

# Capture Input System Size (For Comparison Table later)
if [ -f "$custom_system_img" ]; then
    input_source_size=$(stat --format="%s" "$custom_system_img")
else
    echo "Error: Custom system image '$custom_system_img' does not exist."
    exit 1
fi

# --- 3. INPUT SOURCE PROCESSING ---
echo
printf "${CYAN}>>> Processing Source Firmware...${NC}\n"

if [[ "$src_input" == *.raw ]] || [[ "$src_input" == *.img ]]; then
     # Check if sparse, convert if necessary
     if file -b -L "$src_input" | grep -q "sparse image"; then
        echo "--> Converting Sparse Image to Raw..."
        simg2img "$src_input" "$stock_super_raw"
     else
        echo "--> Copying Raw Image..."
        cp "$src_input" "$stock_super_raw"
     fi
elif [[ "$src_input" == *.zip ]]; then
    echo "--> Extracting AP Archive from Zip..."
    unzip -o "$src_input" "AP_*.tar.md5" -d "$rps_dir"
    tar_file=$(find "$rps_dir" -name "AP_*.tar.md5" | head -n1)
    
    echo "--> Extracting super.img.lz4 from Tar..."
    tar -xf "$tar_file" -C "$rps_dir" super.img.lz4
    
    echo "--> Decompressing LZ4..."
    lz4 -d "$rps_dir/super.img.lz4" "$rps_dir/super.img"
    simg2img "$rps_dir/super.img" "$stock_super_raw"
else
    echo "Error: Unknown input format. Supported: .raw, .img, .zip"
    exit 1
fi

if [ ! -f "$stock_super_raw" ]; then
    echo "Error: Failed to generate super.raw."
    exit 1
fi

# Analyze Stock Partition Sizes (Before Modification)
echo "--> Analyzing Stock Partition Table..."
stock_json=$("$lptools_path"/lpdump "$stock_super_raw" -j)
stock_system_size=$(echo "$stock_json" | jq -r '.partitions[] | select(.name == "system") | .size')
stock_product_size=$(echo "$stock_json" | jq -r '.partitions[] | select(.name == "product") | .size')
# Handle case where product partition doesn't exist
if [ -z "$stock_product_size" ] || [ "$stock_product_size" == "null" ]; then stock_product_size=0; fi

echo "--> Unpacking Stock Super..."
"$lptools_path"/lpunpack "$stock_super_raw" "$super_dir"

# --- 4. PRODUCT PARTITION DEBLOAT ---
echo
printf "${CYAN}>>> Debloating Product Partition...${NC}\n"
product_img="$super_dir/product.img"

if [ -f "$product_img" ] && [ "$stock_product_size" -gt 0 ]; then
    mkdir -p "$work_dir/mnt_product" "$work_dir/product_build"
    
    # Ensure raw for mounting
    if file -b -L "$product_img" | grep -q "sparse image"; then
        simg2img "$product_img" "$product_img.raw"
        mv "$product_img.raw" "$product_img"
    fi

    # Mount
    mount -o ro,loop "$product_img" "$work_dir/mnt_product"
    
    # Copy Essentials Only (Drop 'app' and 'priv-app')
    echo "--> Removing Bloatware (app/priv-app)..."
    rsync -aAX "$work_dir/mnt_product/" "$work_dir/product_build/" \
        --exclude "app" --exclude "priv-app" --exclude "lost+found" > /dev/null

    umount "$work_dir/mnt_product"

    # Repack using EROFS LZ4HC
    echo "--> Repacking Product (EROFS LZ4HC)..."
    mkfs.erofs -z lz4hc,9 -T 0 --mount-point /product \
        "$super_dir/product_new.img" "$work_dir/product_build" 2>/dev/null
    mv "$super_dir/product_new.img" "$super_dir/product.img"
else
    echo "Warning: No product partition found. Skipping debloat."
fi

# --- 5. SYSTEM PARTITION PROCESSING ---
echo
printf "${CYAN}>>> Processing Custom System Image...${NC}\n"
mkdir -p "$work_dir/mnt_system" "$work_dir/system_build"

# Handle input format (Sparse vs Raw)
if file -b -L "$custom_system_img" | grep -q "sparse image"; then
    simg2img "$custom_system_img" "$work_dir/system_raw.img"
    sys_src="$work_dir/system_raw.img"
else
    sys_src="$custom_system_img"
fi

echo "--> Mounting Custom System..."
mount -o ro,loop "$sys_src" "$work_dir/mnt_system"

echo "--> Syncing Files..."
rsync -aAX "$work_dir/mnt_system/" "$work_dir/system_build/" > /dev/null
umount "$work_dir/mnt_system"

echo "--> Compressing System (EROFS LZ4HC)..."
mkfs.erofs -z lz4hc,9 -T 0 --mount-point /system \
    "$super_dir/system_new.img" "$work_dir/system_build"
mv "$super_dir/system_new.img" "$super_dir/system.img"

# --- 6. PARTITION SIZING & COMPARISON ---
echo
printf "${CYAN}>>> Calculating Optimized Partition Sizes...${NC}\n"

# Get Dynamic Partition Group Info (Usually 'group_basic' or 'qti_dynamic_partitions')
lpdump_json=$("$lptools_path"/lpdump "$stock_super_raw" -j)
group_name=$(echo "$lpdump_json" | jq -r '.groups[] | select(.name != "default") | .name' | head -n1)
group_max_size=$(echo "$lpdump_json" | jq -r ".groups[] | select(.name == \"$group_name\") | .maximum_size")
block_device_size=$(echo "$lpdump_json" | jq -r '.block_devices[0].size')

# Get New File Sizes
new_vendor_size=$(stat --format="%s" "$super_dir/vendor.img")
new_product_size=$(stat --format="%s" "$super_dir/product.img")
new_system_erofs_size=$(stat --format="%s" "$super_dir/system.img")
odm_size=0; [ -f "$super_dir/odm.img" ] && odm_size=$(stat --format="%s" "$super_dir/odm.img")
sys_ext_size=0; [ -f "$super_dir/system_ext.img" ] && sys_ext_size=$(stat --format="%s" "$super_dir/system_ext.img")

# Calculate Remaining Space for System
used_space=$((new_vendor_size + new_product_size + odm_size + sys_ext_size))
available_space=$((group_max_size - used_space))
# Reserve 4MB buffer for metadata alignment
safe_buffer=4194304
new_system_part_size=$((available_space - safe_buffer))

# Safety Check
if [ $new_system_erofs_size -gt $new_system_part_size ]; then
    echo "${RED}Error: The compressed system image ($(bytes_to_human $new_system_erofs_size)) is too large for the available space ($(bytes_to_human $new_system_part_size)).${NC}"
    exit 1
fi

# Print Comparison Table
echo -e "${YELLOW}=========================================================================================${NC}"
echo -e "${YELLOW}                                PARTITION OPTIMIZATION REPORT                            ${NC}"
echo -e "${YELLOW}=========================================================================================${NC}"
printf "%-10s | %-15s | %-15s | %-15s | %-15s\n" "PARTITION" "STOCK SIZE" "INPUT RAW" "EROFS SIZE" "PARTITION LIMIT"
echo "-----------------------------------------------------------------------------------------"

# Product Stats
printf "%-10s | %-15s | %-15s | %-15s | %-15s\n" \
    "PRODUCT" "$(bytes_to_human $stock_product_size)" "N/A" \
    "$(bytes_to_human $new_product_size)" "$(bytes_to_human $new_product_size)"

echo "-----------------------------------------------------------------------------------------"

# System Stats
printf "%-10s | %-15s | %-15s | %-15s | %-15s\n" \
    "SYSTEM" "$(bytes_to_human $stock_system_size)" "$(bytes_to_human $input_source_size)" \
    "${GREEN}$(bytes_to_human $new_system_erofs_size)${NC}" "$(bytes_to_human $new_system_part_size)"

echo "-----------------------------------------------------------------------------------------"
space_gained=$((new_system_part_size - stock_system_size))
echo "Summary:"
echo "  - Product Bloat Removed."
echo "  - System Compression: Reduced $(bytes_to_human $input_source_size) -> $(bytes_to_human $new_system_erofs_size)"
echo "  - Partition Resized:  System partition capacity increased by $(bytes_to_human $space_gained)"
echo -e "${YELLOW}=========================================================================================${NC}"
echo

# --- 7. FINAL REPACKING ---
printf "${CYAN}>>> Building New Super Image...${NC}\n"

args="--metadata-size 65536 --super-name super --metadata-slots 2"
args="$args --device super:$block_device_size"
args="$args --group $group_name:$group_max_size"

# Add Partitions (System gets max size, others get file size)
args="$args --partition system:readonly:$new_system_part_size:$group_name --image system=$super_dir/system.img"

# Determine which vendor image to use (precedence: patched_dir > custom_vendor_img > extracted)
vendor_src="$super_dir/vendor.img"
if [ -n "$patched_dir" ] && [ -f "$patched_dir/vendor.img" ]; then
    vendor_src="$patched_dir/vendor.img"
    echo "--> Using patched vendor image from: $vendor_src"
elif [ -n "$custom_vendor_img" ] && [ -f "$custom_vendor_img" ]; then
    vendor_src="$custom_vendor_img"
    echo "--> Using custom patched vendor image: $vendor_src"
fi
args="$args --partition vendor:readonly:$new_vendor_size:$group_name --image vendor=$vendor_src"

# Determine which product image to use
product_src="$super_dir/product.img"
if [ -n "$patched_dir" ] && [ -f "$patched_dir/product.img" ]; then
    product_src="$patched_dir/product.img"
    echo "--> Using patched product image from: $product_src"
fi
args="$args --partition product:readonly:$new_product_size:$group_name --image product=$product_src"

# Check for patched ODM
odm_src="$super_dir/odm.img"
if [ $odm_size -gt 0 ]; then
    if [ -n "$patched_dir" ] && [ -f "$patched_dir/odm.img" ]; then
        odm_src="$patched_dir/odm.img"
        echo "--> Using patched odm image from: $odm_src"
    fi
    args="$args --partition odm:readonly:$odm_size:$group_name --image odm=$odm_src"
fi

# Check for patched system_ext
sys_ext_src="$super_dir/system_ext.img"
if [ $sys_ext_size -gt 0 ]; then
    if [ -n "$patched_dir" ] && [ -f "$patched_dir/system_ext.img" ]; then
        sys_ext_src="$patched_dir/system_ext.img"
        echo "--> Using patched system_ext image from: $sys_ext_src"
    fi
    args="$args --partition system_ext:readonly:$sys_ext_size:$group_name --image system_ext=$sys_ext_src"
fi

args="$args --sparse --output $output_name"

# Execute lpmake
"$lptools_path"/lpmake $args

if [ $? -eq 0 ]; then
    echo
    echo -e "${GREEN}SUCCESS: Super image created at: $output_name${NC}"
else
    echo
    echo -e "${RED}FAILURE: lpmake encountered an error.${NC}"
    exit 1
fi
