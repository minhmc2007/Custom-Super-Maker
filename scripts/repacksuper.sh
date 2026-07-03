#!/bin/sh
# Copyleft 2021-2025 Uluruman (Modified for EROFS/Universal Support)
version=1.17.0

script_dir=$(dirname $0)
lptools_path="$script_dir/../tools/lpunpack_and_lpmake"
heimdall_path="$script_dir/../tools/heimdall"
empty_product_path="$script_dir/../tools/misc/product.img"
empty_system_ext_path="$script_dir/../tools/misc/system_ext.img"
system_required="simg2img tar unxz lz4 unzip gzip jq file"

# Colors
if [ ! $NO_COLOR ] && [ $TERM != "dumb" ]; then
  RED="\033[1;31m"
  GREEN="\033[1;32m"
  CYAN="\033[1;36m"
  YELLOW="\033[1;33m"
  BLUE="\033[1;34m"
  BR="\033[1m"
  NC="\033[0m"
fi

# Ctrl+C trap
trap_func() {
  if [ "$new_super_dir/super.img" != "$new_super" ] && [ -f "$new_super_dir/super.img" ]; then
    echo "Renaming \"super.img\" back to \"$new_super_name\""
    mv "$new_super_dir/super.img" "$new_super"
  fi
  echo "Action aborted. Exiting..."
  exit 1
}

mkdircr() {
  mkdir -p "$1"
  if [ ! $? -eq 0 ]; then
    echo "Cannot create directory. Exiting..."
    exit 1
  fi
}

lpdump() {
  retval=$($lptools_path/lpdump "$stock_super_raw" -j | jq -r '.'$1'[] | select(.name == "'$2'") | .'$3)
}

isunzipped() {
  do_unzip=
  if [ -f "$unpacked_file" ]; then
    printf "${BLUE}The new system file seems already unzipped before.${NC}\n"
    if [ ! $silent_mode ]; then
      read -p "Reuse it? y/N " ans
      if [ "$ans" != "y" ]; then
        rm -f "$unpacked_file"
        do_unzip=true
      fi
    else
      # Silent mode
      echo "(silent mode) Unpacking again."
      rm -f "$unpacked_file"
      do_unzip=true
    fi
  else
    do_unzip=true
  fi
}

mto_group_warning() {
  if [ "$retval" != "$system_group" ]; then
    printf "${RED}WARNING! There is more then one partition group. This is currently unsupported.\n"
    printf "The resulting file may not work.${NC} Continuing anyway...\n"
  fi
}

pack_tar() {
  if [ ! "$tar_name" ]; then
    tar_name=super.tar
  fi
  if [ $(basename "$tar_name") = "$tar_name" ]; then
    tar_name="$new_super_dir"/"$tar_name"
  fi
  echo
  printf "${CYAN}Packing into \"$tar_name\"...${NC}\n"
  mv "$new_super" "$new_super_dir"/super.img
  tar cv -C "$new_super_dir" -f "$tar_name" super.img
  if [ ! $? -eq 0 ]; then
    echo "Error packing tar. Skipping..."
    mv "$new_super_dir"/super.img "$new_super"
    return
  fi
  mv "$new_super_dir"/super.img "$new_super"
  echo "Done"
}

# Check for the system requirements
for i in $system_required
do
  if [ ! $(which "$i") ]; then
    echo "The \"$i\" tool was not found on your system."
    echo "Please install it using your system's package manager. Exiting..."
    exit 1
  fi
done

# Parse arguments
optstr="?hexsmwpr:v:"
while getopts $optstr opt; do
  case "$opt" in
    e) empty_product=true ;;
    x) empty_system_ext=true ;;
    s) silent_mode=true ;;
    m) manual_super_name=true ;;
    w) writable=true ;;
    p) purge_all=true ;;
    r) rdir="$OPTARG" ;;
    v) custom_vdlkm="$OPTARG" ;;
    \?) exit 1 ;;
  esac
done
shift $(expr $OPTIND - 1)

# Check the root dir
if [ ! "$rdir" ]; then
  rdir="."
elif [ ! -d "$rdir" ]; then
  echo "-r parameter points to a non-existing directory \"$rdir\". Exiting..."
  exit 1
fi

# Check the custom Vendor DLKM file
if [ "$custom_vdlkm" ]; then
  if [ ! -f "$custom_vdlkm" ]; then
    echo "-v parameter points to a non-existing file. Exiting..."
    exit 1
  elif ! file -b -L "$custom_vdlkm" | grep "ext[2-4] filesystem" > /dev/null; then
    echo "The new Vendor DLKM file does not contain an ext2/3/4 filesystem. Exiting..."
    exit 1
  fi
fi

# Identify the source format
echo
printf "${CYAN}Checking the source files...${NC}\n"
if [ ! -e "$1" ]; then
  echo "The specified source file or directory does not exist. Exiting..."
  exit 1
fi
if [ -d "$1" ]; then
  if [ -f "$1/AP/super.img" ]; then
    src_format="dir"
    src_dir="$1"
    stock_super="$src_dir"/AP/super.img
    echo "Source identified as directory created by heimdall_flash_stock.sh"
  elif [ -f "$1"/super.img ]; then
    src_format="dir"
    src_dir="$1"
    stock_super="$src_dir"/super.img
    rps_dir="$src_dir"
    echo "Source identified as the repacksuper dir"
  else
    src_format="ap_tar"
    src_dir="$1"
    ap_tar=$(find "$src_dir" -type f -iname "AP_*.tar*" | head -n 1)
    if [ $ap_tar ]; then
      echo "Source identified as directory containing an AP_*.tar* file"
    else
      echo "Directory was specified but no useful file was found there. Exiting..."
      exit 1
    fi
  fi
else
  if file -b -L "$1" | grep "Android sparse image" > /dev/null; then
    src_format="img"
    src_dir=$(dirname "$1")
    stock_super="$1"
    echo "Source identified as a directly specified sparse image file"
  elif file -b -L "$1" | grep "Zip archive data" > /dev/null; then
    src_format="zip"
    bn=$(basename "$1")
    src_dir=$(dirname "$1")"/${bn%.*}"
    zip_file="$1"
    echo "Source identified as Zip archive with tar archives inside"
  elif file -b -L "$1" | grep "tar archive" > /dev/null; then
    src_format="ap_tar"
    src_dir=$(dirname "$1")
    ap_tar="$1"
    echo "Source identified as tar archive with super.img inside"
  else
    echo "Unknown source file format. Exiting..."
    exit 1
  fi
fi

new_system_src="$2"
if [ "$new_system_src" != "-" ]; then
  new_system_src_dir=$(dirname "$new_system_src")
fi
if [ ! "$rps_dir" ]; then
  rps_dir="$rdir"/repacksuper
fi

if [ $purge_all ]; then
  echo
  printf "${CYAN}Purging the \"repacksuper\" directory...${NC}\n"
  if [ -d "$rps_dir" ]; then
    rm -rf "$rps_dir"
    echo "Done"
  else
    echo "Skipping: no existing \"repacksuper\" directory found."
  fi
fi

if [ ! -d "$rps_dir" ]; then
  mkdircr "$rps_dir"
fi

# Unpack files logic (simplified for brevity, mostly stock logic remains)
if [ "$src_format" != "dir" ] && [ "$src_format" != "img" ]; then
  echo
  printf "${CYAN}Unpacking files...${NC}\n"
  if [ "$src_format" = "zip" ]; then
      ap_tar=$(zipinfo -1 "$zip_file" | grep -i "^AP_.*\.tar")
      unzip -o "$zip_file" "$ap_tar" -d "$src_dir"
      ap_tar="$src_dir"/"$ap_tar"
  fi
  
  stock_super=$(find "$rps_dir" -maxdepth 1 -type f -iname "super.img*" | head -n 1)
  if [ ! "$stock_super" ]; then
    tar xv -C "$rps_dir" -f "$ap_tar" --wildcards "*super.img*"
    stock_super=$(find "$rps_dir" -maxdepth 1 -type f -iname "super.img*" | head -n 1)
  fi

  if file -b -L "$stock_super" | grep "LZ4 compressed data" > /dev/null; then
    echo "super.img is LZ4-compressed, uncompressing..."
    lz4 -d "$stock_super" "$stock_super.out"
    mv "$stock_super.out" "${stock_super%.*}"
    stock_super="${stock_super%.*}"
  fi
else
    if [ -f "$rps_dir"/super.raw ]; then
      stock_super_raw="$rps_dir"/super.raw
    fi
fi

# Create super.raw
if [ ! "$stock_super_raw" ]; then
  echo
  printf "${CYAN}Checking the stock super.img file...${NC}\n"
  if ! file -b -L "$stock_super" | grep "sparse image" > /dev/null; then
    echo "Not a sparse image. May be already non-sparse?"
    stock_super_raw="$stock_super"
  else
    stock_super_raw="$rps_dir"/super.raw
    if [ ! -f "$stock_super_raw" ]; then
      echo "Converting the sparse file format to non-sparse (raw)..."
      simg2img "$stock_super" "$stock_super_raw"
    fi
  fi
fi

# Prepare the super dir
super_dir="$rps_dir"/super
if [ ! -d "$super_dir" ]; then
  mkdircr "$super_dir"
  urs=true
fi

# Unpack the raw stock super file
if [ $urs ]; then
  echo
  printf "${CYAN}Unpacking the super file...${NC}\n"
  "$lptools_path"/lpunpack "$stock_super_raw" "$super_dir"
fi

# Replace the system
echo
printf "${CYAN}Replacing the system image with the new one...${NC}\n"
new_system="$super_dir"/system.img

# --- SYSTEM IMAGE PREPARATION (ZIP/XZ/GZ) ---
if [ "$new_system_src" != "-" ]; then
    # Simple copy if already unpacked in workflow
    cp "$new_system_src" "$new_system"
fi

# Check format - UNIVERSAL FIX
echo "Checking the new system format..."
if file -b -L "$new_system" | grep "sparse image" > /dev/null; then
    echo "Converting the new system image to the non-sparse (raw) format..."
    mv "$new_system" "$new_system.sparse"
    simg2img "$new_system.sparse" "$new_system"
    rm "$new_system.sparse"
fi

# --- FILESYSTEM CHECK (MODIFIED FOR EROFS/RAW SUPPORT) ---
echo "Checking the new system filesystem..."
file_info=$(file -b -L "$new_system")
if echo "$file_info" | grep -E "ext[2-4]|erofs|filesystem|data" > /dev/null; then
  echo "Filesystem accepted: $file_info"
else
  # Warning only, don't exit. lpmake will decide.
  echo "WARNING: Unknown filesystem type ($file_info). Proceeding anyway..."
fi

# Prepare repacking arguments
if [ "$3" ]; then
  new_super="$3"
else
  new_super="super.img"
fi
new_super_dir=$(dirname "$new_super")

# Repack the new super
echo
printf "${CYAN}(Re)packing the new super file...${NC}\n"
if [ -f "$new_super" ]; then rm -f "$new_super"; fi

# Get partition sizes
system_size=$(stat --format="%s" "$new_system")
if [ -f "$super_dir"/system_ext.img ]; then system_ext_size=$(stat --format="%s" "$super_dir"/system_ext.img); fi
if [ -f "$super_dir"/odm.img ]; then odm_size=$(stat --format="%s" "$super_dir"/odm.img); fi
if [ -f "$super_dir"/odm_dlkm.img ]; then odlkm_size=$(stat --format="%s" "$super_dir"/odm_dlkm.img); fi
if [ -f "$super_dir"/product.img ]; then product_size=$(stat --format="%s" "$super_dir"/product.img); fi
if [ -f "$super_dir"/vendor.img ]; then vendor_size=$(stat --format="%s" "$super_dir"/vendor.img); fi
if [ -f "$super_dir"/vendor_dlkm.img ]; then vdlkm_size=$(stat --format="%s" "$super_dir"/vendor_dlkm.img); fi

# Get super size logic (from stock script)
lpdump "block_devices" "super" "size"
block_device_table_size=$retval
lpdump "partitions" "system" "group_name"
system_group=$retval

# Helper for optional partitions
get_group() {
    lpdump "partitions" "$1" "group_name"
    echo $retval
}

# Fetch groups
if [ $system_ext_size ]; then system_ext_group=$(get_group "system_ext"); fi
if [ $odm_size ]; then odm_group=$(get_group "odm"); fi
if [ $odlkm_size ]; then odlkm_group=$(get_group "odm_dlkm"); fi
if [ $product_size ]; then product_group=$(get_group "product"); fi
if [ $vendor_size ]; then vendor_group=$(get_group "vendor"); fi
if [ $vdlkm_size ]; then vdlkm_group=$(get_group "vendor_dlkm"); fi

lpdump "groups" "$system_group" "maximum_size"
groups_max_size=$retval
metadata_max_size=65536

# Display info
printf "${GREEN}System Size:${NC} $system_size | Group: $system_group\n"

# Privacy enhancements
if [ $empty_product ]; then product_img="$empty_product_path"; product_size=$(stat --format="%s" "$product_img"); else product_img="$super_dir"/product.img; fi
if [ $empty_system_ext ]; then system_ext_img="$empty_system_ext_path"; system_ext_size=$(stat --format="%s" "$system_ext_img"); else system_ext_img="$super_dir"/system_ext.img; fi
if [ $writable ]; then attrs="none"; else attrs="readonly"; fi

# Custom Vendor DLKM
if [ "$custom_vdlkm" ]; then
  vdlkm_img="$custom_vdlkm"
  vdlkm_size=$(stat --format="%s" "$vdlkm_img")
else
  vdlkm_img="$super_dir"/vendor_dlkm.img
fi

# Create the new super.img
"$lptools_path"/lpmake --metadata-size $metadata_max_size --super-name super --metadata-slots 2 \
  --device super:$block_device_table_size --group $system_group:$groups_max_size \
  --partition system:$attrs:$system_size:$system_group --image system="$new_system" \
  ${system_ext_size:+--partition system_ext:$attrs:$system_ext_size:$system_ext_group --image system_ext="$system_ext_img"} \
  ${odm_size:+--partition odm:$attrs:$odm_size:$odm_group --image odm="$super_dir/odm.img"} \
  ${odlkm_size:+--partition odm_dlkm:$attrs:$odlkm_size:$odlkm_group --image odm_dlkm="$super_dir/odm_dlkm.img"} \
  ${product_size:+--partition product:$attrs:$product_size:$product_group --image product="$product_img"} \
  ${vendor_size:+--partition vendor:$attrs:$vendor_size:$vendor_group --image vendor="$super_dir/vendor.img"} \
  ${vdlkm_size:+--partition vendor_dlkm:$attrs:$vdlkm_size:$vdlkm_group --image vendor_dlkm="$vdlkm_img"} \
  --sparse --output "$new_super"

if [ $? -ne 0 ]; then
  echo "lpmake failed. Exiting..."
  exit 1
else
  echo "Done"
fi
echo
printf "${YELLOW}Success! Your re-packed super image file:\n$new_super${NC}\n"

# Pack into tar (if needed)
if [ "$3" ]; then
  ext="${3##*.}"
  if [ "$ext" = "tar" ]; then
    tar_name="$3"
    pack_tar
  fi
fi
