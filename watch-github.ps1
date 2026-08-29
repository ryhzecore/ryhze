param(
  [string]$Root = $PSScriptRoot
)

# Publishes project changes after the file system reports a change and it has settled.
Set-Location -LiteralPath $Root
$watcher = [System.IO.FileSystemWatcher]::new($Root)
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'
$watcher.EnableRaisingEvents = $true

foreach ($eventName in 'Changed', 'Created', 'Deleted', 'Renamed') {
  Register-ObjectEvent -InputObject $watcher -EventName $eventName | Out-Null
}

$pending = $true
$lastChange = (Get-Date).AddMilliseconds(-1200)
while ($true) {
  $event = Wait-Event -Timeout 1
  if ($event) {
    $path = $event.SourceEventArgs.FullPath
    Remove-Event -EventIdentifier $event.EventIdentifier -ErrorAction SilentlyContinue
    if ($path -notmatch '[\\/]\.git([\\/]|$)') {
      $pending = $true
      $lastChange = Get-Date
    }
  }

  if ($pending -and ((Get-Date) - $lastChange).TotalMilliseconds -ge 1200) {
    $pending = $false
    git add -A
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
      git commit -m "Auto-sync Ryhze updates"
      if ($LASTEXITCODE -eq 0) { git push origin main }
    }
  }
}
