param([Parameter(ValueFromRemainingArguments = $true)][string[]]$DartArgs)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$env:PATH = "$(Join-Path $projectRoot '.tools\mingit\cmd');$env:PATH"
$env:PUB_CACHE = Join-Path $projectRoot '.tools\pub-cache'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:CI = 'true'
Set-Location -LiteralPath $projectRoot
& (Join-Path $projectRoot '.tools\flutter\bin\dart.bat') @DartArgs
exit $LASTEXITCODE
