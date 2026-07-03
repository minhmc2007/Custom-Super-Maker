# Custom-Super-Maker

Samsung firmware repacking toolkit. Replaces the OneUI system in a `super.img`
with a custom GSI, runs entirely in GitHub Actions.

## Repo layout

```
scripts/           # Main shell scripts (entrypoints)
  repacksuper.sh        # Unpack stock super, replace system, repack
  repacksuper_lite.sh   # Same + product debloat + EROFS + auto-sizing
  compress_system_img.sh# Convert any system image to EROFS LZ4HC
  heimdall_flash.sh     # Flash a single .img via Heimdall
  heimdall_flash_stock.sh# Download+flash full stock firmware
  oem_port.sh           # Port firmware from one device to another
  patch_firmware.sh     # Patch vendor/product/system_ext using QuantumROM
tools/             # Precompiled binaries (heimdall, lpunpack, lpmake, etc.)
android/
  ASRControl/      # Companion Android app (Kotlin/Jetpack Compose)
  QuantumROM/      # **Nested git repo, ignored** — do not modify
docs/
assets/
.github/workflows/
  main.yml         # Simple GSI repack workflow
  stable.yml       # Same with firmware caching
  testing.yml      # Full workflow with OEM porting support
```

## Key constraints

- **ALL scripts need root** (mount, simg2img, lpmake) — `sudo ./scripts/...`
- **QuantumROM (`android/QuantumROM/`)** is a nested git repo, ignored by `.gitignore`. Do not touch it. It is referenced at runtime by `patch_firmware.sh` via `source scripts/QuantumRom.sh`.
- Scripts resolve sibling tools via `$(dirname $0)/../tools/...` — always run from repo root, not from `scripts/`.
- Testing workflows are `workflow_dispatch` only (no push/PR trigger).

## CI workflows

| Workflow | When | What it does |
|---|---|---|
| `main.yml` | manual | Download stock firmware + GSI → repack → upload `.tar` |
| `stable.yml` | manual | Same + firmware caching, more flags |
| `testing.yml` | manual | Full pipeline: firmware → OEM port or GSI download → (optional EROFS) → repack → upload |

All run on `ubuntu-latest`. Dependencies installed via `apt` (erofs-utils,
android-sdk-libsparse-utils, lz4, etc.).

## OEM port gotchas (ErfanGSIs)

1. **unlz4 patches**: `url2GSI.sh` calls `update.sh` which resets the
   `Firmware_extractor` submodule (via `git submodule update`), **overwriting**
   any unlz4 patches. The fix in `oem_port.sh` appends a patching command to
   `update.sh` — do not remove or reorder this. The patch uses `-c` with
   explicit redirect to avoid breaking the tarmd5 extraction branch.

2. **EROFS firmware**: Newer Samsung firmware ships EROFS images which
   ErfanGSIs can't mount+modify. A `convert_erofs_to_ext4.sh` helper is
   created in the ErfanGSIs dir and called after `extractor.sh` completes
   (via a `sed -i '/extractor.sh/a ...'` patch on `url2GSI.sh`).

## Output artifact attribution

See LICENSE — any ROM built with these tools must credit
`Custom-Super-Maker by Minhmc2077` in `build.prop` or docs.

## Third-party licenses

| Component | License |
|---|---|
| This project's code | GPL-3.0 + additional terms |
| QuantumROM | GPL-3.0 |
| ErfanGSIs | GPL-3.0 |
| Link2GSI | Unlicensed (All Rights Reserved) |
| repacksuper.sh (original) | Unknown (XDA) |
