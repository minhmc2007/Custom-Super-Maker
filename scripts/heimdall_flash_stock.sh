#!/bin/sh
# Copyleft 2022-2025 Uluruman
version=1.16.1

system_required="unzip tar file lz4"
script_dir=$(dirname $0)
heimdall_path="$script_dir"/../tools/heimdall

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
  if [ ! $skip_super ] && [ "$cs_bname" ] && [ "$cs_bname" != "super.img" ]; then
    echo "Renaming \"super.img\" back to \"$cs_bname\""
    mv "$cs_dir"/super.img "$custom_super"
  fi
  if [ ! $skip_optics ] && [ "$co_bname" ] && [ "$co_bname" != "optics.img" ]; then
    echo "Renaming \"optics.img\" back to \"$co_bname\""
    mv "$co_dir"/optics.img "$custom_optics"
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

unzip_section() {
  echo
  printf "${CYAN}Unzipping the $2 section...${NC}\n"
  if [ -d "$unzip_dir" ]; then
    section_file=$(find "$unzip_dir" -maxdepth 1 -type f -iname "$2_*.tar*" | head -n 1)
    if [ "$section_file" ]; then
      printf "${BLUE}It seems like the $2 section was already unzipped before.${NC}\n"
      read -p "Skip it? Y/n " ans
      if [ "$ans" = "n" ]; then
        rm -f "$section_file"
        uz=true
      fi
    else
      uz=true
    fi
  else
    mkdircr "$unzip_dir"
    uz=true
  fi
  if [ $uz ]; then
    section_file=$(zipinfo -1 "$1" | grep -i "^$2_.*\.tar")
    if [ "$section_file" ]; then
      if [ $(echo "$section_file" | wc -l) -gt 1 ]; then
        echo "Error: more than one $2 section file found in the Zip. Exiting..."
        exit 1
      fi
      printf "${GREEN}$2 section file:${NC} $section_file\n"
    else
      echo "$2 section of the firmware was not found in the Zip. Exiting..."
      exit 1
    fi
    unzip "$1" "$section_file" -d "$unzip_dir"
    if [ ! $? -eq 0 ]; then
      echo "Error while unzipping. Exiting..."
      exit 1
    fi
    section_file="$unzip_dir"/"$section_file"
  fi
}

check_section_dir() {
  section_file=$(find "$unzip_dir" -maxdepth 1 -type f -iname "$1_*.tar*" | head -n 1)
  if [ ! "$section_file" ]; then
    echo "$1 section tar was not found in the specified directory. Exiting..."
    exit 1
  else
    echo "$1 section tar found: $section_file"
  fi
}

untar_section() {
  echo
  printf "${CYAN}Unpacking the $2 tar...${NC}\n"
  untar_dir="$unzip_dir"/"$2"
  if [ -d "$untar_dir" ]; then
    f=$(find "$untar_dir" -maxdepth 1 -type f)
    if [ "$f" ]; then
      printf "${GREEN}Found unpacked files:${NC}\n"
      echo "$f"
      read -p "Reuse them? Y/n " ans
      if [ "$ans" = "n" ]; then
        rm -rf "$untar_dir"
        mkdircr "$untar_dir"
        ut=true
      fi
    else
      rm -rf "$untar_dir"
      mkdircr "$untar_dir"
      ut=true
    fi
  else
    mkdircr "$untar_dir"
    ut=true
  fi
  if [ $ut ]; then
    tar xv -C "$untar_dir" -f "$1"
    if [ ! $? -eq 0 ]; then
      echo "Error while unpacking. Exiting..."
      exit 1
    fi
  fi
}

update_useful_list() {
  useful=$(find "$ap" -maxdepth 1 -type f -iname "*.img*" -o -iname "*.bin*")
  add=$(find "$bl" -maxdepth 1 -type f -iname "*.img*" -o -iname "*.bin*")
  useful=$(printf "$useful\n$add")
  add=$(find "$cp" -maxdepth 1 -type f -iname "*.img*" -o -iname "*.bin*")
  useful=$(printf "$useful\n$add")
  add=$(find "$csc" -maxdepth 1 -type f -iname "*.img*" -o -iname "*.bin*")
  useful=$(printf "$useful\n$add")
}

prepare_flash_arg() {
  fname=$(basename "$2")
  # Skip
  skip=
  if [ ! $flash_unsafe ]; then
    case "$fname" in
      "metadata.img") skip=1 ;;
      "md_udc.img") skip=1 ;;
      "userdata.img") skip=1 ;;
      "cache.img") skip=1 ;;
      "misc.bin") skip=1 ;;
    esac
  fi
  if [ $skip_super ] && [ "$fname" = "super.img" ]; then skip=2
  elif [ $skip_optics ] && [ "$fname" = "optics.img" ]; then skip=2
  elif [ $skip_recovery ] && [ "$fname" = "recovery.img" ]; then skip=2
  elif [ $skip_boot ] && [ "$fname" = "boot.img" ]; then skip=2
  fi
  if [ $skip ]; then
    printf "${YELLOW}Skipping \"$fname\""
    if [ $skip -eq 1 ]; then printf " (unsafe)"; fi
    printf "${NC}\n"
    flash_arg=
    return
  fi
  # Prepare argument
  partition_name=$(echo "$1" | grep -B 1 -i "^Flash Filename: $fname$" | head -n 1)
  if [ ! "$partition_name" ]; then
    echo "Partition name for \"$fname\" was not found in the PIT file."
    echo "Incompatible firmware? Exiting..."
    exit 1
  fi
  partition_name=${partition_name#"Partition Name: "}
  if echo "$pnames" | grep "^$partition_name$" >> /dev/null; then
    printf "${YELLOW}Skipping \"$fname\" (duplicate partition name \"$partition_name\")${NC}\n"
    flash_arg=
  else
    echo "\"$fname\" goes into \"$partition_name\""
    flash_arg="--$partition_name \"$2\""
    pnames=$(printf "$pnames\n$partition_name")
  fi
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
optstr="?hpdsorb"
while getopts $optstr opt; do
  case "$opt" in
    p) purge_all=true ;;
    d) flash_unsafe=true ;;
    s) skip_super=true ;;
    o) skip_optics=true ;;
    r) skip_recovery=true ;;
    b) skip_boot=true ;;
    \?) exit 1 ;;
  esac
done
shift $(expr $OPTIND - 1)

# Help if no args
if [ $# -lt 1 ]; then
  echo
  printf "${YELLOW}=======================================================================
${CYAN} Script for flashing the stock firmware set using Heimdall for Samsung
 Galaxy A-series phones (e.g. SM-A127F/DSN, SM-A325F/DS, etc.).
 Version $version by Uluruman.
${YELLOW}=======================================================================\n
${GREEN}Usage:${NC} heimdall_flash_stock.sh [options] <firmware> [super.img] [optics.img]\n
'${CYAN}firmware${NC}': Either a zip file or a directory containing .tar* files for the AP,
  BL, CP and CSC sections of the firmware. Note that unsafe partitions
  (${GREEN}metadata/md_udc, userdata, cache, misc${NC}) will NOT be flashed unless you
  directly specify the '${CYAN}-d${NC}' option. Flashing these partitions will most likely
  cause the factory reset, and with that all the user data will be gone. As long
  as you do not flash the unsafe partitions you can always try flashing the
  previous version of firmware and restore your system in case it fails to boot
  after upgrade. Please note, that different phone models may have different
  unsafe partitions; the current list was made after the experiments with
  SM-A127F and SM-A325F.\n
'${CYAN}super.img${NC}' (optional): Use custom image for the Super partition. Use this to
  upgrade the stock firmware while retaining the custom GSI (and thus saving the
  user data as well). To achieve this, first you have to repack the GSI with the
  new stock firmware using the ${GREEN}repacksuper.sh${NC} script and then suppy the produced
  .img file as this parameter.\n
'${CYAN}optics.img${NC}' (optional): Use custom image for the Optics partition. The Optics
  partition contains the network providers database and generally the only file
  that has to be taken from your national version of the firmware for the phone
  to be fully-functional. For all the other partitions you can use another
  national variant which may be smaller and cleaner, e.g. NPB or PNG.\n
${GREEN}Options:${NC}\n
'${CYAN}-p${NC}': Purge the unpacking directories and start from scratch.\n
'${CYAN}-d${NC}': DO flash unsafe partitions. This option may cause corruption of user data,
  use it ONLY if you want a COMPLETE re-flash of the whole firmware.\n
'${CYAN}-s${NC}': Skip flashing super.img. You can try this as a quick-and-dirty way to
  upgrade the stock firmware while keeping the repacked GSI intact, but it is
  quite possible that the system will not boot in this case. For a cleaner way
  use the '${CYAN}super.img${NC}' parameter.\n
'${CYAN}-o${NC}': Skip flashing optics.img. Use this option if you mix different national
  versions of the firmware.\n
'${CYAN}-r${NC}': Skip flashing recovery.img. Use this if you are using a custom recovery
  tool such as TWRP, OrangeFox, etc.\n
'${CYAN}-b${NC}': Skip flashing boot.img. Use this if you are using a custom kernel,
  such as \"rainbow kernel\", though it is likely that the system won't boot
  after such a mixed upgrade.\n\n"
  exit
fi

# Check the "firmware" parameter
if [ -d "$1" ]; then
  # Dir
  unzip_dir="$1"
  echo
  printf "${CYAN}Checking the directory...${NC}\n"
  check_section_dir "AP"
  ap_unzipped="$section_file"
  check_section_dir "BL"
  bl_unzipped="$section_file"
  check_section_dir "CP"
  cp_unzipped="$section_file"
  check_section_dir "CSC"
  csc_unzipped="$section_file"
else
  # File, symbolic link, etc.
  echo
  printf "${CYAN}Checking the zip file...${NC}\n"
  if ! file -b -L "$1" | grep "Zip archive data" > /dev/null; then
    echo "The specified file is not a zip archive. Exiting...\n"
    exit 1
  else
    echo "Identified as zip archive"
  fi
fi

# Check the "super.img" parameter
if [ "$2" ]; then
  echo
  printf "${CYAN}Checking custom super.img...${NC}\n"
  custom_super="$2"
  if [ ! -f "$custom_super" ]; then
    echo "The specified Super image does not exist or not a file. Exiting..."
    exit 1
  elif ! file -b -L "$custom_super" | grep "Android sparse image" > /dev/null; then
    echo "The specified Super image is not an Android sparse image. Exiting..."
    exit 1
  fi
  echo "File format correct (Android sparse image)"
  cs_bname=$(basename "$custom_super")
  cs_dir=$(dirname "$custom_super")
fi

# Check the "optics.img" parameter
if [ "$3" ]; then
  echo
  printf "${CYAN}Checking custom optics.img...${NC}\n"
  custom_optics="$3"
  if [ ! -f "$custom_optics" ]; then
    echo "The specified Optics image does not exist or not a file. Exiting..."
    exit 1
  elif ! file -b -L "$custom_optics" | grep "Android sparse image" > /dev/null; then
    echo "The specified Optics image is not an Android sparse image. Exiting..."
    exit 1
  fi
  echo "File format correct (Android sparse image)"
  co_bname=$(basename "$custom_optics")
  co_dir=$(dirname "$custom_optics")
fi

# Purge
if [ $purge_all ]; then
  echo
  printf "${CYAN}Purging the unpacking directories...${NC}\n"
  if [ -d "$1" ]; then
    # Dir
    find "$1" -mindepth 1 -type d -exec rm -rf '{}' \; 2> /dev/null
    echo "Done"
  else
    # Zip, symbolic link to zip, etc.
    bn=$(basename "$1")
    unzip_dir="${bn%.*}"
    rm -rf "$unzip_dir"
    echo "Done"
  fi
fi

# Unpack zip
if [ ! -d "$1" ]; then
  # Zip
  bn=$(basename "$1")
  unzip_dir="${bn%.*}"
  unzip_section "$1" "AP"
  ap_unzipped="$section_file"
  unzip_section "$1" "BL"
  bl_unzipped="$section_file"
  unzip_section "$1" "CP"
  cp_unzipped="$section_file"
  unzip_section "$1" "CSC"
  csc_unzipped="$section_file"
fi

# Untar all files
untar_section "$ap_unzipped" "AP"
ap="$untar_dir"
untar_section "$bl_unzipped" "BL"
bl="$untar_dir"
untar_section "$cp_unzipped" "CP"
cp="$untar_dir"
untar_section "$csc_unzipped" "CSC"
csc="$untar_dir"
pit=$(find "$csc" -maxdepth 1 -type f -iname "*.pit")

# Check pit file
echo
printf "${CYAN}Checking the PIT file format...${NC}\n"
if [ ! -e "$pit" ]; then
  echo "PIT file not found. Don't know how to flash such a firmware. Exiting..."
  exit
fi
pit_id=$(cat "$pit" | od -t x1 -A n -N 4 | sed "s/ //g")
if [ "$pit_id" != "76983412" ]; then
  echo "PIT file seems to be incorrect. Exiting..."
  exit 1
else
  echo "Identified as PIT by file signature \"$pit_id\""
fi

# Decompress LZ4
echo
printf "${CYAN}Decompressing files...${NC}\n"
update_useful_list
echo "$useful" | while IFS= read f; do
  if [ ! -e "$f" ]; then
    echo "File \"$f\" is missing??? Something's wrong. Exiting..."
    exit 1
  fi
  echo -n "Checking \""$(basename "$f")"\" format: "
  if file -b -L "$f" | grep "LZ4 compressed data" > /dev/null; then
    echo "LZ4 compressed. Decompressing..."
    lz4 -d "$f"
    if [ $? -ne 0 ]; then
      echo "Error while uncompressing. Exiting..."
      exit 1
    fi
    rm -f "$f"
    f="${f%.*}"
  else
    echo "seems uncompressed. Accepting as is."
  fi
done
if [ $? -ne 0 ]; then exit 1; fi
update_useful_list

# Replace or add super.img
if [ "$custom_super" ]; then
  if echo "$useful" | grep "super.img[^\/]*$" > /dev/null; then
    echo "Replacing stock super.img with custom \"$cs_bname\""
    useful=$(echo "$useful" | sed "/super.img[^\/]*$/c $cs_dir/super.img")
  else
    echo "Adding custom super.img ($cs_bname)"
    useful="$useful\n$cs_dir"/super.img
  fi
fi

# Replace or add optics.img
if [ "$custom_optics" ]; then
  if echo "$useful" | grep "optics.img[^\/]*$" > /dev/null; then
    echo "Replacing stock optics.img with custom \"$co_bname\""
    useful=$(echo "$useful" | sed "/optics.img[^\/]*$/c $co_dir/optics.img")
  else
    echo "Adding custom optics.img ($co_bname)"
    useful="$useful\n$co_dir"/optics.img
  fi
fi

# Detect partition names and prepare the flash command arguments
# Why all the FIFO stuff? My zealous Bourne Shell compatibility, you know...
echo
printf "${CYAN}Detecting partition names...${NC}\n"
tf=$(mktemp -u)
mkfifo "$tf"
pit_data=$("$heimdall_path"/heimdall print-pit --file "$pit")
echo "$useful" | while IFS= read f; do
  prepare_flash_arg "$pit_data" "$f"
  if [ "$flash_arg" ]; then
    echo -n " $flash_arg" > "$tf" &
  fi
done
if [ $? -ne 0 ]; then
  rm "$tf"
  exit 1
fi
flash_args=$(cat "$tf" | cut -c 2-) # cut cuts the space char at the end
rm "$tf"

# Flash
echo
printf "${CYAN}Now get into the Download mode:${NC}
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

echo
printf "${CYAN}Detecting device...${NC}\n"
while true; do
  "$heimdall_path"/heimdall detect
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

if [ ! $skip_super ] && [ "$cs_bname" ] && [ "$cs_bname" != "super.img" ]; then
  echo "Temporarily renaming \"$cs_bname\" to \"super.img\""
  if [ -f "$cs_dir"/super.img ]; then
    printf "${BLUE}\"super.img\" already exists in the same directory.${NC}\n"
    read -p "Overwrite it? y/N " ans
    if [ "$ans" != "y" ]; then
      echo "Then exiting..."
      exit 0
    fi
    rm -f "$cs_dir"/super.img
  fi
  mv "$custom_super" "$cs_dir"/super.img
fi
if [ ! $skip_optics ] && [ "$co_bname" ] && [ "$co_bname" != "optics.img" ]; then
  echo "Temporarily renaming \"$co_bname\" to \"optics.img\""
  if [ -f "$cs_dir"/optics.img ]; then
    printf "${BLUE}\"optics.img\" already exists in the same directory.${NC}\n"
    read -p "Overwrite it? y/N " ans
    if [ "$ans" != "y" ]; then
      echo "Then exiting..."
      exit 0
    fi
    rm -f "$co_dir"/optics.img
  fi
  mv "$custom_optics" "$co_dir"/optics.img
fi
echo
printf "${CYAN}Flashing all partitions...${NC}\n"
trap "trap_func" INT
echo "Flushing disk cache (this may take some time)"
sync
echo "$flash_args" | xargs "$heimdall_path"/heimdall flash --pit "$pit"
hm_ec=$?
trap - INT
echo "Heimdall exit code: $hm_ec\n"
if [ ! $skip_super ] && [ "$cs_bname" ] && [ "$cs_bname" != "super.img" ]; then
  echo "Renaming \"super.img\" back to \"$cs_bname\""
  mv "$cs_dir"/super.img "$custom_super"
fi
if [ ! $skip_optics ] && [ "$co_bname" ] && [ "$co_bname" != "optics.img" ]; then
  echo "Renaming \"optics.img\" back to \"$co_bname\""
  mv "$co_dir"/optics.img "$custom_optics"
fi

if [ ! $hm_ec -eq 0 ]; then
  printf "${RED}Heimdall was unable to upload firmware.${NC}\n"
  printf "${YELLOW}You have to resort to Odin for Windows. Sorry.${NC}\n"
  echo "Exiting..."
  exit 0
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

