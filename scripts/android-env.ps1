$ErrorActionPreference = 'Stop'
$novaRoot = Split-Path -Parent $PSScriptRoot
$env:ANDROID_HOME = Join-Path $novaRoot '.tools\android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_USER_HOME = Join-Path $novaRoot '.tools\android-user'
$env:ANDROID_AVD_HOME = Join-Path $novaRoot '.tools\avd'
$env:GRADLE_USER_HOME = Join-Path $novaRoot '.tools\gradle-cache'
$novaJdk = Get-ChildItem -LiteralPath (Join-Path $novaRoot '.tools\jdk') -Directory | Select-Object -First 1
if (-not $novaJdk) { throw 'JDK local introuvable.' }
$env:JAVA_HOME = $novaJdk.FullName
$env:DEBUG = $null
$env:PATH = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\emulator;$env:PATH"
foreach ($directory in @($env:ANDROID_USER_HOME, $env:ANDROID_AVD_HOME, $env:GRADLE_USER_HOME)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}
