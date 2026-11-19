param([string]$FFmpegPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'workspace_paths.ps1')
$workspace=Get-MMWorkspace
$source=Join-Path $workspace.Cache 'audio-generation/source'
New-Item -ItemType Directory -Path $source -Force | Out-Null
if(-not $FFmpegPath){
 $found=@(Get-ChildItem -LiteralPath (Join-Path $workspace.Cache 'audio-generation/tools') -Filter ffmpeg.exe -Recurse -File)
 if($found.Count -ne 1){throw 'Pass a verified portable FFmpegPath'}
 $FFmpegPath=$found[0].FullName
}
$ffprobe=Join-Path ([IO.Path]::GetDirectoryName($FFmpegPath)) 'ffprobe.exe'
$logRoot=New-MMLogDirectory -Category tests -Label 'pr21-original-soundtrack'
& $FFmpegPath -version | Set-Content -LiteralPath (Join-Path $logRoot 'encoder-version.log') -Encoding utf8
Add-Type -Path (Join-Path $PSScriptRoot 'audio/MutationScore.cs')
$config=Get-Content -LiteralPath (Join-Path $workspace.Project 'data/music.json') -Raw | ConvertFrom-Json
$stats=@()
$index=0
foreach($entry in $config.tracks.PSObject.Properties){
 $id=$entry.Name
 $track=$entry.Value
 $wav=Join-Path $source ($id+'.wav')
 $midi=Join-Path $source ($id+'.mid')
 $result=[MutationScore]::Compose($id,$wav,$midi,[int]$track.duration,[int]$track.bpm,$index)
 $destination=Join-Path $workspace.Project ($track.path.Substring(6))
 New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force | Out-Null
 $encoderLog=Join-Path $logRoot ($id+'-encode.log')
 & $FFmpegPath -hide_banner -nostdin -y -i $wav -c:a libvorbis -q:a 3 -map_metadata -1 $destination 2> $encoderLog
 if($LASTEXITCODE -ne 0){throw "Encoding failed: $id"}
 $probe=& $ffprobe -v error -show_entries format=duration,size,bit_rate -of json $destination
 if($LASTEXITCODE -ne 0){throw "Probe failed: $id"}
 $parsed=$probe | ConvertFrom-Json
 $result['ogg_bytes']=[long]$parsed.format.size
 $result['ogg_sha256']=(Get-FileHash -LiteralPath $destination).Hash
 $result['measured_duration']=[double]::Parse($parsed.format.duration,[Globalization.CultureInfo]::InvariantCulture)
 $stats+=$result
 Write-Output ($id+': '+$result.notes+' score events; '+$result.ogg_bytes+' bytes')
 $index++
}
$stats | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $logRoot 'soundtrack-measurements.json') -Encoding utf8
Write-Output ('Logs: '+$logRoot)
Write-Output ('Intermediates: '+$source)
