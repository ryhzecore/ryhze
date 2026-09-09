# Ryhze application validation

Validated on 9 September 2026 using Flutter 3.47.2 and Dart 3.13.2.

## Version 1.0.6 website parity checks

- All 63 shared unit/widget tests pass, including session persistence, updater validation, hover behavior, responsive layouts and nine new website-parity checks.
- Android emulator checks pass for the brand introduction at four widths, opaque game/film artwork flight and interrupted return, saved mute preferences, and desktop-to-phone detail resizing. A separate native decoder check passes for the refreshed Valorant and GTA VI images.
- The website's AVIF payloads under PNG filenames were losslessly decoded into real PNG assets for the app. Decoded pixels and dimensions match the website source images.
- The dedicated animation test uses a longer test route to inspect an in-flight frame reliably on the emulator; production transitions follow the website's 700ms duration.
- Windows native checks pass for all nine parity cases across focused runs. Final rendered phone/desktop library, detail sheet and brand-home captures were inspected. A full-width artwork constraint was added after visual review; desktop and phone width assertions and return navigation now pass. Captures are in `.private/qa/parity-1.0.6/`.
- Static analysis reports no issues. The full shared suite passed, and the nine focused parity tests were rerun after the final artwork-width correction.
- Release Windows 1.0.6+7 was built, packaged and installed into the existing per-user folder. Installed executable/application hashes match the build, preferences remain byte-for-byte unchanged, and the reopened Ryhze window is responsive.
- Android 1.0.6/build 7 was built with the existing release identity and passes APK Signature Scheme v2 verification. Both distributable archives were checked for private material, and release checksums were regenerated.
- Signed 1.0.6 in-app updates are published. The website passed all 20 tests and its production build, then was deployed with synchronized installer cards/routes. Complete Windows and Android downloads from both the update service and ryhze.com match the release hashes and sizes. The APK downloaded through the website reports 1.0.6/build 7.
- `WEBSITE_PARITY.md` records the website changes and native adaptations. Apple builds remain subject to the external release requirements below.

## Version 1.0.5 session persistence checks

- All 54 shared tests pass, static analysis reports no issues, and changed Dart files pass formatting checks.
- Reproduced the unchecked Remember me default and loss of an unexpired saved session when switching between Ryhze's two production addresses. Both regressions pass after the fixes.
- Windows and Android each pass a two-process native secure-storage test: one process signs in and exits; a fresh process restores the saved session while switching from the backup address to the main address, then signs out and verifies removal.
- Native tests use a dedicated secure-storage key and local fixture responses, without accessing a member password or session. Android runs use `--no-uninstall`; the initial attempt correctly lost data because Flutter's default test cleanup uninstalled the test app.
- Unrelated origins remain isolated, expired/rejected sessions are removed, and opting out of Remember me clears previous saved authentication.
- Windows 1.0.5+6 was packaged, installed into the existing per-user folder and reopened successfully. Installed executable and application code hashes match the release build; preferences were preserved byte for byte and the Ryhze window remains responsive.
- Android release 1.0.5/build 6 passes APK Signature Scheme v2 verification with the existing signer. Release packages were checked for private material and checksums regenerated.
- The signed 1.0.5 update index is live. Full public Windows and Android downloads match the published byte counts and SHA-256 hashes.

## Version 1.0.4 regression checks

- 52 shared unit/widget tests pass; static analysis reports no issues.
- Two focused native regression tests pass on Windows and two on the Android 15 emulator.
- Reproduced a successful login leaving the user on the sign-in form when the session response is delayed. The regression failed before the screen lifecycle correction and passes afterward. Tests use fixture credentials and session cookies; no real member password is accessed.
- Verified that hovering directly over the status moves the status, categories and artwork together by three logical pixels. Artwork zoom stays specific to artwork hover, the save button remains independent, pointer exit restores the position, and Reduced motion disables the movement.
- Release 1.0.4 is distributed through the existing signed update service. Native updater behavior and Windows close/install/reopen were verified during 1.0.3; this release retains that updater.
- Windows release and installer built successfully. The installed per-user copy was upgraded to `1.0.4+5`; its executable and application code hashes match the release build, and existing preferences were preserved byte for byte.
- The installed Windows application was reopened successfully and remained responsive with the Ryhze window visible. The signed 1.0.4 update index was published, and both public package downloads were verified against their full SHA-256 hashes and byte counts.
- Android release APK reports version `1.0.4`, build `5`, and passes APK Signature Scheme v2 verification with one signer. Windows portable ZIP and Android APK contain no private signing material; release checksums were regenerated after packaging.

## Earlier completed checks (1.0.1)

- Static analysis: no issues.
- Shared unit/widget suite: 33 passing tests for version 1.0.1.
- Native Windows integration suites: 5 passing tests for version 1.0.1 (run as separate native test applications).
- Native Android integration suites: 5 passing tests on the Android 15 / API 35 Pixel 7 emulator.
- Layouts rendered and inspected at 1280×820, 768×1024, 390×844 and 320×740 logical pixels. Navigation, search, title details, return transitions and sign-in validation exercised without layout exceptions.
- Live public catalogue access verified. The native client successfully uses Ryhze's existing Cloudflare endpoint when the workstation's DNS resolver returns the retired GitHub host.
- Actual OS secure-storage write/read/delete verified on Windows and Android.
- Actual native video decoder verified with a generated authenticated HTTP fixture, including duration, seeking, pause/resume, the application player controls and return to artwork. No production member password was used.
- Mouse hover/press/exit and keyboard activation exercised in native runners, including a pixel comparison proving the button hover is painted. Navigation label/highlight bounds match at each end and after rapid switching.
- Header, search, settings, details, sign-in and editorial screens checked from 320 to 1920 logical pixels at 150% display scaling. Outgoing pages do not receive input, and title backdrops dismiss their panels.
- Authenticated hover previews stop on pointer exit and behind overlays. Native playback speed selection and full-screen entry/exit exercised with a compact 320-pixel layout.
- Android artwork decoding failure reproduced and fixed: GTA VI and Valorant assets contained AVIF data under PNG filenames. Bundled files now use actual PNG encoding, preserving artwork dimensions; the affected native interaction test passes.
- Riot Client installation detection verified on the workstation. Tests did not launch a real game or execute a downloaded game installer.
- Original 1.0.0 Windows installer verification: installed silently into an isolated workspace directory, launched successfully, remained responsive, and uninstalled its application files and registration. Version 1.0.1 uses the same installer structure.
- Version 1.0.1 Windows release and NSIS installer built successfully. Updated the existing per-user installation, verified its executable hash against the release build and its product version as `1.0.1+2`, launched it, and confirmed the process remained responsive.
- Android release APK built with the local release key. APK Signature Scheme v2 verification passed; one signer present.
- Android release App Bundle built successfully and its JAR signature verified with the same local release identity.
- Signing keys, test credentials, SDKs and build outputs confirmed excluded from Git source tracking.
- Version 1.0.1 Windows portable ZIP, Android APK and Android App Bundle inspected to exclude private signing material. Release checksums regenerated after packaging.

## Evidence

Local UI renders: `.private/qa/home-1280.png`, `home-768.png`, `home-390.png`, `home-320.png`, and `catalog-hover.png`.

Release artifacts and SHA-256 checksums: repository-root `releases/`.

## Remaining external release steps

macOS and iOS have generated platform projects and a Codemagic build/TestFlight configuration. No Apple build, signing, notarization, TestFlight upload or App Store review has been completed in this Windows environment. Those steps require access to the owner's Apple and cloud-build accounts.

No Google Play upload has been performed. No Windows Authenticode publisher certificate is configured. Authentication against an existing production member account and playback of its private production catalogue require that member to sign in; automated media testing used an isolated fixture instead.

This record describes checks actually performed. A release build alone is not evidence of App Store approval or of tests on untested devices.
