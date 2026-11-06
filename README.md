# Samsung Super-Repacker

Replace the bloated One UI on your budget Samsung with a lightweight GSI, without needing a Linux box.

[![Status](https://img.shields.io/badge/STATUS-EXPERIMENTAL-orange?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Telegram](https://img.shields.io/badge/Telegram-Join%20Chat-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/asr_community)

This GitHub Actions workflow rebuilds your `super.img` in the cloud. It works on the Galaxy A04s, A05, A05s, A06, A15, A16, and any Samsung device with a `super` partition and Project Treble support.

---

## READ THIS FIRST

**Use the "Android Super Repack (Universal FS)" workflow. NOT the legacy one.**

I have said this. It is written right here, in bold, at the top. And yet half the issues I get are from people running the legacy workflow.

The legacy workflow is the bare-minimum fallback. It is unmaintained. It exists so there is *something* when everything else is broken, not so you can click it because it was the first thing in the list. If you ran it anyway, you didn't read this README, and your issue gets closed. I'm not debugging a problem you created by ignoring one sentence.

Same story with Google Drive. **Google Drive links do not work.** The tool downloads Google's HTML verification page instead of your image, and the build dies. It is documented in three separate places in this README. Use a direct link. Run `wget` on it. It is not hard.

"But ChatGPT told me to..." No. Stop. That is exactly the problem. People were given eyes and a working brain, and they hand both to a chatbot and then wonder why nothing works. AI is a tool. It is not your brain. It doesn't know your device, it doesn't know this repo, and it will happily tell you complete garbage with total confidence. Reading a README is a fifteen-second skill, and you skipped it.

So here is how this works:

1. Read the README. All of it.
2. Use the Universal FS workflow.
3. If it still breaks, open an issue with the workflow name, your inputs, and the full log.

Skip step 1 and your issue gets closed with a link to this section. If your plan is to paste this README into an AI and ask it what to do, congratulations, you just read it once, so now do it properly. Then take whatever is left of your problem back to your AI, because I'm done being its tech support.

---

## Why this exists

**The `super` partition.** Google put `system`, `vendor`, `product` and `system_ext` into one dynamic container. That's fine for OTAs and miserable for modders.

**No TWRP.** Most budget Samsung devices have no official TWRP. Without it, flashing a GSI normally means a Linux machine and hand-written `lpmake` commands.

This repo automates all of that on GitHub's servers.

---

## Features

- Presets for the **Galaxy A04s (64GB)** and **Galaxy A15**. No firmware link needed.
- EROFS and EXT4 support.
- Runs entirely on GitHub Actions, so it uses none of your CPU or RAM.
- Accepts `.img`, `.img.xz`, `.img.gz` or `.zip`.
- Stock firmware is cached, so repeat builds are much faster.

---

## Usage

### 1. Setup

- **Fork** this repo.
- Open the **Actions** tab and enable workflows.

### 2. Run

Pick **"Android Super Repack (Universal FS)"** and click **Run workflow**.

| Input | What to put |
| :--- | :--- |
| **Device Preset** | A04s or A15 skips the firmware URL. |
| **Stock Firmware URL** | Direct link to your `AP_*.tar.md5`. Skip if you're using a preset. |
| **Custom System URL** | Direct link to your GSI (`.img`, `.xz`, `.zip`). Its Android version must match or exceed the stock one. |
| **Options** | Empty Product, Writable Partitions, Silent Mode. |

### 3. Flash

1. Wait 10 to 20 minutes.
2. Download the repacked `.tar` from **Releases** or **Artifacts**.
3. In Odin, put the `.tar` in the **AP** slot.
4. **Wipe data. This is mandatory.** Boot to recovery (Volume Up + Power while plugged into USB) and choose **Wipe Data/Factory Reset**.

---

## Getting firmware links

SAMFW now sits behind Cloudflare, so the script can't download from it. Use a firmware host that gives you a plain direct link.

Not sure where to find the `AP` link? `pic/pic1.png` through `pic/pic14.png` walk through it step by step.

To check whether a link works, run `wget "your_link_here"`. If you get the actual file (the `.img`, the `.tar.md5`), the link is good. If you get an HTML page, it will fail.

---

## What it does

1. Pulls your stock firmware and extracts the original `super.img`.
2. Frees up runner disk space by removing unneeded packages, since Samsung images are huge.
3. Injects your GSI into the super container in place of the One UI system partition.
4. Repacks everything as an Odin-flashable `.tar`, or a raw `.img` for Heimdall.

---

## Troubleshooting

- **"No space left on device"**: GitHub runners have about 14GB usable. If the firmware is too big, the build fails.
- **Bootloop**: Did you wipe data? Also check that your GSI matches the device architecture (usually `arm64-ab`).
- **Odin errors**: Update Odin and your Samsung USB drivers.
- **Google Drive links**: Not supported. See above.

---

## Community

Stuck, found a bug, or want to post benchmarks? Join the Telegram group: [t.me/asr_community](https://t.me/asr_community)

Read this README before you ask.

---

## License

[MIT](LICENSE). This covers the code written for this repo. Third-party components and bundled tools keep their own licenses.
