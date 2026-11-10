param([string]$Executable = 'build\windows\x64\runner\Release\NOVA_IPTV.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$exePath = (Resolve-Path -LiteralPath (Join-Path $projectRoot $Executable)).Path
if (-not $exePath.StartsWith($projectRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Executable outside project.' }
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NovaWindowProbe {
  [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct Monitor { public int Size; public Rect Bounds, Work; public int Flags; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out Rect r);
  [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr h, uint flags);
  [DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr h, ref Monitor info);
  [DllImport("user32.dll")] public static extern IntPtr GetWindowLongPtr(IntPtr h, int index);
  [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int command);
  [DllImport("user32.dll")] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
  public static IntPtr View(IntPtr parent) { return FindWindowEx(parent, IntPtr.Zero, null, null); }
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder name, int count);
  public delegate bool EnumCallback(IntPtr h, IntPtr data);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumCallback cb, IntPtr data);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  public static IntPtr AppWindow(int pid) {
    IntPtr result = IntPtr.Zero;
    EnumWindows(delegate(IntPtr h, IntPtr data) {
      uint owner; GetWindowThreadProcessId(h, out owner);
      if (owner == pid) {
        var name = new System.Text.StringBuilder(256); GetClassName(h, name, 256);
        if (name.ToString() == "FLUTTER_RUNNER_WIN32_WINDOW") { result = h; return false; }
      }
      return true;
    }, IntPtr.Zero);
    return result;
  }
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  public static void Key(IntPtr view, int key, int scan) {
    PostMessage(view, 0x100, (IntPtr)key, (IntPtr)(1 | (scan << 16)));
    PostMessage(view, 0x101, (IntPtr)key, new IntPtr(unchecked((int)(0xC0000001u | ((uint)scan << 16)))));
  }
  public static bool Fullscreen(IntPtr h) {
    Rect r, c; GetWindowRect(h, out r); GetClientRect(h, out c);
    var m = new Monitor(); m.Size = Marshal.SizeOf(m);
    GetMonitorInfo(MonitorFromWindow(h, 2), ref m);
    long style = GetWindowLongPtr(h, -16).ToInt64();
    return (style & 0x00C40000) == 0 && r.Left == m.Bounds.Left && r.Top == m.Bounds.Top &&
      r.Right == m.Bounds.Right && r.Bottom == m.Bounds.Bottom &&
      c.Right == r.Right-r.Left && c.Bottom == r.Bottom-r.Top;
  }
  public static string Bounds(IntPtr h) {
    Rect r; GetWindowRect(h, out r); return string.Format("{0},{1},{2},{3}", r.Left, r.Top, r.Right, r.Bottom);
  }
}
'@
function Wait-Mode([IntPtr]$Window, [bool]$Fullscreen) {
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        Start-Sleep -Milliseconds 100
        if ([NovaWindowProbe]::Fullscreen($Window) -eq $Fullscreen) { return }
    }
    throw "Fullscreen expected=$Fullscreen, actual=$([NovaWindowProbe]::Fullscreen($Window)), bounds=$([NovaWindowProbe]::Bounds($Window))"
}
$process = Start-Process -FilePath $exePath -WorkingDirectory (Split-Path -Parent $exePath) -WindowStyle Hidden -PassThru
try {
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        Start-Sleep -Milliseconds 250
        $process.Refresh()
        if ($process.HasExited) { throw 'App exited before test.' }
        if ($process.MainWindowHandle -ne 0) { break }
    }
    Start-Sleep -Seconds 2
    $window = [NovaWindowProbe]::AppWindow($process.Id)
    if ($window -eq 0) { throw 'No Flutter runner window.' }
    $view = [NovaWindowProbe]::View($window)
    if ($view -ne 0) {
        $className = New-Object System.Text.StringBuilder 256
        [NovaWindowProbe]::GetClassName($view, $className, 256) | Out-Null
        Write-Output "Child window class: $className"
    }
    if ($view -eq 0) { throw 'No Flutter view.' }
    [NovaWindowProbe]::ShowWindow($window, 9) | Out-Null
    Start-Sleep -Milliseconds 300
    $normalBounds = [NovaWindowProbe]::Bounds($window)
    [NovaWindowProbe]::Key($view, 0x7A, 0x57)
    Wait-Mode $window $true
    Write-Output 'PASS: F11 removes caption/borders and fills monitor including client area.'
    [NovaWindowProbe]::Key($view, 0x7A, 0x57)
    Wait-Mode $window $false
    Start-Sleep -Milliseconds 250
    if ([NovaWindowProbe]::Bounds($window) -ne $normalBounds) { throw 'Normal placement not restored.' }
    Write-Output 'PASS: F11 restores original window bounds.'
    [NovaWindowProbe]::ShowWindow($window, 3) | Out-Null
    Start-Sleep -Milliseconds 300
    [NovaWindowProbe]::Key($view, 0x7A, 0x57)
    Wait-Mode $window $true
    Write-Output 'PASS: F11 also removes borders from a maximized window.'
    [NovaWindowProbe]::Key($view, 0x1B, 0x01)
    Wait-Mode $window $false
    Start-Sleep -Milliseconds 250
    if (-not [NovaWindowProbe]::IsZoomed($window)) { throw 'Maximized state not restored.' }
    Write-Output 'PASS: Escape restores maximized state.'
    if (-not $process.CloseMainWindow()) { throw 'Close refused.' }
    if (-not $process.WaitForExit(10000) -or $process.ExitCode -ne 0) { throw 'Abnormal close.' }
    Write-Output 'PASS: normal close, exit 0.'
} finally {
    $process.Refresh()
    if (-not $process.HasExited) { Stop-Process -Id $process.Id }
    $process.Dispose()
}
