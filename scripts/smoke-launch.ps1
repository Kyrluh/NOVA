param([string]$Executable = 'build\windows\x64\runner\Release\NOVA_IPTV.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$exePath = (Resolve-Path -LiteralPath (Join-Path $projectRoot $Executable)).Path
if (-not $exePath.StartsWith($projectRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Le test doit cibler un exécutable dans ce projet.'
}
$process = Start-Process -FilePath $exePath -WorkingDirectory (Split-Path -Parent $exePath) -WindowStyle Hidden -PassThru
try {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Milliseconds 500
        $process.Refresh()
        if ($process.HasExited) { throw "L''application s''est arrêtée (code $($process.ExitCode))." }
    } while ($process.MainWindowHandle -eq 0 -and $watch.Elapsed.TotalSeconds -lt 15)
    if ($process.MainWindowHandle -eq 0) { throw 'Fenêtre principale non détectée.' }
    Start-Sleep -Seconds 3
    $process.Refresh()
    if ($process.HasExited) { throw 'Arrêt inattendu après création de la fenêtre.' }
    Write-Output "PASS : fenêtre NOVA IPTV créée et processus stable, PID $($process.Id)."
    if (-not $process.CloseMainWindow()) { throw 'Fermeture de la fenêtre refusée.' }
    if (-not $process.WaitForExit(10000)) { throw 'L''application ne s''est pas fermée normalement.' }
    if ($process.ExitCode -ne 0) { throw "Code de sortie anormal : $($process.ExitCode)." }
    Write-Output 'PASS : fermeture normale, code 0.'
} finally {
    $process.Refresh()
    if (-not $process.HasExited) {
        # Stop only the exact child created by this test, never another session.
        Stop-Process -Id $process.Id
    }
    $process.Dispose()
}
