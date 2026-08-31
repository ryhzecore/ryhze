$ErrorActionPreference = 'Stop'

$caddy = 'C:\Users\crnjl\AppData\Local\Microsoft\WinGet\Packages\CaddyServer.Caddy_Microsoft.Winget.Source_8wekyb3d8bbwe\caddy.exe'
$caddyConfig = 'C:\Test123\video-server\local.Caddyfile'
$cloudflared = 'C:\Program Files (x86)\cloudflared\cloudflared.exe'
$tunnelConfig = 'C:\Users\crnjl\.cloudflared\config.yml'

if (-not (Test-Path -LiteralPath $caddy)) { throw "Caddy was not found: $caddy" }
if (-not (Test-Path -LiteralPath $caddyConfig)) { throw "Caddy config was not found: $caddyConfig" }
if (-not (Test-Path -LiteralPath $cloudflared)) { throw "Cloudflared was not found: $cloudflared" }
if (-not (Test-Path -LiteralPath $tunnelConfig)) { throw "Tunnel config was not found: $tunnelConfig" }

if (-not (Get-Process caddy -ErrorAction SilentlyContinue)) {
  Start-Process -FilePath $caddy -ArgumentList @('run', '--config', $caddyConfig) -WindowStyle Hidden
}

Start-Sleep -Seconds 5

if (-not (Get-Process cloudflared -ErrorAction SilentlyContinue)) {
  Start-Process -FilePath $cloudflared -ArgumentList @('tunnel', '--config', $tunnelConfig, 'run') -WindowStyle Hidden
}

# Keep GitHub, the local library index, and R2 synchronized in the background.
$syncScript = 'C:\Test123\watch-sync.ps1'
$syncRunning = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -like "*$syncScript*" }
if (-not $syncRunning) {
  Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $syncScript) -WindowStyle Hidden
}
