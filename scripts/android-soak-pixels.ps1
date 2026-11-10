param(
    [string]$Device = 'emulator-5556',
    [int]$WaitSeconds = 600
)
$ErrorActionPreference = 'Stop'
if ($Device -notmatch '^emulator-[0-9]+$') { throw 'This observer supports only a disposable emulator.' }
$projectRoot = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $projectRoot '.tools\android-sdk\platform-tools\adb.exe'
$baseUrl = 'http://127.0.0.1:18758'
$reportPath = Join-Path $projectRoot '.tools\android-soak-pixel-check.json'
$captures = @()
Add-Type -AssemblyName System.Drawing
function Invoke-Adb([string[]]$Arguments) {
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = (& $adb -s $Device @Arguments 2>&1 | Out-String).Trim()
        $nativeExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $oldPreference }
    if ($nativeExit -ne 0) { throw $output }
    return $output
}
function Capture-Video([object]$State, [string]$Name) {
    $box = $State.videoContentPixels
    if ($null -eq $box) { throw 'The actual video-content rectangle is unavailable.' }
    $path = Join-Path $projectRoot ('.tools\' + $Name + '.png')
    $remote = '/sdcard/' + $Name + '.png'
    Invoke-Adb @('shell','screencap','-p',$remote) | Out-Null
    Invoke-Adb @('pull',$remote,$path) | Out-Null
    $bitmap = New-Object System.Drawing.Bitmap $path
    try {
        $marginX = ($box.right - $box.left) * 0.12
        $marginY = ($box.bottom - $box.top) * 0.12
        $left = [Math]::Max(0, [int]($box.left + $marginX))
        $right = [Math]::Min($bitmap.Width - 1, [int]($box.right - $marginX))
        $top = [Math]::Max(0, [int]($box.top + $marginY))
        $bottom = [Math]::Min($bitmap.Height - 1, [int]($box.bottom - $marginY))
        if ($right - $left -lt 16 -or $bottom - $top -lt 16) { throw 'The video content is outside the screenshot.' }
        $colored = 0
        $samples = 0
        $bins = New-Object 'System.Collections.Generic.HashSet[string]'
        for ($row = 0; $row -lt 15; $row++) {
            for ($column = 0; $column -lt 15; $column++) {
                $x = $left + [int](($right - $left) * ($column + 0.5) / 15)
                $y = $top + [int](($bottom - $top) * ($row + 0.5) / 15)
                $pixel = $bitmap.GetPixel($x, $y)
                $maximum = [Math]::Max([int]$pixel.R, [Math]::Max([int]$pixel.G, [int]$pixel.B))
                $minimum = [Math]::Min([int]$pixel.R, [Math]::Min([int]$pixel.G, [int]$pixel.B))
                if ($maximum -ge 55 -and $maximum - $minimum -ge 30) {
                    $colored++
                    $bins.Add(('{0},{1},{2}' -f ([int]($pixel.R / 32)), ([int]($pixel.G / 32)), ([int]($pixel.B / 32)))) | Out-Null
                }
                $samples++
            }
        }
        $ratio = $colored / [double]$samples
        $check = @{name=$Name; passed=($ratio -ge 0.12 -and $bins.Count -ge 5);
            coloredSamples=$colored; totalSamples=$samples; distinctColorBins=$bins.Count;
            coloredRatio=$ratio; mediaPositionMs=$State.positionMs; openCount=$State.openCount;
            playing=$State.playing; phase=$State.phase; native=$State.native;
            crop=@{left=$left; top=$top; right=$right; bottom=$bottom}}
        if (-not $check.passed -or $State.openCount -ne 1 -or -not $State.playing) {
            throw ('The soak video is not visibly playing: chroma=' + $ratio + ', opens=' + $State.openCount)
        }
        return $check
    } finally { $bitmap.Dispose() }
}
$failure = $null
Invoke-Adb @('forward','tcp:18758','tcp:18757') | Out-Null
try {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $targets = @(180000, 240000)
    $next = 0
    while ($next -lt $targets.Count -and $watch.Elapsed.TotalSeconds -lt $WaitSeconds) {
        $state = $null
        try { $state = Invoke-RestMethod -Uri ($baseUrl + '/status') -TimeoutSec 3 } catch {}
        if ($null -ne $state -and $state.phase -eq 'native-transitions-complete' -and $state.positionMs -gt $targets[$next]) {
            $check = Capture-Video $state ('android-soak-' + [int]($targets[$next] / 1000) + 's')
            $captures += $check
            @{passed=($captures.Count -eq $targets.Count); captures=$captures; failure=$null} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportPath -Encoding UTF8
            Write-Host ('PASS: soak pixels position=' + $state.positionMs + 'ms, chroma=' + [Math]::Round($check.coloredRatio,3))
            $next++
        }
        if ($next -lt $targets.Count) { Start-Sleep -Milliseconds 1500 }
    }
    if ($next -ne $targets.Count) { throw 'The completed-transitions soak did not reach both capture positions.' }
} catch {
    $failure = $_.Exception.Message
    throw
} finally {
    @{passed=($null -eq $failure -and $captures.Count -eq 2); captures=$captures; failure=$failure} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Invoke-Adb @('forward','--remove','tcp:18758') | Out-Null
}
