param(
    [ValidateSet('Export','Restore')][string]$Mode = 'Export',
    [string]$BackupPath
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'android-env.ps1')
Add-Type -AssemblyName System.Security
$signingRoot = Join-Path $novaRoot '.signing'
$keyPath = Join-Path $signingRoot 'nova-android-release.p12'
$protectedPath = Join-Path $signingRoot 'password.dpapi'
if (-not $BackupPath) { $BackupPath = Join-Path $signingRoot 'nova-android-portable-backup.p12' }
if ($Mode -eq 'Export' -and (Test-Path -LiteralPath $BackupPath)) { throw 'La sauvegarde existe deja. Choisir un autre chemin pour ne pas la remplacer.' }
if ($Mode -eq 'Restore' -and (Test-Path -LiteralPath $keyPath)) { throw 'Une signature de production existe deja. Elle ne sera pas remplacee.' }
$secure = Read-Host 'Mot de passe de la sauvegarde portable (12 caracteres minimum)' -AsSecureString
if ($secure.Length -lt 12) { throw 'Utiliser au moins 12 caracteres.' }
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
$currentBytes = $null
try {
    $backupPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $env:NOVA_BACKUP_PASSWORD = $backupPassword
    if ($Mode -eq 'Export') {
        $currentBytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($protectedPath), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        $env:NOVA_ANDROID_STORE_PASSWORD = [Text.Encoding]::UTF8.GetString($currentBytes)
        & (Join-Path $env:JAVA_HOME 'bin\keytool.exe') -importkeystore -srckeystore $keyPath -srcstoretype PKCS12 -srcstorepass:env NOVA_ANDROID_STORE_PASSWORD -srckeypass:env NOVA_ANDROID_STORE_PASSWORD -srcalias nova-android -destkeystore $BackupPath -deststoretype PKCS12 -deststorepass:env NOVA_BACKUP_PASSWORD -destkeypass:env NOVA_BACKUP_PASSWORD -destalias nova-android -noprompt
        if ($LASTEXITCODE -ne 0) { throw 'Export de signature echoue.' }
        Write-Output 'Sauvegarde de la meme signature creee avec le mot de passe choisi. La conserver en lieu prive, hors Git.'
    } else {
        & (Join-Path $env:JAVA_HOME 'bin\keytool.exe') -list -keystore $BackupPath -storetype PKCS12 -storepass:env NOVA_BACKUP_PASSWORD -alias nova-android
        if ($LASTEXITCODE -ne 0) { throw 'Sauvegarde ou mot de passe invalide.' }
        New-Item -ItemType Directory -Path $signingRoot -Force | Out-Null
        Copy-Item -LiteralPath $BackupPath -Destination $keyPath
        $protected = [Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::UTF8.GetBytes($backupPassword), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        [IO.File]::WriteAllBytes($protectedPath, $protected)
        Write-Output 'Signature restauree pour le compte Windows courant ; les futures APK peuvent mettre a jour les installations existantes.'
    }
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    $env:NOVA_BACKUP_PASSWORD = $null
    $env:NOVA_ANDROID_STORE_PASSWORD = $null
    $backupPassword = $null
    if ($currentBytes) { [Array]::Clear($currentBytes, 0, $currentBytes.Length) }
}
