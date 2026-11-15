$ErrorActionPreference = 'Stop'
$novaRoot = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.Drawing
$original = [Drawing.Image]::FromFile((Join-Path $novaRoot 'assets/branding/nova-popcorn.png'))
function Resize-NovaIcon([int]$pixels) {
    $bitmap = New-Object Drawing.Bitmap $pixels, $pixels
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([Drawing.Color]::Transparent)
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($original, 0, 0, $pixels, $pixels)
    } finally { $graphics.Dispose() }
    return $bitmap
}
try {
    foreach ($entry in @(@('mdpi',48),@('hdpi',72),@('xhdpi',96),@('xxhdpi',144),@('xxxhdpi',192))) {
        $target = Join-Path $novaRoot ('android/app/src/main/res/mipmap-' + $entry[0] + '/ic_launcher.png')
        $icon = Resize-NovaIcon $entry[1]
        try { $icon.Save($target, [Drawing.Imaging.ImageFormat]::Png) } finally { $icon.Dispose() }
    }
    $drawableFolder = Join-Path $novaRoot 'android/app/src/main/res/drawable-nodpi'
    New-Item -ItemType Directory -Force $drawableFolder | Out-Null
    $icon = Resize-NovaIcon 256
    try { $icon.Save((Join-Path $drawableFolder 'nova_logo.png'), [Drawing.Imaging.ImageFormat]::Png) } finally { $icon.Dispose() }
    $sizes = @(16,24,32,48,64,128,256)
    $pngs = @()
    foreach ($size in $sizes) {
        $icon = Resize-NovaIcon $size
        $stream = New-Object IO.MemoryStream
        try {
            $icon.Save($stream, [Drawing.Imaging.ImageFormat]::Png)
            $pngs += ,$stream.ToArray()
        } finally { $stream.Dispose(); $icon.Dispose() }
    }
    $file = [IO.File]::Create((Join-Path $novaRoot 'windows/runner/resources/app_icon.ico'))
    $writer = New-Object IO.BinaryWriter $file
    try {
        $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
        $offset = 6 + 16 * $sizes.Count
        for ($index=0; $index -lt $sizes.Count; $index++) {
            $dimension = if ($sizes[$index] -eq 256) { 0 } else { $sizes[$index] }
            $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
            $writer.Write([byte]0); $writer.Write([byte]0)
            $writer.Write([uint16]1); $writer.Write([uint16]32)
            $writer.Write([uint32]$pngs[$index].Length); $writer.Write([uint32]$offset)
            $offset += $pngs[$index].Length
        }
        foreach ($png in $pngs) { $writer.Write([byte[]]$png) }
    } finally { $writer.Dispose(); $file.Dispose() }
} finally { $original.Dispose() }
Write-Output 'Icônes NOVA Windows et Android mises à jour.'
