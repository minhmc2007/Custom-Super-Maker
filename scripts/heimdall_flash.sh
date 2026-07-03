#!/bin/sh
# Copyleft 2022-2025 Uluruman
version=1.16.1

system_required="tar file column"
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
  if [ "$img_fname" != "$img_bname" ] && [ -f "$img_dir"/"$img_fname" ]; then
    echo "Renaming \"$img_fname\" back to \"$img_bname\""
    mv "$img_dir"/"$img_fname" "$img"
  fi
  echo "Action aborted. Exiting..."
  exit 1
}

heimdall_flash() {
  if [ "$img_fname" != "$img_bname" ]; then
    "$heimdall_path"/heimdall flash --$partition_name "$img_dir"/"$img_fname" ${resume:+--resume}
  else
    "$heimdall_path"/heimdall flash --$partition_name "$img" ${resume:+--resume}
  fi
  hm_ec=$?
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
optstr="?hsp:f:"
while getopts $optstr opt; do
  case "$opt" in
    s) flash_as_super=true ;;
    p) ext_pit="$OPTARG" ;;
    f) flash_as_file=true
       img_fname="$OPTARG"
       ;;
    \?) exit 1 ;;
  esac
done
shift $(expr $OPTIND - 1)

# Help if no args
if [ $# -lt 1 ]; then
  echo
  printf "${BLUE}=======================================================================
${YELLOW} Script for flashing custom firmware using Heimdall for Samsung Galaxy
 A-series phones (e.g. SM-A127F/DSN, SM-A325F/DS, etc.).
 Version $version by Uluruman.
${BLUE}=======================================================================\n
${YELLOW}Usage:${NC} heimdall_flash.sh [options] <firmware> [partition_name]\n
'${CYAN}firmware${NC}': Either an .img or .tar archive file for flashing. tar archive will
  be unpacked into the current directory prior to flashing).\n
'${CYAN}partition_name${NC}' (optional): Allows you to specify the partition name manually.
  Use this option only if you know the ${YELLOW}exact${NC} name of the partition (case
  sensitive). The internal file name for flashing will be obtained from PIT
  (partition image table) unless you specified either the ${CYAN}-s${NC} or the ${CYAN}-f${NC} option.\n
${GREEN}Options:${NC}\n
'${CYAN}-s${NC}': Flash file as super.img. Use this option for flashing the Super partition
  images produced using the repacksuper.sh script.\n
'${CYAN}-f <file_name>${NC}': Flash file as 'file_name'. Use this option if your real file
  name and the internal file name required for flashing are different (e.g.
  'orange_fox.img' instead of the correct 'recovery.img').\n
'${CYAN}-p <pit_file>${NC}': Specify an external PIT file. This option makes it is possible
  to flash devices that can only be flashed in two passes (e.g. SM-A127F) in one
  pass without reboot, even if you don't know exact partition names. PIT file
  can be extracted from the CSC section of stock firmware.\n\n"
  exit
fi

# Some terminology:
# $img - full path to source image file
# $img_bname - basename of the source image file
# $img_dir - dirname of the source image file
# $img_fname - filename under which the image will be flashed

# Check for existence
img="$1"
if [ ! -f "$img" ]; then
  echo "The specified file does not exist or not a file. Exiting..."
  exit 1
fi

# Flash as super
if [ $flash_as_super ]; then
  if [ $flash_as_file ]; then
    echo "You have specified both the -s and -f options, -s will be ignored."
  else
    echo
    printf "${CYAN}Flashing as super...${NC}\n"
    img_fname="super.img"
    if ! file -b -L "$img" | grep "Android sparse image" > /dev/null; then
      echo "The specified Super image is not an Android sparse image. Exiting..."
      exit 1
    fi
    echo "File format correct (Android sparse image)"
  fi
fi

# Custom partition name
if [ $2 ]; then
  cpn="$2"
fi

# Extract tar
ext=${img##*.}
if [ $ext = "tar" ]; then
  if ! file -b -L "$1" | grep "tar archive" > /dev/null; then
    echo "File has .tar extension but not a tar archive. Flashing as is."
    img="$1"
  else
    echo
    printf "${CYAN}Unpacking the tar archive...${NC}\n"
    img=$(tar t -f "$1" | grep "\.img$" | head -n 1)
    if [ ! "$img" ]; then
      echo "No .img files found in \"$1\". Exiting..."
      exit 1
    fi
    echo "\"$img\" found. Extracting..."
    if [ -f "./$img" ]; then
      printf "${BLUE}File with the same name already present in the current directory.${NC}\n"
      read -p "Overwrite it? Y/n " ans
      if [ "$ans" = "n" ]; then
        echo "Then exiting..."
        exit 0
      fi
      rm -f "./$img"
    fi
    tar xv -f "$1" "$img"
    if [ ! $? -eq 0 ]; then
      echo "Error while unpacking tar. Exiting..."
      exit 1
    fi
    img="./$img"
  fi
fi

# Additional file-related vars
img_dir=$(dirname "$img")
img_bname=$(basename "$img")
if [ ! $img_fname ]; then
  img_fname=$(basename "$img")
fi

# Flash under custom file name
if [ $flash_as_file ]; then
  echo
  printf "${CYAN}Flashing using custom file name...${NC}\n"
  echo "Real name: $img_bname"
  echo "Flashing as: $img_fname"
fi

# Detect device
echo
printf "${CYAN}Preparing...${NC}\n"
echo "Flushing disk cache (this may take some time)"
sync
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

# Use PIT
if [ $cpn ] && [ $flash_as_super ]; then
  ignore_pit=true
elif [ $cpn ] && [ $flash_as_file ]; then
  ignore_pit=true
fi
if [ ! $ignore_pit ]; then
  echo
  printf "${CYAN}Getting PIT (partition image table)...${NC}\n"
  if [ "$ext_pit" ]; then
    echo "Using external PIT: $ext_pit"
    if [ ! -f "$ext_pit" ]; then
      echo "PIT file does not exist. Exiting..."
      exit 1
    fi
    pit_id=$(cat "$ext_pit" | od -t x1 -A n -N 4 | sed "s/ //g")
    if [ "$pit_id" != "76983412" ]; then
      echo "PIT file seems to be incorrect. Exiting..."
      exit 1
    else
      echo "Identified as PIT by file signature \"$pit_id\""
    fi
    pit=$("$heimdall_path"/heimdall print-pit --file "$ext_pit")
  else
    echo "Obtaining PIT from device"
    pit=$("$heimdall_path"/heimdall print-pit --no-reboot)
    resume=true
  fi
  if [ ! $? -eq 0 ]; then
    echo "Heimdall error. Exiting..."
    exit 1
  fi

  # Print the list of partitions
  files_f=$(mktemp -u)
  partitions_f=$(mktemp -u)
  mkfifo "$files_f"
  mkfifo "$partitions_f"
  echo "$pit" | grep "Flash Filename:" | cut -d ' ' -f 3- | sed 's/^$/--none--/' > "$files_f" &
  echo "$pit" | grep "Partition Name:" | cut -d ' ' -f 3- | sed 's/^$/--none--/' > "$partitions_f" &
  esc=$(printf '\033')
  partitions_table=$(paste "$files_f" "$partitions_f" | column -t -N "File Name","Partition Name" |\
    sed "1 s/^/`printf "${GREEN}"`/" | sed "1 s/$/`printf "${NC}"`/")
  echo
  printf "$partitions_table\n"
  echo
  rm "$files_f"
  rm "$partitions_f"

  # Find matching partition
  if [ "$cpn" ]; then
    # Get file name by partition name
    cpn_rx=$(echo "$cpn" | sed "s/\\\/\\\\\\\\/;s/\./\\\\./g") # regexify . and \
    p=$(echo "$pit" | grep -A 1 -i "Partition Name: $cpn_rx$")
    if [ ! "$p" ]; then
      printf "There is no \"$cpn\" partition on this phone. Original file name will be used.\n"
      partition_name=
    else
      partition_name=$(echo "$p" | head -n 1 | cut -c 17-)
      img_fname=$(echo "$p" | tail -n 1 | cut -c 17-)
      printf "${GREEN}File name detected${NC}: $img_fname\n"
    fi
  else
    # Get partition name by file name
    img_rx=$(echo "$img_fname" | sed "s/\\\/\\\\\\\\/;s/\./\\\\./g") # regexify . and \
    partition_name=$(echo "$pit" | grep -B 1 -i "^Flash Filename: $img_rx$" | head -n 1 | cut -c 17-)
  fi
  if [ ! "$partition_name" ]; then
    printf "${RED}Cannot auto-detect partition name.${NC}\n"
    printf "${BLUE}You can enter the name of partition manually.${NC}\n"
    printf "For super.img partition name is usually either \"SUPER\" or \"super\"\n"
    read -p "Enter partition name (case sensitive): " partition_name
  else
    printf "${GREEN}Parition name detected${NC}: $partition_name\n"
  fi
else
  partition_name=$cpn
  echo "Flashing file \"$img_bname\" as \"$img_fname\" into partition \"$partition_name\""
fi

# Prepare
if [ "$img_fname" != "$img_bname" ]; then
  echo "Temporarily renaming \"$img_bname\" to \"$img_fname\""
  if [ -f "$img_dir"/"$img_fname" ]; then
    printf "${BLUE}\"$img_fname\" already exists in the same directory.${NC}\n"
    read -p "Overwrite it? y/N " ans
    if [ "$ans" != "y" ]; then
      echo "Then exiting..."
      exit 0
    fi
    rm -f "$img_dir"/"$img_fname"
  fi
  mv "$img" "$img_dir"/"$img_fname"
fi

# Flash
echo
printf "${CYAN}Flashing...${NC}\n"
trap "trap_func" INT
heimdall_flash
if [ ! $hm_ec -eq 0 ] && [ $resume ]; then
  printf "${RED}Heimdall was unable to upload firmware.${NC}\n"
  read -p "Did you see any uploading progress (percents counting up) y/N " ans
  if [ "$ans" != "y" ]; then
    echo
    printf "${YELLOW}Then let's try a different approach. Now restart your device and enter the\n"
    printf "Download mode once again.${NC}\n"
    read -p "Have you done it? Y/n " ans
    if [ "$ans" != "n" ]; then
      resume=
      heimdall_flash
    fi
  fi
fi
trap - INT

# Outro
echo "Heimdall exit code: $hm_ec"
if [ "$img_fname" != "$img_bname" ]; then
  echo "Renaming \"$img_fname\" back to \"$img_bname\""
  mv "$img_dir"/"$img_fname" "$img"
fi
if [ ! $hm_ec -eq 0 ]; then
  printf "${RED}Heimdall was unable to upload firmware.${NC}\n"
  printf "${YELLOW}You have to resort to Odin for Windows. Sorry.${NC}\n"
  echo "Exiting..."
  exit 0
else
  printf "${GREEN}Success!${NC}\n\n"
fi

