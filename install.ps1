# =====================================================================
# Windows Power Toggle v1.0.0.4 - Self-Building Package
# Publisher: Mikesunboxing Ltd
# =====================================================================

$DesktopPath = [Environment]::GetFolderPath("Desktop")
$BuildFolder = Join-Path$DesktopPath "Windows Power Toggle Setup"
New-Item -ItemType Directory -Force -Path $BuildFolder | Out-Null

$OutputExe = Join-Path$BuildFolder "WindowsPowerToggle.exe"
$SourceFile = Join-Path$env:TEMP "WindowsPowerToggle_Source.cs"

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
        private const string MUTEX_NAME = "Global\\WindowsPowerToggle_SingleInstance_Mutex_9001";

        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            string localPrograms = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs");
            string targetDir = Path.Combine(localPrograms, "WindowsPowerToggle");
            string targetExe = Path.Combine(targetDir, "WindowsPowerToggle.exe");
            string currentExe = System.Diagnostics.Process.GetCurrentProcess().MainModule.FileName;

            if (currentExe.Equals(targetExe, StringComparison.OrdinalIgnoreCase))
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
            InitializeTray();
            RegisterHotkey();
            RefreshPowerSchemes();
            PromoteTrayIconInRegistry();
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

        private void PromoteTrayIconInRegistry()
        {
            try
            {
                string currentExePath = System.Diagnostics.Process.GetCurrentProcess().MainModule.FileName;
                using (RegistryKey notifyKey = Registry.CurrentUser.OpenSubKey(@"Control Panel\NotifyIconSettings"))
                {
                    if (notifyKey == null) return;

                    foreach (string subkeyName in notifyKey.GetSubKeyNames())
                    {
                        using (RegistryKey appKey = Registry.CurrentUser.OpenSubKey(@"Control Panel\NotifyIconSettings\" + subkeyName, true))
                        {
                            if (appKey != null)
                            {
                                object execPathObj = appKey.GetValue("ExecutablePath");
                                if (execPathObj != null)
                                {
                                    string execPath = execPathObj.ToString();
                                    if (execPath.Equals(currentExePath, StringComparison.OrdinalIgnoreCase) ||
                                        execPath.IndexOf("WindowsPowerToggle.exe", StringComparison.OrdinalIgnoreCase) >= 0)
                                    {
                                        appKey.SetValue("IsPromoted", 1, RegistryValueKind.DWord);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            catch
            {
                // Non-critical operation: ignore registry access exceptions if key doesn't exist yet
            }
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

            Color iconColor = GetColorForScheme(activeScheme);
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

        private Color GetColorForScheme(PowerScheme scheme)
        {
            if (scheme == null) return Color.FromArgb(255, 215, 0);

            string guidStr = scheme.Guid.ToString().ToLowerInvariant();

            // 1. Universal GUID matching (Language-independent for standard Windows schemes)
            if (guidStr == "381b4222-f694-41f0-9685-ff5bb260df2e") // Balanced
            {
                return Color.FromArgb(255, 215, 0); // Vibrant Gold
            }
            if (guidStr == "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" || guidStr.Contains("e9a42b02")) // High / Ultimate Performance
            {
                return Color.FromArgb(255, 45, 85); // Neon Crimson
            }
            if (guidStr == "a1841308-3541-4fab-bc81-f71556f20b4a") // Power Saver / Eco
            {
                return Color.FromArgb(0, 255, 128); // Electric Green
            }

            // 2. Fallback localized keyword matching for custom OEM or international naming variations
            string name = scheme.Name.ToLowerInvariant();
            if (name.Contains("saver") || name.Contains("eco") || name.Contains("ström") || name.Contains("effekt") || name.Contains("battery") || name.Contains("spar"))
            {
                return Color.FromArgb(0, 255, 128);
            }
            else if (name.Contains("high") || name.Contains("ultimate") || name.Contains("prestanda") || name.Contains("leistung") || name.Contains("alto") || name.Contains("performance"))
            {
                return Color.FromArgb(255, 45, 85);
            }

            return Color.FromArgb(255, 215, 0); // Default Balanced / Standard Gold
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
            return "Power Scheme (" + schemeGuid.ToString().
