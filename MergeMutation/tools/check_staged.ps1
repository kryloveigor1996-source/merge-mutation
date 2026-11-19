param([string[]]$Paths)
$ErrorActionPreference='Stop'
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $Paths) { $Paths=@(git -C $repoRoot diff --cached --name-only --diff-filter=ACMR) }
$rejected=@()
foreach($path in $Paths) {
    $allowed=$path -in @('AGENTS.md','.gitattributes','.gitignore') -or $path.StartsWith('MergeMutation/')
    $work=$path -match '(?i)(^|/)(APAC|IWG|ENQ|competitor[-_ ]benchmark|work-reports)(/|[-_ .])' -or $path -match '(?i)\.(xlsx?|docx?|pptx?|pdf)$'
    if (-not $allowed -or $work) { $rejected+=$path }
}
if ($rejected.Count) { throw ('Non-game staged paths rejected: '+($rejected -join ', ')) }
Write-Output ('Staged game paths checked: '+$Paths.Count)
