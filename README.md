# 🚀 Samsung Super-Repacker: Unbloat Your Budget Beast

[![Status](https://img.shields.io/badge/STATUS-EXPERIMENTAL-orange?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/)
[![License](https://img.shields.io/badge/LICENSE-GPL--v3-blue?style=for-the-badge)](https://www.gnu.org/licenses/gpl-3.0)
[![Telegram](https://img.shields.io/badge/Telegram-Join%20Chat-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/asr_community)

**Tired of your Samsung budget phone lagging like it's stuck in 2012?** 

This GitHub Actions workflow is your ticket to reviving devices like the **Galaxy A04s, A05, A05s, A06, A15, A16**—and any Samsung device with a `super` partition and Project Treble support. 

We replace the bloated, heavy OneUI system with a lightweight custom ROM by rebuilding your `super.img` directly in the cloud. **No Linux install required. No terminal sorcery. Just raw performance.**

---

## 🛠️ The Problem: Why This Exists

### 1. The "Super" Headache
Google introduced the `super` partition—a dynamic container that crams `system`, `vendor`, `product`, and `system_ext` into one single block. It’s great for OTAs, but **hell for modders**. 

### 2. The TWRP Ghost
Most budget Samsungs don't have official TWRP builds. Without TWRP, flashing a GSI (Generic System Image) usually requires a Linux machine and complex `lpmake` commands. 

**This repo automates the entire process using GitHub's servers.**

---

## ✨ Features

- ✅ **Pre-configured Support**: One-click builds for **Galaxy A04s (64GB)** and **Galaxy A15** (no firmware links needed!).
- ✅ **EROFS & EXT4 Support**: Now officially supports the latest EROFS filesystems.
- ✅ **Cloud Powered**: Runs 100% on GitHub Actions—save your own CPU and RAM.
- ✅ **Universal Input**: Accepts `.img`, `.img.xz`, `.img.gz`, or `.zip`.
- ✅ **Smart Caching**: Stock firmware is cached to make subsequent builds lightning fast.
- ✅ **Branded & Optimized**: Automatically adds `Built.By.Minh2077.Script` to your `build.prop`.

---

## ✅ How to Use (3-Step Speedrun)

### 1. Setup
*   **Fork** this repository to your own account.
*   Navigate to the **Actions** tab and enable them.

### 2. Configure & Run
Choose the **"Android Super Repack (Universal FS)"** workflow and hit **Run Workflow**:

| Input | Instruction |
| :--- | :--- |
| **Device Preset** | Select A04s or A15 to skip the firmware URL step. |
| **Stock Firmware URL** | Direct link to your `AP_*.tar.md5` (Skip if using presets). |
| **Custom System URL** | Link to your GSI (.img, .xz, .zip). *Must match or exceed Stock Android version.* |
| **Options** | Toggle **Empty Product**, **Writable Partitions**, or **Silent Mode**. |

### 3. Flash
1.  Wait 10–20 mins.
2.  Download the repacked `.tar` from the **Releases** or **Artifacts** section.
3.  **Odin:** Put the `.tar` in the **AP** slot.
4.  **Format Data:** This is mandatory. Boot to recovery (Vol Up + Power while plugged into USB) and **Wipe Data/Factory Reset**.

---

## 🖼️ How to Get Firmware Links
# WARNING: SAMFW added cloudflare, so my method wont work, using other site might work
Don't know where to get the `AP` link? Follow the visual guide in the `pic/` folder:
`pic1.png` through `pic14.png` provide a step-by-step walkthrough of the extraction process.

---

## 🧙 How the Magic Works
1.  **Decomposition**: The workflow pulls your stock firmware and extracts the original `super.img`.
2.  **Space Management**: GitHub Runners are small. The script aggressively purges unnecessary packages to make room for the massive Samsung images.
3.  **Injection**: Your custom GSI is injected into the super-container, replacing the bloated OneUI system partition.
4.  **Compression**: The tool repacks the image into an Odin-flashable `.tar` or a raw `.img` for Heimdall.

---

## 🧯 Troubleshooting

*   **"No space left on device"**: GitHub runners have ~14GB of usable space. If your firmware is massive, the build might fail. 
*   **Bootloops**: Ensure you formatted data in recovery. Also, verify your ROM is the correct architecture (usually `arm64-ab`).
*   **Odin Errors**: Ensure you are using the latest version of Odin and your Samsung drivers are up to date.
*   **Google drive link**: This github action DOES NOT support google drive file download, to check if it support or not, run wget "your link here", if it return the real file (or aka the .img) then that link is good. 

---

## 💬 Community & Support

Stuck on a step? Found a bug? Or just want to flex your benchmark scores?
**Join the official Telegram group:**

👉 [**t.me/asr_community**](https://t.me/asr_community)

---

## 📜 License

**Dual-licensed under GNU GPL v3 + Additional Terms.**

All original code in this repository is copyright (C) 2025-2026 Minhmc2077 and licensed under **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for the full text.

This project incorporates code from several sources:
- **QuantumROM**: GPL-3.0
- **ErfanGSIs**: GPL-3.0 by Erfan Abdi
- **repacksuper.sh**: Based on work by Uluruman (from XDA, original license unknown)
- **Link2GSI**: Forked from RadGoodNow/YaEbuEbuGSITool (no explicit license)

### Output Artifact Attribution

If you publish or distribute any custom ROM, firmware, or `super.img` binary that was **built using this project's GitHub Actions workflows or scripts**, you **MUST** give appropriate credit to the author and this project.

Include the following in your ROM's `build.prop` or accompanying documentation:

```
Built with Custom-Super-Maker by Minhmc2077
https://github.com/minhmc2077/Custom-Super-Maker
```

This project took over a year of development. Please respect that effort.

### ⚠️ Disclaimer
> **I am not responsible for bricked devices.** If you ignore the warnings, flash the wrong architecture, or ignore the "Format Data" step, your phone will become a very expensive paperweight. You are choosing to make these modifications. If you point the finger at me, I will laugh. **Basic reading comprehension is a requirement for using this tool.**

---
**Fix the lag. Join the custom ROM master race.** 🚀
