# Ryhze iOS release

The iOS target uses the same catalogue, player and secure session code as the Ryhze Flutter app (`0.1.0+34` in `Launcher/pubspec.yaml`). Its bundle identifier is `com.ryhze.ryhze`; the minimum deployment target is iOS 15. The launch screen matches the app's dark background.

## Build and verification

On Codemagic, run `apple-verification` from the root `codemagic.yaml`. It enables Swift Package Manager (Flutter handles CocoaPods fallback), runs shared checks, builds the simulator app, exercises native screen behavior and secure-session persistence across separate processes, and compiles an unsigned device release. It also retains the existing macOS compilation check.

On a Mac with Flutter 3.47.2 and current Xcode, run these from `RyhzeApp/Launcher`:

```sh
flutter config --enable-swift-package-manager
flutter pub get
flutter analyze
flutter test
bash ../Build/verify-ios.sh
flutter build ios --release --no-codesign
```

The simulator script requires an installed iOS runtime. It uses an isolated test session, never a member's credentials. It also saves `.private/qa/ios-glass-home.png` from the simulator compositor so native UIKit surfaces appear in the visual evidence. Review that capture on an iOS 26 or newer runtime for the Liquid Glass effect. Physical iPhone playback, rotation, audio interruptions, glass interactions and login persistence still need device testing before release acceptance.

## TestFlight distribution

The repository is connected to Codemagic. Apple team `B45M4C7CDW` has registered `com.ryhze.ryhze` and created App Store Connect app `6815007396`. The `Ryhze Internal` TestFlight group includes `crplll.leo@gmail.com`. Apple API access was approved on 23 September 2026. The dedicated App Manager key is configured in the Codemagic Developer Portal integration under the name `Ryhze TestFlight`, with a matching Apple Distribution certificate and App Store provisioning profile. Keep the downloaded `.p8` key in Codemagic's encrypted integration, outside the repository.

Run `ios-testflight` after verification passes. It stops on failed checks, performs native simulator checks, exports a signed IPA for internal TestFlight testing, and assigns it to `Ryhze Internal`. It does not submit the app for public App Store review. The first workflow run uses build 34 (`BUILD_NUMBER` 1 plus 33); later runs increase within that workflow. If migrating the pipeline, keep the next number above the latest uploaded Apple build.

TestFlight/App Store distribution handles iOS binary updates. The Windows/Android executable updater is intentionally unsupported on iOS. Catalogue content continues to refresh from Ryhze's website API.

## Current acceptance status

The 23 September 2026 [apple-verification build](https://codemagic.io/app/6aa168715f5464a1c485054c/build/6ab348f935b07f77cbf01dcc) passed on branch commit `bb99518`: shared analysis and Flutter tests, iPhone/iPad simulator compilation, native screen and Keychain session tests, unsigned device release compilation, and macOS compilation. Website sign-in uses the same Ryhze account, then exchanges a one-use, 60-second code for a separate app session. The website handoff and its database table were deployed to ryhze.com on 23 September 2026. The app first checks its saved session; on a new iPhone/iPad install it opens Ryhze website sign-in. A website session already active in Safari on that same device can be reused, subject to Apple's authentication sheet. User ID sign-in remains available.

The earlier [Liquid Glass capture](https://codemagic.io/app/6aa168715f5464a1c485054c/build/6ab339cea56dee762d5d9344) passed. The [first-launch sign-in capture](https://codemagic.io/app/6aa168715f5464a1c485054c/build/6ab378a72f6988f0005ca818) also passed on commit `6990dd8`; its actual iPhone simulator image was inspected after correcting the loading label. Both captures are in [the Google Drive document](https://docs.google.com/document/d/17OvnsHBGy17-HmG7loyA98pkR4x34ZSfHiNvxc7AeRE/edit?tab=t.0). The new image shows the sign-in screen awaiting website authentication; it does not prove completed Safari session reuse. That behavior, physical iOS 27 beta glass interactions, and the installed TestFlight build still require device testing.

On 24 September 2026, signing was configured successfully using a downloaded and validated App Manager API key in the Codemagic `Ryhze TestFlight` integration. The Apple Distribution certificate and active App Store provisioning profile for `com.ryhze.ryhze` were added to Codemagic. A private backup of the API key is saved in iCloud Drive under `Ryhze Signing`; no signing secrets are stored in this repository. Superseded keys were revoked. Normal browser download buttons saved the key successfully; the previous conclusion that the browser could not save downloads was incorrect.

The [first signed TestFlight build](https://codemagic.io/app/6aa168715f5464a1c485054c/build/6ab497ec729c801ba78a7353) passed shared analysis, 243 shared tests (one non-iOS release-feed test skipped), native simulator checks and IPA export. Its artifact collector found no files, so no upload occurred despite the successful build status. The workflow now checks that one nonempty IPA exists and copies it to Codemagic's export directory; retained evidence paths are absolute. The [corrected export build](https://codemagic.io/app/6aa168715f5464a1c485054c/build/6ab49bc93768dea8ea11521a), commit `af52201`, produced build 35 and reached Apple upload. Apple rejected its bundled Linux updater script with error 90035. Desktop updater assets are now restricted to Linux or Windows through Flutter platform-specific asset declarations. A final IPA check rejects updater or executable assets; it was verified against the actual rejected build 35 archive. The [platform-filtered release build](https://codemagic.io/app/6aa168715f5464a1c485054c/build/6ab4a11d8af5eae6295e2d32), commit `a5ca529`, passed shared and native checks, exported build 36, and passed the final IPA asset check. Apple accepted the upload at 04:20 UTC on 24 September 2026. Processing completed with state `VALID` and audience `INTERNAL_ONLY`. The encryption questionnaire was completed for standard encryption and this private testing distribution, with no distribution in France; reconsider that answer before expanding distribution. Apple records `usesNonExemptEncryption=false`. Codemagic's automatic post-processing failed while the declaration was outstanding; setup was completed in App Store Connect. Apple now reports `IN_BETA_TESTING`, the `Ryhze Internal` group has build 36, and `crplll.leo@gmail.com` shows `Invited` on 24 September. Installation and physical iOS 27 beta testing still require the tester's iPhone.

On the iPhone, open the invitation email sent to `crplll.leo@gmail.com`, select **View in TestFlight**, accept, and install **Ryhze 0.1.0 (36)**. The invitation link handles redemption; no separate API key or manually supplied invite code is needed.

## Native test runner update

Simulator XCTest runs use local ad-hoc signing (`CODE_SIGN_IDENTITY=-`) so Xcode applies the app's Keychain entitlements. Disabling signing caused secure storage to fail with errSecMissingEntitlement (-34018). This does not require a paid certificate and is restricted to the simulator destination; TestFlight continues to require Apple distribution signing. The Keychain persistence tests remain real native-storage checks, with no mock-storage fallback.

The simulator checks run through xcodebuild and Flutter's XCTest bridge instead of flutter test's VM-service attachment, which stalled in cloud runs. Screens, session seed and session restore remain separate phases on the same simulator. Each native phase has a 15-minute process limit; failures remain blocking and xcresult bundles are retained. The September 10 run verified this runner; each later source change still needs its own cloud run.
