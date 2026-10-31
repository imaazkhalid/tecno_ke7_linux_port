$ErrorActionPreference = "Stop"
$rects = "C:\Users\mk\snw_rects.txt"
$state = "C:\Users\mk\snw_state.txt"
Set-Content -Path $rects -Value "waiting" -Encoding UTF8
Set-Content -Path $state -Value "starting" -Encoding UTF8

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class P8 {
  public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public static string Text(IntPtr h) { var sb = new StringBuilder(2048); GetWindowTextW(h, sb, 2048); return sb.ToString(); }
}
"@

$exe = "C:\Users\mk\SN\SN_Write_Tool_v1.2020.00\SN_Writer_patched.exe"
Get-Process SN_Writer_patched -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
$p = Start-Process -FilePath $exe -WorkingDirectory "C:\Users\mk\SN\SN_Write_Tool_v1.2020.00" -PassThru
$procId = [uint32]$p.Id
Start-Sleep -Seconds 7

$script:main = [IntPtr]::Zero
$cb = [P8+EnumProc]{ param($h,$l)
  $q=0; [void][P8]::GetWindowThreadProcessId($h,[ref]$q)
  if ($q -eq $procId -and [P8]::Text($h) -like "SN Writer*") { $script:main = $h }
  return $true }
[void][P8]::EnumWindows($cb, [IntPtr]::Zero)
if ($script:main -eq [IntPtr]::Zero) { Set-Content $state "no-main"; exit 1 }
[void][P8]::PostMessage([P8]::GetDlgItem($script:main,1002), 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)

$script:dlg = [IntPtr]::Zero
for ($i=0; $i -lt 40; $i++) {
  Start-Sleep -Milliseconds 400
  $cb2 = [P8+EnumProc]{ param($h,$l)
    $q=0; [void][P8]::GetWindowThreadProcessId($h,[ref]$q)
    if ($q -eq $procId -and [P8]::Text($h) -eq "Scan Data") { $script:dlg = $h }
    return $true }
  [void][P8]::EnumWindows($cb2, [IntPtr]::Zero)
  if ($script:dlg -ne [IntPtr]::Zero) { break }
}
if ($script:dlg -eq [IntPtr]::Zero) { Set-Content $state "no-dialog"; exit 1 }

# keep the dialog above every other window so synthetic clicks always land on it
[void][P8]::SetWindowPos($script:dlg, [IntPtr](-1), 0, 0, 0, 0, 0x0001 -bor 0x0002 -bor 0x0004)
[void][P8]::SetWindowPos($script:main, [IntPtr](-1), 0, 0, 0, 0, 0x0001 -bor 0x0002 -bor 0x0004)

$e1 = [P8]::GetDlgItem($script:dlg, 1056)
$e2 = [P8]::GetDlgItem($script:dlg, 1058)
$ok = [P8]::GetDlgItem($script:dlg, 1071)
$r1 = New-Object P8+RECT; [void][P8]::GetWindowRect($e1, [ref]$r1)
$r2 = New-Object P8+RECT; [void][P8]::GetWindowRect($e2, [ref]$r2)
$r3 = New-Object P8+RECT; [void][P8]::GetWindowRect($ok, [ref]$r3)
$rd = New-Object P8+RECT; [void][P8]::GetWindowRect($script:dlg, [ref]$rd)
$sw = [P8]::GetSystemMetrics(0)
$sh = [P8]::GetSystemMetrics(1)

# rects file: screenW screenH e1(L,T,R,B) e2 ok dialog
Set-Content $rects ("{0} {1} {2} {3} {4} {5} {6} {7} {8} {9} {10} {11} {12} {13} {14} {15} {16} {17} {18} {19} {20}" -f `
  $sw,$sh,$r1.L,$r1.T,$r1.R,$r1.B,$r2.L,$r2.T,$r2.R,$r2.B,$r3.L,$r3.T,$r3.R,$r3.B,$rd.L,$rd.T,$rd.R,$rd.B,0,0,0) -Encoding ASCII

# keep reporting state for 240 s so the host can verify each step
for ($i=0; $i -lt 240; $i++) {
  $st = ([P8]::Text([P8]::GetDlgItem($script:main,1075)) -replace "`r?`n"," / ")
  $t1 = [P8]::Text($e1)
  $t2 = [P8]::Text($e2)
  Set-Content $state ("t1={0}|t2={1}|status={2}" -f $t1,$t2,$st) -Encoding UTF8
  Start-Sleep -Seconds 1
}
