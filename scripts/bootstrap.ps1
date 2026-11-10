param([switch]$Precache)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolsRoot = Join-Path $projectRoot '.tools'
New-Item -ItemType Directory -Path $toolsRoot -Force | Out-Null
$gitExe = Join-Path $toolsRoot 'mingit\cmd\git.exe'
if (-not (Test-Path -LiteralPath $gitExe)) {
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/git-for-windows/git/releases/latest'
    $asset = $release.assets | Where-Object { $_.name -match '^MinGit-[0-9.]+-64-bit.zip$' } | Select-Object -First 1
    if (-not $asset) { throw 'Archive officielle MinGit introuvable.' }
    $archive = Join-Path $toolsRoot 'mingit.zip'
    curl.exe --fail --location --silent --show-error $asset.browser_download_url --output $archive
    if ($LASTEXITCODE -ne 0) { throw 'Téléchargement de MinGit échoué.' }
    Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $toolsRoot 'mingit') -Force
}
$env:PATH = "$(Join-Path $toolsRoot 'mingit\cmd');$env:PATH"
$env:PUB_CACHE = Join-Path $toolsRoot 'pub-cache'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:CI = 'true'
$flutterRoot = Join-Path $toolsRoot 'flutter'
if (-not (Test-Path -LiteralPath (Join-Path $flutterRoot 'bin\flutter.bat'))) {
    & $gitExe clone --depth 1 --branch 3.47.9 https://github.com/flutter/flutter.git $flutterRoot
    if ($LASTEXITCODE -ne 0) { throw 'Téléchargement Flutter échoué.' }
}
& (Join-Path $flutterRoot 'bin\flutter.bat') --version
if ($LASTEXITCODE -ne 0) { throw 'Initialisation Flutter échouée.' }
& (Join-Path $flutterRoot 'bin\flutter.bat') config --no-analytics --enable-windows-desktop
if ($Precache) { & (Join-Path $flutterRoot 'bin\flutter.bat') precache --windows }
