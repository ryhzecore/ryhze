param([Parameter(Mandatory=$true)][string]$Archive,[Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string]$BuildId,[Parameter(Mandatory=$true)][string]$Entrypoint,[Parameter(Mandatory=$true)][string]$Sha256)
$ErrorActionPreference='Stop'
function LongPath([string]$path){
 if($path.StartsWith('\\?\')){return $path}
 if($path.StartsWith('\\')){return '\\?\UNC\'+$path.Substring(2)}
 return '\\?\'+$path
}
if($BuildId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,120}$' -or $Sha256 -notmatch '^[a-f0-9]{64}$'){throw 'Invalid release identity.'}
if((Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash -ne $Sha256){throw 'Package checksum mismatch.'}
$installRoot=[IO.Path]::GetFullPath($Root).TrimEnd('\')
[IO.Directory]::CreateDirectory((LongPath $installRoot)) | Out-Null
$destination=[IO.Path]::GetFullPath((Join-Path $installRoot $BuildId))
$stage=[IO.Path]::GetFullPath((Join-Path $installRoot ('.staging-'+[Guid]::NewGuid().ToString())))
foreach($target in @($destination,$stage)){if(!$target.StartsWith($installRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Invalid installation destination.'}}
if(Test-Path -LiteralPath $destination){throw 'This build is already installed. Existing versions are never overwritten.'}
function Inside([string]$parent,[string]$relative){
 if([IO.Path]::IsPathRooted($relative) -or $relative.Contains(':') -or ($relative -split '[/\\]') -contains '..'){throw 'Unsafe archive path.'}
 $result=[IO.Path]::GetFullPath((Join-Path $parent $relative))
 if(!$result.StartsWith($parent.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Archive path leaves the installation.'}
 return $result
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead($Archive)
try {
 [IO.Directory]::CreateDirectory((LongPath $stage)) | Out-Null
 $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
 [long]$total=0
 if($zip.Entries.Count -gt 10000){throw 'Too many package files.'}
 foreach($entry in $zip.Entries){
  $target=Inside $stage $entry.FullName
  if(!$names.Add($target)){throw 'Duplicate package path.'}
  if((($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000){throw 'Package links are not allowed.'}
  $total+=$entry.Length
  if($total -gt 4GB){throw 'Expanded package is too large.'}
  if($entry.FullName.EndsWith('/') -or $entry.FullName.EndsWith('\')){[IO.Directory]::CreateDirectory((LongPath $target)) | Out-Null;continue}
  [IO.Directory]::CreateDirectory((LongPath ([IO.Path]::GetDirectoryName($target)))) | Out-Null
  [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(LongPath $target),$false)
 }
 $exe=Inside $stage $Entrypoint
 if(!(Test-Path -LiteralPath $exe -PathType Leaf) -or [IO.Path]::GetFileName($exe) -ne 'RACE.exe'){throw 'RACE executable is missing.'}
 $packageRoot=[IO.Path]::GetDirectoryName($exe)
 $manifest=Get-Content -LiteralPath (Join-Path $packageRoot 'package-manifest.json') -Raw | ConvertFrom-Json
 if($manifest.product -ne 'RACE' -or $manifest.schemaVersion -ne 1 -or !$manifest.files.Count){throw 'Package manifest is invalid.'}
 foreach($file in $manifest.files){
  $item=Inside $packageRoot $file.path
  $longItem=LongPath $item
  if(!(Test-Path -LiteralPath $longItem -PathType Leaf) -or (Get-Item -LiteralPath $longItem).Length -ne $file.bytes -or (Get-FileHash -LiteralPath $longItem -Algorithm SHA256).Hash -ne $file.sha256){throw 'An installed file failed integrity verification.'}
 }
 [IO.Directory]::Move((LongPath $stage),(LongPath $destination))
 Write-Output 'RACE version installed and verified.'
} finally {
 $zip.Dispose()
 if((Test-Path -LiteralPath $stage) -and $stage.StartsWith($installRoot+'\',[StringComparison]::OrdinalIgnoreCase)){Remove-Item -LiteralPath (LongPath $stage) -Recurse -Force}
}
