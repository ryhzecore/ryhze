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

The repository is connected to Codemagic. Apple team `B45M4C7CDW` has registered `com.ryhze.ryhze` and created App Store Connect app `6815007396`. The `Ryhze Internal` TestFlight group includes `crplll.leo@gmail.com`. Apple API access and a dedicated `Ryhze TestFlight` Codemagic Developer Portal integration are still required, followed by a matching App Store distribution certificate and provisioning profile. Keep the Apple private key in Codemagic's encrypted integration, outside the repository.

Run `ios-testflight` after `apple-verification` passes. It stops on failed checks, performs native simulator checks, exports a signed IPA for internal TestFlight testing, and assigns it to `Ryhze Internal`. It does not submit the app for public App Store review. Build numbers use Codemagic's project-wide sequence plus 34; if migrating the pipeline, keep the number above the latest uploaded Apple build.

TestFlight/App Store distribution handles iOS binary updates. The Windows/Android executable updater is intentionally unsupported on iOS. Catalogue content continues to refresh from Ryhze's website API.

## Current acceptance status

Codemagic's current-source `apple-verification` build passed on 23 September 2026 at commit `da453af`: shared analysis and tests, iPhone/iPad simulator build, native iOS screen and Keychain persistence checks, unsigned device release compilation, and macOS release compilation. Build: https://codemagic.io/app/6aa168715f5464a1c485054c/build/6ab3058a155e6f23080124a8 . Apple distribution signing, physical-device testing and TestFlight upload have not yet run. Do not advertise an iOS download until a signed current-source build has passed those checks.

## Native test runner update

Simulator XCTest runs use local ad-hoc signing (`CODE_SIGN_IDENTITY=-`) so Xcode applies the app's Keychain entitlements. Disabling signing caused secure storage to fail with errSecMissingEntitlement (-34018). This does not require a paid certificate and is restricted to the simulator destination; TestFlight continues to require Apple distribution signing. The Keychain persistence tests remain real native-storage checks, with no mock-storage fallback.

The simulator checks run through xcodebuild and Flutter's XCTest bridge instead of flutter test's VM-service attachment, which stalled in cloud runs. Screens, session seed and session restore remain separate phases on the same simulator. Each native phase has a 15-minute process limit; failures remain blocking and xcresult bundles are retained. This runner passed in the 10 September cloud build and must be rerun on the current source.
