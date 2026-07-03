#!/bin/sh
# Copyleft 2021-2025 Uluruman
version=1.16.1

script_dir=$(dirname $0)
lptools_path="$script_dir/lpunpack_and_lpmake"
heimdall_path="$script_dir/heimdall"
empty_product_path="$script_dir/misc/product.img"
empty_system_ext_path="$script_dir/misc/system_ext.img"
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
  mkdir "$1"
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
    # Generic name
    tar_name=super.tar
  fi
  if [ $(basename "$tar_name") = "$tar_name" ]; then
    # Add default path
    tar_name="$new_super_dir"/"$tar_name"
  fi
  # Pack
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

heimdall_flash () {
  echo
  printf "${CYAN}Trying flashing using Heimdall...${NC}\n"
  echo "Flushing disk cache (this may take some time)"
  sync
  # Detect device
  while true; do
    "$heimdall_path/heimdall" detect
    if [ $? -eq 0 ]; then
      break
    fi
    printf "${RED}Device not detected. Is it really connected and in the Download mode?${NC}\n"
    read -p "Try again? Y/n " ans
    if [ "$ans" = "n" ]; then
      echo "Then exiting..."
      exit 0
    fi
  done
  echo
  # Extract partition name from PIT
  if [ ! $manual_super_name ]; then
    pit=$("$heimdall_path"/heimdall print-pit --no-reboot)
    hm_ec=$?
    if [ ! $hm_ec -eq 0 ]; then
      return
    fi
    partition_name=$(echo "$pit" | grep -B 1 -i "^Flash Filename: super\.img$" | head -n 1)
    partition_name=${partition_name#"Partition Name: "}
  fi
  if [ ! "$partition_name" ]; then
    if [ ! $manual_super_name ]; then
      printf "${RED}Cannot auto-detect the exact name of the Super partition for your phone.${NC}\n"
    else
      printf "${BLUE}Please enter the exact name of the Super partition for your phone.${NC}\n"
    fi
    printf "Usually it is just \"SUPER\" (SM-A127F) or \"super\" (SM-A325F).\n"
    read -p "Enter partition name (case sensitive): " partition_name
  else
    printf "${GREEN}Super parition name:${NC} $partition_name\n"
  fi
  echo
  # Prepare
  if [ "$new_super" != "$new_super_dir"/super.img ]; then
    echo "Temporarily renaming \"$new_super_name\" to \"super.img\""
    if [ -f "$new_super_dir"/super.img ]; then
      printf "${BLUE}super.img file already exists in the same directory.${NC}\n"
      read -p "Overwrite it? y/N " ans
      if [ "$ans" != "y" ]; then
        echo "Then exiting..."
        exit 0
      fi
      rm -f "$new_super_dir"/super.img
    fi
    mv "$new_super" "$new_super_dir"/super.img
  fi
  # Flash
  trap "trap_func" INT
  if [ ! $manual_super_name ]; then
    "$heimdall_path"/heimdall flash --$partition_name "$new_super_dir"/super.img --resume
  else
    "$heimdall_path"/heimdall flash --$partition_name "$new_super_dir"/super.img
  fi
  hm_ec=$?
  trap - INT
  # Outro
  echo "Heimdall exit code: $hm_ec"
  if [ "$new_super_dir"/super.img != "$new_super" ]; then
    echo "Renaming \"super.img\" back to \"$new_super_name\""
    mv "$new_super_dir"/super.img "$new_super"
  fi
  echo
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
  if [ ! $? -eq 0 ]; then
    exit
  fi
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

# Help if no args
if [ $# -lt 2 ]; then
  echo
  printf "${GREEN}===========================================================================
${YELLOW} Script for repacking and flashing GSI (Generic System Image) files into
   super partition of Samsung Galaxy A-series phones (e.g. SM-A127F/DSN,
   SM-A325F/DS, etc.). Version $version by Uluruman
${GREEN}===========================================================================\n
${YELLOW}Usage:${NC} repacksuper.sh [options] <source> <new_system> [destination]\n
'${CYAN}source${NC}' is the stock firmware in any of the following forms:
  1. Stock firmware Zip file
  2. Directory created by the heimdall_flash_stock.sh script
  3. Directory containing the AP_*.tar* file from the stock firmware
  4. .tar file containing the stock super.img, e.g. AP_*.tar* file
  5. Directory containing the unpacked and converted files from the previous
     runs of this script (\"repacksuper\" dir)
  5. Stock super.img file (name can be arbitrary). In this case no files related
     to the stock super.img will be reused.
  Examples: ${BLUE}Samfw.com_SM-A127F_NPB_A127FXXU4AUK1_fac.zip
            Samfw.com_SM-A127F_NPB_A127FXXU4AUK1_fac
            AP_A127FXXU4AUK1_CL23021938_QB46136399_REV00.tar.md5
            Samfw.com_SM-A127F_NPB_A127FXXU4AUK1_fac/repacksuper${NC}\n
'${CYAN}new_system${NC}': GSI image file you want to install.
  Supported formats: IMG, XZ, Zip, GZ.
  Example: ${BLUE}lineage-18.1-20211108-UNOFFICIAL-treble_arm64_bvS.img.xz${NC}\n
  If you specify an existing \"repacksuper\" dir as <source> and \"-\" as
  <new_system> nothing will be unpacked and the existing files in the \"super\"
  subdir will be reused unconditionally.\n
'${CYAN}destination${NC}' (optional): Any of the following:
  1. .img file for flashing using Heimdall
     Example: ${BLUE}~/firmware/lineage-18.1_super.img${NC}
  2. .tar file for flashing using Odin
     Example: ${BLUE}lineage-18.1_super.tar${NC}\n
  If this parameter is omitted completely then the the default name \"super.img\"
  will be used. If file extension is not specified then .img will be used.\n
  ${RED}NOTE${NC}: The super partition file must have a name of \"super.img\" (either
  normally or within a tar archive). If it is different you must rename it to
  \"super.img\" before flashing, otherwise the phone will not boot. When the file
  is flashed by this script or by heimdall_flash.sh all of this is done
  automatically.\n
${YELLOW}Options:${NC}\n
'${CYAN}-r <dir>${NC}': Root directory where the resulting super.img file will be placed by
  default and where the \"repacksuper\" subdir will be created. The \"repacksuper\"
  directory contains all the unpacked files and can later be reused. Default:
  current directory.\n
'${CYAN}-e${NC}': Use empty product.img file instead of the stock one. If you are replacing
  your system with any vanilla-based GSI (avZ, bvZ) you can use this option for
  extra protection against the gray Goo. The stock product.img usually contains
  files of unclear functionality, including various suspicious APKs.\n
'${CYAN}-x${NC}': (${RED}experimental${NC}) Use empty system_ext.img for the firmware types which use
  it (e.g. SM-A032F/M). The reasons are the same as for the ${CYAN}-e${NC} option.\n
'${CYAN}-v <vendor_dlkm.img>${NC}': (${RED}experimental${NC}) Specify an vendor_dlkm.img file (ext2-4)
  to be used for the Vendor DLKM partition. If the partition already exists the
  new file will replace it.\n
'${CYAN}-s${NC}': Silent mode. Just repack everything without questions (but with lesser
  flexibility).\n
'${CYAN}-p${NC}': Purge the \"repacksuper\" directory and do the whole repacking from scratch.\n
'${CYAN}-m${NC}' (${RED}needed for SM-A127F${NC}): Forces manual specification of the Super partition
  name when flashing with Heimdall (Linux). Use this option if Heimdall only
  gets the parition name (i.e. displays something like \"Super parition name:
  SUPER\") and does nothing on the second stage, just exiting without the
  actual flashing.\n
'${CYAN}-w${NC}': (${RED}experimental${NC}) Make all partitions writable. This option doesn't do much
  without altering the fstab file (which is not a trivial task on its own) and
  also may greatly lessen protection from malicious apps.\n\n"
  exit
fi

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
  # First parameter is a dir
  if [ -f "$1/AP/super.img" ]; then
    # Dir created by heimdall_flash_stock.sh
    src_format="dir"
    src_dir="$1"
    stock_super="$src_dir"/AP/super.img
    if ! file -b -L "$stock_super" | grep "Android sparse image" > /dev/null; then
      echo "Unknown source file format. Exiting..."
      exit 1
    fi
    echo "Source identified as directory created by heimdall_flash_stock.sh"
  elif [ -f "$1"/super.img ]; then
    # Repacksuper dir
    src_format="dir"
    src_dir="$1"
    stock_super="$src_dir"/super.img
    rps_dir="$src_dir"
    if ! file -b -L "$stock_super" | grep "Android sparse image" > /dev/null; then
      echo "Unknown source file format. Exiting..."
      exit 1
    fi
    echo "Source identified as the repacksuper dir"
  else
    # Dir containing an AP_*.tar* file
    src_format="ap_tar"
    src_dir="$1"
    ap_tar=$(find "$src_dir" -type f -iname "AP_*.tar*" | head -n 1)
    if [ $ap_tar ]; then
      if ! file -b -L "$ap_tar" | grep "tar archive" > /dev/null; then
        echo "Unknown source file format. Exiting..."
        exit 1
      fi
      if ! tar t -f "$ap_tar" | grep -i "^super\.img" > /dev/null; then
        echo "super.img not found in the tar file. Exiting..."
        exit 1
      fi
      echo "Source identified as directory containing an AP_*.tar* file"
    else
      echo "Directory was specified but no useful file was found there. Exiting..."
      exit 1
    fi
  fi
else
  # First parameter is a file, symbolic link, etc.
  if file -b -L "$1" | grep "Android sparse image" > /dev/null; then
    # Stock super.img directly specified
    src_format="img"
    src_dir=$(dirname "$1")
    stock_super="$1"
    echo "Source identified as a directly specified sparse image file"
  elif file -b -L "$1" | grep "Zip archive data" > /dev/null; then
    # Zip with full stock firmware
    src_format="zip"
    bn=$(basename "$1")
    src_dir=$(dirname "$1")"/${bn%.*}"
    zip_file="$1"
    if ! zipinfo -1 "$zip_file" | grep "\.tar" > /dev/null; then
      echo "The specified Zip archive does not contain any .tar files. Exiting..."
      exit 1
    fi
    echo "Source identified as Zip archive with tar archives inside"
  elif file -b -L "$1" | grep "tar archive" > /dev/null; then
    # .tar file with super.img inside
    src_format="ap_tar"
    src_dir=$(dirname "$1")
    ap_tar="$1"
    if ! tar t -f "$ap_tar" | grep -i "^super\.img" > /dev/null; then
      echo "super.img was not found in the tar file. Exiting..."
      exit 1
    fi
    echo "Source identified as tar archive with super.img inside"
  else
    echo "Unknown source file format. Exiting..."
    exit 1
  fi
fi
case "$src_format" in
     "zip") printf "${GREEN}Source Zip file${NC}: $zip_file\n" ;;
  "ap_tar") printf "${GREEN}Source AP tar file${NC}: $ap_tar\n" ;;
     "img") printf "${GREEN}Source super.img file${NC}: $stock_super\n" ;;
     "dir") printf "${GREEN}Source dir${NC}: $src_dir\n" ;;
esac
# Additional info
new_system_src="$2"
if [ "$new_system_src" != "-" ]; then
  new_system_src_dir=$(dirname "$new_system_src")
fi
printf "${GREEN}New system image${NC}: $new_system_src\n"
if [ ! "$rps_dir" ]; then
  rps_dir="$rdir"/repacksuper
fi
printf "${GREEN}Repacksuper dir${NC}: $rps_dir\n"

# Purge the repacksuper dir
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

# Create the repacksuper dir
if [ ! -d "$rps_dir" ]; then
  mkdircr "$rps_dir"
fi

# Unpack files
if [ "$src_format" != "dir" ] && [ "$src_format" != "img" ]; then
  echo
  printf "${CYAN}Unpacking files...${NC}\n"

  # Unpack Zip
  if [ "$src_format" = "zip" ]; then
    if [ -d "$src_dir" ]; then
      ap_tar=$(find "$src_dir" -maxdepth 1 -type f -iname "AP_*.tar*" | head -n 1)
      if [ "$ap_tar" ]; then
        echo "Found \"$ap_tar\""
        if [ ! $silent_mode ]; then
          echo "${BLUE}It seems like the file was already extracted before.${NC}"
          read -p "Use the existing file? Y/n " ans
          if [ "$ans" = "n" ]; then
            rm -f "$ap_tar"
            uz=true
          fi
        else
          echo "(silent mode) Using existing file"
        fi
      else
        uz=true
      fi
    else
      mkdircr "$src_dir"
      uz=true
    fi
    if [ $uz ]; then
      if [ -f "$rps_dir"/super.img ] || [ -f "$rps_dir"/super.raw ]; then
        echo "Removing the old super.img and super.raw"
        rm -f "$rps_dir"/super.*
      fi
      ap_tar=$(zipinfo -1 "$zip_file" | grep -i "^AP_.*\.tar")
      if [ "$ap_tar" ]; then
        if [ $(echo "$ap_tar" | wc -l) -gt 1 ]; then
          echo "Error: more than one AP section file found in \"$zip_file\". Exiting..."
          exit 1
        fi
        echo "AP section file: $ap_tar"
      else
        echo "AP section of the firmware was not found in \"$zip_file\". Exiting..."
        exit 1
      fi
      unzip "$zip_file" "$ap_tar" -d "$src_dir"
      if [ ! $? -eq 0 ]; then
        echo "Error while unzipping. Exiting..."
        exit 1
      fi
      ap_tar="$src_dir"/"$ap_tar"
    fi
  fi

  # Check for existing super.img
  stock_super=$(find "$rps_dir" -maxdepth 1 -type f -iname "super.img*" | head -n 1)
  if [ "$stock_super" ]; then
    echo "Found \"$stock_super\""
    if [ ! $silent_mode ]; then
      printf "${BLUE}It seems like super.img was already extracted before.${NC}\n"
      read -p "Use the existing file? Y/n " ans
      if [ "$ans" = "n" ]; then
        rm -f "$stock_super"
        ut=true
      fi
    else
      echo "(silent mode) Using existing file"
    fi
  else
    ut=true
  fi

  # Unpack super.img.lz4 from tar
  if [ $ut ]; then
    if [ -f "$rps_dir"/super.img ] || [ -f "$rps_dir"/super.raw ]; then
      echo "Removing the old super.img and super.raw"
      rm -f "$rps_dir"/super.*
    fi
    ttf=$(tar tf "$ap_tar" | grep "^super\.img" | head -n 1)
    if [ "$ttf" ]; then
      echo "super.img found in \"$ap_tar\", extracting..."
      tar xv -C "$rps_dir" -f "$ap_tar" "$ttf"
      if [ ! $? -eq 0 ]; then
        echo "Error while extracting. Exiting..."
        exit 1
      fi
      stock_super="$rps_dir"/"$ttf"
      echo "Done"
    else
      echo "No super.img found in \"$ap_tar\". Exiting..."
      exit 1
    fi
  fi

  # Unpack LZ4-compressed super.img
  if file -b -L "$stock_super" | grep "LZ4 compressed data" > /dev/null; then
    echo "super.img is LZ4-compressed, uncompressing..."
    lz4 -d "$stock_super"
    if [ ! $? -eq 0 ]; then
      echo "Error while uncompressing. Exiting..."
      exit 1
    fi
    rm -f "$stock_super"
    stock_super="${stock_super%.*}"
  fi
else
  if [ -f "$rps_dir"/super.raw ]; then
    printf "${BLUE}super.raw file already exists in the \"repacksuper\" directory.${NC}\n"
    if [ $src_format != "dir" ]; then
      if [ ! $silent_mode ]; then
        read -p "Reuse it? Y/n " ans
        if [ "$ans" = "n" ]; then
          # Remove the old super.raw
          echo "Removing the old super.raw"
          rm -f "$rps_dir"/super.raw
        fi
        echo "Reusing the old super.raw"
        stock_super_raw="$rps_dir"/super.raw
      else
        echo "(silent mode) Reusing existing image files"
        stock_super_raw="$rps_dir"/super.raw
      fi
    else
      # Reuse the old super.raw
      echo "Reusing the old super.raw"
      stock_super_raw="$rps_dir"/super.raw
    fi
  fi
fi

# Create super.raw
if [ ! "$stock_super_raw" ]; then
  # Check the sparse super format
  echo
  printf "${CYAN}Checking the stock super.img file...${NC}\n"
  printf "${GREEN}Stock super.img:${NC} $stock_super\n"
  echo "Checking the file format (should be sparse image)..."
  if ! file -b -L "$stock_super" | grep "sparse image" > /dev/null; then
    # Already raw?
    echo "Not a sparse image. May be already non-sparse?"
  else
    # Sparse to non-sparse conversion
    stock_super_raw="$rps_dir"/super.raw
    if [ ! -f "$stock_super_raw" ]; then
      echo "Converting the sparse file format to non-sparse (raw)..."
      simg2img "$stock_super" "$stock_super_raw"
      if [ $? -ne 0 ]; then
        echo "Cannot convert. File corrupt? Exiting..."
        exit 1
      fi
    fi
  fi
  printf "${GREEN}Raw stock super.img:${NC} $stock_super_raw\n"
  echo "Checking the raw super file format (should be dumpable by lpdump)..."
  "$lptools_path"/lpdump "$stock_super_raw" -d > /dev/null
  if [ $? -ne 0 ]; then
    echo "Cannot dump metadata size using lpdump. Exiting..."
    exit 1
  else
    echo "Correct"
  fi
fi

# Prepare the super dir
echo
printf "${CYAN}Preparing the \"super\" directory...${NC}\n"
super_dir="$rps_dir"/super
printf "${GREEN}\"super\" directory${NC}: $super_dir\n"
if [ ! -d "$super_dir" ]; then
  echo "Directory does not exist, creating"
  mkdircr "$super_dir"
  urs=true
else
  # Check if there are already some unpacked files in the super dir
  img_in_super=$(find "$super_dir" -type f -iname "*.img" | head -n 1)
  if [ "$img_in_super" ]; then
    if [ $ut ] || [ "$src_format" = "img" ]; then
      # Don't reuse if new super.img was just unpacked or directly specified
      rm -f "$super_dir"/*
      urs=true
    else
      printf "${BLUE}There are some image files in the \"super\" directory.${NC}\n"
      if [ "$new_system_src" != "-" ]; then
        if [ ! $silent_mode ]; then
          read -p "Reuse them? Y/n " ans
          if [ "$ans" = "n" ]; then
            rm -f "$super_dir"/*
            urs=true
          fi
        else
          echo "(silent mode) Reusing existing image files"
        fi
      else
        echo "\"-\" was specified as the new system image. Reusing the existing files."
      fi
    fi
  else
    urs=true
  fi
fi

# Unpack the raw stock super file
if [ $urs ]; then
  echo
  printf "${CYAN}Unpacking the super file...${NC}\n"
  "$lptools_path"/lpunpack "$stock_super_raw" "$super_dir"
  if [ $? -ne 0 ]; then
    echo "Cannot correctly unpack the super file. Exiting..."
    exit 1
  else
    echo "Done"
  fi
  if [ ! -f "$super_dir"/system.img ]; then
    echo "system.img was not unpacked for some reason. Exiting..."
    exit 1
  fi
  echo "Backing up the stock system.img"
  if [ ! -f "$rps_dir"/system.stock.img ]; then
    mv "$super_dir"/system.img "$rps_dir"/system.stock.img
  fi
fi

# Replace the system
echo
printf "${CYAN}Replacing the system image with the new one...${NC}\n"
new_system="$super_dir"/system.img
if [ "$new_system_src" = "-" ] && [ ! -f "$new_system" ]; then
  echo "No existing system.img found and no new system image specified. Exiting..."
  exit 1
fi
if [ -f "$new_system" ]; then
  if [ "$new_system_src" != "-" ]; then
    printf "${BLUE}There is already a system.img file in the \"super\" subdir.${NC}\n"
    if [ ! $silent_mode ]; then
      read -p "Reuse it? y/N " ans
      if [ "$ans" != "y" ]; then
        rm -f "$new_system"
        suz=true
      fi
    else
      echo "(silent mode) Unpacking again."
      rm -f "$new_system"
      suz=true
    fi
  else
    echo "\"-\" was specified as the new system image. Reusing the existing system.img."
  fi
else
  suz=true
fi
if [ $suz ]; then
  echo "Checking the new system format (compressed image)..."
  format=$(file -b -L "$new_system_src")
  # Unpack
  if echo "$format" | grep "Zip archive data" > /dev/null; then
    # Unzip
    img_files=$(zipinfo -1 "$new_system_src" | grep -i "\.img$")
    if [ ! "$img_files" ]; then
      echo "No .img files found in the archive. Exiting..."
      exit 1
    fi
    img_file_cnt=$(echo "$img_files" | wc -l)
    if [ $img_file_cnt -gt 1 ]; then
      echo "More than one .img file found in the Zip."
      echo "Checking if there is system.img among them..."
      if echo "$img_files" | grep -i "^system\.img$" > /dev/null; then
        echo "system.img found."
        unpack_file=system.img
      else
        echo "system.img not found. Exiting..."
        exit 1
      fi
    else
      unpack_file=$(echo "$img_files" | sed 's|.*  \(.*\)|\1|')
    fi
    unpacked_file="$rps_dir"/"$unpack_file"
    isunzipped
    if [ $do_unzip ]; then
      echo "Unzipping $unpack_file from the Zip archive..."
      unzip "$new_system_src" "$unpack_file" -d "$rps_dir"
    fi
  else
    if echo "$format" | grep "XZ compressed" > /dev/null; then
      # UnXZ
      unpacked_src="${new_system_src%.*}"
      unpacked_src_fname=$(basename "$unpacked_src")
      unpacked_file="$rps_dir"/"$unpacked_src_fname"
      isunzipped
      if [ $do_unzip ]; then
        echo "Unzipping $unpacked_src_fname from the XZ archive..."
        unxz -T 0 -k "$new_system_src"
        mv "$unpacked_src" "$rps_dir"
      fi
    else
      if echo "$format" | grep "gzip compressed" > /dev/null; then
        # Un-gzip
        zip_list=$(gzip -l "$new_system_src")
        img_files=$(echo "$zip_list" | grep -i "\.img$")
        if [ ! "$img_files" ]; then
          echo "No .img files found in the archive. Exiting..."
          exit 1
        fi
        unpack_file=$(basename $(echo "$img_files" | sed 's|.* \(.*\)|\1|'))
        unpacked_file="$rps_dir"/"$unpack_file"
        isunzipped
        if [ $do_unzip ]; then
          echo "Unzipping $unpack_file from the GZ archive..."
          cur_dir="$PWD"
          cd "$new_system_src_dir"
          gzip -d -k "$new_system_src"
          cd "$cur_dir"
          mv "$new_system_src_dir"/"$unpack_file" "$unpacked_file"
        fi
      else
        # Just copy
        echo "Presuming the new system file is uncompressed..."
        unpacked_file="$rps_dir"/system.img
        cp "$new_system_src" "$unpacked_file"
      fi
    fi
  fi
  # Check the format
  echo "Checking the new system format (uncompressed image)..."
  if ! file -b -L "$unpacked_file" | grep "sparse image" > /dev/null; then
    # Copy
    echo "Not a sparse image format. Already raw?"
    cp "$unpacked_file" "$new_system"
  else
    # Convert to raw
    echo "Converting the new system image to the non-sparse (raw) format..."
    simg2img "$unpacked_file" "$new_system"
    if [ $? -ne 0 ]; then
      echo "The super file seems corrupt. Exiting..."
      exit 1
    fi
  fi
fi
# Check if the new system format is actually ext2/3/4
echo "Checking the new system format (filesystem)..."
if ! file -b -L "$new_system" | grep "ext[2-4] filesystem" > /dev/null; then
  echo "The new system file does not contain an ext2/3/4 filesystem. Exiting..."
  exit 1
else
  echo "Correct: ext2/3/4 filesystem"
fi

# Prepare repacking
if [ "$3" ]; then
  ext="${3##*.}"
  if [ "$ext" = "$3" ]; then
    ext= # No extension
  fi
  if [ ! "$ext" ]; then
    # Add extension
    new_super="$3.img"
  elif [ "$ext" = "img" ]; then
    # Full name
    new_super="$3"
  else
    # Replace extension
    filename="${3%.*}"
    new_super="$filename.img"
  fi
else
  # Generic name
  new_super="super.img"
fi
# Add rdir if needed
new_super_name=$(basename "$new_super")
if [ ! $(dirname "$new_super") ]; then
  new_super="$rdir"/"$new_super"
fi
new_super_dir=$(dirname "$new_super")

# Repack the new super
echo
printf "${CYAN}(Re)packing the new super file...${NC}\n"
if [ -f "$new_super" ]; then
  rm -f "$new_super"
fi
echo "Preparing metadata..."
# Get partition sizes
system_size=$(stat --format="%s" "$new_system")
if [ -f "$super_dir"/system_ext.img ]; then
  system_ext_size=$(stat --format="%s" "$super_dir"/system_ext.img)
fi
if [ -f "$super_dir"/odm.img ]; then
  odm_size=$(stat --format="%s" "$super_dir"/odm.img)
fi
if [ -f "$super_dir"/odm_dlkm.img ]; then
  odlkm_size=$(stat --format="%s" "$super_dir"/odm_dlkm.img)
fi
if [ -f "$super_dir"/product.img ]; then
  product_size=$(stat --format="%s" "$super_dir"/product.img)
fi
if [ -f "$super_dir"/vendor.img ]; then
  vendor_size=$(stat --format="%s" "$super_dir"/vendor.img)
fi
if [ -f "$super_dir"/vendor_dlkm.img ]; then
  vdlkm_size=$(stat --format="%s" "$super_dir"/vendor_dlkm.img)
fi
# Get super size
lpdump "block_devices" "super" "size"
if [ ! $retval ]; then
  echo "Cannot extract a value using lpdump. Incompatible firmware? Exiting..."
  exit 1
fi
block_device_table_size=$retval
# Get group names
lpdump "partitions" "system" "group_name"
system_group=$retval
if [ $system_ext_size ]; then
  lpdump "partitions" "system_ext" "group_name"
  mto_group_warning
  system_ext_group=$retval
fi
if [ $odm_size ]; then
  lpdump "partitions" "odm" "group_name"
  mto_group_warning
  odm_group=$retval
fi
if [ $odlkm_size ]; then
  lpdump "partitions" "odm_dlkm" "group_name"
  mto_group_warning
  odlkm_group=$retval
fi
if [ $product_size ]; then
  lpdump "partitions" "product" "group_name"
  mto_group_warning
  product_group=$retval
fi
if [ $vendor_size ]; then
  lpdump "partitions" "vendor" "group_name"
  mto_group_warning
  vendor_group=$retval
fi
if [ $vdlkm_size ]; then
  lpdump "partitions" "vendor_dlkm" "group_name"
  mto_group_warning
  vdlkm_group=$retval
fi
# Get groups size
lpdump "groups" "$system_group" "maximum_size"
groups_max_size=$retval
metadata_max_size=65536
# Display info
printf "${GREEN}System partition group name:${NC} $system_group\n"
printf "${GREEN}System partition size:${NC} $system_size\n"
if [ $system_ext_size ]; then
  printf "${GREEN}System_ext partition group name:${NC} $system_ext_group\n"
  printf "${GREEN}System_ext partition size:${NC} $system_ext_size\n"
fi
if [ $odm_size ]; then
  printf "${GREEN}ODM partition group name:${NC} $odm_group\n"
  printf "${GREEN}ODM partition size:${NC} $odm_size\n"
fi
if [ $odlkm_size ]; then
  printf "${GREEN}ODM DLKM partition group name:${NC} $odlkm_group\n"
  printf "${GREEN}ODM DLKM partition size:${NC} $odlkm_size\n"
fi
if [ $product_size ]; then
  printf "${GREEN}Product partition group name:${NC} $product_group\n"
  printf "${GREEN}Product partition size:${NC} $product_size\n"
fi
if [ $vendor_size ]; then
  printf "${GREEN}Vendor partition group name:${NC} $vendor_group\n"
  printf "${GREEN}Vendor partition size:${NC} $vendor_size\n"
fi
if [ $vdlkm_size ]; then
  printf "${GREEN}Vendor DLKM partition group name:${NC} $vdlkm_group\n"
  printf "${GREEN}Vendor DLKM partition size:${NC} $vdlkm_size\n"
fi
printf "${GREEN}Block device table size:${NC} $block_device_table_size\n"
printf "${GREEN}Groups maximum size:${NC} $groups_max_size\n"
# Privacy enhancements
if [ $empty_product ]; then
  echo "Using empty product.img"
  product_img="$empty_product_path"
  product_size=$(stat --format="%s" "$product_img")
else
  product_img="$super_dir"/product.img
fi
if [ $empty_system_ext ]; then
  echo "Using empty system_ext.img"
  system_ext_img="$empty_system_ext_path"
  system_ext_size=$(stat --format="%s" "$system_ext_img")
else
  system_ext_img="$super_dir"/system_ext.img
fi
if [ $writable ]; then
  echo "All partitions will be writable"
  attrs="none"
else
  echo "All partitions will be read-only"
  attrs="readonly"
fi
# Custom Vendor DLKM
if [ "$custom_vdlkm" ]; then
  echo "Using custom vendor_dlkm.img"
  vdlkm_img="$custom_vdlkm"
  vdlkm_size=$(stat --format="%s" "$vdlkm_img")
  if [ ! "$vdlkm_group" ]; then
    if [ "$vendor_group" ]; then
      echo "Using the Vendor partition group name for Vendor DLKM"
      vdlkm_group="$vendor_group"
    else
      echo "Using the System partition group name for Vendor DLKM"
      vdlkm_group="$system_group"
    fi
  fi
else
  vdlkm_img="$super_dir"/vendor_dlkm.img
fi
# Create the new super.img
echo "(Re)packing..."
"$lptools_path"/lpmake --metadata-size $metadata_max_size --super-name super --metadata-slots 2 \
  --device super:$block_device_table_size --group $system_group:$groups_max_size \
  --partition system:readonly:$system_size:$system_group --image system="$new_system" \
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

# Flash the file
echo
read -p "Do you want to flash it into the device? Y/n " ans
if [ "$ans" != "n" ]; then
  printf "
${CYAN}Now get into the Download mode:${NC}
A. If the phone is currently turned off, hold down BOTH the Volume Up and Down
   buttons and connect the USB cable to PC while keeping them pressed
B. If the phone is currently booted, first connect the USB cable to PC, then do
   the reboot but as soon as the screen goes black immediately hold down BOTH
   the Volume Up and Down buttons
When the phone is in the Download mode (teal screen), continue to the
\"Downloading...\" page following the instructions on the screen (usually it is
done by pressing the Volume Up button).\n\n"
  read -p "Are you now in the download mode? Y/n " ans
  if [ "$ans" = "n" ]; then
    echo "Then exiting..."
    exit 0
  fi

  # Flash
  heimdall_flash
  if [ ! $hm_ec -eq 0 ]; then
    printf "${RED}Heimdall was unable to upload firmware.${NC}\n"
    read -p "Did you see any uploading progress (percents counting up) y/N " ans
    if [ "$ans" != "y" ]; then
      echo
      printf "${YELLOW}Then let's try a different approach. Now restart your device and enter the\n"
      printf "Download mode once again.${NC}\n"
      read -p "Have you done it? Y/n " ans
      if [ "$ans" != "n" ]; then
        manual_super_name=true
        heimdall_flash
      fi
    fi
  fi

  # Final check
  if [ ! $hm_ec -eq 0 ]; then
    echo
    printf "${YELLOW}It seems like every attempt at using Heimdall fails. You can try packing your\n"
    printf "firmware into a tar archive and flash it into the AP slot using Odin (for\n"
    printf "Windows).${NC}\n"
    if [ ! $pack_tar ]; then
      read -p "Do you want to pack it? Y/n " ans
      if [ "$ans" != "n" ]; then
        tar_name="${new_super%.*}.tar"
        pack_tar
      fi
    else
      echo
      printf "${GREEN}Your tar file:${NC}\n$tar_name\n\n"
    fi
  else
    printf "${GREEN}Success!${NC}\n
${YELLOW}Now DON'T disconnect the USB cable, otherwise the phone may freeze at the
logo screen on the first boot.${NC}\n
Some phones (such as SM-A127F) do not boot without the USB cable at all, so you
should at least plug in an empty OTG adapter for such phones to boot or reboot.
If you still cannot boot, try it with the USB cable disconnected.\n
In case you have downgraded your system version or just as a last resort try
rebooting into the Recovery mode and do factory reset (in this case all your
user data will be erased):\n
1. Connect the USB cable
2. Hold down Volume Down and Power buttons to reboot the phone
3. As soon as the screen goes black hold down the Volume Up and Power buttons
4. Once you got into the Recovery, do \"Factory Reset\" there, then \"Reboot\".\n\n"
  fi
else
  echo "Then just exiting..."
fi


