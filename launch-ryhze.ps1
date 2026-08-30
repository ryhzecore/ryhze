$site = Join-Path $PSScriptRoot 'index.html'
$app = Join-Path $PSScriptRoot 'Ryhze.exe'

if (-not (Test-Path -LiteralPath $site)) {
  Add-Type -AssemblyName PresentationFramework
  [System.Windows.MessageBox]::Show('Ryhze could not find index.html.', 'Ryhze') | Out-Null
  exit 1
}

if (Test-Path -LiteralPath $app) {
  Start-Process -FilePath $app -WorkingDirectory $PSScriptRoot
  exit 0
}

$edgeCandidates = @(
  'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
  'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
  (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
  (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

if (-not $edgeCandidates) {
  Add-Type -AssemblyName PresentationFramework
  [System.Windows.MessageBox]::Show('Microsoft Edge is required to open the Ryhze desktop app.', 'Ryhze') | Out-Null
  exit 1
}

$uri = 'file:///C:/Test123/index.html'
Start-Process -FilePath $edgeCandidates[0] -ArgumentList @("--app=$uri", '--new-window', '--start-maximized')
