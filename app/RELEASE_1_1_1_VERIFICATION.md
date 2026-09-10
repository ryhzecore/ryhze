# Ryhze 1.1.1 — release verification

Completed 2026-09-10. Application source: `a2e4531` (game-library implementation `9b9ee91`).

## Checks completed

- The complete application unit/widget suite passed 78 tests after the game-library, discovery, process-identity, media and Unicode-matching changes.
- Final code analysis reported no issues. All four library UI regressions passed after the audio lifecycle correction, covering 480, 800 and 1280 pixel layouts, details-open/close notifications and remembered permission denial.
- Native Windows integration exercised Start, process detection, Resume, graceful Close, Force stop, a game started outside Ryhze, restored last-played history and rejection of a forged process creation identity. Only an isolated test executable was controlled.
- Native Windows integration fetched official Dota 2 artwork, screenshots and trailers from Steam, played a real trailer and rendered the library and expanded gallery. Screenshots are retained locally under `.private/qa/game-library/`; test fixtures are not distributed.
- The final Windows release executable reports `1.1.1+9`. Its installer and portable ZIP were packaged from the Release directory.
- The final Android APK reports application ID `com.ryhze.ryhze`, version `1.1.1`, code `9`. Its APK signature verified and the signer matches the previously distributed 1.0.6 APK.
- The publisher signed the update index, uploaded the final packages, downloaded both public packages in full, and verified their hashes and byte lengths.
- All 20 website tests and the production website build passed with the final release metadata.
- Website deployment `650c88e9-5abf-4993-b6f4-a865d5cf84a1` serves the final homepage bundle. Public `/downloads/windows` and `/downloads/android` HEAD requests returned 200 with the exact final filenames, lengths and SHA-256 headers.

## Published packages

| Platform | File | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| Windows | Ryhze-1.1.1-Windows-Setup.exe | 34953382 | cc1a5548b70a59297268474fcac3b653dd47eb7c4dc12d5e60023ef531c3e085 |
| Android | Ryhze-1.1.1-Android.apk | 108288874 | 156388fbb0406ebfc5b2a5af00ab2140887e4d20bd8f8f29b578d9a4a1537b5c |

Public installer routes: https://ryhze.com/downloads/windows and https://ryhze.com/downloads/android. The existing signed update service now advertises 1.1.1, build 9, for both platforms. Published 1.1.0 artifacts were preserved; 1.1.1 supersedes that version with the background-audio correction.

## Scope and practical limits

PC discovery and process controls are Windows-only. Activity tracking requires Ryhze to remain open; it does not reconstruct sessions played while the app was closed. Automatic discovery covers Steam, Epic and installed Valorant; other games can be added manually. Store launchers/accounts and OS access restrictions still apply. Public store media availability varies by title; unavailable galleries show a store link rather than invented media. No iOS/TestFlight release was published during this update.
