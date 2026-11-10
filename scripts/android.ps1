param([Parameter(ValueFromRemainingArguments = $true)][string[]]$AndroidArgs)
. (Join-Path $PSScriptRoot 'android-env.ps1')
& (Join-Path $env:ANDROID_HOME 'cmdline-tools\latest\bin\android.exe') --no-metrics --sdk=$env:ANDROID_HOME @AndroidArgs
exit $LASTEXITCODE
