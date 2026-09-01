param(
  [string]$Root = $PSScriptRoot,
  [string]$VideoBaseUrl = $(if ($env:RYHZE_VIDEO_BASE_URL) { $env:RYHZE_VIDEO_BASE_URL } else { 'https://video.ryhze.com' }),
  [string]$R2VideoBaseUrl = $(if ($env:RYHZE_R2_VIDEO_BASE_URL) { $env:RYHZE_R2_VIDEO_BASE_URL } else { 'https://pub-7e02d448a41c4dbabd5711a9c5f799f0.r2.dev' })
)

$VideoBaseUrl = $VideoBaseUrl.TrimEnd('/')
$R2VideoBaseUrl = $R2VideoBaseUrl.TrimEnd('/')

$imageExtensions = @('.png', '.jpg', '.jpeg', '.webp', '.avif')
$streamExtensions = @('.mp4', '.webm', '.ogv', '.ogg', '.m4v', '.mkv', '.mp3', '.m4a', '.wav', '.aac')
$installerExtensions = @('.exe', '.msi', '.msix', '.appx')

function Get-NoteValue([string[]]$Notes, [string]$Label) {
  $pattern = '^\s*' + [regex]::Escape($Label) + '\s*:\s*(.*)$'
  $line = $Notes | Where-Object { $_ -match $pattern } | Select-Object -First 1
  if ($line) { return ([regex]::Match($line, $pattern)).Groups[1].Value.Trim() }
  return ''
}

function Get-RelativeUrl([string]$FilePath) {
  $relativePath = $FilePath.Substring($Root.Length + 1)
  return (($relativePath -split '[\\/]') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
}

function Get-AssetUrl($File) {
  if (-not $File) { return '' }
  # New or replaced artwork receives a URL version so browsers fetch it after an approved update.
  return "$(Get-RelativeUrl $File.FullName)?v=$($File.LastWriteTimeUtc.Ticks)"
}

function Get-StreamItems($Files) {
  $mediaFiles = @($Files | Where-Object { $_ -and $streamExtensions -contains $_.Extension.ToLowerInvariant() })
  $browserFiles = @($mediaFiles | Where-Object { $_.BaseName -match '-web$' })
  if ($browserFiles.Count) { $mediaFiles = $browserFiles }
  @($mediaFiles |
    Sort-Object Name | ForEach-Object {
      $localUrl = Get-RelativeUrl $_.FullName
      [PSCustomObject]@{
        url = $localUrl
        publicUrl = "$VideoBaseUrl/$localUrl"
        backupPublicUrl = "$R2VideoBaseUrl/$localUrl"
        type = $_.Extension.ToLowerInvariant()
      }
    })
}

function Get-InstallerItem([string]$TitleFolder) {
  $downloadPath = Join-Path $TitleFolder 'Download'
  if (-not (Test-Path -LiteralPath $downloadPath)) { return $null }
  $file = Get-ChildItem -LiteralPath $downloadPath -File -Recurse |
    Where-Object { $installerExtensions -contains $_.Extension.ToLowerInvariant() } |
    Select-Object -First 1
  if (-not $file) { return $null }
  [PSCustomObject]@{ name = $file.Name; url = Get-RelativeUrl $file.FullName }
}

function Get-RyhzeTitles([string]$LibraryType) {
  $libraryPath = Join-Path $Root $LibraryType
  if (-not (Test-Path -LiteralPath $libraryPath)) { return @() }

  @(
    Get-ChildItem -LiteralPath $libraryPath -Directory | ForEach-Object {
      $titleFolder = $_
      $thumbnailPath = Join-Path $titleFolder.FullName 'Thumbnail'
      $thumbnail = if (Test-Path -LiteralPath $thumbnailPath) {
        Get-ChildItem -LiteralPath $thumbnailPath -File |
          Where-Object { $imageExtensions -contains $_.Extension.ToLowerInvariant() } |
          Select-Object -First 1
      }

      if ($thumbnail) {
        $imagesPath = Join-Path $titleFolder.FullName 'Images'
        $exclusiveImages = if (Test-Path -LiteralPath $imagesPath) {
          Get-ChildItem -LiteralPath $imagesPath -File |
            Where-Object { $imageExtensions -contains $_.Extension.ToLowerInvariant() } |
          ForEach-Object { Get-AssetUrl $_ }
        } else { @() }
        
        $streamPath = @(
          Join-Path $titleFolder.FullName 'Stream'
          Join-Path $titleFolder.FullName 'Streams'
        ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        
        $notesPath = Join-Path $titleFolder.FullName 'notes.txt'
        $notes = if (Test-Path -LiteralPath $notesPath) { Get-Content -LiteralPath $notesPath } else { @() }
        
        # Check if sub-directories exist inside Streams folder
        $hasSubdirectories = if ($streamPath) { (Get-ChildItem -LiteralPath $streamPath -Directory).Count -gt 0 } else { $false }
        $noteType = Get-NoteValue $notes 'Type'
        
        # Automatically mark as Series if notes explicitly say so OR if subfolders exist
        $mediaType = if ($noteType -eq 'Series' -or $hasSubdirectories) { 'Series' } else { 'Movie' }
        
        $streamFiles = if ($streamPath -and $mediaType -eq 'Movie') { Get-StreamItems (Get-ChildItem -LiteralPath $streamPath -File) } else { @() }
        $seasons = @()
        
        if ($mediaType -eq 'Series' -and $streamPath) {
          $seasonItems = @()
          foreach ($seasonFolder in (Get-ChildItem -LiteralPath $streamPath -Directory | Sort-Object Name)) {
            $episodeItems = @()
            $episodeFolders = @(Get-ChildItem -LiteralPath $seasonFolder.FullName -Directory | Sort-Object Name)
            
            if ($episodeFolders.Count -gt 0) {
              foreach ($episodeFolder in $episodeFolders) {
                $episodeObject = [PSCustomObject]@{ title = $episodeFolder.Name; streams = $null }
                $episodeObject.streams = @(Get-StreamItems (Get-ChildItem -LiteralPath $episodeFolder.FullName -File -Recurse))
                $episodeItems += $episodeObject
              }
            } else {
              # Fallback: create individual episodes from files directly inside the season folder
              $seasonFiles = @(Get-ChildItem -LiteralPath $seasonFolder.FullName -File | Sort-Object Name)
              if ($seasonFiles.Count -gt 0) {
                $epIndex = 1
                foreach ($file in $seasonFiles) {
                  if ($streamExtensions -contains $file.Extension.ToLowerInvariant()) {
                    $episodeObject = [PSCustomObject]@{ title = "Episode $epIndex"; streams = $null }
                    $episodeObject.streams = @(Get-StreamItems @($file))
                    $episodeItems += $episodeObject
                    $epIndex++
                  }
                }
              }
            }
            
            $seasonObject = [PSCustomObject]@{ title = $seasonFolder.Name; episodes = $null }
            $seasonObject.episodes = $episodeItems
            $seasonItems += $seasonObject
          }
          $seasons = @($seasonItems)
        }
        
        $categories = (Get-NoteValue $notes 'Categories') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $searchTags = (Get-NoteValue $notes 'Search Tags') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $installer = if ($LibraryType -eq 'Games') { Get-InstallerItem $titleFolder.FullName } else { $null }
        
        [PSCustomObject]@{
          title = $titleFolder.Name
          image = Get-AssetUrl $thumbnail
          exclusiveImages = @($exclusiveImages)
          streams = @($streamFiles)
          synopsis = Get-NoteValue $notes 'Synopsis'
          release = Get-NoteValue $notes 'Release'
          licensor = Get-NoteValue $notes 'Licensor'
          mediaType = $mediaType
          seasons = @($seasons)
          categories = @($categories)
          searchTags = @($searchTags)
          installer = $installer
        }
      }
    }
  )
}

function Group-RyhzeTitles($Titles) {
  $groups = [ordered]@{}
  foreach ($title in $Titles) {
    $categories = if ($title.categories.Count) { $title.categories } else { @('Uncategorized') }
    foreach ($category in $categories) {
      if (-not $groups.Contains($category)) { $groups[$category] = [System.Collections.Generic.List[object]]::new() }
      $groups[$category].Add($title) | Out-Null
    }
  }
  @($groups.GetEnumerator() | ForEach-Object { [PSCustomObject]@{ title = $_.Key; items = $_.Value.ToArray() } })
}

$library = [PSCustomObject]@{
  films = @(Group-RyhzeTitles (Get-RyhzeTitles 'Films'))
  games = @(Group-RyhzeTitles (Get-RyhzeTitles 'Games'))
}

$json = $library | ConvertTo-Json -Depth 10
$build = (git rev-parse --short HEAD 2>$null)
if (-not $build) { $build = 'local' }
Set-Content -LiteralPath (Join-Path $Root 'library-data.js') -Value "window.RyhzeLibrary = $json;`nwindow.RyhzeBuild = '$build';`n" -Encoding utf8
Write-Host 'Ryhze library data updated successfully.'
