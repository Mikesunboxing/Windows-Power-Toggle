# =====================================================================
# Windows Power Toggle v1.0.0.4 - Repaired Self-Building Package
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
[assembly: AssemblyVersion("1.0.0.4")]
[assembly: AssemblyFileVersion("1.0.0.4")]

namespace WindowsPowerToggle
{
    static class Program
    {
        private const string MUTEX_NAME = "Local\\WindowsPowerToggle_SingleInstance_Mutex_9001";

        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            string localPrograms = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs");
            string targetDir = Path.Combine(localPrograms, "WindowsPowerToggle");
            string targetExe = Path.Combine(targetDir, "WindowsPowerToggle.exe");
            string currentExe = Path.GetFullPath(System.Diagnostics.Process.GetCurrentProcess().MainModule.FileName);

            if (args != null && Array.Exists(args, a => string.Equals(a, "--uninstall", StringComparison.OrdinalIgnoreCase)))
            {
                Installer.Uninstall(targetDir, targetExe);
                return;
            }

            // Only launch directly when running from the canonical install location.
            if (string.Equals(currentExe, Path.GetFullPath(targetExe), StringComparison.OrdinalIgnoreCase))
            {
                RunSingleInstanceApp();
                return;
            }

            DialogResult result = MessageBox.Show(
                "Do you want to install Windows Power Toggle for the active user?\n\nIt will create Start Menu & Desktop shortcuts with a custom icon, run automatically on login, and can be uninstalled anytime via Windows Settings.",
                "Windows Power Toggle Setup",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question);

            if (result == DialogResult.Yes)
            {
                Installer.Install(currentExe, targetDir, targetExe);
            }
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
            try
            {
                InitializeTray();
                RegisterHotkey();
                RefreshPowerSchemes();
                PromoteTrayIconInRegistry();
            }
            catch
            {
                if (globalHotkey != null) globalHotkey.Dispose();
                if (trayIcon != null) { trayIcon.Visible = false; trayIcon.Dispose(); }
                if (contextMenu != null) contextMenu.Dispose();
                throw;
            }
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

        /// <summary>
        /// Automatically forces Windows 11 to display the tray icon permanently (IsPromoted = 1)
        /// </summary>
        private void PromoteTrayIconInRegistry()
        {
            try
            {
                string currentExePath = Path.GetFullPath(System.Diagnostics.Process.GetCurrentProcess().MainModule.FileName);
                const string notifyPath = @"Control Panel\NotifyIconSettings";
                using (RegistryKey notifyKey = Registry.CurrentUser.OpenSubKey(notifyPath))
                {
                    if (notifyKey == null) return;
                    foreach (string subkeyName in notifyKey.GetSubKeyNames())
                    {
                        using (RegistryKey appKey = Registry.CurrentUser.OpenSubKey(notifyPath + "\\" + subkeyName, true))
                        {
                            if (appKey == null) continue;
                            object value = appKey.GetValue("ExecutablePath");
                            if (value == null) continue;
                            string candidate;
                            try { candidate = Path.GetFullPath(value.ToString()); }
                            catch { continue; }
                            if (string.Equals(candidate, currentExePath, StringComparison.OrdinalIgnoreCase))
                                appKey.SetValue("IsPromoted", 1, RegistryValueKind.DWord);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                // Best-effort only: Windows controls notification-area visibility.
                System.Diagnostics.Debug.WriteLine("Tray promotion skipped: " + ex.Message);
            }
        }

        private void RegisterHotkey()
        {
            globalHotkey = new GlobalHotkey();
            globalHotkey.KeyPressed += (s, e) => CyclePowerScheme(true);
            if (!globalHotkey.Register(MOD_CONTROL | MOD_ALT, Keys.P, HOTKEY_ID))
            {
                int error = Marshal.GetLastWin32Error();
                globalHotkey.Dispose();
                globalHotkey = null;
                MessageBox.Show(
                    "The global hotkey Ctrl+Alt+P could not be registered. Another application may already be using it.\n\nWindows error: " + error,
                    "Windows Power Toggle - Hotkey Unavailable",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
            }
        }

        private void RefreshPowerSchemes()
        {
            try
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
            catch (Exception ex)
            {
                schemes = new List<PowerScheme>();
                currentSchemeIndex = -1;
                UpdateTrayUI();
                System.Diagnostics.Debug.WriteLine("Unable to refresh power schemes: " + ex);
                MessageBox.Show(
                    "Unable to read Windows power profiles. Retry using Refresh Schemes.\n\n" + ex.Message,
                    "Windows Power Toggle",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
            }
        }

        private void UpdateTrayUI()
        {
            contextMenu.Items.Clear();

            if (schemes.Count == 0)
            {
                trayIcon.Text = "Windows Power Toggle (No schemes)";
                contextMenu.Items.Add(new ToolStripMenuItem("No power profiles found") { Enabled = false });
                contextMenu.Items.Add(new ToolStripSeparator());
                contextMenu.Items.Add(new ToolStripMenuItem("Windows Power Settings", null, (s, e) => OpenPowerSettings()));
                contextMenu.Items.Add(new ToolStripMenuItem("Refresh Schemes", null, (s, e) => RefreshPowerSchemes()));
                contextMenu.Items.Add(new ToolStripMenuItem("Exit", null, (s, e) => ExitThread()));
                return;
            }

            PowerScheme activeScheme = (currentSchemeIndex >= 0 && currentSchemeIndex < schemes.Count) 
                ? schemes[currentSchemeIndex] 
                : null;

            string activeName = activeScheme != null ? activeScheme.Name : "Unknown";
            string tooltip = string.Format("Power Mode: {0}", activeName);
            // NotifyIcon.Text is limited to 63 characters on supported Windows versions.
            trayIcon.Text = tooltip.Length > 63 ? tooltip.Substring(0, 63) : tooltip;

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

            ToolStripMenuItem openSettings = new ToolStripMenuItem("Windows Power Settings", null, (s, e) => OpenPowerSettings());
            contextMenu.Items.Add(openSettings);

            ToolStripMenuItem refreshItem = new ToolStripMenuItem("Refresh Schemes", null, (s, e) => RefreshPowerSchemes());
            contextMenu.Items.Add(refreshItem);

            ToolStripMenuItem exitItem = new ToolStripMenuItem("Exit", null, (s, e) => ExitThread());
            contextMenu.Items.Add(exitItem);
        }

        private void OpenPowerSettings()
        {
            try
            {
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("control.exe", "powercfg.cpl") { UseShellExecute = true });
            }
            catch (Exception ex)
            {
                MessageBox.Show("Unable to open Power Settings: " + ex.Message, "Windows Power Toggle", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private Color GetColorForScheme(string schemeName)
        {
            string name = schemeName.ToLowerInvariant();
            if (name.Contains("saver") || name.Contains("eco") || name.Contains("efficient"))
            {
                return Color.FromArgb(0, 255, 128); 
            }
            else if (name.Contains("high") || name.Contains("ultimate") || name.Contains("performance"))
            {
                return Color.FromArgb(255, 45, 85); 
            }
            return Color.FromArgb(255, 215, 0); 
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
            if (schemes == null || index < 0 || index >= schemes.Count) return;

            PowerScheme scheme = schemes[index];
            uint result = PowerManager.SetActiveScheme(scheme.Guid);
            if (result != 0)
            {
                RefreshPowerSchemes();
                MessageBox.Show(
                    "Windows could not switch to the selected power profile. Native error: " + result,
                    "Windows Power Toggle",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                return;
            }

            RefreshPowerSchemes();
            if (showNotification)
                trayIcon.ShowBalloonTip(2000, "Windows Power Toggle", string.Format("Power mode set to: {0}", scheme.Name), ToolTipIcon.Info);
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
        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool DestroyIcon(IntPtr hIcon);

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

                using (Pen borderPen = new Pen(Color.FromArgb(15, 15, 15), 2.8f))
                {
                    borderPen.LineJoin = LineJoin.Round;
                    g.DrawPolygon(borderPen, boltPoints);
                }

                using (SolidBrush mainBrush = new SolidBrush(fillBrush))
                {
                    g.FillPolygon(mainBrush, boltPoints);
                }

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
                try
                {
                    Icon icon = Icon.FromHandle(hIcon);
                    return (Icon)icon.Clone();
                }
                finally
                {
                    if (hIcon != IntPtr.Zero) DestroyIcon(hIcon);
                }
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

        [DllImport("powrprof.dll", SetLastError = true)]
        private static extern uint PowerGetActiveScheme(IntPtr UserPowerKey, out IntPtr ActivePolicyGuid);

        [DllImport("powrprof.dll", SetLastError = true)]
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
                if (result == 259) break; // ERROR_NO_MORE_ITEMS
                if (result != 0)
                    throw new InvalidOperationException("PowerEnumerate failed with Windows error " + result + ".");
                if (guidSize < 16)
                    throw new InvalidOperationException("PowerEnumerate returned an invalid GUID buffer size.");

                Guid schemeGuid = new Guid(guidBuffer);
                string name = GetSchemeFriendlyName(schemeGuid);
                if (string.IsNullOrEmpty(name))
                    name = "Power Scheme (" + schemeGuid.ToString().Substring(0, 8) + ")";
                list.Add(new PowerScheme(schemeGuid, name));
                index++;
            }
            return list;
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr LocalFree(IntPtr hMem);

        public static Guid GetActiveScheme()
        {
            IntPtr guidPtr = IntPtr.Zero;
            uint result = PowerGetActiveScheme(IntPtr.Zero, out guidPtr);
            if (result != 0)
                throw new InvalidOperationException("PowerGetActiveScheme failed with Windows error " + result + ".");
            if (guidPtr == IntPtr.Zero)
                throw new InvalidOperationException("PowerGetActiveScheme returned a null pointer.");
            try
            {
                return (Guid)Marshal.PtrToStructure(guidPtr, typeof(Guid));
            }
            finally
            {
                LocalFree(guidPtr);
            }
        }

        public static uint SetActiveScheme(Guid schemeGuid)
        {
            return PowerSetActiveScheme(IntPtr.Zero, ref schemeGuid);
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
        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

        private const int WM_HOTKEY = 0x0312;
        private int currentId;
        private bool registered;
        private bool disposed;

        public event EventHandler KeyPressed;

        public GlobalHotkey()
        {
            this.CreateHandle(new CreateParams());
        }

        public bool Register(uint modifiers, Keys key, int id)
        {
            if (disposed) throw new ObjectDisposedException("GlobalHotkey");
            currentId = id;
            registered = RegisterHotKey(this.Handle, id, modifiers, (uint)key);
            return registered;
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
            if (disposed) return;
            disposed = true;
            if (registered && this.Handle != IntPtr.Zero)
            {
                UnregisterHotKey(this.Handle, currentId);
                registered = false;
            }
            if (this.Handle != IntPtr.Zero) this.DestroyHandle();
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
                        throw new InvalidOperationException("Windows Power Toggle is already running. Exit it from the tray menu, then run setup again.");
                }

                Directory.CreateDirectory(targetDir);
                string stagedExe = targetExe + ".new";
                if (File.Exists(stagedExe)) File.Delete(stagedExe);
                File.Copy(currentExe, stagedExe, true);
                if (File.Exists(targetExe))
                    File.Replace(stagedExe, targetExe, null);
                else
                    File.Move(stagedExe, targetExe);

                string iconPath = Path.Combine(targetDir, "app.ico");
                using (Icon icon = IconGenerator.CreateLightningIcon(Color.FromArgb(255, 215, 0)))
                {
                    IconGenerator.SaveIconToFile(icon, iconPath);
                }

                // Autostart via Start Menu Startup folder (No registry run switches)
                string startupFolderPath = Environment.GetFolderPath(Environment.SpecialFolder.Startup);
                string startupShortcutPath = Path.Combine(startupFolderPath, "Windows Power Toggle.lnk");
                CreateShortcut(startupShortcutPath, targetExe, "", "Windows Power Toggle AutoStart", iconPath);

                // Desktop & Start Menu Shortcuts
                string startMenuPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Windows Power Toggle.lnk");
                CreateShortcut(startMenuPath, targetExe, "", "Windows Power Toggle", iconPath);

                string desktopPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Windows Power Toggle.lnk");
                CreateShortcut(desktopPath, targetExe, "", "Windows Power Toggle", iconPath);

                // Register Uninstall Info
                string uninstallKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\WindowsPowerToggle";
                using (RegistryKey uninstKey = Registry.CurrentUser.CreateSubKey(uninstallKeyPath))
                {
                    if (uninstKey != null)
                    {
                        uninstKey.SetValue("DisplayName", "Windows Power Toggle");
                        uninstKey.SetValue("ApplicationVersion", "1.0.0.4");
                        uninstKey.SetValue("Publisher", "Mikesunboxing Ltd");
                        uninstKey.SetValue("DisplayIcon", iconPath);
                        uninstKey.SetValue("UninstallString", "\"" + targetExe + "\" --uninstall");
                        uninstKey.SetValue("InstallLocation", targetDir);
                        uninstKey.SetValue("NoModify", 1);
                        uninstKey.SetValue("NoRepair", 1);
                    }
                }

                MessageBox.Show("Windows Power Toggle v1.0.0.4 installed successfully!\n\nShortcuts have been added, and the app will start automatically on login.", "Installation Complete", MessageBoxButtons.OK, MessageBoxIcon.Information);

                System.Diagnostics.Process.Start(targetExe);
            }
            catch (Exception ex)
            {
                MessageBox.Show("Installation failed: " + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        public static void Uninstall(string targetDir, string targetExe)
        {
            try
            {
                string startupShortcutPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Startup), "Windows Power Toggle.lnk");
                string startMenuShortcutPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Windows Power Toggle.lnk");
                string desktopShortcutPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Windows Power Toggle.lnk");
                int currentPid = System.Diagnostics.Process.GetCurrentProcess().Id;
                string script =
                    "$targetPid = " + currentPid + "; " +
                    "while (Get-Process -Id $targetPid -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 250 }; " +
                    "$paths = @('" + EscapePowerShellPath(startupShortcutPath) + "','" +
                    EscapePowerShellPath(startMenuShortcutPath) + "','" +
                    EscapePowerShellPath(desktopShortcutPath) + "'); " +
                    "foreach ($p in $paths) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }; " +
                    "Remove-Item -LiteralPath 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\WindowsPowerToggle' -Recurse -Force -ErrorAction SilentlyContinue; " +
                    "Remove-Item -LiteralPath '" + EscapePowerShellPath(targetDir) + "' -Recurse -Force -ErrorAction SilentlyContinue";

                string encoded = Convert.ToBase64String(Encoding.Unicode.GetBytes(script));
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(
                    "powershell.exe", "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand " + encoded)
                {
                    UseShellExecute = false,
                    CreateNoWindow = true
                });
                Application.Exit();
            }
            catch (Exception ex)
            {
                MessageBox.Show("Unable to start uninstallation: " + ex.Message, "Windows Power Toggle", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private static string EscapePowerShellPath(string path)
        {
            return path.Replace("'", "''");
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

# Locate the .NET Framework C# compiler.
$cscCandidates = @(
    "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)
$cscPath = $cscCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $cscPath) {
    throw "C# compiler (csc.exe) was not found. The .NET Framework compiler must be available on this Windows installation."
}

# Remove stale output so a failed build cannot be mistaken for success.
Remove-Item -LiteralPath $OutputExe -Force -ErrorAction SilentlyContinue
Set-Content -LiteralPath $SourceFile -Value $Code -Encoding UTF8
try {
    Write-Host "Building Windows Power Toggle v1.0.0.4..." -ForegroundColor Cyan
    & $cscPath /target:winexe /out:"$OutputExe" /r:System.dll,System.Drawing.dll,System.Windows.Forms.dll "$SourceFile"
    $compileExitCode = $LASTEXITCODE
    if ($compileExitCode -ne 0 -or -not (Test-Path -LiteralPath $OutputExe)) {
        throw "Compilation failed (csc exit code: $compileExitCode)."
    }
}
finally {
    Remove-Item -LiteralPath $SourceFile -Force -ErrorAction SilentlyContinue
}

# Sign only a freshly compiled binary. Self-signing does not guarantee Defender trust.
try {
    $Cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction Stop |
        Where-Object { $_.Subject -eq "CN=Mikesunboxing Ltd Code Signing" } |
        Select-Object -First 1
    if (-not $Cert) {
        $Cert = New-SelfSignedCertificate `
            -Type CodeSigningCert `
            -Subject "CN=Mikesunboxing Ltd Code Signing" `
            -CertStoreLocation "Cert:\CurrentUser\My" `
            -NotAfter (Get-Date).AddYears(3) `
            -ErrorAction Stop
    }
    $signature = Set-AuthenticodeSignature -LiteralPath $OutputExe -Certificate $Cert -ErrorAction Stop
    if (-not $signature -or $signature.Status -eq "NotSigned") {
        throw "Authenticode signature was not applied."
    }
    if ($signature.Status -ne "Valid") {
        Write-Warning "Signature verification status is '$($signature.Status)'. The file may be signed but the self-signed certificate is not trusted; this does not establish Defender reputation."
    } else {
        Write-Host "Signature status: Valid." -ForegroundColor Green
    }
}
catch {
    Remove-Item -LiteralPath $OutputExe -Force -ErrorAction SilentlyContinue
    throw "Signing failed. The output executable was removed. Details: $($_.Exception.Message)"
}

if (Test-Path -LiteralPath $OutputExe) {
    Write-Host "Success! Built and signed v1.0.0.4 WindowsPowerToggle.exe" -ForegroundColor Green
    Invoke-Item $BuildFolder
} else {
    throw "Build failed: output executable was not created."
}
