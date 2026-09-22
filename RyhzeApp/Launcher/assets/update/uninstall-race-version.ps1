param(
 [Parameter(Mandatory=$true)][string]$Root,
 [Parameter(Mandatory=$true)][string]$BuildId,
 [Parameter(Mandatory=$true)][string]$Executable,
 [Parameter(Mandatory=$true)][string]$Version,
 [string]$ManifestSha256,
 [string]$Archive,
 [string]$Sha256
)
$ErrorActionPreference='Stop'
$changed=$false
$leases=[Collections.Generic.List[object]]::new()
$files=[Collections.Generic.List[object]]::new()
try {
 if($BuildId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,120}$' -or $Version -notmatch '^\d+\.\d+\.\d+$'){throw 'Invalid release identity.'}
 $installRoot=[IO.Path]::GetFullPath($Root).TrimEnd('\')
 if(!$installRoot.EndsWith('\RACE\versions',[StringComparison]::OrdinalIgnoreCase)){throw 'Not an App-managed versions directory.'}
 $destination=[IO.Path]::GetFullPath((Join-Path $installRoot $BuildId))
 $packageRoot=Join-Path $destination $BuildId
 $expectedExe=Join-Path $packageRoot 'RACE.exe'
 if(!$destination.StartsWith($installRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFullPath($Executable) -ne $expectedExe){throw 'Selected executable is not owned by this managed installation.'}
 if(!(Test-Path -LiteralPath $destination)){Write-Output 'This managed installation is already removed.';exit 0}
 Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using Microsoft.Win32.SafeHandles;
public sealed class RaceRemovalLease : IDisposable {
 [StructLayout(LayoutKind.Sequential)] struct Info { public uint Attributes, CreationLow, CreationHigh, AccessLow, AccessHigh, WriteLow, WriteHigh, Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow; }
 [StructLayout(LayoutKind.Sequential)] struct Disposition { public byte Delete; }
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFile(string path,uint access,uint share,IntPtr security,uint mode,uint flags,IntPtr template);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandle(SafeFileHandle handle,out Info info);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetFileInformationByHandle(SafeFileHandle handle,int kind,ref Disposition info,uint size);
 SafeFileHandle handle; FileStream stream;
 public string Path {get;private set;}
 public RaceRemovalLease(string path,bool directory,bool deletable) {
  Path=path;
  var nativePath=path.StartsWith(@"\\?\")?path:path.StartsWith(@"\\")?@"\\?\UNC\"+path.Substring(2):@"\\?\"+path;
  handle=CreateFile(nativePath,(directory?0x80u:0x80000000u)|(deletable?0x10000u:0u),directory?3u:1u,IntPtr.Zero,3,0x00200000u|(directory?0x02000000u:0u),IntPtr.Zero);
  if(handle.IsInvalid) { handle.Dispose(); throw new Win32Exception(Marshal.GetLastWin32Error(),"Close processes using this installation and check file permissions."); }
  Info info;
  if(!GetFileInformationByHandle(handle,out info) || (info.Attributes&0x400)!=0 || ((info.Attributes&0x10)!=0)!=directory) { handle.Dispose(); throw new IOException("Redirected or unexpected installation paths are not removable."); }
  if(!directory) stream=new FileStream(handle,FileAccess.Read);
 }
 public long Length {get{return stream.Length;}}
 public string Hash() {stream.Position=0;using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-","").ToLowerInvariant();}
 public string Text() {stream.Position=0;using(var reader=new StreamReader(stream,System.Text.Encoding.UTF8,true,1024,true))return reader.ReadToEnd();}
 public void Remove() {var d=new Disposition{Delete=1};if(!SetFileInformationByHandle(handle,4,ref d,1))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not remove an owned installation item.");Dispose();}
 public void Dispose() {if(stream!=null){stream.Dispose();stream=null;}if(handle!=null){handle.Dispose();handle=null;}}
}
'@
 # Lock every ancestor against rename/reparse replacement for the entire operation.
 $ancestors=[Collections.Generic.List[string]]::new()
 $cursor=$installRoot
 while($cursor){$ancestors.Insert(0,$cursor);$parent=[IO.Directory]::GetParent($cursor);$cursor=if($parent){$parent.FullName}else{$null}}
 foreach($path in $ancestors){$leases.Add([RaceRemovalLease]::new($path,$true,$false))}
 foreach($process in Get-CimInstance Win32_Process){
  if($process.ExecutablePath -and [IO.Path]::GetFullPath($process.ExecutablePath).StartsWith($destination+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'This RACE version is running. Close its editor and runtime before uninstalling.'}
 }
 $directories=[Collections.Generic.List[object]]::new()
 $pending=[Collections.Generic.Queue[string]]::new();$pending.Enqueue($destination)
 $actualFiles=[Collections.Generic.List[string]]::new()
 while($pending.Count){
  $path=$pending.Dequeue()
  $lease=[RaceRemovalLease]::new($path,$true,$true);$leases.Add($lease);$directories.Add($lease)
  $nativePath=if($path.StartsWith('\\')){'\\?\UNC\'+$path.Substring(2)}else{'\\?\'+$path}
  foreach($item in Get-ChildItem -LiteralPath $nativePath -Force){
   if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Redirected installation paths are not removable.'}
   $itemPath=if($item.FullName.StartsWith('\\?\UNC\')){'\\'+$item.FullName.Substring(8)}else{$item.FullName.Substring(4)}
   if($item.PSIsContainer){$pending.Enqueue($itemPath)}else{$actualFiles.Add($itemPath)}
  }
 }
 $manifestPath=Join-Path $packageRoot 'package-manifest.json'
 # Older App installs have no stored manifest hash: authenticate their original ZIP.
 if(!$ManifestSha256){
  if(!$Archive -or $Sha256 -notmatch '^[a-f0-9]{64}$'){throw 'This older installation needs its verified release archive before removal.'}
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  Add-Type -AssemblyName System.IO.Compression
  $archiveStream=[IO.File]::Open($Archive,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
  try {
   $hasher=[Security.Cryptography.SHA256]::Create()
   try {$actual=[BitConverter]::ToString($hasher.ComputeHash($archiveStream)).Replace('-','').ToLowerInvariant()}finally{$hasher.Dispose()}
   if($actual -ne $Sha256){throw 'Original release archive checksum mismatch.'}
   $archiveStream.Position=0
   $zip=[IO.Compression.ZipArchive]::new($archiveStream,[IO.Compression.ZipArchiveMode]::Read,$true)
   try {
    $entries=@($zip.Entries | Where-Object {$_.FullName.Replace('\','/') -eq "$BuildId/package-manifest.json"})
    if($entries.Count -ne 1 -or $entries[0].Length -gt 4MB){throw 'Original release manifest is invalid.'}
    $entryStream=$entries[0].Open();$hasher=[Security.Cryptography.SHA256]::Create()
    try {$ManifestSha256=[BitConverter]::ToString($hasher.ComputeHash($entryStream)).Replace('-','').ToLowerInvariant()}finally{$hasher.Dispose();$entryStream.Dispose()}
   }finally{$zip.Dispose()}
  }finally{$archiveStream.Dispose()}
 }
 if($ManifestSha256 -notmatch '^[a-f0-9]{64}$'){throw 'Invalid installation ownership checksum.'}
 $manifestLease=[RaceRemovalLease]::new($manifestPath,$false,$true);$files.Add($manifestLease)
 if($manifestLease.Length -gt 4MB -or $manifestLease.Hash() -ne $ManifestSha256){throw 'The ownership manifest changed. No files can be safely removed.'}
 $manifest=$manifestLease.Text() | ConvertFrom-Json
 if($manifest.product -ne 'RACE' -or $manifest.schemaVersion -ne 1 -or $manifest.version -ne $Version -or !$manifest.files.Count -or $manifest.files.Count -gt 10000){throw 'Cannot verify this installation ownership manifest.'}
 $owned=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
 $ownedDirectories=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
 $ownedDirectories.Add($destination) | Out-Null;$ownedDirectories.Add($packageRoot) | Out-Null
 foreach($file in $manifest.files){
  $relative=[string]$file.path
  if(!$relative -or [IO.Path]::IsPathRooted($relative) -or $relative.Contains(':') -or ($relative -split '[/\\]' | Where-Object {$_ -in @('.','..') -or $_ -match '[. ]$'})){throw 'Unsafe ownership manifest path.'}
  $path=[IO.Path]::GetFullPath((Join-Path $packageRoot $relative))
  if(!$path.StartsWith($packageRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or $owned.ContainsKey($path) -or $file.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or $file.bytes -lt 0){throw 'Invalid ownership manifest entry.'}
  $owned.Add($path,$file)
  $parent=[IO.Path]::GetDirectoryName($path)
  while($parent.Length -ge $packageRoot.Length){$ownedDirectories.Add($parent)|Out-Null;$parent=[IO.Path]::GetDirectoryName($parent)}
 }
 if(!$owned.ContainsKey($expectedExe)){throw 'The manifest does not own the selected executable.'}
 foreach($dir in $directories){if(!$ownedDirectories.Contains($dir.Path)){throw 'Extra folders were found. Move your projects or data outside this installation before uninstalling.'}}
 foreach($path in $actualFiles){if($path -ne $manifestPath -and !$owned.ContainsKey($path)){throw 'Extra files were found. Move your projects or data outside this installation before uninstalling.'}}
 # Include any runtime executable in the selected installation, not only RACE.exe.
 $exeNames=@($owned.Keys | Where-Object {$_ -like '*.exe'} | ForEach-Object {[IO.Path]::GetFileName($_)})
 foreach($process in Get-CimInstance Win32_Process){
  if($process.ExecutablePath -and [IO.Path]::GetFullPath($process.ExecutablePath).StartsWith($destination+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'This RACE version is running. Close its editor and runtime before uninstalling.'}
  if(!$process.ExecutablePath -and $process.Name -in $exeNames){throw 'Cannot verify whether this RACE version is running. Close its editor and runtime first.'}
 }
 # Acquire delete rights and deny writes to every file before deleting any file.
 foreach($path in ($actualFiles | Where-Object {$_ -ne $manifestPath} | Sort-Object @{Expression={if($_ -eq $expectedExe){1}else{0}}}, @{Expression={$_}})){
  $lease=[RaceRemovalLease]::new($path,$false,$true);$files.Add($lease)
  if($path -ne $manifestPath){$record=$owned[$path];if($lease.Length -ne $record.bytes -or $lease.Hash() -ne $record.sha256){throw 'Modified files were found. Preserve your changes outside this installation before uninstalling.'}}
 }
 $changed=$true
 foreach($file in ($files | Sort-Object @{Expression={if($_.Path -eq $manifestPath){2}elseif($_.Path -eq $expectedExe){1}else{0}}})){$file.Remove()}
 foreach($dir in ($directories | Sort-Object {$_.Path.Length} -Descending)){$dir.Remove()}
 Write-Output 'Selected RACE version uninstalled. Other versions, projects and user data were preserved.'
} catch {
 $prefix=if($changed){'Uninstall incomplete. Some owned app files may have been removed; other data was preserved. '}else{'Uninstall stopped before removing any files. '}
 [Console]::Error.WriteLine($prefix+$_.Exception.Message)
 exit 1
} finally {
 foreach($file in $files){$file.Dispose()}
 for($i=$leases.Count-1;$i -ge 0;$i--){$leases[$i].Dispose()}
}
