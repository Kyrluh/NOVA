param([switch]$Emulator)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tools = Join-Path $root '.tools'
New-Item -ItemType Directory -Path $tools -Force | Out-Null
function Get-VerifiedArchive([string]$Url, [string]$File, [string]$Hash, [string]$Algorithm = 'SHA256') {
    if (-not (Test-Path -LiteralPath $File)) {
        & curl.exe --fail --location --retry 3 --silent --show-error $Url --output $File
        if ($LASTEXITCODE -ne 0) { throw 'Telechargement des outils Android echoue.' }
    }
    if ((Get-FileHash -LiteralPath $File -Algorithm $Algorithm).Hash.ToLowerInvariant() -ne $Hash) { throw 'Empreinte des outils invalide.' }
}
if (-not (Test-Path -LiteralPath (Join-Path $tools 'jdk\jdk-21.0.13+9\bin\java.exe'))) {
    $jdkZip = Join-Path $tools 'jdk21.zip'
    Get-VerifiedArchive 'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13%2B9/OpenJDK21U-jdk_x64_windows_hotspot_21.0.13_9.zip' $jdkZip 'a4dbaa05fca4bd89d84584e58c459bd732efebb1722af80ab13c6516832004f9'
    Expand-Archive -LiteralPath $jdkZip -DestinationPath (Join-Path $tools 'jdk') -Force
}
$sdkBin = Join-Path $tools 'android-sdk\cmdline-tools\latest\bin\android.exe'
if (-not (Test-Path -LiteralPath $sdkBin)) {
    $sdkZip = Join-Path $tools 'android-commandline.zip'
    Get-VerifiedArchive 'https://dl.google.com/android/repository/commandlinetools-win-16111833_latest.zip' $sdkZip '57d04f2d75eb8e8fffc5000a987e5de4b5a63e9d' 'SHA1'
    $unpacked = Join-Path $tools 'android-cli-unpacked'
    Expand-Archive -LiteralPath $sdkZip -DestinationPath $unpacked -Force
    $destination = Join-Path $tools 'android-sdk\cmdline-tools\latest'
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $unpacked 'cmdline-tools') | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force }
}
. (Join-Path $PSScriptRoot 'android-env.ps1')
& $sdkBin --no-metrics --sdk=$env:ANDROID_HOME sdk install 'platform-tools' 'platforms/android-36' 'platforms/android-35' 'build-tools/36.0.0' 'ndk/28.2.13676358' 'cmake/3.22.1'
if ($LASTEXITCODE -ne 0) { throw 'Installation SDK Android echouee.' }
if ($Emulator) {
    & $sdkBin --no-metrics --sdk=$env:ANDROID_HOME sdk install 'emulator' 'system-images/android-35/google_apis/x86_64'
    if ($LASTEXITCODE -ne 0) { throw 'Installation emulateur echouee.' }
}
Write-Output 'Outils Android installes localement. Utiliser scripts/flutter.ps1 pour compiler.'
