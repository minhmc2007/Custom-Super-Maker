#!/bin/bash
# ==============================================================================
# SYSTEM SHRINKER - EROFS PATCHER
# ==============================================================================
# Purpose: 
#   Converts a System image (Raw/Sparse) to a high-compression EROFS image.
#
# Usage:
#   sudo ./shrink_system.sh <input_system.img> <output_system.img>
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run with sudo (required for mounting images)."
  exit 1
fi

# Required tools
system_required="simg2img mkfs.erofs rsync stat file"
for tool in $system_required; do
  if ! command -v "$tool" &> /dev/null; then
    echo "Error: Tool '$tool' is missing. Install via: sudo apt install erofs-utils android-sdk-libsparse-utils"
    exit 1
  fi
done

# Args
input_img="$1"
output_img="$2"

if [ -z "$input_img" ] || [ -z "$output_img" ]; then
    echo "Usage: sudo $0 <input_system.img> <output_system.img>"
    exit 1
fi

# Setup Temp Directories
work_dir="temp_shrink_$(date +%s)"
mnt_dir="$work_dir/mnt"
src_dir="$work_dir/src"
mkdir -p "$mnt_dir" "$src_dir"

# Colors
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

echo -e "${CYAN}>>> Processing: $input_img${NC}"

# 1. Handle Sparse Images
if file -b -L "$input_img" | grep -q "sparse image"; then
    echo "--> Converting Sparse to Raw..."
    simg2img "$input_img" "$work_dir/system_raw.img"
    img_to_mount="$work_dir/system_raw.img"
else
    img_to_mount="$input_img"
fi

# 2. Extract Content
echo "--> Mounting and Extracting Files..."
mount -o ro,loop "$img_to_mount" "$mnt_dir"
rsync -aAX "$mnt_dir/" "$src_dir/" > /dev/null
umount "$mnt_dir"

# 3. Create Compressed EROFS
echo "--> Compressing to EROFS (LZ4HC Max)..."
# -z lz4hc,12 provides maximum compression
# -T 0 sets timestamps to 0 for reproducibility
# --mount-point /system ensures internal paths are correct
mkfs.erofs -z lz4hc,12 -T 0 --mount-point /system "$output_img" "$src_dir"

# 4. Result Comparison
old_size=$(stat --format="%s" "$input_img")
new_size=$(stat --format="%s" "$output_img")

bytes_to_mb() { echo "scale=2; $1 / 1048576" | bc; }

echo -e "\n${GREEN}✔ Patching Complete!${NC}"
echo "---------------------------------------"
echo "Original Size: $(bytes_to_mb $old_size) MB"
echo "Shrunk Size:   $(bytes_to_mb $new_size) MB"
echo "Space Saved:   $(bytes_to_mb $((old_size - new_size))) MB"
echo "---------------------------------------"
echo "Output: $output_img"

# Cleanup
rm -rf "$work_dir"
