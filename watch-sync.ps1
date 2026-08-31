param([string]$Root = $PSScriptRoot)

$ErrorActionPreference = 'Continue'
Set-Location -LiteralPath $Root
$watchPaths = @('Films', 'Games', 'assets', 'menu') | ForEach-Object { Join-Path $Root $_ } | Where-Object { Test-Path -LiteralPath $_ }
$watchers = foreach ($path in $watchPaths) {
  $w = [System.IO.FileSystemWatcher]::new($path)
  $w.IncludeSubdirectories = $true
  $w.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'
  $w.EnableRaisingEvents = $true
  foreach ($name in 'Changed','Created','Deleted','Renamed') { Register-ObjectEvent -InputObject $w -EventName $name | Out-Null }
  $w
}

function Invoke-Publish {
  & (Join-Path $Root 'sync-library.ps1') -Root $Root | Out-Null
  git add -A
  git diff --cached --quiet
  if ($LASTEXITCODE -ne 0) {
    git commit -m 'Auto-sync Ryhze updates' | Out-Null
    if ($LASTEXITCODE -eq 0) { git push origin main | Out-Null }
  }
  if ($env:R2_ACCESS_KEY_ID -and $env:R2_SECRET_ACCESS_KEY) {
    node (Join-Path $Root 'sync-r2-s3.mjs') | Out-Null
  }
}

$lastLocal = [datetime]::MinValue
$lastRemoteCheck = [datetime]::MinValue
$busy = $false
while ($true) {
  $event = Wait-Event -Timeout 2
  if ($event) {
    $path = $event.SourceEventArgs.FullPath
    Remove-Event -EventIdentifier $event.EventIdentifier -ErrorAction SilentlyContinue
    if ($path -notmatch '[\\/]\.git([\\/]|$)' -and $path -notmatch 'mobile-conversion.*\.log$') { $lastLocal = Get-Date }
  }

  if (-not $busy -and $lastLocal -ne [datetime]::MinValue -and ((Get-Date) - $lastLocal).TotalSeconds -ge 2) {
    $busy = $true; $lastLocal = [datetime]::MinValue
    Invoke-Publish
    $busy = $false
  }

  if (-not $busy -and ((Get-Date) - $lastRemoteCheck).TotalSeconds -ge 30) {
    $lastRemoteCheck = Get-Date
    git fetch origin main | Out-Null
    $head = git rev-parse HEAD 2>$null
    $remote = git rev-parse origin/main 2>$null
    if ($head -and $remote -and $head -ne $remote) {
      $dirty = git status --porcelain
      if (-not $dirty) {
        $busy = $true
        git pull --ff-only origin main | Out-Null
        Invoke-Publish
        $busy = $false
      }
    }
  }
}
