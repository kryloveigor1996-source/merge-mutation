param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [switch]$Gpu,
    [switch]$IncludePortraitRegression,
    [string]$Label='regression'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'workspace_paths.ps1')
$workspace = Get-MMWorkspace
$mode = if ($Gpu) {'gpu'} else {'headless'}
$logRoot = New-MMLogDirectory -Category tests -Label ($Label + '-' + $mode)
$originalAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $workspace.Cache 'test-appdata'
    $suites = @('landscape_ui', 'landscape_navigation', 'modular_habitat', 'modular_habitat_ui', 'wheel_navigation', 'ecosystem_model', 'ecosystem_ui')
    if ($Gpu) { $suites = @('landscape_ui', 'landscape_navigation', 'modular_habitat_ui', 'wheel_navigation', 'ecosystem_ui') }
    if ($IncludePortraitRegression) {
        $suites = @('prototype','presentation','slime_sprite','mutant_sprites','mutant_levels_4_6','progressive_sizes','species_evolution','campaign','tactical','portal_world','portal_revision','mutation','challenge_navigation','mutation_undo','mutation_undo_ui','mutation_ui','complex','complex_ui','living_habitat','living_habitat_ui') + $suites
        if ($Gpu) { $suites = @('portal_navigation_render','mutation_ui','mutation_undo_ui','complex_ui','living_habitat_ui','landscape_ui','landscape_navigation','modular_habitat_ui','wheel_navigation','ecosystem_ui') }
    }
    if ($Gpu) { $suites += @('world_progression_ui') } else { $suites += @('world_progression_model','world_progression_ui') }
    $failed = @()
    foreach ($suite in $suites) {
        $log = Join-Path $logRoot ($suite + '-' + $mode + '.log')
        $renderer = if ($Gpu) {'--rendering-method gl_compatibility'} else {'--headless'}
        $legacy = if ($suite.StartsWith('world_progression_')) {''} elseif ($suite.StartsWith('landscape_')) {' -- --habitat-stage-regression --ecosystem-legacy'} elseif ($suite.StartsWith('modular_')) {' -- --ecosystem-legacy'} elseif ($suite.StartsWith('wheel_') -or $suite.StartsWith('ecosystem_')) {' -- --living-world-legacy'} else {' -- --portrait-regression'}
        try {
            $content = Invoke-MMGodot -GodotPath $GodotPath -LogPath $log -EngineArguments ($renderer + ' --script res://tests/' + $suite + '_test.gd' + $legacy)
            Write-Output ($content -split '\r?\n' | Where-Object { $_ -match 'checks:' })
            if ($content -notmatch 'failures: 0') { throw ('Missing successful test summary: ' + $suite) }
        } catch {
            $failed += $suite
            Write-Output $_.Exception.Message
        }
    }
    Write-Output ('Logs: ' + $logRoot)
    if ($failed.Count) { throw ('Failed suites: ' + ($failed -join ', ')) }
} finally {
    $env:APPDATA = $originalAppData
}
