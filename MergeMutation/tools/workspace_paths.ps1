# Shared paths and process rules for project tools. Never derive paths from the caller's cwd.
function Get-MMWorkspace {
    $project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $repo = [IO.Path]::GetFullPath((Join-Path $project '..'))
    if (-not (Test-Path -LiteralPath (Join-Path $project 'project.godot') -PathType Leaf)) { throw 'Godot project not found beside tools.' }
    if (-not (Test-Path -LiteralPath (Join-Path $repo '.git'))) { throw 'Git repository not found above Godot project.' }
    [pscustomobject]@{ Project = $project; Repo = $repo; Cache = Join-Path $project '.godot' }
}
function New-MMLogDirectory {
    param([string]$Category, [string]$Label)
    if ($Category -notin @('import','runtime','tests')) { throw 'Unsupported log category.' }
    if ($Label -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Log label must contain letters, numbers, dash or underscore.' }
    $workspace = Get-MMWorkspace
    $stamp = [DateTime]::UtcNow.ToString('yyyy-MM-dd_HH-mm-ss-fff') + 'Z'
    $name = $stamp + '-' + $Label + '-' + [guid]::NewGuid().ToString('N').Substring(0,6)
    $directory = Join-Path $workspace.Repo ('logs/' + $Category + '/' + $name)
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $directory
}
function Get-MMBuildPath {
    param([string]$Platform, [string]$FileName)
    if ($Platform -notin @('android','windows')) { throw 'Unsupported build platform.' }
    if ([string]::IsNullOrWhiteSpace($FileName) -or $FileName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or $FileName.Contains('/') -or $FileName.Contains('\') -or $FileName -in @('.','..')) { throw 'Build output must be a filename, not a path.' }
    $extension = [IO.Path]::GetExtension($FileName).ToLowerInvariant()
    if (($Platform -eq 'android' -and $extension -notin @('.apk','.aab')) -or ($Platform -eq 'windows' -and $extension -notin @('.exe','.zip'))) { throw 'Unexpected export extension.' }
    $workspace = Get-MMWorkspace
    Join-Path $workspace.Repo ('builds/' + $Platform + '/' + $FileName)
}
function Assert-MMNoExternalCache {
    $workspace = Get-MMWorkspace
    if (Test-Path -LiteralPath (Join-Path $workspace.Repo '.godot')) { throw 'Unexpected repository-root .godot. Audit/archive it; do not delete it automatically.' }
}
function Invoke-MMGodot {
    param([string]$GodotPath, [string]$EngineArguments, [string]$LogPath, [int]$TimeoutSeconds = 300)
    $workspace = Get-MMWorkspace
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Godot executable not found.' }
    $allowedLogs = [IO.Path]::GetFullPath((Join-Path $workspace.Repo 'logs')) + [IO.Path]::DirectorySeparatorChar
    if (-not [IO.Path]::GetFullPath($LogPath).StartsWith($allowedLogs, [StringComparison]::OrdinalIgnoreCase)) { throw 'Godot logs must stay inside repository logs/.' }
    Assert-MMNoExternalCache
    $arguments = '--path "' + $workspace.Project + '" --log-file "' + $LogPath + '" ' + $EngineArguments
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WorkingDirectory $workspace.Project -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id
        throw ('Godot timed out. Log: ' + $LogPath)
    }
    $process.Refresh()
    Assert-MMNoExternalCache
    if (-not (Test-Path -LiteralPath $LogPath)) { throw ('Godot produced no log: ' + $LogPath) }
    $content = [IO.File]::ReadAllText($LogPath)
    if ($process.ExitCode -ne 0 -or $content -match '(?m)^(SCRIPT ERROR|ERROR|WARNING|FAIL):') { throw ('Godot check failed. Log: ' + $LogPath + [Environment]::NewLine + $content) }
    $content
}
