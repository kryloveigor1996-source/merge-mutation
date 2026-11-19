param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [switch]$Gpu,
    [switch]$IncludePortraitRegression
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$logRoot = Join-Path $projectRoot '.godot/landscape-check'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$env:APPDATA = Join-Path $projectRoot '.godot/test-appdata'
$suites = @('landscape_ui', 'landscape_navigation', 'modular_habitat', 'modular_habitat_ui', 'wheel_navigation', 'ecosystem_model', 'ecosystem_ui')
if ($Gpu) { $suites = @('landscape_ui', 'landscape_navigation', 'modular_habitat_ui', 'wheel_navigation', 'ecosystem_ui') }
if ($IncludePortraitRegression) {
    $suites = @('prototype','presentation','slime_sprite','mutant_sprites','mutant_levels_4_6','progressive_sizes','species_evolution','campaign','tactical','portal_world','portal_revision','mutation','challenge_navigation','mutation_undo','mutation_undo_ui','mutation_ui','complex','complex_ui','living_habitat','living_habitat_ui') + $suites
    if ($Gpu) { $suites = @('portal_navigation_render','mutation_ui','mutation_undo_ui','complex_ui','living_habitat_ui','landscape_ui','landscape_navigation','modular_habitat_ui','wheel_navigation','ecosystem_ui') }
}
$failed = @()
foreach ($suite in $suites) {
    $log = Join-Path $logRoot ($suite + $(if ($Gpu) {'-gpu'} else {'-headless'}) + '.log')
    $renderer = if ($Gpu) {'--rendering-method gl_compatibility'} else {'--headless'}
    $legacy = if ($suite.StartsWith('landscape_')) {' -- --habitat-stage-regression --ecosystem-legacy'} elseif ($suite.StartsWith('modular_')) {' -- --ecosystem-legacy'} elseif ($suite.StartsWith('wheel_') -or $suite.StartsWith('ecosystem_')) {''} else {' -- --portrait-regression'}
    $arguments = $renderer + ' --path "' + $projectRoot + '" --script res://tests/' + $suite + '_test.gd --log-file "' + $log + '"' + $legacy
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(300000)) {
        Stop-Process -Id $process.Id
        $failed += $suite
        Write-Output ($suite + ': TIMEOUT')
        continue
    }
    $content = [IO.File]::ReadAllText($log)
    Write-Output ($content -split "`n" | Where-Object { $_ -match 'checks:|FAIL:|^SCRIPT ERROR:|^ERROR:|^WARNING:' })
    if ($process.ExitCode -ne 0 -or $content -match '(?m)^(SCRIPT ERROR|ERROR|WARNING|FAIL):' -or $content -notmatch 'failures: 0') { $failed += $suite }
}
if ($failed.Count) { throw ('Failed suites: ' + ($failed -join ', ')) }
