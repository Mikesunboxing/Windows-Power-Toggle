<div align="center">

# ⚡ Windows Power Toggle

**Switch Windows power plans instantly — from the system tray or your keyboard.**

[![Version](https://img.shields.io/badge/version-1.0.0.7-2563eb?style=flat-square)](#download--install)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078d4?style=flat-square&logo=windows)](#requirements)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-3b7d3b?style=flat-square)](./LICENSE)

A lightweight, single-instance Windows tray utility by **Mikesunboxing Ltd**.

**[Features](#features)** · **[Install](#download--install)** · **[Controls](#controls)** · **[Build from source](#build-from-source)** · **[Troubleshooting](#troubleshooting)**

</div>

---

## At a glance

Windows Power Toggle makes it easy to move between the power plans available on your PC. Click the lightning-bolt tray icon, use the right-click menu, or press **`Ctrl` + `Alt` + `P`** — no need to dig through Control Panel.

> **Note:** The available power plans depend on your Windows installation and hardware. The app switches existing plans; it does not create new ones.

## Features

- ⚡ **One-click switching** — left-click the tray icon to cycle through available plans.
- ⌨️ **Global keyboard shortcut** — press **`Ctrl` + `Alt` + `P`** from anywhere in Windows.
- 🎨 **Colour-coded tray icon** — see the current power plan at a glance.
- 🖱️ **Quick-access menu** — select a plan directly, refresh the list, or open Windows Power Settings.
- 🔔 **Switch notifications** — legacy Windows tray notifications when cycling plans (subject to Windows notification settings).
- 🚀 **Start with Windows** — enabled by default; toggle it from the tray menu.
- 👤 **Per-user installation** — installs under your user profile without normally needing administrator privileges.
- 🧹 **Windows uninstall integration** — remove it from **Settings → Apps → Installed apps**.

### Tray icon colours

| Colour | Hex | Typical plan names |
|:--|:--|:--|
| 🟢 Green | `#00FF80` | Power saver, Eco, Efficient |
| 🔴 Red | `#FF2D55` | High performance, Ultimate performance |
| 🟡 Gold | `#FFD700` | Balanced and other plans |

> Colours are selected by matching words in the power plan's **display name**. Custom or non-English names may fall back to gold.

## Screenshots

<!-- Add a screenshot to your repository at docs/images/tray-menu.png, then uncomment:
![Windows Power Toggle tray menu](docs/images/tray-menu.png)
-->

*Screenshot coming soon: the right-click tray menu showing available power plans and the “Start with Windows” option.*

## Download & install

1. Download **`WindowsPowerToggle_Setup_v1.0.0.7.exe`** from this repository's **Releases** section when a release is published.
2. Double-click the downloaded file.
3. Choose **Yes** when Windows Power Toggle asks whether to install for the current user.
4. The app installs and starts automatically. Find the ⚡ icon in the notification area (it may be in the tray overflow menu).

**Installed location:**

```text
%LOCALAPPDATA%\Programs\WindowsPowerToggle\WindowsPowerToggle.exe
```

The setup EXE is self-contained: you do **not** need to run the PowerShell build script to install a published release. The downloaded setup file can be kept or deleted after installation.

> **Windows security:** Development builds may be unsigned. Windows SmartScreen or Smart App Control may warn about or block unfamiliar applications. A Defender antivirus exclusion does **not** override Smart App Control. Do not disable Windows security features just to install this tool. See [Troubleshooting](#troubleshooting).

## Controls

| Action | How |
|:--|:--|
| Cycle power plans | **Left-click** the tray icon |
| Cycle from anywhere | **`Ctrl` + `Alt` + `P`** |
| Choose a specific plan | **Right-click** tray icon → select a plan |
| Refresh available plans | **Right-click** → **Refresh Schemes** |
| Open Windows power settings | **Right-click** → **Windows Power Settings** |
| Enable or disable auto-start | **Right-click** → **Start with Windows** |
| Close the utility | **Right-click** → **Exit** |

**Tip:** If notifications do not appear, check **Settings → System → Notifications** and make sure **Do not disturb** is off.

## Requirements

- Windows 10 or Windows 11 desktop environment.
- Windows .NET Framework runtime suitable for the compiled application.
- Existing Windows power plans to switch between.

> Compatibility varies by device and Windows configuration; some modern PCs expose only a limited set of traditional power plans.

## Uninstall

1. Exit Windows Power Toggle from its tray menu if it is running.
2. Open **Settings → Apps → Installed apps** (or the equivalent Apps settings page on your Windows version).
3. Find **Windows Power Toggle** and choose **Uninstall**.

The uninstaller is designed to remove the installed application, its Start Menu/Desktop/startup shortcuts, and its uninstall registration. **The original downloaded setup EXE and the Desktop build-output folder are not removed** — you can delete those manually if you no longer need them.

## Build from source

For developers who prefer to compile the application locally:

1. Obtain the project's PowerShell build script from the source repository.
2. Review the script before running it.
3. Run it in a normal, non-administrator PowerShell session on Windows.
4. The script uses the Windows .NET Framework C# compiler (`csc.exe`) to create:

```text
Desktop\Windows Power Toggle Setup\WindowsPowerToggle_Setup_v1.0.0.7.exe
```

**Development builds are unsigned by default.** Release signing is optional and requires an appropriate trusted code-signing certificate. The build script looks for the certificate thumbprint in the `WPT_SIGNING_THUMBPRINT` environment variable. A signature alone does not guarantee approval by SmartScreen or Smart App Control.

> If Windows blocks a downloaded `.ps1` file, do not disable Smart App Control or weaken security settings. Prefer a published, trusted release, or review and build from source in a development environment you control.

## Troubleshooting

| Issue | What to check |
|:--|:--|
| Hotkey does not respond | Another application may already be using `Ctrl + Alt + P`. |
| No notification appears | Check Windows notifications and **Do not disturb**. |
| Tray icon is missing | Check the notification-area overflow menu. |
| A power plan is missing | Use **Refresh Schemes** and confirm it exists in Windows Power Settings. |
| Installer is blocked | Identify whether the warning is from SmartScreen, Defender Antivirus, or Smart App Control; these have different policies. |
| App will not update | Exit the running tray app before launching the newer setup EXE. |

**Security note:** Smart App Control does not offer a normal per-app “allow” exception. A file's **Properties → Unblock** option, where available, does not guarantee that Smart App Control will permit it.

## License

Windows Power Toggle is distributed under the **GNU General Public License v3.0 (GPLv3)**. See [LICENSE](./LICENSE) for the full terms.

GPLv3 permits use, modification, and redistribution, including commercial distribution, subject to its conditions. Distributors of modified or covered versions must comply with the applicable source-code and licensing requirements.

---

<div align="center">

Made by **Mikesunboxing Ltd** · **Windows Power Toggle v1.0.0.7**

</div>
