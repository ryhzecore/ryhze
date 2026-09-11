# Ryhze application

One Flutter/Dart application for Windows, Android, iPhone/iPad and macOS. The interface ports the existing `next/` website, using the supplied Ryhze wordmark, symbol, artwork, Space Grotesk, Inter, dark glass panels and Games/Films navigation.

Current application version: **1.1.4 (build 12)**. See `RELEASE_NOTES.md` for changes, `GAME_LIBRARY.md` for the Windows game library, and `updates/README.md` for publishing future in-app updates.

The latest Website task changes are mapped in `WEBSITE_PARITY.md`, including smooth corners, translucent frames, artwork flight, ambient sound defaults and the native brand introduction. Game artwork is losslessly transcoded from the website's AVIF payloads into real PNG files for native decoder compatibility.

## Product behavior

- Public discovery and invitation-only sign-in connect to the existing Ryhze service. The app does not create a second account database.
- Search, title details, My List, per-account watch history, availability subscriptions, invitation activation, preferences, contact/privacy pages and member administration are implemented.
- Native playback supports authenticated streams, seeking, pause/resume, volume, speed, embedded subtitles, seasons/episodes, source selection and full screen. Controls sit outside the picture. Hover previews are muted and use only catalogue-provided media.
- Windows detects Riot Client, launches Valorant through that client, and downloads the authenticated installer when needed. Installers open only on an explicit button press. Mobile presents game discovery instead of Windows installer actions.
- Remember me is selected by default. Sessions persist for up to 30 days in operating-system secure storage and survive switching between Ryhze's main and backup service addresses. Unchecking Remember me keeps the session only until the app closes; signing out removes it. Passwords are never persisted. My List, history and subscriptions are per-account local preferences; they do not sync between devices. Availability notices appear on a later visit, not through push or email.
- Unavailable media and unreleased games have explicit states. There are no fabricated playable streams, installers or production claims.
- Windows and the direct-download Android edition check for signed updates on launch and every six hours while running. A dismissible notice and the App updates menu provide download progress, cancellation, retry and verified installation. Windows closes and reopens around installation; Android asks for installation permission and system confirmation. App data remains in place.

## Build and check

Flutter is pinned to **3.47.2** and dependencies are recorded in `pubspec.lock`. This workstation's SDKs are under the ignored root `.tools/` directory. Visual Studio Build Tools includes the C++ desktop workload and ATL.

From the repository root:

```powershell
.\app\tool\flutter.ps1 pub get
.\app\tool\windows-plugins.ps1
.\app\tool\flutter.ps1 analyze
.\app\tool\flutter.ps1 test
.\app\tool\flutter.ps1 build windows --release
.\app\tool\package-windows.ps1
.\app\tool\flutter.ps1 build apk --release
.\app\tool\flutter.ps1 build appbundle --release
```

On another configured machine, use equivalent `flutter` commands from this directory. Run platform builds and native tests sequentially: Flutter updates generated plugin registration shared across targets. `windows-plugins.ps1` creates directory junctions for package links without requiring a system-wide Developer Mode change.

## Service connection

The primary service is `https://ryhze.com`. Some resolvers still cache its retired GitHub host. Before restoring a session, the app probes `/api/health`. If the primary is unavailable and the existing `https://ryhze-web.live-insights.workers.dev` service reports the expected health response, the app uses that Ryhze origin. Probes send no credentials. Cookies and media stay on the selected origin; unrelated API redirects are never followed.

The two production addresses share the account service, so an unexpired saved session is accepted across those exact addresses. Custom development origins remain isolated. To test persistence with actual secure storage, run `integration_test/remember_session_test.dart` twice on the same native device: first with `--dart-define=RYHZE_SESSION_PHASE=seed`, then with `--dart-define=RYHZE_SESSION_PHASE=restore`. Pass `--no-uninstall` to retain Android test app data between runs. Each run starts a separate application process; the second verifies restoration and sign-out cleanup. The test uses a separate storage key and local account fixtures.

For isolated development, use `--dart-define=RYHZE_API_ORIGIN=http://127.0.0.1:PORT`. Unencrypted non-loopback origins are rejected. Release Android builds disable cleartext traffic.

## Signing and distribution

Windows packaging produces an installer and portable ZIP including the Microsoft C++ runtime. No purchased Authenticode certificate is configured, so Windows may show an unrecognized-publisher prompt.

Android releases use the generated upload key in `.private/ryhze-upload.jks` and `.private/android-signing.properties`. Both are excluded from source control and release bundles. Back up both privately before publishing: future updates must retain the signing identity. The application ID is `com.ryhze.ryhze`. Release builds never fall back to a debug signing key.

The root `codemagic.yaml` provides Apple build verification and a separate TestFlight workflow. Distribution requires an Apple Developer team, an App Store Connect app for `com.ryhze.ryhze`, a certificate/provisioning profile configured in Codemagic, and the `ryhze_apple_signing` secret group with `APP_STORE_CONNECT_PRIVATE_KEY`, `APP_STORE_CONNECT_KEY_IDENTIFIER` and `APP_STORE_CONNECT_ISSUER_ID`. No credentials are embedded and no Apple/store upload is triggered by local builds.

Apple projects include network access and keychain entitlements. They must be built and exercised on macOS/iOS before being described as tested Apple releases. A Windows build cannot validate Apple integration or store approval.

## Verification

Unit/widget tests cover session persistence/expiration, origin restrictions, Unicode catalogue data, domain failover, account isolation, offline errors, search/details, sign-in validation and layouts at 320, 390, 768 and 1280 logical pixels. Rendered evidence is written to ignored `.private/qa/` files.

The interaction suite adds actual mouse hover/press/exit, painted appearance checks, keyboard activation, rapid Games/Films switching, preview suppression behind panels, and responsive header/dialog/form checks from 320 to 1920 pixels at 150% display scaling. Run `flutter test integration_test/interaction_test.dart -d windows` or select an Android device to exercise those interactions in a native runner. The native video suite also checks authenticated hover preview playback, speed selection, and compact full-screen controls.

`integration_test/native_test.dart` exercises actual secure-storage and media plugins, the live public catalogue, a local authenticated video fixture, seeking, pause/resume and return to artwork. It uses no real member credentials. Generate its 12-second fixture using FFmpeg:

```text
ffmpeg -f lavfi -i testsrc2=size=640x360:rate=24 -f lavfi -i sine=frequency=440:sample_rate=48000 -t 12 -c:v libx264 -pix_fmt yuv420p -c:a aac -movflags +faststart .private/qa/playback.mp4
```

Pass the fixture's absolute path using `--dart-define=RYHZE_TEST_VIDEO=...` on another workstation. For an Android emulator, run `node tool/qa-video-server.mjs` and pass `--dart-define RYHZE_TEST_VIDEO_URL=http://10.0.2.2:8871/playback.mp4`. Only debug builds allow this local HTTP fixture; release Android traffic remains HTTPS-only. Production media and accounts are never modified by these tests.
