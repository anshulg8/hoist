# Hoist 🚩

**Hoist** is a tiny, zero-dependency macOS menu-bar utility that displays your selected country flag, live local time, and custom status text. Built in native Swift using AppKit, SwiftUI, and ServiceManagement.

---

## ✨ Features

- 🌍 **110+ Country Flags**: Rich built-in library with capital time zones.
- ⭐ **Favourites & Recents**: Quick access to your frequently selected countries at the top of the menu.
- ⏱️ **Live Local Time**: Optional minute-aligned clock showing local time at the selected country's capital.
- 🏷️ **Multiple Display Modes**:
  - Flag only (e.g. `🇮🇳`)
  - Flag + ISO code (e.g. `🇮🇳 IN`)
  - Flag + custom label (e.g. `🇮🇳 Mumbai` or `🇯🇵 Tokyo`)
- 🛡️ **⌘Q Confirmation Dialog**: Protects against accidental quits from keyboard shortcut or menu clicks.
- ℹ️ **Dedicated About Window**: Native About window with instant update checking and creator details.
- 🔄 **In-App GitHub Updates**: Built-in zero-dependency updater that checks GitHub Releases and updates with one click.
- 🚀 **Launch at Login**: Native toggle supported via Apple's modern `SMAppService`.
- 🪶 **Ultra Lightweight**: Pure native Swift, zero external pods or dependencies, negligible CPU & RAM footprint.

---

## 📥 Download & Installation

You do **not** need Xcode or Swift installed to use Hoist:

1. **Download**: Grab the latest **[`Hoist.zip`](https://github.com/anshulg8/hoist/releases/latest)** from GitHub Releases.
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
