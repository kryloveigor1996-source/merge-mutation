param([Parameter(Mandatory=$true)][string]$GodotPath)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$cacheRoot = Join-Path $projectRoot '.godot'
$logRoot = Join-Path $cacheRoot 'script-check'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$scripts = @(Get-ChildItem -LiteralPath $projectRoot -Filter '*.gd' -File -Recurse | Where-Object { -not $_.FullName.StartsWith($cacheRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) } | Sort-Object FullName)
$failures = @()
foreach ($scriptFile in $scripts) {
    $relative = $scriptFile.FullName.Substring($projectRoot.Length + 1).Replace('\','/')
    $logPath = Join-Path $logRoot ($relative.Replace('/','_') + '.log')
    $nativeArgs = '--headless --editor --path "' + $projectRoot + '" --script "res://' + $relative + '" --check-only --log-file "' + $logPath + '"'
    $process = Start-Process -FilePath $GodotPath -ArgumentList $nativeArgs -WindowStyle Hidden -PassThru -Wait
    $logText = [IO.File]::ReadAllText($logPath)
    if ($process.ExitCode -ne 0 -or $logText -match '(?m)^(SCRIPT ERROR|ERROR|WARNING):') {
        $failures += $relative
        Write-Output $logText
    }
}
Write-Output ('GDScript cold compilation: ' + $scripts.Count + ' scripts; failures: ' + $failures.Count)
if ($failures.Count -gt 0) { throw ('Compilation failed: ' + ($failures -join ', ')) }
