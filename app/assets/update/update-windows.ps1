param(
  [Parameter(Mandatory=$true)][string]$Installer,
  [Parameter(Mandatory=$true)][string]$InstallDir,
  [Parameter(Mandatory=$true)][int]$AppProcessId,
  [Parameter(Mandatory=$true)][string]$ExpectedHash,
  [Parameter(Mandatory=$true)][string]$ExpectedVersion,
  [Parameter(Mandatory=$true)][string]$ReadyFile
)
$ErrorActionPreference = 'Stop'
$logPath = Join-Path (Split-Path $Installer -Parent) 'install.log'
$handoffReady = $false
try {
  $Installer = [IO.Path]::GetFullPath($Installer).Replace('/', '\')
  $InstallDir = [IO.Path]::GetFullPath($InstallDir).Replace('/', '\')
  $appExe = Join-Path $InstallDir 'ryhze.exe'
  if (!(Test-Path -LiteralPath $appExe)) { throw 'Ryhze installation was not found.' }
  if ((Get-FileHash -LiteralPath $Installer -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'The downloaded update could not be verified.' }
  [IO.File]::WriteAllText($ReadyFile, 'ready')
  $handoffReady = $true
  $running = Get-Process -Id $AppProcessId -ErrorAction SilentlyContinue
  if ($running -and $running.Path -eq $appExe) {
    if (!$running.WaitForExit(60000)) { throw 'Ryhze is still running. Close it and try the update again.' }
  }
  Start-Sleep -Milliseconds 1000
  # NSIS requires /D to be last, without enclosing quotes even for paths with spaces.
  $setup = Start-Process -FilePath $Installer -ArgumentList "/S /D=$InstallDir" -WindowStyle Hidden -Wait -PassThru
  if ($setup.ExitCode -ne 0) { throw "The installer could not finish (code $($setup.ExitCode))." }
  if ((Get-Item -LiteralPath $appExe).VersionInfo.ProductVersion -ne $ExpectedVersion) { throw 'The installed version could not be confirmed.' }
  "Installed $ExpectedVersion successfully." | Set-Content -LiteralPath $logPath
  Start-Process -FilePath $appExe -WorkingDirectory $InstallDir -WindowStyle Normal
} catch {
  $_.Exception.Message | Set-Content -LiteralPath $logPath
  if (!$handoffReady) {
    [IO.File]::WriteAllText($ReadyFile, 'error')
  } else {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("The update did not finish. $($_.Exception.Message) Open Ryhze to try again.", 'Ryhze update') | Out-Null
  }
}
