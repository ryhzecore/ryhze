param([string]$Root = $PSScriptRoot)

$ErrorActionPreference = 'Continue'
$ffmpeg = Join-Path $Root 'tools\ffmpeg-9.0.1-essentials_build\bin\ffmpeg.exe'
$ffprobe = Join-Path $Root 'tools\ffmpeg-9.0.1-essentials_build\bin\ffprobe.exe'
$logPath = Join-Path $Root 'web-media-conversion.log'

if (-not (Test-Path -LiteralPath $ffmpeg) -or -not (Test-Path -LiteralPath $ffprobe)) {
  "[$(Get-Date)] FFmpeg is unavailable; conversion skipped." | Add-Content -LiteralPath $logPath
  exit 1
}

$mediaExtensions = @('.mp4','.m4v','.mov','.mkv','.webm')
$sources = Get-ChildItem -LiteralPath (Join-Path $Root 'Films'),(Join-Path $Root 'Games') -File -Recurse -ErrorAction SilentlyContinue |
  Where-Object { $mediaExtensions -contains $_.Extension.ToLowerInvariant() -and $_.BaseName -notmatch '-web$' } |
  Sort-Object Length

foreach ($source in $sources) {
  $output = Join-Path $source.DirectoryName ($source.BaseName + '-web.mp4')
  $partial = Join-Path $source.DirectoryName ($source.BaseName + '-web.partial.mp4')
  if (Test-Path -LiteralPath $output) { continue }
  Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
  $codec = (& $ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $source.FullName 2>$null | Select-Object -First 1).Trim()
  if (-not $codec) { continue }
  "[$(Get-Date)] Creating browser copy for $($source.FullName) ($codec)" | Add-Content -LiteralPath $logPath
  & $ffmpeg -hide_banner -nostats -y -i $source.FullName -map 0:v:0 -map 0:a? -vf "scale='min(1920,iw)':-2:flags=lanczos" -c:v libx264 -preset medium -crf 21 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 192k $partial 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $partial)) {
    Move-Item -LiteralPath $partial -Destination $output -Force
    "[$(Get-Date)] Browser copy completed: $output" | Add-Content -LiteralPath $logPath
  } else {
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    "[$(Get-Date)] Browser copy failed: $($source.FullName)" | Add-Content -LiteralPath $logPath
  }
}
