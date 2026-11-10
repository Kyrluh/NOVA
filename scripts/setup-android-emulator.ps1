param([switch]$Start)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'android-env.ps1')
$manager = Join-Path $env:ANDROID_HOME 'cmdline-tools\latest\bin\avdmanager.bat'
if (-not (Test-Path -LiteralPath (Join-Path $env:ANDROID_AVD_HOME 'NovaFold35.avd'))) {
    'no' | & $manager create avd --force --name NovaFold35 --package 'system-images;android-35;google_apis;x86_64' --device pixel_fold
    if ($LASTEXITCODE -ne 0) { throw 'Creation du profil pliable echouee.' }
}
if ($Start) {
    $emulator = Join-Path $env:ANDROID_HOME 'emulator\emulator.exe'
    $args = @('-avd', 'NovaFold35', '-no-window', '-no-audio', '-no-boot-anim', '-no-snapshot', '-gpu', 'swiftshader_indirect', '-memory', '3072', '-cores', '4', '-port', '5556')
    $outLog = Join-Path $novaRoot '.tools\emulator-stdout.log'
    $errorLog = Join-Path $novaRoot '.tools\emulator-stderr.log'
    $process = Start-Process -FilePath $emulator -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput $outLog -RedirectStandardError $errorLog
    Write-Output "Emulateur NovaFold35 lance, PID $($process.Id), adb emulator-5556."
}
