param([Parameter(Mandatory=$true)][string]$ApkPath,[string]$SdkPath=(Join-Path $env:LOCALAPPDATA 'Android/Sdk'),[string]$BuildToolsVersion='36.0.0')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'workspace_paths.ps1')
$w=Get-MMWorkspace
$apk=[IO.Path]::GetFullPath($ApkPath)
if(-not $apk.StartsWith((Join-Path $w.Repo 'builds/android')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Audit an APK in builds/android/'}
$log=New-MMLogDirectory -Category tests -Label pr21-apk-check
$tools=Join-Path $SdkPath ('build-tools/'+$BuildToolsVersion)
$checks=0
function Check([bool]$ok,[string]$message){$script:checks++; if(-not $ok){throw $message}}
$signature=& (Join-Path $tools 'apksigner.bat') verify --verbose --print-certs $apk
Check ($LASTEXITCODE -eq 0) 'APK signature verification'
$signature | Set-Content (Join-Path $log 'signature.txt')
$badging=& (Join-Path $tools 'aapt.exe') dump badging $apk
Check ($LASTEXITCODE -eq 0) 'APK metadata inspection'
$badging | Set-Content (Join-Path $log 'package.txt')
Check (($badging -join "`n").Contains("name='org.mergemutation.prototype.debug'")) 'Stable test package'
Check (($badging -join "`n").Contains("versionCode='21'")) 'PR21 version'
Check (($badging -join "`n").Contains("native-code: 'arm64-v8a'")) 'Arm64 mobile target'
Check (($badging -join "`n").Contains('application-debuggable')) 'Debug test build'
$manifest=& (Join-Path $tools 'aapt.exe') dump xmltree $apk AndroidManifest.xml
Check ($LASTEXITCODE -eq 0) 'Manifest inspection'
$manifest | Set-Content (Join-Path $log 'manifest.txt')
Check (($manifest -join "`n") -match 'screenOrientation.*0x0\s') 'Landscape orientation'
& (Join-Path $tools 'zipalign.exe') -c -P 16 4 $apk
Check ($LASTEXITCODE -eq 0) 'Page and ZIP alignment'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead($apk)
try {
 $names=@($zip.Entries.FullName)
 $names | Set-Content (Join-Path $log 'files.txt')
 Check (@($names | Where-Object {$_ -match '(?i)/tests/|/tools/|/docs/|/references/|\.keystore$|\.jks$'}).Count -eq 0) 'No test suites, generation sources, docs, references or signing keys exported'
 Check (@($names | Where-Object {$_ -like '*.oggvorbisstr'}).Count -eq 9) 'All nine OGG resources packed'
 foreach($name in @('assets/data/core_economy.json','assets/data/music.json','assets/scripts/core_game.gdc','assets/scripts/music_manager.gdc')){Check ($name -in $names) ('Runtime resource '+$name)}
} finally {$zip.Dispose()}
Get-FileHash $apk | Format-List | Out-String | Set-Content (Join-Path $log 'sha256.txt')
Write-Output ('Android package checks: '+$checks+'; failures: 0; bytes: '+(Get-Item $apk).Length)
Write-Output ('Logs: '+$log)