# Windows Power Toggle ⚡

**Windows Power Toggle** is a lightweight, single-instance Windows system tray utility built for seamless power plan management. Switch between Power Profiles on the fly using customizable hotkeys, your mouse, or a quick-access system tray menu.

Created by **Mikesunboxing Ltd**.

---

## Features

* ⚡ **One-Click Power Cycling:** Left-click the tray icon to cycle through available Windows Power Profiles instantly.
* ⌨️ **Global Hotkey Support:** Press `Ctrl` + `Alt` + `P` anywhere in Windows to toggle power modes instantly with balloon notifications.
* 🎨 **Dynamic Tray Icons:** Visual status indicators that automatically adjust colors based on your active power mode:
  * 🟢 **Green:** Power Saver / Eco modes
  * 🔴 **Red:** High / Ultimate Performance modes
  * 🟡 **Yellow:** Balanced / Standard modes
* 📁 **Zero-Dependency Build Script:** Simple copy-and-paste installer script built directly using Windows' native C# compiler (`csc.exe`)—no external downloads or Visual Studio required.
* 🚀 **Auto-Start & Desktop Shortcuts:** Configures clean user-level startup registry entries and Start Menu / Desktop shortcuts with custom dynamic icons.
* 🛠️ **Built-in Control Panel Link:** Quick option in the context menu to open native Windows Power Settings (`powercfg.cpl`).
* 🧹 **Clean Uninstall Support:** Fully registered in Windows Settings / Control Panel for standard 1-click uninstallation.

---

## Quick Installation (Copy & Paste)

You don't need to compile anything manually. Just run the single PowerShell command script:

1. Press `Win + X` and select **PowerShell** (or Terminal).
2. Copy the contents of [`install.ps1`](./install.ps1) (or the complete PowerShell setup script from the release thread).
3. Paste it directly into your PowerShell window and press **Enter**.

### What happens next?
1. The script creates a **`Windows Power Toggle Setup`** folder on your Desktop.
2. It compiles `WindowsPowerToggle.exe` using your system's built-in .NET C# compiler.
3. The setup folder will automatically open on your Desktop.
4. **Double-click `WindowsPowerToggle.exe`** inside the desktop setup folder to launch the installer prompt!

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
* **Option 2:** Run `WindowsPowerToggle.exe --uninstall` via your command line.

This will safely remove shortcuts, startup registry entries, and local app data directory files without touching system defaults.

---

## License & Usage Terms

This project is licensed under the **GNU General Public License v3.0 (GPLv3)**.

### Summary of Rights:
* **Free Use:** You are free to download, run, use, and share this tool completely free of charge for personal or commercial use.
* **Non-Proprietary / No Re-Sale:** You **cannot** package, modify, or lock this source code into closed-source commercial software for resale or profit. Any derivative works or distributions **must** remain 100% open-source under the same GPLv3 license terms.

See the full [LICENSE](./LICENSE) file for complete terms and legal details.
