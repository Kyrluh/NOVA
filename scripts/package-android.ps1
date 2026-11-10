param([switch]$Television)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'android-env.ps1')

# This script only inspects and packages existing APKs. It does not build,
# sign, install, upload or read the private signing key/password.
$expectedPackage = if ($Television) { 'app.nova.iptv.tv' } else { 'app.nova.iptv' }
$versionText = Get-Content -LiteralPath (Join-Path $novaRoot 'pubspec.yaml') -Raw
if ($versionText -notmatch '(?m)^version:\s*([0-9.]+)\+(\d+)\s*$') { throw 'Version pubspec introuvable.' }
$expectedVersion = $Matches[1]
$expectedVersionCode = [int]$Matches[2]
$expectedMinSdk = 24
$expectedTargetSdk = 36
$projectDirectory = [IO.Path]::GetFullPath($novaRoot).TrimEnd('\')
$outputDirectory = Join-Path $projectDirectory $(if ($Television) { 'dist\android-tv' } else { 'dist\android' })

function Invoke-NovaCheckedTool {
    param([string]$Tool, [string[]]$ToolArguments, [string]$Label)
    $previousPreference = $ErrorActionPreference
    try {
        # Native stderr is captured for diagnostics; its exit code decides
        # success. This also works on Windows PowerShell 5.1.
        $ErrorActionPreference = 'Continue'
        $toolOutput = @(& $Tool @ToolArguments 2>&1)
        $toolExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    $outputText = ($toolOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    if ($toolExitCode -ne 0) {
        throw "$Label a echoue (code $toolExitCode).`n$outputText"
    }
    return $outputText
}

function Get-NovaApkCertificate {
    param([string]$ApkPath)
    $signature = Invoke-NovaCheckedTool -Tool $script:apkSigner -ToolArguments @(
        'verify', '--verbose', '--print-certs', $ApkPath
    ) -Label 'Verification de signature APK'
    $digests = [regex]::Matches($signature, '(?m)^Signer #\d+ certificate SHA-256 digest:\s*([0-9a-fA-F:]+)\s*$')
    $subjects = [regex]::Matches($signature, '(?m)^Signer #\d+ certificate DN:\s*(.+)\r?$')
    if ($digests.Count -ne 1 -or $subjects.Count -ne 1) {
        throw 'L''APK doit avoir exactement un certificat de signature identifiable.'
    }
    $certificate = $digests[0].Groups[1].Value.Replace(':', '').ToLowerInvariant()
    $subject = $subjects[0].Groups[1].Value.Trim()
    if ($certificate -notmatch '^[0-9a-f]{64}$') { throw 'Empreinte SHA-256 du certificat invalide.' }
    if ($subject -match '(?i)android\s*debug' -or $subject -notmatch '(?i)(?:^|,\s*)CN=NOVA IPTV(?:,|$)') {
        throw 'Le certificat ne correspond pas a la signature de production NOVA IPTV.'
    }
    if ($signature -notmatch '(?m)^Verified using v[23](?:\.\d+)? scheme.*:\s*true\s*$') {
        throw 'Une signature APK moderne v2 ou v3 est requise.'
    }
    return $certificate
}

function Get-NovaApkMetadata {
    param([string]$ApkPath, [string]$Architecture)
    $certificate = Get-NovaApkCertificate -ApkPath $ApkPath
    $badging = Invoke-NovaCheckedTool -Tool $script:aapt -ToolArguments @(
        'dump', 'badging', $ApkPath
    ) -Label 'Inspection du manifeste APK'
    $packageLine = [regex]::Match($badging, '(?m)^package:.*$').Value
    $packageName = [regex]::Match($packageLine, "\bname='([^']+)'").Groups[1].Value
    $versionName = [regex]::Match($packageLine, "\bversionName='([^']+)'").Groups[1].Value
    $versionCode = [regex]::Match($packageLine, "\bversionCode='([^']+)'").Groups[1].Value
    $minimumSdk = [regex]::Match($badging, "(?m)^sdkVersion:'(\d+)'\s*$").Groups[1].Value
    $targetSdk = [regex]::Match($badging, "(?m)^targetSdkVersion:'(\d+)'\s*$").Groups[1].Value
    if ($packageName -ne $script:expectedPackage -or $versionName -ne $script:expectedVersion -or
        $versionCode -ne [string]$script:expectedVersionCode) {
        throw "Version ou application inattendue dans $ApkPath. Attendu : $script:expectedPackage $script:expectedVersion+$script:expectedVersionCode."
    }
    if ($minimumSdk -ne [string]$script:expectedMinSdk -or $targetSdk -ne [string]$script:expectedTargetSdk) {
        throw "SDK inattendus dans $ApkPath. Attendu : minimum $script:expectedMinSdk, cible $script:expectedTargetSdk."
    }
    if ($badging -match '(?m)^application-debuggable(?:\s|$)') {
        throw 'Une APK debuggable ne peut pas etre livree comme version Release.'
    }
    if ($script:Television -and ($badging -notmatch 'leanback-launchable-activity:' -or $badging -notmatch "uses-feature-not-required: name='android.hardware.touchscreen'")) {
        throw 'Le manifeste TV doit declarer le lanceur Leanback et ne pas exiger un ecran tactile.'
    }
    $nativeLine = [regex]::Match($badging, '(?m)^native-code:.*$').Value
    $abis = @([regex]::Matches($nativeLine, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
    if ($Architecture -eq 'arm64-v8a') {
        if ($abis.Count -ne 1 -or $abis[0] -ne 'arm64-v8a') { throw 'L''APK ARM64 doit contenir uniquement arm64-v8a.' }
    } elseif ($Architecture -eq 'universal') {
        foreach ($requiredAbi in @('armeabi-v7a', 'arm64-v8a', 'x86_64')) {
            if ($abis -notcontains $requiredAbi) { throw "Architecture $requiredAbi absente de l'APK universelle." }
        }
    } else { throw 'Architecture de livraison inconnue.' }
    $null = Invoke-NovaCheckedTool -Tool $script:zipAlign -ToolArguments @(
        '-c', '-P', '16', '4', $ApkPath
    ) -Label 'Verification de l''alignement ZIP 16 KiB'
    return [pscustomobject]@{
        Architecture = $Architecture
        Package = $packageName
        VersionName = $versionName
        VersionCode = [int]$versionCode
        MinimumSdk = [int]$minimumSdk
        TargetSdk = [int]$targetSdk
        Abis = $abis
        CertificateSha256 = $certificate
        ZipAlignment16KiB = $true
    }
}

$buildToolsRoot = Join-Path $env:ANDROID_HOME 'build-tools'
$buildTools = Get-ChildItem -LiteralPath $buildToolsRoot -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
    Sort-Object { [version]$_.Name } -Descending |
    Where-Object {
        (Test-Path -LiteralPath (Join-Path $_.FullName 'apksigner.bat')) -and
        (Test-Path -LiteralPath (Join-Path $_.FullName 'aapt.exe')) -and
        (Test-Path -LiteralPath (Join-Path $_.FullName 'zipalign.exe'))
    } | Select-Object -First 1
if (-not $buildTools) { throw 'Android Build Tools complets introuvables. Executer bootstrap-android.ps1.' }
$apkSigner = Join-Path $buildTools.FullName 'apksigner.bat'
$aapt = Join-Path $buildTools.FullName 'aapt.exe'
$zipAlign = Join-Path $buildTools.FullName 'zipalign.exe'
$apkSpecs = @(
    @{ Architecture = 'arm64-v8a'; Source = 'app-arm64-v8a-release.apk' },
    @{ Architecture = 'universal'; Source = 'app-release.apk' }
)
if ($Television) { $apkSpecs = @(@{ Architecture = 'universal'; Source = 'app-release.apk' }) }
$apkDirectory = Join-Path $projectDirectory 'build\app\outputs\flutter-apk'
$verified = @()
foreach ($spec in $apkSpecs) {
    $sourcePath = Join-Path $apkDirectory $spec.Source
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "APK manquante : $sourcePath. Executer build-android.ps1 sans -SkipUniversal."
    }
    $resolvedSource = (Resolve-Path -LiteralPath $sourcePath).Path
    if (-not $resolvedSource.StartsWith($projectDirectory + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'La source APK doit rester dans le projet.'
    }
    $metadata = Get-NovaApkMetadata -ApkPath $resolvedSource -Architecture $spec.Architecture
    $verified += [pscustomobject]@{
        Source = $resolvedSource
        Name = $(if ($Television) { "NOVA-IPTV-TV-$expectedVersion-universal.apk" } else { "NOVA-IPTV-$expectedVersion-$($spec.Architecture).apk" })
        Hash = (Get-FileHash -LiteralPath $resolvedSource -Algorithm SHA256).Hash.ToLowerInvariant()
        Metadata = $metadata
    }
}
if ($verified.Count -gt 1 -and $verified[0].Metadata.CertificateSha256 -ne $verified[1].Metadata.CertificateSha256) {
    throw 'Les APK ARM64 et universelle ne portent pas le meme certificat de production.'
}

# Verify every input before writing any release artifact. Existing deliverables
# can only be replaced by an APK carrying the same production certificate.
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$resolvedOutput = (Resolve-Path -LiteralPath $outputDirectory).Path
if (-not $resolvedOutput.StartsWith($projectDirectory + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'La destination de livraison doit rester dans le projet.'
}
foreach ($apk in $verified) {
    $destination = Join-Path $resolvedOutput $apk.Name
    if (Test-Path -LiteralPath $destination -PathType Leaf) {
        if ((Get-NovaApkCertificate -ApkPath $destination) -ne $apk.Metadata.CertificateSha256) {
            throw 'Une APK existante utilise une autre signature. La livraison ne sera pas remplacee.'
        }
    }
}
foreach ($apk in $verified) {
    $destination = Join-Path $resolvedOutput $apk.Name
    Copy-Item -LiteralPath $apk.Source -Destination $destination -Force
    if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -ne $apk.Hash) {
        throw "Copie APK non conforme : $destination"
    }
}
$verified | ForEach-Object { "$($_.Hash)  $($_.Name)" } |
    Set-Content -LiteralPath (Join-Path $resolvedOutput 'SHA256SUMS.txt') -Encoding ASCII
$releaseMetadata = [ordered]@{
    Package = $expectedPackage
    Version = $expectedVersion
    VersionCode = $expectedVersionCode
    CertificateSha256 = $verified[0].Metadata.CertificateSha256
    Apks = @($verified | ForEach-Object {
        [ordered]@{ File = $_.Name; Sha256 = $_.Hash; Abis = $_.Metadata.Abis;
            MinimumSdk = $_.Metadata.MinimumSdk; TargetSdk = $_.Metadata.TargetSdk;
            ZipAlignment16KiB = $_.Metadata.ZipAlignment16KiB }
    })
}
$releaseMetadata | ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath (Join-Path $resolvedOutput 'release-metadata.json') -Encoding UTF8
Write-Output "PASS : APK verifiees pour $expectedPackage, version $expectedVersion+$expectedVersionCode."
Write-Output 'PASS : minSdk 24, targetSdk 36, alignement ZIP 16 KiB et empreintes SHA-256 verifies.'
Write-Output "Livraison Android : $resolvedOutput"
