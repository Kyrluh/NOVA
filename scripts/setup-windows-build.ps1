$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $projectRoot '.tools\vs_BuildTools.exe'
curl.exe --fail --location --silent --show-error 'https://aka.ms/vs/17/release/vs_BuildTools.exe' --output $installer
if ($LASTEXITCODE -ne 0) { throw 'Téléchargement des outils Microsoft échoué.' }
$signature = Get-AuthenticodeSignature -LiteralPath $installer
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') {
    throw 'La signature Microsoft de l''installateur est invalide.'
}
$arguments = '--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.VC.CMake.Project --add Microsoft.VisualStudio.Component.Windows11SDK.26100'
$process = Start-Process -FilePath $installer -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -notin @(0, 3010)) { throw "Installation Microsoft : code $($process.ExitCode)." }
Write-Output "Outils C++ installés (code $($process.ExitCode))."
