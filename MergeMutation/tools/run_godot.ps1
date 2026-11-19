param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [ValidateSet('import','runtime','script','export')][string]$Mode='runtime',
    [string]$Script,
    [string[]]$UserArguments=@(),
    [switch]$Gpu,
    [int]$QuitAfterFrames=5,
    [string]$Label='godot',
    [ValidateSet('android','windows')][string]$Platform='android',
    [string]$ExportPreset,
    [switch]$DebugExport,
    [string]$OutputName
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'workspace_paths.ps1')
$workspace=Get-MMWorkspace
if ($QuitAfterFrames -lt 1) { throw 'QuitAfterFrames must be positive.' }
foreach($argument in $UserArguments) { if ($argument -notmatch '^--[a-zA-Z0-9_-]+$') { throw 'UserArguments accepts script flags only.' } }
$renderer=if($Gpu){'--rendering-method gl_compatibility'}else{'--headless'}
$arguments=$renderer
switch($Mode){
    'import' { $arguments+=' --editor --quit' }
    'runtime' { $arguments+=' --quit-after '+$QuitAfterFrames }
    'script' {
        if ([string]::IsNullOrWhiteSpace($Script) -or -not $Script.StartsWith('res://') -or $Script.Contains('"')) { throw 'Script must be a project resource.' }
        $file=[IO.Path]::GetFullPath((Join-Path $workspace.Project $Script.Substring(6)))
        if (-not $file.StartsWith($workspace.Project+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $file -PathType Leaf)) { throw 'Script outside project or missing.' }
        $arguments+=' --script "'+$Script+'"'
        if($UserArguments.Count){$arguments+=' -- '+($UserArguments -join ' ')}
    }
    'export' {
        if (-not (Test-Path -LiteralPath (Join-Path $workspace.Project 'export_presets.cfg'))) { throw 'No export preset configuration; no build was produced.' }
        if ([string]::IsNullOrWhiteSpace($ExportPreset) -or $ExportPreset.Contains('"')) { throw 'Provide an existing export preset.' }
        if ([string]::IsNullOrWhiteSpace($OutputName)) { $OutputName=[DateTime]::UtcNow.ToString('yyyy-MM-dd_HH-mm-ss')+'Z-'+$Label+$(if($Platform -eq 'android'){'.apk'}else{'.exe'}) }
        $output=Get-MMBuildPath -Platform $Platform -FileName $OutputName
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($output)) -Force | Out-Null
        if(Test-Path -LiteralPath $output){throw 'Build output exists; choose a new filename.'}
        $exportMode=if($DebugExport){' --export-debug "'}else{' --export-release "'}
        $arguments+=$exportMode+$ExportPreset+'" "'+$output+'"'
    }
}
$category=if($Mode -eq 'import'){'import'}elseif($Mode -eq 'script'){'tests'}else{'runtime'}
$logRoot=New-MMLogDirectory -Category $category -Label ($Label+'-'+$Mode)
$log=Join-Path $logRoot 'godot.log'
$originalAppData=$env:APPDATA
try {
    $env:APPDATA=Join-Path $workspace.Cache 'test-appdata'
    $content=Invoke-MMGodot -GodotPath $GodotPath -LogPath $log -EngineArguments $arguments
    Write-Output $content
    Write-Output ('Log: '+$log)
    if($Mode -eq 'export'){Write-Output ('Build: '+$output)}
} finally { $env:APPDATA=$originalAppData }
