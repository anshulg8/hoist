# Hoist

<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="Hoist Icon">
</p>

<p align="center">
  <strong>Native macOS Menu-Bar Utility for Country Flags, Local Time & Status</strong>
</p>

<p align="center">
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9+-FA7343.svg?logo=swift&logoColor=white" alt="Swift 5.9+"></a>
  <a href="https://apple.com/macos"><img src="https://img.shields.io/badge/macOS-14.0+-000000.svg?logo=apple&logoColor=white" alt="macOS 14+"></a>
  <a href="https://github.com/anshulg8/hoist/releases/latest"><img src="https://img.shields.io/github/v/release/anshulg8/hoist?color=blue&label=Release" alt="Latest Release"></a>
  <img src="https://img.shields.io/badge/Dependencies-0-success.svg" alt="Zero Dependencies">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License"></a>
</p>

<p align="center">
  <a href="https://github.com/anshulg8/hoist/releases/latest/download/Hoist.zip">
    <img src="https://img.shields.io/badge/⬇️_Direct_Download-Hoist.zip-2ea44f?style=for-the-badge&logo=apple&logoColor=white" alt="Download Hoist.zip">
  </a>
</p>

---

## 🌟 Open Source & Free for Everyone

**Hoist is 100% free and open-source software under the [MIT License](LICENSE).**

Built in pure native Swift using AppKit, SwiftUI, and ServiceManagement. Zero third-party dependencies, zero tracking, and negligible system footprint.

Created and maintained with ❤️ by **[Anshul Garg](http://anshulgarg.in/)**.

---

## ✨ Features

- 🌍 **110+ Country Flags**: Rich built-in library with capital time zones.
- ⭐ **Favourites & Recents**: Quick access to frequently selected countries at the top of the menu.
- ⏱️ **Live Local Time**: Optional minute-aligned clock showing local time at the selected country's capital.
- 🏷️ **Multiple Display Modes**:
  - Flag only (e.g. `🇮🇳`)
  - Flag + ISO code (e.g. `🇮🇳 IN`)
  - Flag + custom label (e.g. `🇮🇳 Mumbai` or `🇯🇵 Tokyo`)
- 🛡️ **⌘Q Confirmation Dialog**: Protects against accidental quits from keyboard shortcut or menu clicks.
- ℹ️ **Dedicated About Window**: Native About window with instant update checks and author details.
- 🔄 **In-App GitHub Updates**: Built-in zero-dependency updater that checks GitHub Releases and updates with one click.
- 🚀 **Launch at Login**: Native toggle supported via Apple's modern `SMAppService`.
- 🪶 **Ultra Lightweight**: Pure native Swift, zero external pods or dependencies, negligible CPU & RAM footprint.

---

## 📥 Download & Installation

### [⬇️ Direct Download Latest Release (`Hoist.zip`)](https://github.com/anshulg8/hoist/releases/latest/download/Hoist.zip)
*(Or browse all versions on [GitHub Releases](https://github.com/anshulg8/hoist/releases))*

You do **not** need Xcode or Swift installed to use Hoist:

1. **Download**: Click **[`Hoist.zip`](https://github.com/anshulg8/hoist/releases/latest/download/Hoist.zip)** to download the latest release directly.
2. **Install**: Double-click `Hoist.zip` to extract, then drag **`Hoist.app`** into your **Applications** folder.
3. **First Launch (macOS Gatekeeper)**:  
   Because Hoist is free, open-source software and not notarized through a paid Apple Developer subscription ($99/year), macOS will show a standard first-launch warning:
   - **System Settings (Standard macOS Sequoia / Sonoma flow)**:  
     Double-click `Hoist.app` → click **Done** on the prompt → open **System Settings** → **Privacy & Security** → scroll down to **Security** → click **Open Anyway**.
   - **Terminal (Fastest one-liner)**:  
     ```bash
     xattr -cr /Applications/Hoist.app
     ```
   *(You only need to do this once; macOS permanently remembers your choice thereafter).*

---

## 🛠️ Building from Source

Requirements: macOS 14.0+ (Sonoma or Sequoia) and Xcode Command Line Tools.

```bash
# Clone the repository
git clone https://github.com/anshulg8/hoist.git
cd hoist

# Build and package into Hoist.app + Hoist.zip
./scripts/bundle.sh release

# Launch Hoist
open Hoist.app
```

---

## 📄 License

MIT License © 2026 [Anshul Garg](http://anshulgarg.in/) — see the [LICENSE](LICENSE) file for details.
