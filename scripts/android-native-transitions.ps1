param(
    [string]$Device = 'emulator-5556',
    [string]$ApplicationId = 'app.nova.iptv.debug',
    [int]$WaitSeconds = 300
)
$ErrorActionPreference = 'Stop'
if ($Device -notmatch '^emulator-[0-9]+$') { throw 'This helper changes only a disposable emulator.' }
$projectRoot = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $projectRoot '.tools\android-sdk\platform-tools\adb.exe'
$baseUrl = 'http://127.0.0.1:18757'
$events = @()
$failure = $null
$ready = $false
$transitionHandshake = $false
$captures = @()
$splitTaskId = $null
Add-Type -AssemblyName System.Drawing
function Invoke-Adb([string[]]$Arguments) {
    $previousPreference = $ErrorActionPreference
    try {
        # adb screencap may warn on stderr while succeeding on foldable AVDs.
        # Judge native execution by its exit code, not PowerShell stream routing.
        $ErrorActionPreference = 'Continue'
        $output = (& $adb -s $Device @Arguments 2>&1 | Out-String).Trim()
        $nativeExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($nativeExit -ne 0 -or $output -match '(?m)^KO:') { throw $output }
    return $output
}
function Get-State {
    Invoke-RestMethod -Uri ($baseUrl + '/status') -TimeoutSec 5
}
function Record-State([string]$Name) {
    Start-Sleep -Milliseconds 1000
    $state = Get-State
    $script:events += [pscustomobject]@{name=$Name; state=$state}
    Write-Output ("PASS: " + $Name + ', activity=' + $state.native.activityInstance + ', sizeDp=' + $state.native.widthDp + 'x' + $state.native.heightDp)
}
function Capture-Video([string]$Name) {
    $state = Get-State
    $box = $state.videoContentPixels
    if ($null -eq $box) { throw 'The Flutter video-content rectangle is unavailable.' }
    $imagePath = Join-Path $projectRoot ('.tools\' + $Name + '.png')
    $devicePath = '/sdcard/' + $Name + '.png'
    Invoke-Adb @('shell','screencap','-p',$devicePath) | Out-Null
    Invoke-Adb @('pull',$devicePath,$imagePath) | Out-Null
    $bitmap = New-Object System.Drawing.Bitmap $imagePath
    try {
        # Sample inside the exact 16:9 picture, excluding HUD, white app borders,
        # subtitle edges and system bars. Grey/white UI cannot satisfy chroma.
        $marginX = ($box.right - $box.left) * 0.12
        $marginY = ($box.bottom - $box.top) * 0.12
        $left = [Math]::Max(0, [int]($box.left + $marginX))
        $right = [Math]::Min($bitmap.Width - 1, [int]($box.right - $marginX))
        $top = [Math]::Max(0, [int]($box.top + $marginY))
        $bottom = [Math]::Min($bitmap.Height - 1, [int]($box.bottom - $marginY))
        if ($right - $left -lt 16 -or $bottom - $top -lt 16) { throw 'The video picture is outside the screenshot.' }
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
            coloredRatio=$ratio; crop=@{left=$left; top=$top; right=$right; bottom=$bottom}}
        $script:captures += $check
        $script:captures | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $projectRoot '.tools\android-pixel-checks.json') -Encoding UTF8
        if (-not $check.passed) { throw ('The generated test pattern is not visible in ' + $Name + ': chroma ratio=' + $ratio) }
        Write-Host ('PASS: colored video pixels visible in ' + $Name + ', ratio=' + [Math]::Round($ratio, 3))
        return $check
    } finally { $bitmap.Dispose() }
}
$originalSize = Invoke-Adb @('shell','wm','size')
$originalDensity = Invoke-Adb @('shell','wm','density')
$originalAutoRotate = Invoke-Adb @('shell','settings','get','system','accelerometer_rotation')
$originalRotation = Invoke-Adb @('shell','settings','get','system','user_rotation')
$originalSizeOverride = [regex]::Match($originalSize, 'Override size:\s*(\d+x\d+)').Groups[1].Value
$originalDensityOverride = [regex]::Match($originalDensity, 'Override density:\s*(\d+)').Groups[1].Value
Invoke-Adb @('forward','tcp:18757','tcp:18757') | Out-Null
try {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do {
        try {
            $state = Get-State
            $ready = @('waiting-initial-capture','waiting-native-transitions') -contains $state.phase
        } catch { $ready = $false }
        if (-not $ready) { Start-Sleep -Milliseconds 500 }
    } while (-not $ready -and $watch.Elapsed.TotalSeconds -lt $WaitSeconds)
    if (-not $ready) { throw 'Playback handshake not reached. Run android_full_test.dart with NOVA_FOLD_HANDSHAKE=true.' }
    if ($state.phase -eq 'waiting-initial-capture') {
        $initial = @{passed=$false}
        try {
            $initial.pixelCheck = Capture-Video 'android-video-initial'
            $initial.passed = $true
        } catch { $initial.failure = $_.Exception.Message }
        Invoke-RestMethod -Uri ($baseUrl + '/initial-captured') -Method Post -ContentType 'application/json' -Body ($initial | ConvertTo-Json -Depth 8) -TimeoutSec 8 | Out-Null
        if (-not $initial.passed) { throw $initial.failure }
        $resizeWatch = [Diagnostics.Stopwatch]::StartNew()
        do { Start-Sleep -Milliseconds 200; $state = Get-State } while ($state.phase -ne 'waiting-native-transitions' -and $resizeWatch.Elapsed.TotalSeconds -lt 35)
        if ($state.phase -ne 'waiting-native-transitions') { throw 'Flutter responsive resizing did not complete.' }
    }
    $transitionHandshake = $true
    Record-State 'initial'
    Capture-Video 'android-video-after-flutter-resize' | Out-Null
    Invoke-Adb @('emu','fold') | Out-Null
    Invoke-Adb @('shell','input','keyevent','KEYCODE_WAKEUP') | Out-Null
    Invoke-Adb @('shell','wm','dismiss-keyguard') | Out-Null
    Record-State 'emulator-fold'
    Invoke-Adb @('emu','unfold') | Out-Null
    Invoke-Adb @('shell','input','keyevent','KEYCODE_WAKEUP') | Out-Null
    Record-State 'emulator-unfold'
    Capture-Video 'android-video-after-native-fold' | Out-Null
    Invoke-Adb @('shell','wm','size','1080x2340') | Out-Null
    Record-State 'native-window-compact'
    Invoke-Adb @('shell','wm','size','1768x2208') | Out-Null
    Record-State 'native-window-expanded'
    Invoke-Adb @('shell','settings','put','system','accelerometer_rotation','0') | Out-Null
    Invoke-Adb @('shell','settings','put','system','user_rotation','1') | Out-Null
    Record-State 'native-landscape'
    Invoke-Adb @('shell','settings','put','system','user_rotation','0') | Out-Null
    Record-State 'native-portrait'
    # Enter real Android split screen; changing wm size alone is not this test.
    $stacks = Invoke-Adb @('shell','am','stack','list')
    $taskMatch = [regex]::Match($stacks, ('taskId=(\d+):\s*' + [regex]::Escape($ApplicationId) + '/'))
    if (-not $taskMatch.Success) { throw 'NOVA task not found for the split-screen test.' }
    $splitTaskId = $taskMatch.Groups[1].Value
    # Open the companion first, then move the existing NOVA task beside it.
    # Launching Settings after moveToSideStage dismisses the newly formed split
    # on API 35. NO_USER_ACTION also avoids requesting an automatic PiP switch.
    Invoke-Adb @('shell','am','start','-a','android.settings.SETTINGS','-f','0x10040000') | Out-Null
    Start-Sleep -Milliseconds 600
    Invoke-Adb @('shell','dumpsys','activity','service','com.android.systemui/.SystemUIService','WMShell','splitscreen','moveToSideStage',$splitTaskId,'0') | Out-Null
    $splitWatch = [Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Milliseconds 300
        $splitState = Get-State
    } while ((-not $splitState.native.multiWindow -or $splitState.native.inPip) -and $splitWatch.Elapsed.TotalSeconds -lt 8)
    if (-not $splitState.native.multiWindow -or $splitState.native.inPip) { throw 'Real split-screen mode did not become active.' }
    Record-State 'native-split-screen'
    $splitBefore = (Get-State).positionMs
    Start-Sleep -Milliseconds 1800
    $splitAfter = Get-State
    if (-not $splitAfter.playing -or $splitAfter.openCount -ne 1 -or $splitAfter.positionMs -le $splitBefore + 500) { throw 'Video did not advance within real split screen.' }
    Capture-Video 'android-native-split-screen' | Out-Null
    Invoke-Adb @('shell','dumpsys','activity','service','com.android.systemui/.SystemUIService','WMShell','splitscreen','exitSplitScreen',$splitTaskId) | Out-Null
    Invoke-Adb @('shell','am','start','-n',($ApplicationId + '/app.nova.iptv.MainActivity')) | Out-Null
    Start-Sleep -Milliseconds 1000
    Record-State 'native-split-screen-return'
    if ((Get-State).native.multiWindow) { throw 'Application remained in split screen after return.' }
    $splitTaskId = $null
    $pip = Invoke-RestMethod -Uri ($baseUrl + '/pip') -Method Post -ContentType 'application/json' -Body '{}' -TimeoutSec 8
    if (-not $pip.pipRequested) { throw 'Android refused Picture-in-Picture.' }
    $pipWatch = [Diagnostics.Stopwatch]::StartNew()
    do {
        $pipState = Get-State
        if (-not $pipState.native.inPip) { Start-Sleep -Milliseconds 200 }
    } while (-not $pipState.native.inPip -and $pipWatch.Elapsed.TotalSeconds -lt 6)
    if (-not $pipState.native.inPip) { throw 'Picture-in-Picture did not become active.' }
    Record-State 'native-pip-entered'
    $pipBefore = (Get-State).positionMs
    Start-Sleep -Milliseconds 2200
    $pipAfter = Get-State
    if ($pipAfter.positionMs -le $pipBefore + 500 -or $pipAfter.openCount -ne 1) { throw 'Video did not advance within Picture-in-Picture.' }
    Capture-Video 'android-native-pip' | Out-Null
    Invoke-Adb @('shell','am','start','-n',($ApplicationId + '/app.nova.iptv.MainActivity')) | Out-Null
    Start-Sleep -Milliseconds 1200
    Record-State 'native-pip-return'
    Capture-Video 'android-video-after-pip' | Out-Null
    if ((Get-State).native.inPip) { throw 'Application remained in Picture-in-Picture after return.' }
    $beforeLock = (Get-State).positionMs
    Invoke-Adb @('shell','input','keyevent','KEYCODE_SLEEP') | Out-Null
    Start-Sleep -Milliseconds 2000
    Invoke-Adb @('shell','input','keyevent','KEYCODE_WAKEUP') | Out-Null
    Invoke-Adb @('shell','wm','dismiss-keyguard') | Out-Null
    Invoke-Adb @('shell','am','start','-n',($ApplicationId + '/app.nova.iptv.MainActivity')) | Out-Null
    $resumeWatch = [Diagnostics.Stopwatch]::StartNew()
    do {
        $resumeState = Get-State
        if (-not $resumeState.playing -or $resumeState.positionMs -le $beforeLock + 500) { Start-Sleep -Milliseconds 250 }
    } while ((-not $resumeState.playing -or $resumeState.positionMs -le $beforeLock + 500) -and $resumeWatch.Elapsed.TotalSeconds -lt 8)
    if (-not $resumeState.playing -or $resumeState.positionMs -le $beforeLock + 500 -or $resumeState.openCount -ne 1) { throw 'Playback did not resume after screen lock.' }
    Record-State 'native-lock-unlock-resumed'
    Capture-Video 'android-native-playback' | Out-Null
} catch {
    $failure = $_.Exception.Message
} finally {
    try {
        if ($null -ne $splitTaskId) {
            Invoke-Adb @('shell','dumpsys','activity','service','com.android.systemui/.SystemUIService','WMShell','splitscreen','exitSplitScreen',$splitTaskId) | Out-Null
            Invoke-Adb @('shell','am','start','-n',($ApplicationId + '/app.nova.iptv.MainActivity')) | Out-Null
        }
        Invoke-Adb @('shell','wm','size',$(if ($originalSizeOverride) { $originalSizeOverride } else { 'reset' })) | Out-Null
        Invoke-Adb @('shell','wm','density',$(if ($originalDensityOverride) { $originalDensityOverride } else { 'reset' })) | Out-Null
        Invoke-Adb @('shell','settings','put','system','accelerometer_rotation',$originalAutoRotate) | Out-Null
        Invoke-Adb @('shell','settings','put','system','user_rotation',$originalRotation) | Out-Null
        Invoke-Adb @('emu','unfold') | Out-Null
        if ($transitionHandshake) {
            Record-State 'restored-emulator-window'
            $report = @{passed=($null -eq $failure); emulator=$Device; transitions=$events; captures=$captures; failure=$failure}
            $json = $report | ConvertTo-Json -Depth 12
            $json | Set-Content -LiteralPath (Join-Path $projectRoot '.tools\android-native-transitions.json') -Encoding UTF8
            Invoke-RestMethod -Uri ($baseUrl + '/continue') -Method Post -ContentType 'application/json' -Body $json -TimeoutSec 8 | Out-Null
        }
    } finally { Invoke-Adb @('forward','--remove','tcp:18757') | Out-Null }
}
if ($null -ne $failure) { throw $failure }
Write-Output 'Native transition checks completed; original emulator size, density and rotation restored.'
