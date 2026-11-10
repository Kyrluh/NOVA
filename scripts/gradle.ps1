param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GradleArgs)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'android-env.ps1')
$env:DEBUG = $null
$sdkValue = $env:ANDROID_HOME.Replace('\', '\\')
$flutterValue = (Join-Path $novaRoot '.tools\flutter').Replace('\', '\\')
@("sdk.dir=$sdkValue", "flutter.sdk=$flutterValue") | Set-Content -LiteralPath (Join-Path $novaRoot 'android\local.properties') -Encoding ASCII
& (Join-Path $novaRoot 'android\gradlew.bat') --project-dir (Join-Path $novaRoot 'android') @GradleArgs
exit $LASTEXITCODE
