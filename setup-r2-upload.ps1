param([string]$Root = $PSScriptRoot, [switch]$Persist)

$ErrorActionPreference = 'Stop'
$access = Read-Host 'R2 Access Key ID'
$secretSecure = Read-Host 'R2 Secret Access Key' -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretSecure)
try { $secret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }

if ([string]::IsNullOrWhiteSpace($access) -or [string]::IsNullOrWhiteSpace($secret)) {
  throw 'Both R2 credentials are required.'
}
$env:R2_ACCESS_KEY_ID = $access
$env:R2_SECRET_ACCESS_KEY = $secret
if ($Persist) {
  [Environment]::SetEnvironmentVariable('R2_ACCESS_KEY_ID', $access, 'User')
  [Environment]::SetEnvironmentVariable('R2_SECRET_ACCESS_KEY', $secret, 'User')
}
Push-Location $Root
try { node .\sync-r2-s3.mjs }
finally {
  if (-not $Persist) {
    Remove-Item Env:R2_ACCESS_KEY_ID -ErrorAction SilentlyContinue
    Remove-Item Env:R2_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue
  }
  Pop-Location
}
