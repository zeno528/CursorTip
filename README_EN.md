<div align="center">

<img src="assets/logo.png" alt="CursorTip" width="128" height="128">

# CursorTip

**A lightweight Windows desktop status indicator** · [Learn more](https://cursortip-website.pages.dev/)

Displays real-time caps lock + IME state and clipboard operation feedback on screen, helping you stay aware of your input environment.

[![Release](https://img.shields.io/github/v/release/zeno528/CursorTip?style=flat&logo=github&labelColor=1e293b&color=3b82f6)](https://github.com/zeno528/CursorTip/releases)
[![License](https://img.shields.io/github/license/zeno528/CursorTip?style=flat&labelColor=1e293b&color=3b82f6)](LICENSE)
[![Website](https://img.shields.io/badge/Website-cursortip--website.pages.dev-8b5cf6?style=flat&logo=cloudflare-pages&labelColor=1e293b)](https://cursortip-website.pages.dev/)
[![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2-334455?style=flat&logo=autohotkey&labelColor=1e293b&color=4a5568)](https://www.autohotkey.com/)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?style=flat&logo=windows&labelColor=1e293b)](https://github.com/zeno528/CursorTip)

English | [简体中文](README.md)

</div>

## Screenshots

| Caps Lock + IME | Copy Feedback |
|:----------------:|:-------------:|
| ![](images/preview-caps-ime-light.png)![](images/preview-caps-ime-dark.png) | ![](images/preview-copy-tip-light.png)![](images/preview-copy-tip-dark.png) |

## Features

| Feature | Trigger | Display |
|:--------|:--------|:--------|
| Caps Lock state | CapsLock toggle; or pressing and releasing **Shift alone** | 🔒 CAPS / 🔓 caps |
| IME state | Shown with caps lock indicator | ZH / EN |
| Copy feedback | Clipboard content changes | Copied: N char(s) / N image(s) / N file(s) |

Tips appear as floating bubbles on screen and auto-dismiss after a few seconds without interrupting your workflow. Position can be **follow mouse / screen top / screen bottom / screen center**, and tips support **light / dark themes** — follow the system automatically or switch manually in Settings.

> **About the Shift trigger**: the tip only fires when Shift is pressed **on its own** — if you press another key, a mouse button, or another modifier while holding Shift, nothing shows on release (so combinations like `Shift+A` don't misfire). That means holding Shift to type won't keep re-triggering the bubble.

## Copy Detection

| Copy Method | Detection Result |
|:------------|:-----------------|
| Text | N chars |
| Image files | N images |
| Other files | N files |

Image files are detected by extension, supporting: `png / jpg / jpeg / gif / bmp / webp / ico / cur / svg / tif / tiff / heic / heif / avif / jfif / jpe / dib`

## Installation

1. Download the latest `CursorTip_vX.X.X.zip` from [Releases](https://github.com/zeno528/CursorTip/releases)
2. Extract and run `CursorTip_vX.X.X.exe`, no need to install AutoHotkey

> Extract to a fixed directory (e.g. `D:\Tools\CursorTip`) before running — the exe name carries the version number and gets replaced on upgrade.

### Auto-start on Boot

Right-click the tray icon → Settings → Check "🚀 Run at startup", or place the exe in the startup folder (`Win+R` → `shell:startup`)

## Settings

Right-click the tray icon → Settings. Changes preview live; only **Save** writes them to disk.

| Group | Options |
|:------|:--------|
| **Features** | Run at startup · Caps lock tip · IME status · Copy tip |
| **Duration** | Separate duration for caps and copy tips (100–3000 ms) |
| **Position** | Follow mouse (with top-right / bottom-right) · screen top · screen bottom · screen center, each with an offset slider |
| **Appearance** | Follow system / Light / Dark · font size · bold |
| **Language** | Follow system / 简体中文 / English |
| **Version** | Version number · Check for updates |

The tray menu also has **Restart** and **Exit**.

## Auto Update

Update checking and in-app upgrading are built in — no need to download from Releases manually:

- **Silent check** — runs once about 10 seconds after launch, throttled to once every 24 hours; shows a tray bubble when a new version is available
- **Manual check** — the "Check for updates" button in Settings, with live status text: checking / up to date / new version found / download progress / failed
- **In-app upgrade** — click "Upgrade" to silently download the new exe, then restart to swap it in and launch the new version (when running the `.ahk` source directly, this button opens the Releases page instead)

A few implementation details: checks go through the GitHub Releases Atom feed (no API rate limit); downloads follow the system static proxy; if the exe has been renamed or moved, the startup registry path is repaired automatically. A failed upgrade leaves the old version fully working.

## Compilation

Requires [AutoHotkey v2](https://www.autohotkey.com/) and the Ahk2Exe compiler (bundled with the v2 installer).

```bash
"C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" \
  /in CursorTip.ahk \
  /out CursorTip_v1.3.8.exe \
  /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
```

The script embeds the `;@Ahk2Exe-SetMainIcon` directive to set the icon, so no `/icon` parameter is needed.

The version number lives only in `VERSION.ahk`; changing it triggers GitHub Actions to compile and open a Draft Release (changelog extracted from git history — review, then publish).

## System Requirements

- Windows 10 / 11
- Light memory footprint (~2.6 MB resident)

## Project Structure

```
CursorTip/
├── CursorTip.ahk               # Main script (all development and bug fixes target this file)
├── VERSION.ahk                 # Single source of truth for the version number
├── config.ini                  # User settings (generated at runtime, not committed)
├── LICENSE                     # MIT License
├── README.md / README_EN.md    # Chinese / English documentation
│
├── .github/workflows/          # CI syntax check + automated build/release
├── assets/                     # Icons and brand assets
├── images/                     # README preview images
└── docs/                       # AHK v2 development documentation
```

## License

[MIT](LICENSE)
