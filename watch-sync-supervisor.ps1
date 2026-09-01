param([string]$Root = $PSScriptRoot)

$ErrorActionPreference = 'Continue'
$watchScript = Join-Path $Root 'watch-sync.ps1'
$heartbeat = Join-Path $Root 'watch-sync.heartbeat'

function Get-Watcher {
  Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*$watchScript*" }
}

function Start-Watcher {
  Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$watchScript) -WindowStyle Hidden
}

while ($true) {
  # A separate process keeps automatic updates available after a stalled publish.
  $watcher = @(Get-Watcher)
  $heartbeatAge = if (Test-Path -LiteralPath $heartbeat) { ((Get-Date) - (Get-Item -LiteralPath $heartbeat).LastWriteTime).TotalSeconds } else { [double]::PositiveInfinity }
  if ($watcher.Count -eq 0) {
    Start-Watcher
  } elseif ($heartbeatAge -gt 180) {
    $watcher | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
    Start-Watcher
  }
  Start-Sleep -Seconds 30
}
