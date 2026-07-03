#!/bin/bash
# ==============================================================================
# OEM PORT SCRIPT - Port a firmware from one Samsung device to another
# ==============================================================================
# Purpose:
#   Downloads a source firmware (via URL or Samloader), then runs either
#   Link2GSI or ErfanGSIs to extract the system image for use as a custom ROM
#   on a different base device.
#
# Usage:
#   ./oem_port.sh <work_dir> <porting_tool> <rom_type> --url <URL>
#   ./oem_port.sh <work_dir> <porting_tool> <rom_type> --samloader <model> <csc> <imei>
#
#   <work_dir>     : Working directory (output goes to work_dir/custom_system.img)
#   <porting_tool> : Link2GSI or ErfanGSIs
#   <rom_type>     : OneUI, Pixel, MIUI, OxygenOS, Flyme, Moto, ColorOS, Generic
#   --url <URL>    : Direct download URL to port firmware
#   --samloader <model> <csc> <imei> : Download via Samloader
#
# Dependencies:
#   - wget, git, sudo
#   - python3 with samloader (for --samloader mode)
#   - Link2GSI or ErfanGSIs (cloned on-the-fly)
# ==============================================================================

set -e

usage() {
    echo "Usage:"
    echo "  $0 <work_dir> <porting_tool> <rom_type> --url <URL>"
    echo "  $0 <work_dir> <porting_tool> <rom_type> --samloader <model> <csc> <imei>"
    echo ""
    echo "  <work_dir>     : Working directory"
    echo "  <porting_tool> : Link2GSI or ErfanGSIs"
    echo "  <rom_type>     : OneUI, Pixel, MIUI, OxygenOS, Flyme, Moto, ColorOS, Generic"
    echo "  --url <URL>    : Direct download URL to port firmware"
    echo "  --samloader <model> <csc> <imei> : Download via Samloader"
    exit 1
}

if [ "$#" -lt 4 ]; then
    usage
fi

WORK_DIR="$1"
PORT_TOOL="$2"
ROM_TYPE="$3"
shift 3

if [ ! -d "$WORK_DIR" ]; then
    mkdir -p "$WORK_DIR"
fi

WORK_DIR="$(cd "$WORK_DIR" && pwd)"
TMP_DIR="$WORK_DIR/tmp"
FIRMWARE_ZIP="$WORK_DIR/port_firmware.zip"
OUTPUT_IMG="$WORK_DIR/custom_system.img"

echo "=== OEM Port Mode ==="
echo "Work dir: $WORK_DIR"
echo "Tool: $PORT_TOOL"
echo "ROM type: $ROM_TYPE"

# 1. Acquire Port Firmware Zip
case "$1" in
    --url)
        if [ -z "$2" ]; then
            echo "Error: --url requires a URL argument."
            exit 1
        fi
        echo "==> Downloading Port Firmware via URL..."
        wget -q --content-disposition -O "$FIRMWARE_ZIP" "$2"
        ;;
    --samloader)
        if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
            echo "Error: --samloader requires <model> <csc> <imei>"
            exit 1
        fi
        PORT_MODEL="$2"
        PORT_CSC="$3"
        PORT_IMEI="$4"

        echo "==> Fetching Port Firmware via Samloader..."
        mkdir -p "$WORK_DIR/port_fw"
        cd "$WORK_DIR/port_fw"

        echo "==> Checking Port Firmware Version..."
        VERSION_PORT=$(python3 -m samloader -m "$PORT_MODEL" -r "$PORT_CSC" -i "$PORT_IMEI" checkupdate 2>/dev/null)
        if [ -z "$VERSION_PORT" ]; then
            echo "Error: Failed to fetch version for Port Model: $PORT_MODEL ($PORT_CSC)."
            exit 1
        fi
        echo "Port Firmware Version: $VERSION_PORT"

        echo "==> Downloading Port Firmware..."
        python3 -m samloader -m "$PORT_MODEL" -r "$PORT_CSC" -i "$PORT_IMEI" download -v "$VERSION_PORT" -O .

        echo "==> Checking downloaded files..."
        ls -la

        ENC_FILE_PORT=$(find . -maxdepth 1 -name "*.enc*" | head -n1)
        if [ -n "$ENC_FILE_PORT" ]; then
            echo "==> Found encrypted file: $ENC_FILE_PORT. Decrypting manually..."
            python3 -m samloader -m "$PORT_MODEL" -r "$PORT_CSC" -i "$PORT_IMEI" decrypt -v "$VERSION_PORT" -i "$ENC_FILE_PORT" -o port_firmware.zip
            rm -f "$ENC_FILE_PORT"
        else
            echo "==> No encrypted file found. Checking for on-the-fly decrypted ZIP..."
            ZIP_FILE_PORT=$(find . -maxdepth 1 -name "*.zip" ! -name "port_firmware.zip" | head -n1)
            if [ -n "$ZIP_FILE_PORT" ]; then
                echo "==> Found decrypted ZIP file: $ZIP_FILE_PORT."
                mv "$ZIP_FILE_PORT" port_firmware.zip
            else
                echo "Error: No port firmware files (.enc or .zip) found after download."
                exit 1
            fi
        fi

        mv port_firmware.zip "$FIRMWARE_ZIP"
        cd "$WORK_DIR"
        rm -rf "$WORK_DIR/port_fw"
        ;;
    *)
        echo "Error: Must specify --url or --samloader"
        usage
        ;;
esac

if [ ! -f "$FIRMWARE_ZIP" ]; then
    echo "Error: Firmware download failed."
    exit 1
fi

# 2. Execute selected Porting Tool
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

if [ "$PORT_TOOL" = "Link2GSI" ]; then
    echo "==> Porting using Link2GSI..."
    git clone https://github.com/minhmc2007/Link2GSI
    cd Link2GSI

    rm -rf Tools/Firmware_extractor
    git clone https://github.com/erfanoabdi/Firmware_extractor.git Tools/Firmware_extractor

    echo "==> Patching unlz4 in Firmware_extractor..."
    find Tools/Firmware_extractor -name "*.sh" -exec sed -i 's|unlz4 "$tmpdir/$file"|unlz4 -c "$tmpdir/$file" > "${tmpdir}/${file%.lz4}"|g' {} +

    sudo bash LinkToGSI.sh "$FIRMWARE_ZIP" "$ROM_TYPE"

    IMG=$(find Output -name "*.img" | head -n1)
    if [ -z "$IMG" ]; then
        echo "Error: Link2GSI failed to produce an image."
        exit 1
    fi

    sudo mv "$IMG" "$OUTPUT_IMG"
    sudo chown "$(whoami)" "$OUTPUT_IMG"
    cd "$TMP_DIR"
    sudo rm -rf Link2GSI

elif [ "$PORT_TOOL" = "ErfanGSIs" ]; then
    echo "==> Porting using ErfanGSIs..."
    git clone --recurse-submodules https://github.com/erfanoabdi/ErfanGSIs.git
    cd ErfanGSIs

    echo "==> Setting up requirements..."
    sed -i 's/apt install/apt install -y/g' setup.sh
    sed -i 's/python-pip/python3-pip/g' setup.sh
    sed -i 's/pycrypto/pycryptodome/g' setup.sh
    sed -i 's/pip install/pip install --break-system-packages/g' setup.sh

    sudo bash setup.sh

    # Create EROFS-to-ext4 converter helper script
    echo "==> Creating EROFS-to-ext4 converter..."
    cat > convert_erofs_to_ext4.sh << 'EROFSEOF'
#!/bin/bash
WORKDIR="$1"
for img in "$WORKDIR"/*.img; do
    [ -f "$img" ] || continue
    if file "$img" | grep -qi "erofs"; then
        echo "Converting EROFS $(basename "$img") to ext4..."
        mnt=$(mktemp -d)
        sudo mount -o loop -t erofs "$img" "$mnt" 2>/dev/null || { echo "  mount failed, skipping"; rmdir "$mnt" 2>/dev/null; continue; }
        sz=$(stat --format="%s" "$img")
        newsz=$((sz / 1048576 + 1))
        dd if=/dev/zero of="$img.tmp" bs=1048576 count=$newsz 2>/dev/null
        mkfs.ext4 -F "$img.tmp" >/dev/null 2>&1
        mnt2=$(mktemp -d)
        sudo mount -o loop "$img.tmp" "$mnt2" 2>/dev/null
        sudo cp -a "$mnt"/* "$mnt2"/ 2>/dev/null
        sudo umount "$mnt2" 2>/dev/null
        sudo umount "$mnt" 2>/dev/null
        mv "$img.tmp" "$img"
        rmdir "$mnt" "$mnt2" 2>/dev/null
    fi
done
EROFSEOF
    chmod +x convert_erofs_to_ext4.sh

    # url2GSI.sh calls update.sh which resets submodules (including Firmware_extractor).
    # Patch update.sh to fix unlz4 AFTER it updates submodules,
    # so the fix survives the submodule reset.
    echo "==> Patching update.sh to fix unlz4 after submodule update..."
    # Only target the super section pattern (without -f flags) to not break tarmd5
    cat >> update.sh << 'UNLZEOF'
find . -path "*/Firmware_extractor/extractor.sh" -exec sed -i 's|unlz4 "$tmpdir/$file"|unlz4 -c "$tmpdir/$file" > "${tmpdir}/${file%.lz4}"|g' {} +
UNLZEOF

    # Patch url2GSI.sh directly to add EROFS conversion after extractor.sh
    echo "==> Patching url2GSI.sh to add EROFS conversion..."
    sed -i '/\$TOOLS_DIR\/Firmware_extractor\/extractor.sh/a\ sudo bash '"$PWD"'/convert_erofs_to_ext4.sh "$PROJECT_DIR/working"' url2GSI.sh

    echo "==> Running url2GSI.sh (stdout muted - binary output)..."
    sudo ./url2GSI.sh "$FIRMWARE_ZIP" "$ROM_TYPE" > /dev/null

    echo "==> Locating ErfanGSIs output image..."
    IMG=$(find output out . -name "*GSI*.img" -o -name "*Aonly*.img" -o -name "*AB*.img" 2>/dev/null | head -n1)

    if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
        echo "Error: ErfanGSIs failed to produce an image."
        exit 1
    fi

    echo "Found GSI image: $IMG"
    sudo mv "$IMG" "$OUTPUT_IMG"
    sudo chown "$(whoami)" "$OUTPUT_IMG"
    cd "$TMP_DIR"
    sudo rm -rf ErfanGSIs
else
    echo "Error: Unknown porting tool '$PORT_TOOL'. Use 'Link2GSI' or 'ErfanGSIs'."
    exit 1
fi

# 3. Cleanup
rm -f "$FIRMWARE_ZIP"
rm -rf "$TMP_DIR"

if [ -f "$OUTPUT_IMG" ]; then
    echo "=== OEM Port complete ==="
    echo "Output: $OUTPUT_IMG"
    ls -lh "$OUTPUT_IMG"
else
    echo "Error: Output image not created."
    exit 1
fi
