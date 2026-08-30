param(
  [string]$Root = $PSScriptRoot,
  [string]$VideoBaseUrl = $(if ($env:RYHZE_VIDEO_BASE_URL) { $env:RYHZE_VIDEO_BASE_URL } else { 'https://video.ryhze.com' })
)

$VideoBaseUrl = $VideoBaseUrl.TrimEnd('/')

$imageExtensions = @('.png', '.jpg', '.jpeg', '.webp', '.avif')
$streamExtensions = @('.mp4', '.webm', '.ogv', '.ogg', '.m4v', '.mkv', '.mp3', '.m4a', '.wav', '.aac')

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

function Get-StreamItems($Files) {
  @($Files | Where-Object { $_ -and $streamExtensions -contains $_.Extension.ToLowerInvariant() } |
    Sort-Object Name | ForEach-Object {
      $localUrl = Get-RelativeUrl $_.FullName
      [PSCustomObject]@{
        url = $localUrl
        publicUrl = "$VideoBaseUrl/$localUrl"
        type = $_.Extension.ToLowerInvariant()
      }
    })
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
            ForEach-Object { Get-RelativeUrl $_.FullName }
        } else { @() }
        $streamPath = @(
          Join-Path $titleFolder.FullName 'Stream'
          Join-Path $titleFolder.FullName 'Streams'
        ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        $notesPath = Join-Path $titleFolder.FullName 'notes.txt'
        $notes = if (Test-Path -LiteralPath $notesPath) { Get-Content -LiteralPath $notesPath } else { @() }
        $mediaType = if ((Get-NoteValue $notes 'Type') -eq 'Series') { 'Series' } else { 'Movie' }
        $streamFiles = if ($streamPath) { Get-StreamItems (Get-ChildItem -LiteralPath $streamPath -File) } else { @() }
        $seasons = @()
        if ($mediaType -eq 'Series' -and $streamPath) {
          $seasonItems = @()
          foreach ($seasonFolder in (Get-ChildItem -LiteralPath $streamPath -Directory | Sort-Object Name)) {
            $episodeItems = @()
            $episodeFolders = @(Get-ChildItem -LiteralPath $seasonFolder.FullName -Directory | Sort-Object Name)
            if ($episodeFolders.Count) {
              foreach ($episodeFolder in $episodeFolders) {
                $episodeObject = [PSCustomObject]@{ title = $episodeFolder.Name; streams = $null }
                $episodeObject.streams = @(Get-StreamItems (Get-ChildItem -LiteralPath $episodeFolder.FullName -File -Recurse))
                $episodeItems += $episodeObject
              }
            } else {
              $episodeObject = [PSCustomObject]@{ title = 'Episode 1'; streams = $null }
              $episodeObject.streams = @(Get-StreamItems (Get-ChildItem -LiteralPath $seasonFolder.FullName -File -Recurse))
              $episodeItems += $episodeObject
            }
            $seasonObject = [PSCustomObject]@{ title = $seasonFolder.Name; episodes = $null }
            $seasonObject.episodes = $episodeItems
            $seasonItems += $seasonObject
          }
          $seasons = @($seasonItems)
        }
        $categories = (Get-NoteValue $notes 'Categories') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $searchTags = (Get-NoteValue $notes 'Search Tags') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        [PSCustomObject]@{
          title = $titleFolder.Name
          image = Get-RelativeUrl $thumbnail.FullName
          exclusiveImages = @($exclusiveImages)
          streams = @($streamFiles)
          synopsis = Get-NoteValue $notes 'Synopsis'
          release = Get-NoteValue $notes 'Release'
          mediaType = $mediaType
          seasons = @($seasons)
          categories = @($categories)
          searchTags = @($searchTags)
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
      $groups[$category].Add($title)
    }
  }
  @($groups.GetEnumerator() | ForEach-Object { [PSCustomObject]@{ title = $_.Key; items = @($_.Value) } })
}

$library = [PSCustomObject]@{
  films = @(Group-RyhzeTitles (Get-RyhzeTitles 'Films'))
  games = @(Group-RyhzeTitles (Get-RyhzeTitles 'Games'))
}

$json = $library | ConvertTo-Json -Depth 6
Set-Content -LiteralPath (Join-Path $Root 'library-data.js') -Value "window.RyhzeLibrary = $json;`n" -Encoding utf8
Write-Host 'Ryhze library data updated.'
