param([switch]$SkipUniversal)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'android-env.ps1')
$keyPath = Join-Path $novaRoot '.signing\nova-android-release.p12'
$passwordPath = Join-Path $novaRoot '.signing\password.dpapi'
if (-not (Test-Path -LiteralPath $keyPath) -or -not (Test-Path -LiteralPath $passwordPath)) {
    throw 'Executer initialize-android-signing.ps1 avant une compilation Release.'
}
Add-Type -AssemblyName System.Security
$passwordBytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($passwordPath), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
$env:NOVA_ANDROID_STORE_PASSWORD = [Text.Encoding]::UTF8.GetString($passwordBytes)
try {
    # Keep Flutter's tooling refresh enabled: --no-pub also skips regenerating
    # the release registrant, leaving integration_test after native tests.
    & (Join-Path $PSScriptRoot 'flutter.ps1') build apk --release --split-per-abi --target-platform 'android-arm,android-arm64,android-x64'
    if ($LASTEXITCODE -ne 0) { throw 'Compilation APK par architecture echouee.' }
    if (-not $SkipUniversal) {
        & (Join-Path $PSScriptRoot 'flutter.ps1') build apk --release --target-platform 'android-arm,android-arm64,android-x64'
        if ($LASTEXITCODE -ne 0) { throw 'Compilation APK universelle echouee.' }
    }
} finally {
    $env:NOVA_ANDROID_STORE_PASSWORD = $null
    [Array]::Clear($passwordBytes, 0, $passwordBytes.Length)
}
