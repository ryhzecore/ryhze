$ErrorActionPreference = 'Stop'
$appRoot = Split-Path $PSScriptRoot -Parent
$metadata = Join-Path $appRoot '.flutter-plugins-dependencies'
$plugins = Get-Content -LiteralPath $metadata -Raw | ConvertFrom-Json
$linkRoot = Join-Path $appRoot 'windows\flutter\ephemeral\.plugin_symlinks'
New-Item -ItemType Directory -Force -Path $linkRoot | Out-Null
foreach ($plugin in $plugins.plugins.windows) {
  $link = Join-Path $linkRoot $plugin.name
  if (!(Test-Path -LiteralPath $link)) { New-Item -ItemType Junction -Path $link -Target $plugin.path | Out-Null }
}
