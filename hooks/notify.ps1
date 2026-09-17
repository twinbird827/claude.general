# Stop / Notification hook: popup when Claude Code needs attention,
# unless VSCode is the foreground window.
param([string]$Message = 'Task completed!')

Add-Type -AssemblyName System.Windows.Forms
Add-Type -Namespace Win32 -Name Fg -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int pid);
'@

$fgPid = 0
[void][Win32.Fg]::GetWindowThreadProcessId([Win32.Fg]::GetForegroundWindow(), [ref]$fgPid)
$fgName = (Get-Process -Id $fgPid -ErrorAction SilentlyContinue).ProcessName

# 'Code' / 'Code - Insiders' / 'Code - OSS'
if ($fgName -like 'Code*') { exit 0 }

[void][System.Windows.Forms.MessageBox]::Show(
    $Message, 'Claude Code', 'OK', 'Information', 'Button1', 'DefaultDesktopOnly')
