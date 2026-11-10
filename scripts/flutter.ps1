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
# Release-only provider presets stay outside Git and command-line secret values.
$novaPresets = Join-Path $projectRoot '.signing\provider-presets.json'
if ($FlutterArgs.Count -gt 0 -and $FlutterArgs[0] -eq 'build' -and (Test-Path -LiteralPath $novaPresets)) {
    $FlutterArgs += "--dart-define-from-file=$novaPresets"
}
& $flutter @FlutterArgs
exit $LASTEXITCODE
