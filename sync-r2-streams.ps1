param(
  [string]$Root = $PSScriptRoot,
  [string]$Bucket = 'ryhze-streams'
)

$ErrorActionPreference = 'Stop'
$s3Uploader = Join-Path $Root 'sync-r2-s3.mjs'
if ($env:R2_ACCESS_KEY_ID -and $env:R2_SECRET_ACCESS_KEY -and (Test-Path -LiteralPath $s3Uploader)) {
  Write-Host 'Using multipart S3 uploader for large R2 objects.'
  node $s3Uploader $Root
  exit $LASTEXITCODE
}

$mediaExtensions = @('.mp4', '.webm', '.m4v', '.mov', '.ogv', '.ogg', '.m4a', '.mp3', '.wav', '.aac')
$ffprobe = Join-Path $Root 'tools\ffmpeg-9.0.1-essentials_build\bin\ffprobe.exe'

function Test-MediaFile([System.IO.FileInfo]$File) {
  if ($File.Length -le 0) { return $false }
  if ($File.Extension.ToLowerInvariant() -eq '.mp4' -and (Test-Path -LiteralPath $ffprobe)) {
    & $ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 $File.FullName *> $null
    return $LASTEXITCODE -eq 0
  }
  return $true
}

Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object {
  $_.FullName -match '\\(Films|Games)\\' -and $mediaExtensions -contains $_.Extension.ToLowerInvariant()
} | ForEach-Object {
  if (-not (Test-MediaFile $_)) {
    Write-Warning "Skipping incomplete media file: $($_.FullName)"
    return
  }
  # Prefer a validated browser-compatible conversion when it exists; this avoids
  # uploading both the HEVC source and its H.264/AAC fallback copy.
  if ($_.BaseName -notmatch '-web$') {
    $web = Join-Path $_.DirectoryName ($_.BaseName + '-web' + $_.Extension)
    if (Test-Path -LiteralPath $web) {
      $webInfo = Get-Item -LiteralPath $web
      if (Test-MediaFile $webInfo) { return }
    }
  }
  $key = $_.FullName.Substring($Root.Length + 1).Replace('\', '/')
  Write-Host "Uploading $key"
  npx wrangler r2 object put "$Bucket/$key" --file $_.FullName --remote
  if ($LASTEXITCODE -ne 0) { throw "Upload failed: $key" }
}

Write-Host 'R2 backup upload complete.'
