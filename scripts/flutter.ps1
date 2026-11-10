# Keep Flutter flags verbatim; advanced binding consumes --debug/--verbose.
$FlutterArgs = $args
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (Test-Path -LiteralPath (Join-Path $projectRoot '.tools\android-sdk\platform-tools')) {
    . (Join-Path $PSScriptRoot 'android-env.ps1')
}
$env:PATH = "$(Join-Path $projectRoot '.tools\mingit\cmd');$env:PATH"
$env:PUB_CACHE = Join-Path $projectRoot '.tools\pub-cache'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:CI = 'true'
Set-Location -LiteralPath $projectRoot
$flutter = Join-Path $projectRoot '.tools\flutter\bin\flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) { throw 'Exécutez d''abord scripts/bootstrap.ps1.' }
& $flutter @FlutterArgs
exit $LASTEXITCODE
