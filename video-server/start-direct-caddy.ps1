$ErrorActionPreference = 'Stop'
$caddy = Get-Command caddy -ErrorAction SilentlyContinue
if (-not $caddy) {
  $caddy = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter caddy.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $caddy) { throw 'Caddy is not installed.' }
$caddyPath = if ($caddy -is [System.IO.FileInfo]) { $caddy.FullName } else { $caddy.Source }
$config = Join-Path $PSScriptRoot 'direct.Caddyfile'
& $caddyPath validate --config $config --adapter caddyfile
& $caddyPath run --config $config --adapter caddyfile
