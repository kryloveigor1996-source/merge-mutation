param([Parameter(Mandatory=$true)][string]$GodotPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'workspace_paths.ps1')
$workspace=Get-MMWorkspace
$logRoot=New-MMLogDirectory -Category tests -Label 'workspace-contracts'
$checks=0
$failed=0
$lines=[Collections.Generic.List[string]]::new()
function Check([bool]$Value,[string]$Message){
    $script:checks++
    if(-not $Value){$script:failed++;$script:lines.Add('FAIL: '+$Message)}
}
foreach($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File){
    $tokens=$null
    $errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    Check ($errors.Count -eq 0) ('PowerShell parses: '+$file.Name)
}
Push-Location ([IO.Path]::GetTempPath())
try {
    $resolved=Get-MMWorkspace
    Check ($resolved.Project -eq $workspace.Project -and $resolved.Repo -eq $workspace.Repo) 'Paths are independent of current directory'
} finally { Pop-Location }
$accepted=@('AGENTS.md','logs/tests/.gitkeep','builds/android/.gitkeep','MergeMutation/scripts/main.gd','MergeMutation/scripts/main.gd.uid','MergeMutation/assets/mutants/slime_lv1.png','MergeMutation/assets/mutants/slime_lv1.png.import','MergeMutation/tests/fixtures/complex_50.json','MergeMutation/docs/world-progression-changed-files.txt','MergeMutation/.env.example')
try { & (Join-Path $PSScriptRoot 'check_staged.ps1') -Paths $accepted | Out-Null; Check $true 'Legitimate game files accepted' } catch { Check $false 'Legitimate game files accepted' }
foreach($path in @('APAC/report.xlsx','MergeMutation/IWG/report.docx','.godot/test.json','MergeMutation/.godot/test.png','logs/archive/progress.json','builds/windows/game.exe','MergeMutation/local.log','MergeMutation/game.apk','MergeMutation/key.jks','MergeMutation/private.pem','MergeMutation/.env','MergeMutation/export_credentials.cfg')){
    $rejected=$false
    try { & (Join-Path $PSScriptRoot 'check_staged.ps1') -Paths @($path) | Out-Null } catch { $rejected=$true }
    Check $rejected ('Staged guard rejects '+$path)
}
foreach($path in @('.godot/test.json','MergeMutation/.godot/test.png','logs/tests/generated.txt','logs/archive/local.json','builds/android/game.apk','MergeMutation/key.jks','MergeMutation/.env')){
    $null=git -C $workspace.Repo check-ignore --no-index -- $path
    Check ($LASTEXITCODE -eq 0) ('Ignored: '+$path)
}
foreach($path in $accepted){
    $null=git -C $workspace.Repo check-ignore --no-index -- $path
    Check ($LASTEXITCODE -eq 1) ('Not ignored: '+$path)
}
Check ((Get-MMBuildPath -Platform android -FileName 'test.apk') -eq (Join-Path $workspace.Repo 'builds/android/test.apk')) 'Android build path'
Check ((Get-MMBuildPath -Platform windows -FileName 'test.exe') -eq (Join-Path $workspace.Repo 'builds/windows/test.exe')) 'Windows build path'
foreach($name in @('../outside.apk','C:\outside.apk','nested/test.apk','test.exe')){
    $rejected=$false
    try { $null=Get-MMBuildPath -Platform android -FileName $name } catch { $rejected=$true }
    Check $rejected ('Build path rejects '+$name)
}
$rejected=$false
try { $null=Invoke-MMGodot -GodotPath $GodotPath -EngineArguments '--version' -LogPath (Join-Path $workspace.Repo 'outside.log') } catch { $rejected=$_.Exception.Message -like '*logs must stay*' }
Check $rejected 'Runner rejects log outside logs without launching Godot'
Check (-not (Test-Path -LiteralPath (Join-Path $workspace.Repo 'outside.log'))) 'No rejected output created'
Check (-not (Test-Path -LiteralPath (Join-Path $workspace.Repo '.godot'))) 'No external cache'
$summary='Workspace tool checks: '+$checks+'; failures: '+$failed
$lines.Add($summary)
[IO.File]::WriteAllLines((Join-Path $logRoot 'workspace-check.log'),$lines,[Text.UTF8Encoding]::new($false))
$lines | Write-Output
Write-Output ('Logs: '+$logRoot)
if($failed){throw 'Workspace tool contracts failed'}
