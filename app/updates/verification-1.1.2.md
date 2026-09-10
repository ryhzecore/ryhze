# Ryhze 1.1.2 (10) release verification

Published 11 September 2026 (Singapore).

The Windows catalogue now includes installed games through its category filter. Local games use the shared RyhzeTitleCard and ArtworkHero components. Expanded official galleries support previous/next buttons, arrow keys, wrapping, selected thumbnails and reduced motion. Library controls and activity tracking remain available.

Validation:
- Flutter static analysis: no issues.
- Flutter regression suite: 79 passed. Targeted category/gallery suite: 5 passed after final UI adjustments.
- Native Windows integration: passed with actual Steam artwork, screenshots and trailer playback. Final screenshots inspected in `.private/qa/game-library-1.1.2/`.
- Release Windows executable: file/product version 1.1.2+10.
- Android release: com.ryhze.ryhze, version 1.1.2, versionCode 10; signature verified and certificate matches 1.1.1.
- Website tests: 20 passed; production build passed.
- Publisher downloaded and verified the full public Windows and Android packages after upload.
- ryhze.com download routes returned HTTP 200 with matching filenames, lengths and SHA-256 headers. Homepage serves index-Damuea-8.js.

Artifacts:

| Platform | Bytes | SHA-256 |
| --- | ---: | --- |
| Windows installer | 34973185 | 13ec559f0538a27286aa5835cb317bdb6c60712723f9cc9628f86f8b6616f247 |
| Android APK | 108338034 | 436685812e48f5b90ee68371111ab97f80d1dcf120d6593416224de16131c097 |

Signed stable update feed: https://ryhze-updates.live-insights.workers.dev/stable.json

Website deployment: a513657a-203d-4ace-ad37-02e03e7bb028.

PC installation discovery and process controls remain Windows-only. Gallery content depends on the original store providing media. This release does not publish an iOS/TestFlight build.
