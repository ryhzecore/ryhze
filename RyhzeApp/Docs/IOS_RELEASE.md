# Ryhze iOS release

The iOS target uses the current Flutter screens, catalogue, player and secure session code. The source version is `0.1.0+34`, its bundle identifier is `com.ryhze.ryhze`, and the minimum deployment target is iOS 15. The launch screen matches the app's dark background.

## Build and verification

On Codemagic, run `apple-verification` from the root `codemagic.yaml`. It enables Swift Package Manager (Flutter handles CocoaPods fallback), runs shared checks, builds the simulator app, exercises native screen behavior and secure-session persistence across separate processes, and compiles an unsigned device release. It also retains the existing macOS compilation check.

On a Mac with Flutter 3.47.2 and Xcode, run these from `RyhzeApp/Launcher`:

```sh
flutter config --enable-swift-package-manager
flutter pub get
flutter analyze
flutter test
bash ../Build/verify-ios.sh
flutter build ios --release --no-codesign
```

The simulator script requires an installed iOS runtime. It uses an isolated test session, never a member's credentials. Physical iPhone playback, rotation, audio interruptions and login persistence still need device testing before release acceptance.

## TestFlight distribution

The repository is connected to Codemagic. Apple team `B45M4C7CDW` has registered `com.ryhze.ryhze` and created App Store Connect app `6815007396`. The `Ryhze Internal` TestFlight group includes `crplll.leo@gmail.com`. Apple API access was approved on 23 September 2026. Add the dedicated App Manager key to the Codemagic Developer Portal integration under the name `Ryhze TestFlight`, then configure a matching App Store distribution certificate and provisioning profile. Keep the downloaded `.p8` key in Codemagic's encrypted integration, outside the repository.

Run `ios-testflight` after verification passes. It stops on failed checks, performs native simulator checks, exports a signed IPA for internal TestFlight testing, and assigns it to `Ryhze Internal`. It does not submit the app for public App Store review. The first workflow run uses build 34 (`BUILD_NUMBER` 1 plus 33); later runs increase within that workflow. If migrating the pipeline, keep the next number above the latest uploaded Apple build.

TestFlight/App Store distribution handles iOS binary updates. The Windows/Android executable updater is intentionally unsupported on iOS. Catalogue content continues to refresh from Ryhze's website API.

## Current acceptance status

The 23 September 2026 [apple-verification build](https://codemagic.io/app/6aa168715f5464a1c485054c/build/6ab348f935b07f77cbf01dcc) passed on branch commit `bb99518`: shared analysis and Flutter tests, iPhone/iPad simulator compilation, native screen and Keychain session tests, unsigned device release compilation, and macOS compilation. Website sign-in uses the same Ryhze account, then exchanges a one-use, 60-second code for a separate app session. The website handoff and its database table were deployed to ryhze.com on 23 September 2026. The app first checks its saved session; on a new iPhone/iPad install it opens Ryhze website sign-in. A website session already active in Safari on that same device can be reused, subject to Apple's authentication sheet. User ID sign-in remains available.

The earlier [Liquid Glass capture](https://codemagic.io/app/6aa168715f5464a1c485054c/build/6ab339cea56dee762d5d9344) passed. The [first-launch sign-in capture](https://codemagic.io/app/6aa168715f5464a1c485054c/build/6ab378a72f6988f0005ca818) also passed on commit `6990dd8`; its actual iPhone simulator image was inspected after correcting the loading label. Both captures are in [the Google Drive document](https://docs.google.com/document/d/17OvnsHBGy17-HmG7loyA98pkR4x34ZSfHiNvxc7AeRE/edit?tab=t.0). The new image shows the sign-in screen awaiting website authentication; it does not prove completed Safari session reuse. That behavior, physical iOS 27 beta glass interactions, and the installed TestFlight build still require device testing.

Apple approved App Store Connect API access. A key creation attempt redirected to Apple sign-in before success could be confirmed. Codemagic signing integration, a distribution certificate and profile, a signed IPA, the TestFlight upload, and the tester invitation remain unverified. Do not advertise an iOS download or invite code until the build appears in App Store Connect and is assigned to Ryhze Internal.

## Native test runner update

Simulator XCTest runs use local ad-hoc signing (`CODE_SIGN_IDENTITY=-`) so Xcode applies the app's Keychain entitlements. Disabling signing caused secure storage to fail with errSecMissingEntitlement (-34018). This does not require a paid certificate and is restricted to the simulator destination; TestFlight continues to require Apple distribution signing. The Keychain persistence tests remain real native-storage checks, with no mock-storage fallback.

The simulator checks run through xcodebuild and Flutter's XCTest bridge instead of flutter test's VM-service attachment, which stalled in cloud runs. Screens, session seed and session restore remain separate phases on the same simulator. Each native phase has a 15-minute process limit; failures remain blocking and xcresult bundles are retained. This runner passed in the 10 September cloud build and must be rerun on the current source.
