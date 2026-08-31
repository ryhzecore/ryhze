param([string]$Root = $PSScriptRoot)

$ErrorActionPreference = 'Stop'
$ffmpeg = Join-Path $Root 'tools\ffmpeg-9.0.1-essentials_build\bin\ffmpeg.exe'
$ffprobe = Join-Path $Root 'tools\ffmpeg-9.0.1-essentials_build\bin\ffprobe.exe'
if (-not (Test-Path -LiteralPath $ffmpeg)) { throw "FFmpeg was not found: $ffmpeg" }

Get-ChildItem -LiteralPath $Root -Recurse -File -Filter *.mp4 | Where-Object {
  $_.FullName -match '\\(Films|Games)\\' -and $_.BaseName -notmatch '-web$'
} | ForEach-Object {
  $output = Join-Path $_.DirectoryName ($_.BaseName + '-web.mp4')
  if (Test-Path -LiteralPath $output) {
    & $ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $output | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "Already available: $output"; return }
  }
  Write-Host "Converting for mobile: $($_.FullName)"
  & $ffmpeg -hide_banner -y -hwaccel auto -i $_.FullName -map 0:v:0 -map 0:a? -c:v h264_nvenc -preset p5 -cq 23 -b:v 0 -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart $output
  if ($LASTEXITCODE -ne 0) { throw "Conversion failed: $($_.FullName)" }
}

& (Join-Path $Root 'sync-library.ps1')
Write-Host 'Mobile-compatible streams are ready.'
