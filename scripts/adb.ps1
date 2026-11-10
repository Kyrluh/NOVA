$AdbArgs = $args
. (Join-Path $PSScriptRoot 'android-env.ps1')
& (Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe') @AdbArgs
exit $LASTEXITCODE
