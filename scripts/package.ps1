$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$versionLine = Get-Content -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') | Where-Object { $_ -match '^version:\s*(\S+)' } | Select-Object -First 1
if ($versionLine -notmatch '^version:\s*([^+\s]+)') { throw 'Version pubspec introuvable.' }
$novaVersion = $Matches[1]
$releaseRoot = Join-Path $projectRoot 'build\windows\x64\runner\Release'
if (-not (Test-Path -LiteralPath (Join-Path $releaseRoot 'NOVA_IPTV.exe'))) { throw 'Compilez la version Release avant le packaging.' }
$distRoot = Join-Path $projectRoot 'dist'
$portable = Join-Path $distRoot "NOVA-IPTV-$novaVersion-windows-x64"
New-Item -ItemType Directory -Path $portable -Force | Out-Null
Get-ChildItem -LiteralPath $releaseRoot | Where-Object { $_.Name -ne 'integration_test_plugin.dll' } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $portable -Recurse -Force
}
foreach ($name in @('README.md','LICENSE','THIRD_PARTY_NOTICES.md')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $portable -Force
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'licenses') -Destination $portable -Recurse -Force
# App-local CRT deployment, using the redistributable files shipped by VS.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (Test-Path -LiteralPath $vswhere) {
    $vsRoot = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($vsRoot) {
        $redistRoot = Join-Path $vsRoot 'VC\Redist\MSVC'
        $versions = Get-ChildItem -LiteralPath $redistRoot -Directory | Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } | Sort-Object Name -Descending
        foreach ($version in $versions) {
            $crt = Join-Path $version.FullName 'x64\Microsoft.VC143.CRT'
            if (-not (Test-Path -LiteralPath $crt)) { continue }
            foreach ($dll in @('msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll')) {
                Copy-Item -LiteralPath (Join-Path $crt $dll) -Destination $portable -Force
            }
            break
        }
    }
}
$archive = Join-Path $distRoot "NOVA-IPTV-$novaVersion-windows-x64.zip"
Compress-Archive -LiteralPath $portable -DestinationPath $archive -Force
$sourceArchive = Join-Path $distRoot "NOVA-IPTV-$novaVersion-source.zip"
$sourcePaths = @('lib','assets','test','integration_test','tool','windows','android','scripts','docs','licenses','pubspec.yaml','pubspec.lock','analysis_options.yaml','README.md','LICENSE','THIRD_PARTY_NOTICES.md','.metadata','.gitignore')
# Explicit file list keeps SDK/cache/build output and plugin symlinks out of sources.
$files = foreach ($name in $sourcePaths) {
    $path = Join-Path $projectRoot $name
    if (Test-Path -LiteralPath $path -PathType Container) {
        Get-ChildItem -LiteralPath $path -File -Recurse | Where-Object {
            $_.FullName -notmatch '\\(ephemeral|\.gradle|\.kotlin|\.cxx|build|\.signing)\\' -and
            $_.Name -notin @('local.properties','key.properties','GeneratedPluginRegistrant.java') -and
            $_.Extension -notin @('.jks','.keystore','.p12','.dpapi')
        }
    } elseif (Test-Path -LiteralPath $path) { Get-Item -LiteralPath $path }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = [System.IO.File]::Open($sourceArchive, [System.IO.FileMode]::Create)
$zip = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($projectRoot.Length + 1).Replace([System.IO.Path]::DirectorySeparatorChar, [char]'/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $relative) | Out-Null
    }
} finally { $zip.Dispose(); $stream.Dispose() }
Get-FileHash -LiteralPath $archive,$sourceArchive -Algorithm SHA256 | ForEach-Object {
    "$($_.Hash.ToLowerInvariant())  $([System.IO.Path]::GetFileName($_.Path))"
} | Set-Content -LiteralPath (Join-Path $distRoot "SHA256SUMS-$novaVersion.txt") -Encoding ASCII
Write-Output "Dossier portable : $portable"
Write-Output "Archive portable : $archive"
Write-Output "Sources NOVA : $sourceArchive"
