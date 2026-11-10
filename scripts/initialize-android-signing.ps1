$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'android-env.ps1')
$signingDirectory = Join-Path $novaRoot '.signing'
$keyPath = Join-Path $signingDirectory 'nova-android-release.p12'
$passwordPath = Join-Path $signingDirectory 'password.dpapi'
New-Item -ItemType Directory -Path $signingDirectory -Force | Out-Null
if (Test-Path -LiteralPath $keyPath) {
    if (-not (Test-Path -LiteralPath $passwordPath)) { throw 'Cle presente mais mot de passe protege absent. Ne pas remplacer la cle.' }
    Write-Output 'Signature NOVA existante conservee.'
    exit 0
}
Add-Type -AssemblyName System.Security
$random = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($random)
$password = [Convert]::ToBase64String($random)
$env:NOVA_ANDROID_STORE_PASSWORD = $password
try {
    & (Join-Path $env:JAVA_HOME 'bin\keytool.exe') -genkeypair -keystore $keyPath -storetype PKCS12 -alias nova-android -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=NOVA IPTV, OU=Android, O=NOVA IPTV' -storepass:env NOVA_ANDROID_STORE_PASSWORD -keypass:env NOVA_ANDROID_STORE_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Creation de la cle de signature echouee.' }
    $protected = [Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::UTF8.GetBytes($password), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    [IO.File]::WriteAllBytes($passwordPath, $protected)
    Write-Output 'Signature de production creee ; mot de passe protege par le compte Windows courant.'
} finally {
    $env:NOVA_ANDROID_STORE_PASSWORD = $null
    [Array]::Clear($random, 0, $random.Length)
    $password = $null
}
