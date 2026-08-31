param(
  [string]$Root = $PSScriptRoot,
  [string]$Bucket = 'ryhze-streams'
)

$ErrorActionPreference = 'Stop'
$mediaExtensions = @('.mp4', '.webm', '.m4v', '.mov', '.ogv', '.ogg', '.m4a', '.mp3', '.wav', '.aac')

Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object {
  $_.FullName -match '\\(Films|Games)\\' -and $mediaExtensions -contains $_.Extension.ToLowerInvariant()
} | ForEach-Object {
  $key = $_.FullName.Substring($Root.Length + 1).Replace('\', '/')
  Write-Host "Uploading $key"
  npx wrangler r2 object put "$Bucket/$key" --file $_.FullName --remote
  if ($LASTEXITCODE -ne 0) { throw "Upload failed: $key" }
}

Write-Host 'R2 backup upload complete.'
