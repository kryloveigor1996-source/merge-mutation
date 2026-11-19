param([string[]]$Paths)
$ErrorActionPreference='Stop'
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $Paths) { $Paths=@(git -C $repoRoot diff --cached --name-only --diff-filter=ACMR) }
$placeholders=@('logs/import/.gitkeep','logs/runtime/.gitkeep','logs/tests/.gitkeep','logs/archive/.gitkeep','builds/android/.gitkeep','builds/windows/.gitkeep')
$rejected=@()
foreach($path in $Paths) {
    $allowed=$path -in @('AGENTS.md','.gitattributes','.gitignore') -or $path.StartsWith('MergeMutation/') -or $path -in $placeholders
    $work=$path -match '(?i)(^|/)(APAC|IWG|ENQ|competitor[-_ ]benchmark|work-reports)(/|[-_ .])' -or $path -match '(?i)\.(xlsx?|docx?|pptx?|pdf)$'
    $generated=$path -notin $placeholders -and ($path -match '(?i)(^|/)\.godot(/|$)' -or $path -match '^(logs|builds)/' -or $path -match '(?i)\.(log|tmp|bak|apk|aab)$')
    $secret=$path -match '(?i)(^|/)(export_credentials\.cfg|\.env(?:\..+)?)$' -and $path -notmatch '(?i)(^|/)\.env\.example$'
    $secret=$secret -or $path -match '(?i)\.(keystore|jks|p12|pfx)$|\.private\.key$|(?:private|signing)[^/]*\.pem$'
    if (-not $allowed -or $work -or $generated -or $secret) { $rejected+=$path }
}
if ($rejected.Count) { throw ('Non-game/generated/private staged paths rejected: '+($rejected -join ', ')) }
Write-Output ('Staged game paths checked: '+$Paths.Count)
