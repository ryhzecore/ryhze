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
