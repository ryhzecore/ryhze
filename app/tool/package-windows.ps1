$ErrorActionPreference = 'Stop'
$appRoot = Split-Path $PSScriptRoot -Parent
$version = [regex]::Match((Get-Content (Join-Path $appRoot 'pubspec.yaml') -Raw), '(?m)^version: ([0-9.]+)\+').Groups[1].Value
if (!$version) { throw 'A release version is required in pubspec.yaml.' }
$release = Join-Path $appRoot 'build\windows\x64\runner\Release'
if (!(Test-Path (Join-Path $release 'ryhze.exe'))) { throw 'Build the Windows release before packaging.' }
$redistRoot = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC'
$runtime = Get-ChildItem $redistRoot -Directory | Where-Object Name -Match '^14\.' | Sort-Object Name -Descending | Select-Object -First 1
if (!$runtime) { throw 'Microsoft C++ runtime was not found.' }
$crt = Get-ChildItem (Join-Path $runtime.FullName 'x64') -Directory -Filter '*.CRT' | Select-Object -First 1
if (!$crt) { throw 'Microsoft C++ redistributable files were not found.' }
Copy-Item (Join-Path $crt.FullName '*.dll') $release -Force
$output = Join-Path (Split-Path $appRoot -Parent) 'releases'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$archive = Join-Path $output "Ryhze-$version-Windows-Portable.zip"
Compress-Archive -Path (Join-Path $release '*') -DestinationPath $archive -Force
$removeLines = @()
foreach ($file in Get-ChildItem $release -File -Recurse) {
  $relative = $file.FullName.Substring($release.Length + 1)
  $removeLines += 'Delete "$INSTDIR\' + $relative + '"'
}
foreach ($directory in Get-ChildItem $release -Directory -Recurse | Sort-Object { $_.FullName.Length } -Descending) {
  $relative = $directory.FullName.Substring($release.Length + 1)
  $removeLines += 'RMDir "$INSTDIR\' + $relative + '"'
}
[IO.File]::WriteAllLines((Join-Path $PSScriptRoot 'uninstall-files.nsh'), $removeLines, [Text.UTF8Encoding]::new($false))
$compiler = 'C:\Program Files (x86)\NSIS\makensis.exe'
if (!(Test-Path $compiler)) { throw 'NSIS is required to produce the Windows installer.' }
& $compiler "/DVERSION=$version" (Join-Path $PSScriptRoot 'ryhze-setup.nsi')
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
Get-ChildItem $output -File | Where-Object Extension -In '.exe','.zip','.apk','.aab' | Get-FileHash -Algorithm SHA256 | ForEach-Object { [pscustomobject]@{ File = [IO.Path]::GetFileName($_.Path); SHA256 = $_.Hash } } | ConvertTo-Json | Set-Content (Join-Path $output 'SHA256.json') -Encoding UTF8
