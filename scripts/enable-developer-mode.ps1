param([ValidateSet('Enable', 'Restore')][string]$Mode = 'Enable')
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Mode ' + $Mode
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -Wait -PassThru
    exit $process.ExitCode
}
$registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
$snapshotPath = Join-Path (Split-Path -Parent $PSScriptRoot) '.tools\developer-mode-original.json'
if ($Mode -eq 'Restore') {
    if (-not (Test-Path -LiteralPath $snapshotPath)) { throw 'État initial manquant : restauration arrêtée.' }
    $snapshot = Get-Content -LiteralPath $snapshotPath -Raw | ConvertFrom-Json
    if ($snapshot.exists -isnot [bool]) { throw 'État initial invalide.' }
    if ($snapshot.exists) {
        New-ItemProperty -LiteralPath $registryPath -Name 'AllowDevelopmentWithoutDevLicense' -Value ([int]$snapshot.value) -PropertyType DWord -Force | Out-Null
    } else {
        Remove-ItemProperty -LiteralPath $registryPath -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $snapshotPath
    Write-Output 'Réglage du mode développeur Windows restauré à son état initial.'
    exit 0
}
if (-not (Test-Path -LiteralPath $snapshotPath)) {
    $original = Get-ItemProperty -LiteralPath $registryPath -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction SilentlyContinue
    @{ exists = ($null -ne $original); value = if ($null -ne $original) { $original.AllowDevelopmentWithoutDevLicense } else { 0 } } |
        ConvertTo-Json | Set-Content -LiteralPath $snapshotPath -Encoding UTF8
}
if (-not (Test-Path -LiteralPath $registryPath)) { New-Item -Path $registryPath -Force | Out-Null }
New-ItemProperty -LiteralPath $registryPath -Name 'AllowDevelopmentWithoutDevLicense' -Value 1 -PropertyType DWord -Force | Out-Null
Write-Output 'Mode développeur Windows activé temporairement ; état initial sauvegardé.'
