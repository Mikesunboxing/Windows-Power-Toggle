# Windows Power Toggle ⚡

**Windows Power Toggle** is a lightweight, single-instance Windows system tray utility built for seamless power plan management. Switch between Power Profiles on the fly using customizable hotkeys, your mouse, or a quick-access system tray menu.

Created by **Mikesunboxing Ltd**.

---

## Features

* ⚡ **One-Click Power Cycling:** Left-click the tray icon to cycle through available Windows Power Profiles instantly.
* ⌨️️ **Global Hotkey Support:** Press `Ctrl` + `Alt` + `P` anywhere in Windows to toggle power modes instantly with balloon notifications.
* 🎨 **Dynamic High-Contrast Tray Icons:** Visual status indicators featuring bold rounded outlines and glowing inner cores that automatically adjust based on your active power mode:
  * 🟢 **Electric Green (`#00FF80`):** Power Saver / Eco / Efficient modes
  * 🔴 **Neon Crimson (`#FF2D55`):** High / Ultimate Performance modes
  * 🟡 **Vibrant Gold (`#FFD700`):** Balanced / Standard modes
* 📁 **Zero-Dependency Build Script:** Simple copy-and-paste installer script built directly using Windows' native C# compiler (`csc.exe`)—no external downloads or Visual Studio required.
* 🚀 **Auto-Start & User-Level Deployment:** Installs directly to `%LOCALAPPDATA%\WindowsPowerToggle` with user-level startup registry entries and Start Menu / Desktop shortcuts with custom dynamic icons.
* 🛡️ **Smart Security Handling:** Runs entirely without administrative rights while dynamically registering machine-wide Windows Defender exclusions if run with elevated privileges.
* 🛠️ **Built-in Control Panel Link:** Quick option in the context menu to open native Windows Power Settings (`powercfg.cpl`).
* 🧹 **Clean Uninstall Support:** Fully registered in Windows Settings / Control Panel for standard 1-click uninstallation.

---

## 📦 Installation & Setup

You don't need to download compiled binaries or use external tools. You can build and deploy the application directly from source using Windows' built-in .NET C# compiler (`csc.exe`).

### Step-by-Step Guide

1. Press `Win + X` and select **PowerShell** (or Windows Terminal).
   > **Note on Administrative Privileges:** You **do NOT need to run PowerShell as Administrator**. The app installs entirely to user-level directories (`%LOCALAPPDATA%` and `HKCU`). However, if you *do* choose to run PowerShell as Administrator, the setup script will automatically attempt to register a machine-wide Windows Defender exclusion as an added benefit.
2. Copy the full setup script block and paste it directly into your PowerShell window, then press **Enter**.
3. The script compiles `WindowsPowerToggle.exe` into a setup folder on your Desktop (`Windows Power Toggle Setup`) and opens the folder automatically.
4. **Double-click `WindowsPowerToggle.exe`** inside the desktop setup folder to launch the interactive setup prompt.
5. If you want to remove or delete the desktop setup folder, you will need to reboot the PC at least once to free up the files in use.

---

### Command-Line Parameters

The compiled binary supports execution flags for silent operation or uninstallation:

| Parameter | Description | Requires Admin? |
| :--- | :--- | :--- |
| *(None)* | Launches the interactive setup installer prompt. | **No** |
| `--run` | Launches the system tray process directly (used by Windows Startup & shortcuts). | **No** |
| `--uninstall` | Removes startup registry entries, shortcuts, and app files, then unregisters from Windows Settings. | **No** |

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

* **Option 1:** Go to **Windows Settings > Apps > Installed Apps**, locate **Windows Power Toggle**, and click **Uninstall**.
* **Option 2:** Run `WindowsPowerToggle.exe --uninstall` via PowerShell or Command Prompt.

This will safely remove shortcuts, startup registry entries, and local app data directory files without touching system defaults.

---

## License & Usage Terms

This project is licensed under the **GNU General Public License v3.0 (GPLv3)**.

### Summary of Rights:
* **Free Use:** You are free to download, run, use, and share this tool completely free of charge for personal or commercial use.
* **Non-Proprietary / No Re-Sale:** You **cannot** package, modify, or lock this source code into closed-source commercial software for resale or profit. Any derivative works or distributions **must** remain 100% open-source under the same GPLv3 license terms.

See the full [LICENSE](./LICENSE) file for complete terms and legal details.
