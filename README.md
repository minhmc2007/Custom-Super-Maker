# 🚀 Samsung Super-Repacker: Unbloat Your Budget Beast

> ⚠️ **READ THE FUCKING WARNINGS BEFORE YOU START:**
> **STOP USING GOOGLE DRIVE LINKS!** It is explicitly stated that **GOOGLE DRIVE IS NOT SUPPORTED**. 
> When you use a Google Drive link, the tool ends up downloading a useless verification HTML page instead of the actual image file, causing the build to immediately fail. Read the instructions, use a direct download link, and stop breaking your own builds!

[![Status](https://img.shields.io/badge/STATUS-EXPERIMENTAL-orange?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/)
[![License](https://img.shields.io/badge/LICENSE-ROSRAL%20v1.4-red?style=for-the-badge)](LICENSE)
[![Telegram](https://img.shields.io/badge/Telegram-Join%20Chat-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/asr_community)

**Tired of your budget Samsung phone lagging like it's stuck in 2012?** 

This GitHub Actions workflow is your ticket to reviving devices like the **Galaxy A04s, A05, A05s, A06, A15, A16**—and any Samsung device with a `super` partition and Project Treble support. 

We replace the bloated, heavy One UI system with a lightweight custom ROM by rebuilding your `super.img` directly in the cloud. **No Linux installation required. No terminal sorcery. Just raw performance.**

---

## 🛠️ The Problem: Why This Exists

### 1. The "Super" Headache
Google introduced the `super` partition—a dynamic container that crams `system`, `vendor`, `product`, and `system_ext` into a single block. It is great for OTAs, but **difficult for modders**. 

### 2. The TWRP Ghost
Most budget Samsung devices do not have official TWRP builds. Without TWRP, flashing a GSI (Generic System Image) usually requires a Linux machine and complex `lpmake` commands. 

**This repository automates the entire process using GitHub's servers.**

---

## ✨ Features

- ✅ **Pre-configured Support**: One-click builds for the **Galaxy A04s (64GB)** and **Galaxy A15** (no firmware links needed!).
- ✅ **EROFS & EXT4 Support**: Officially supports the latest EROFS filesystems.
- ✅ **Cloud Powered**: Runs 100% on GitHub Actions—saving your own CPU and RAM.
- ✅ **Universal Input**: Accepts `.img`, `.img.xz`, `.img.gz`, or `.zip`.
- ✅ **Smart Caching**: Stock firmware is cached to make subsequent builds significantly faster.
- ✅ **Branded & Optimized**: Automatically adds `Built.By.Minh2077.Script` to your `build.prop`.

---

## ✅ How to Use (3-Step Speedrun)

### 1. Setup
*   **Fork** this repository to your own account.
*   Navigate to the **Actions** tab and enable them.

### 2. Configure & Run
Choose the **"Android Super Repack (Universal FS)"** workflow and click **Run Workflow**:

| Input | Instruction |
| :--- | :--- |
| **Device Preset** | Select A04s or A15 to skip the firmware URL step. |
| **Stock Firmware URL** | Direct link to your `AP_*.tar.md5` (Skip if using presets). |
| **Custom System URL** | Link to your GSI (.img, .xz, .zip). *Must match or exceed the Stock Android version.* |
| **Options** | Toggle **Empty Product**, **Writable Partitions**, or **Silent Mode**. |

### 3. Flash
1.  Wait 10–20 minutes.
2.  Download the repacked `.tar` from the **Releases** or **Artifacts** section.
3.  **Odin:** Place the `.tar` in the **AP** slot.
4.  **Format Data:** This is mandatory. Boot to recovery (Volume Up + Power while connected to a USB cable) and select **Wipe Data/Factory Reset**.

---

## 🖼️ How to Get Firmware Links
> ⚠️ **WARNING:** SAMFW has added Cloudflare protection, meaning direct downloads via this script will not work. Please use alternative firmware hosting sites that provide direct, unmitigated download links.

If you are unsure where to obtain the `AP` link, follow the visual guide in the `pic/` folder: `pic1.png` through `pic14.png` provide a step-by-step walkthrough of the extraction process.

---

## 🧙 How the Magic Works
1.  **Decomposition**: The workflow pulls your stock firmware and extracts the original `super.img`.
2.  **Space Management**: GitHub Runners have limited space. The script aggressively purges unnecessary packages to accommodate large Samsung images.
3.  **Injection**: Your custom GSI is injected into the super-container, replacing the bloated One UI system partition.
4.  **Compression**: The tool repacks the image into an Odin-flashable `.tar` or a raw `.img` for Heimdall.

---

## 🧯 Troubleshooting

*   **"No space left on device"**: GitHub runners have approximately 14GB of usable space. If your firmware is too large, the build may fail. 
*   **Bootloops**: Ensure you formatted data in recovery. Also, verify that your ROM matches the correct architecture (usually `arm64-ab`).
*   **Odin Errors**: Ensure you are using the latest version of Odin and that your Samsung USB drivers are up to date.
*   **Google Drive links**: This GitHub Action **DOES NOT** support Google Drive file downloads. To verify if a download link is compatible, run `wget "your_link_here"` in a terminal. If it downloads the actual raw file (e.g., the `.img`), the link is valid. If it downloads an HTML page, it will fail.

---

## 💬 Community & Support

Stuck on a step? Found a bug? Or just want to share your benchmark scores?
**Join the official Telegram group:**

👉 [**t.me/asr_community**](https://t.me/asr_community)

---

## 📜 License

**RESTRICTED OPEN SOURCE & ROM ATTRIBUTION LICENSE (ROSRAL) v1.1**

Copyright (C) 2026 Duong Quang Minh (Minhmc2077). All Rights Reserved.

See the [LICENSE](LICENSE) file for the full text.

### Output Artifact Attribution

If you publish or distribute any custom ROM, firmware, or `super.img` binary that was **built using this project's GitHub Actions workflows or scripts**, you **MUST** give appropriate credit to the author and this project.

The **build.prop signature is IMMUTABLE** — you must NOT delete, overwrite, or fully replace the core credit string. If you fork, the final property must preserve the original authorship in a co-existence format:
