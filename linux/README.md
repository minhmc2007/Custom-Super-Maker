# Custom-Super-Maker Desktop (Linux)

PySide6 GUI that wraps the scripts from `scripts/` into a desktop application.
Mirrors the `testing.yml` workflow: download stock firmware, OEM port or GSI
download, EROFS compress, repack super, upload.

## Requirements

```bash
sudo apt install python3-pip pyside6 erofs-utils android-sdk-libsparse-utils lz4
pip3 install -r requirements.txt
```

## Usage

```bash
# From repo root
python3 -m linux.main
```

All steps require `sudo` access (for mount, simg2img, lpmake, etc.).
