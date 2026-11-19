param([Parameter(Mandatory=$true)][string]$GodotPath, [string]$Label='compile')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'workspace_paths.ps1')
$workspace = Get-MMWorkspace
$logRoot = New-MMLogDirectory -Category tests -Label $Label
$originalAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $workspace.Cache 'test-appdata'
    $scripts = @(Get-ChildItem -LiteralPath $workspace.Project -Filter '*.gd' -File -Recurse | Where-Object { -not $_.FullName.StartsWith($workspace.Cache + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) } | Sort-Object FullName)
    $failures = @()
    foreach ($scriptFile in $scripts) {
        $relative = $scriptFile.FullName.Substring($workspace.Project.Length + 1).Replace('\','/')
        $logPath = Join-Path $logRoot ($relative.Replace('/','_') + '.log')
        try {
            $null = Invoke-MMGodot -GodotPath $GodotPath -LogPath $logPath -EngineArguments ('--headless --editor --script "res://' + $relative + '" --check-only')
        } catch {
            $failures += $relative
            Write-Output $_.Exception.Message
        }
    }
    Write-Output ('GDScript cold compilation: ' + $scripts.Count + ' scripts; failures: ' + $failures.Count)
    Write-Output ('Logs: ' + $logRoot)
    if ($failures.Count) { throw ('Compilation failed: ' + ($failures -join ', ')) }
} finally {
    $env:APPDATA = $originalAppData
}
