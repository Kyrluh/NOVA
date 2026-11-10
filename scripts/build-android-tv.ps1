$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'android-env.ps1')
$keyPath = Join-Path $novaRoot '.signing\nova-android-release.p12'
$passwordPath = Join-Path $novaRoot '.signing\password.dpapi'
if (-not (Test-Path -LiteralPath $keyPath) -or -not (Test-Path -LiteralPath $passwordPath)) {
    throw 'Signature de production absente. Executer initialize-android-signing.ps1 ou restaurer la cle existante.'
}
Add-Type -AssemblyName System.Security
$passwordBytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($passwordPath), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
$env:NOVA_ANDROID_STORE_PASSWORD = [Text.Encoding]::UTF8.GetString($passwordBytes)
try {
    & (Join-Path $PSScriptRoot 'flutter.ps1') build apk --release --dart-define=NOVA_TV=true --target-platform 'android-arm,android-arm64,android-x64'
    if ($LASTEXITCODE -ne 0) { throw 'Compilation APK TV echouee.' }
    & (Join-Path $PSScriptRoot 'package-android.ps1') -Television
    if ($LASTEXITCODE -ne 0) { throw 'Verification APK TV echouee.' }
} finally {
    $env:NOVA_ANDROID_STORE_PASSWORD = $null
    [Array]::Clear($passwordBytes, 0, $passwordBytes.Length)
}
