param([Parameter(Mandatory=$true)][string]$InstallDirectory)
$ErrorActionPreference = 'Stop'
$installRoot = [IO.Path]::GetFullPath($InstallDirectory).TrimEnd('\')
$manifestPath = Join-Path $installRoot 'BuildManifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([IO.Path]::GetFullPath($manifest.runtime).TrimEnd('\') -ine $installRoot) { throw 'Only the published RACE runtime can be registered.' }
foreach ($required in @('race_editor.exe','race_editor_bridge.dll','data\app.so')) {
    $entry = @($manifest.files | Where-Object path -EQ $required)
    if ($entry.Count -ne 1) { throw "Missing manifest identity: $required" }
    $file = Get-Item -LiteralPath (Join-Path $installRoot $required)
    if ($file.Length -ne $entry[0].bytes -or (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ine $entry[0].sha256) { throw "RACE file verification failed: $required" }
}
$versionText = (Get-Item -LiteralPath (Join-Path $installRoot 'race_editor.exe')).VersionInfo.ProductVersion
if ($versionText -notmatch '^(\d+\.\d+\.\d+)\+(\d+)$') { throw 'RACE executable version is invalid.' }
$version = $Matches[1]
$buildNumber = [int]$Matches[2]
if ($buildNumber -le 0) { throw 'RACE build must be positive.' }
$registration = 'HKCU:\Software\RACE'
New-Item -Path $registration -Force | Out-Null
New-ItemProperty -LiteralPath $registration -Name InstallDir -Value $installRoot -PropertyType String -Force | Out-Null
New-ItemProperty -LiteralPath $registration -Name Version -Value $version -PropertyType String -Force | Out-Null
New-ItemProperty -LiteralPath $registration -Name Build -Value $buildNumber -PropertyType DWord -Force | Out-Null
New-ItemProperty -LiteralPath $registration -Name PublishedBuild -Value ([string]$manifest.build) -PropertyType String -Force | Out-Null
Write-Output "Registered RACE $version+$buildNumber at $installRoot"
