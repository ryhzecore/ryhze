$FlutterArgs = $args
$ErrorActionPreference = 'Stop'
$workspace = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$flutterSdk = Join-Path $workspace '.tools\flutter\bin'
$pwshPackage = Get-AppxPackage Microsoft.PowerShell -ErrorAction SilentlyContinue | Select-Object -First 1
if ($pwshPackage) { $env:PATH = $pwshPackage.InstallLocation + ';' + $env:PATH }
$env:PATH = $flutterSdk + ';' + $env:PATH
$androidSdk = Join-Path $workspace '.tools\android-sdk'
if (Test-Path $androidSdk) { $env:ANDROID_HOME = $androidSdk; $env:ANDROID_SDK_ROOT = $androidSdk }
$jdk = Get-ChildItem (Join-Path $workspace '.tools\java') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
if ($jdk) { $env:JAVA_HOME = $jdk.FullName; $env:PATH = (Join-Path $jdk.FullName 'bin') + ';' + $env:PATH }
Push-Location (Split-Path $PSScriptRoot -Parent)
try { & (Join-Path $flutterSdk 'flutter.bat') @FlutterArgs; exit $LASTEXITCODE } finally { Pop-Location }
