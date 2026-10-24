param(
    [Parameter(Mandatory=$true)][string]$RunDir
)
$ErrorActionPreference='Stop'

$displayPath = Join-Path $RunDir 'displays.json'
$telemetryPath = Join-Path $RunDir 'pointer_telemetry.csv'
if (-not (Test-Path $displayPath)) { throw "Missing displays.json: $displayPath" }
if (-not (Test-Path $telemetryPath)) { throw "Missing pointer_telemetry.csv: $telemetryPath" }

$displayDoc = Get-Content -Raw $displayPath | ConvertFrom-Json
$rows = @(Import-Csv $telemetryPath)
$displays = @($displayDoc.displays)

function I($v) { if ($null -eq $v -or $v -eq '') { return $null }; return [int]$v }
function D($v) { if ($null -eq $v -or $v -eq '') { return $null }; return [double]::Parse([string]$v,[Globalization.CultureInfo]::InvariantCulture) }

$expectedRows = @($rows | Where-Object { $_.expected_x -ne '' -and $_.expected_y -ne '' })
$deltaAbsX = @($expectedRows | ForEach-Object { [math]::Abs((I $_.delta_x)) })
$deltaAbsY = @($expectedRows | ForEach-Object { [math]::Abs((I $_.delta_y)) })
$deltaEuclid = @($expectedRows | ForEach-Object {
    $dx = I $_.delta_x; $dy = I $_.delta_y
    [math]::Sqrt(($dx*$dx)+($dy*$dy))
})

$insideViolations = 0
$normViolations = 0
foreach($r in $rows) {
    $x=I $r.screen_x; $y=I $r.screen_y
    $l=I $r.mon_left; $t=I $r.mon_top; $rr=I $r.mon_right; $bb=I $r.mon_bottom
    if ($null -ne $x -and $null -ne $l -and -not ($x -ge $l -and $x -lt $rr -and $y -ge $t -and $y -lt $bb)) { $insideViolations++ }
    $nx=D $r.norm_x; $ny=D $r.norm_y
    if ($null -ne $nx -and ($nx -lt -0.000001 -or $nx -gt 1.000001 -or $ny -lt -0.000001 -or $ny -gt 1.000001)) { $normViolations++ }
}

$expectedMonitorMismatch = 0
$expectedOutsideAllDisplays = 0
foreach($r in $expectedRows) {
    $ex=I $r.expected_x; $ey=I $r.expected_y
    $expectedDisplay = $null
    foreach($d in $displays) {
        $m=$d.monitor_rect
        if ($ex -ge [int]$m.left -and $ex -lt [int]$m.right -and $ey -ge [int]$m.top -and $ey -lt [int]$m.bottom) { $expectedDisplay=$d; break }
    }
    if ($null -eq $expectedDisplay) { $expectedOutsideAllDisplays++; continue }
    if ((I $r.monitor_index) -ne [int]$expectedDisplay.index) { $expectedMonitorMismatch++ }
}

$geometryChecks=@()
$dpiChecks=@()
foreach($d in $displays) {
    $m=$d.monitor_rect
    $mw=[int]$m.right-[int]$m.left; $mh=[int]$m.bottom-[int]$m.top
    $e=$d.enum_display_settings
    $enumMatches=($mw -eq [int]$e.width -and $mh -eq [int]$e.height -and [int]$m.left -eq [int]$e.position_x -and [int]$m.top -eq [int]$e.position_y)
    $sourceMatches=$null
    if ($d.display_config -and $d.display_config.source_mode) {
        $s=$d.display_config.source_mode
        $sourceMatches=($mw -eq [int]$s.width -and $mh -eq [int]$s.height -and [int]$m.left -eq [int]$s.position_x -and [int]$m.top -eq [int]$s.position_y)
    }
    $geometryChecks += [ordered]@{
        index=[int]$d.index
        device_name=[string]$d.device_name
        monitor_rect_width=$mw
        monitor_rect_height=$mh
        enum_display_settings_matches=$enumMatches
        display_config_source_mode_matches=$sourceMatches
    }
    $windowDpi=[int]$d.window_dpi
    $dpiScale=[math]::Round(($windowDpi/96.0)*100.0,2)
    $legacyScale=[int]$d.legacy_get_scale_factor_for_monitor_percent
    $legacyDpi=[int]$d.legacy_get_dpi_for_monitor_effective.x
    $dpiChecks += [ordered]@{
        index=[int]$d.index
        window_dpi=$windowDpi
        dpi_implied_scale_percent=$dpiScale
        legacy_get_dpi_for_monitor=$legacyDpi
        legacy_scale_factor_percent=$legacyScale
        window_vs_legacy_dpi_equal=($windowDpi -eq $legacyDpi)
        legacy_scale_matches_window_dpi=([math]::Abs($legacyScale-$dpiScale) -lt 0.01)
    }
}

$uniqueMonitorIndices=@($rows | Select-Object -ExpandProperty monitor_index -Unique | ForEach-Object {[int]$_} | Sort-Object)
$transitionCount=@($rows | Where-Object {$_.monitor_transition -eq '1'}).Count
$phaseCounts=@{}
foreach($g in ($rows | Group-Object phase)) { $phaseCounts[$g.Name]=$g.Count }

$analysis=[ordered]@{
    run_dir=$RunDir
    pmv2=[bool]$displayDoc.thread_is_per_monitor_v2
    display_count=[int]$displayDoc.display_count
    virtual_screen=$displayDoc.virtual_screen
    sample_count=$rows.Count
    expected_sample_count=$expectedRows.Count
    monitors_observed=$uniqueMonitorIndices
    monitor_transition_samples=$transitionCount
    pointer_error=[ordered]@{
        max_abs_dx=if($deltaAbsX.Count){($deltaAbsX | Measure-Object -Maximum).Maximum}else{$null}
        max_abs_dy=if($deltaAbsY.Count){($deltaAbsY | Measure-Object -Maximum).Maximum}else{$null}
        max_euclidean_px=if($deltaEuclid.Count){[math]::Round((($deltaEuclid | Measure-Object -Maximum).Maximum),3)}else{$null}
    }
    inside_monitor_violations=$insideViolations
    normalized_coordinate_violations=$normViolations
    expected_monitor_mismatches=$expectedMonitorMismatch
    expected_points_outside_all_displays=$expectedOutsideAllDisplays
    geometry_checks=$geometryChecks
    dpi_checks=$dpiChecks
    phase_counts=$phaseCounts
}

$analysisPath=Join-Path $RunDir 'analysis.json'
$analysis | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $analysisPath

$allGeometryGood=(@($geometryChecks | Where-Object {-not $_.enum_display_settings_matches -or $_.display_config_source_mode_matches -eq $false}).Count -eq 0)
$summary=@()
$summary += '# Spike 2 run summary'
$summary += ''
$summary += "- PMv2: $($analysis.pmv2)"
$summary += "- Displays: $($analysis.display_count)"
$summary += "- Virtual screen: x=$($displayDoc.virtual_screen.x), y=$($displayDoc.virtual_screen.y), $($displayDoc.virtual_screen.width)x$($displayDoc.virtual_screen.height)"
$summary += "- Samples: $($analysis.sample_count)"
$summary += "- Monitors observed: $($uniqueMonitorIndices -join ', ')"
$summary += "- Monitor transition samples: $transitionCount"
$summary += "- Max pointer delta X/Y: $($analysis.pointer_error.max_abs_dx) / $($analysis.pointer_error.max_abs_dy) px"
$summary += "- Max pointer Euclidean delta: $($analysis.pointer_error.max_euclidean_px) px"
$summary += "- Inside-monitor violations: $insideViolations"
$summary += "- Normalized-coordinate violations: $normViolations"
$summary += "- Expected-monitor mismatches: $expectedMonitorMismatch"
$summary += "- Expected points outside all displays: $expectedOutsideAllDisplays"
$summary += "- Geometry APIs agree: $allGeometryGood"
$summary += ''
$summary += '## Per-display DPI evidence'
$summary += ''
foreach($d in $dpiChecks) {
    $summary += "- Display $($d.index): GetDpiForWindow=$($d.window_dpi) ($($d.dpi_implied_scale_percent)% implied); legacy GetDpiForMonitor=$($d.legacy_get_dpi_for_monitor); legacy scale-factor API=$($d.legacy_scale_factor_percent)%"
}
$summary += ''
$summary += 'Legacy DPI/scale values are comparison evidence only. The PMv2 window DPI is the current canonical per-monitor DPI measurement for this spike.'
$summary -join "`r`n" | Set-Content -Encoding UTF8 (Join-Path $RunDir 'SUMMARY.md')

Write-Host ($summary -join "`n")
