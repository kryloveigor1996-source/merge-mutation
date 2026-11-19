param([string]$FFmpegPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'workspace_paths.ps1')
$workspace=Get-MMWorkspace
if(-not $FFmpegPath){$FFmpegPath=@(Get-ChildItem (Join-Path $workspace.Cache 'audio-generation/tools') -Filter ffmpeg.exe -Recurse -File)[0].FullName}
$logRoot=New-MMLogDirectory -Category tests -Label 'pr21-audio-audit'
Add-Type -TypeDefinition @"
using System;
using System.IO;
public static class MutationAudioAudit {
 public static double[] Read(string path) {
  byte[] bytes=File.ReadAllBytes(path); double peak=0,sum=0,maxStep=0; long clipped=0;
  double[] first=new double[2],last=new double[2];
  for(int i=0;i<bytes.Length/2;i++){
   double v=BitConverter.ToInt16(bytes,i*2)/32768.0; int channel=i%2;
   if(i<2)first[channel]=v; else maxStep=Math.Max(maxStep,Math.Abs(v-last[channel]));
   last[channel]=v; peak=Math.Max(peak,Math.Abs(v));sum+=v*v;
   if(Math.Abs(v)>=0.999)clipped++;
  }
  return new double[]{peak,Math.Sqrt(sum/(bytes.Length/2)),clipped,Math.Max(Math.Abs(first[0]-last[0]),Math.Abs(first[1]-last[1])),maxStep,bytes.Length/4.0/44100};
 }
}
"@
$config=Get-Content (Join-Path $workspace.Project 'data/music.json') -Raw | ConvertFrom-Json
$measurements=@()
foreach($entry in $config.tracks.PSObject.Properties){
 $path=Join-Path $workspace.Project $entry.Value.path.Substring(6)
 $raw=Join-Path $workspace.Cache ('audio-generation/'+$entry.Name+'-decoded.pcm')
 & $FFmpegPath -hide_banner -nostdin -v error -y -i $path -f s16le -ar 44100 -ac 2 $raw
 if($LASTEXITCODE){throw 'Decoder failed'}
 $result=[MutationAudioAudit]::Read($raw)
 $loudness=Join-Path $logRoot ($entry.Name+'-loudness.log')
 & $FFmpegPath -hide_banner -nostdin -i $path -af ebur128=peak=true -f null NUL 2> $loudness
 if($LASTEXITCODE){throw 'Loudness analysis failed'}
 if($result[2] -ne 0 -or $result[0] -gt 0.95 -or $result[3] -gt 0.02 -or [Math]::Abs($result[5]-$entry.Value.duration) -gt .05){throw ('Audio acceptance failed: '+$entry.Name+' '+($result -join ','))}
 $measurements+=[ordered]@{id=$entry.Name;seconds=$result[5];bytes=(Get-Item $path).Length;peak=$result[0];rms=$result[1];clipped_samples=$result[2];seam_jump=$result[3];max_sample_step=$result[4];sha256=(Get-FileHash $path).Hash;loudness_summary=@((Get-Content $loudness | Select-Object -Last 14))}
 Write-Output ($entry.Name+': peak='+$result[0]+' rms='+$result[1]+' seam='+$result[3]+' clipped='+$result[2])
}
$measurements | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $logRoot 'measurements.json') -Encoding utf8
Write-Output ('Audio audit: '+$logRoot)