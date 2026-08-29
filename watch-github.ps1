param(
  [string]$Root = $PSScriptRoot
)

# Publishes non-ignored Ryhze project changes after they have been quiet for a few seconds.
Set-Location -LiteralPath $Root
while ($true) {
  Start-Sleep -Seconds 8
  $changes = git status --porcelain
  if (-not $changes) { continue }

  Start-Sleep -Seconds 5
  git add -A
  $staged = git diff --cached --quiet
  if ($LASTEXITCODE -eq 0) { continue }

  git commit -m "Auto-sync Ryhze updates"
  if ($LASTEXITCODE -eq 0) { git push origin main }
}
