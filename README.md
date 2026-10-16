# Windows Power Toggle ⚡

**Windows Power Toggle** is a lightweight, single-instance Windows system tray utility built for seamless power plan management. Switch between Power Profiles on the fly using customizable hotkeys, your mouse, or a quick-access system tray menu.

Created by **Mikesunboxing Ltd**.

---

## Features

- ⚡ **One-Click Power Cycling:** Left-click the tray icon to cycle through available Windows Power Profiles instantly.
- ⌨ **Global Hotkey Support:** Press `Ctrl` + `Alt` + `P` anywhere in Windows to toggle power modes instantly with balloon notifications.
- 🎨 **Dynamic High-Contrast Tray Icons:** Visual status indicators featuring bold rounded outlines and glowing inner cores that automatically adjust based on your active power mode:
  - 🟢 **Electric Green (`#00FF80`):** Power Saver / Eco / Efficient modes
  - 🔴 **Neon Crimson (`#FF2D55`):** High / Ultimate Performance modes
  - 🟡 **Vibrant Gold (`#FFD700`):** Balanced / Standard modes
- 🌍 **Universal Multi-Language Support:** Maps power profiles using universal Windows system GUIDs instead of localized text strings, ensuring dynamic tray icon colors match accurately across any Windows display language worldwide.
- 👁️ **Auto-Promoted Tray Icon:** Automatically registers with Windows 11 (`IsPromoted = 1`) to ensure the tray icon defaults to **Always Visible** on your taskbar rather than hiding in the overflow menu.
- 📁 **Zero-Dependency Build Script:** Copy-and-paste installer script built directly using Windows' native C# compiler (`csc.exe`)—no external downloads or Visual Studio required.
- 🚀 **Clean Non-Admin Deployment:** Installs directly to `%LOCALAPPDATA%\Programs\WindowsPowerToggle` with Start Menu Startup folder shortcuts (`.lnk`) for autostart, eliminating suspicious background command-line flags.
- 🛡️ **Built-in Security Hardening:** Generates a local code-signing certificate and signs the compiled binary to establish local trust and resist Microsoft Defender heuristic false-positive blocks (`Trojan:Win32/Commando.A!ml`).
- 🛠️ **Built-in Control Panel Link:** Quick option in the context menu to open native Windows Power Settings (`powercfg.cpl`).
- 🧹 **Clean Uninstall Support:** Fully registered in Windows Settings / Control Panel for standard 1-click uninstallation.

---

## 📦 Installation & Setup

You don't need to download compiled binaries or use external tools. You can build and deploy the application directly from source using Windows' built-in .NET C# compiler (`csc.exe`).

### Step-by-Step Guide

1. Press `Win + X` and select **PowerShell** (or Windows Terminal). *Administrative privileges are **NOT** required.*
2. Copy the full contents of `install.ps1` and paste it directly into your PowerShell window, then press **Enter**.
3. The script compiles `WindowsPowerToggle.exe` into a setup folder on your Desktop (`Windows Power Toggle Setup`), signs the binary with a local cert, and opens the setup folder automatically.
4. **Double-click `WindowsPowerToggle.exe`** inside the desktop setup folder to launch the interactive setup prompt.

---

## Controls & Usage

| Action | Control | Result |
| :--- | :--- | :--- |
| **Cycle Profiles** | `Left-Click` Tray Icon | Instantly switches to the next available power profile. |
| **Cycle Profiles (Global)** | `Ctrl` + `Alt` + `P` | Toggles power profile anywhere, displaying a notification tip. |
| **Profile Menu** | `Right-Click` Tray Icon | Displays all available power profiles, Control Panel link, and exit option. |

---

## Uninstallation

If you ever need to remove the application:

- **Go to Windows Settings > Apps > Installed Apps**, locate **Windows Power Toggle**, and click **Uninstall**.

This will safely remove Start Menu and Desktop shortcuts, the startup folder link, and local application directory files without touching system defaults.

---

## License & Usage Terms

This project is licensed under the **GNU General Public License v3.0 (GPLv3)**.

### Summary of Rights:
- **Free Use:** You are free to download, run, use, and share this tool completely free of charge for personal or commercial use.
- **Non-Proprietary / No Re-Sale:** You **cannot** package, modify, or lock this source code into closed-source commercial software for resale or profit. Any derivative works or distributions **must** remain 100% open-source under the same GPLv3 license terms.

See the full [LICENSE](./LICENSE) file for complete terms and legal details.
