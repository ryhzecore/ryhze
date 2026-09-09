# Ryhze iOS release

The iOS target uses the same Flutter screens, catalogue, player and secure session code as Ryhze 1.0.6. Its bundle identifier is `com.ryhze.ryhze`; the minimum deployment target is iOS 15. The launch screen now matches the app's dark background.

## Build and verification

On Codemagic, run `apple-verification` from the root `codemagic.yaml`. It enables Swift Package Manager (Flutter handles CocoaPods fallback), runs shared checks, builds the simulator app, exercises native screen behavior and secure-session persistence across separate processes, and compiles an unsigned device release. It also retains the existing macOS compilation check.

On a Mac with Flutter 3.47.2 and Xcode, run these from `app`:

```sh
flutter config --enable-swift-package-manager
flutter pub get
flutter analyze
flutter test
bash tool/verify-ios.sh
flutter build ios --release --no-codesign
```

The simulator script requires an installed iOS runtime. It uses an isolated test session, never a member's credentials. Physical iPhone playback, rotation, audio interruptions and login persistence still need device testing before release acceptance.

## TestFlight distribution

Connect this repository to Codemagic and configure an Apple Developer team, an App Store Connect app for the bundle identifier, and matching App Store distribution certificate and provisioning profile. Configure the `ryhze_apple_signing` secret group with `APP_STORE_CONNECT_PRIVATE_KEY`, `APP_STORE_CONNECT_KEY_IDENTIFIER`, and `APP_STORE_CONNECT_ISSUER_ID`; keep these in the service's secret settings, outside the repository.

Run `ios-testflight`. It stops on failed checks, performs native simulator checks and exports a signed IPA before uploading to TestFlight. Build numbers use Codemagic's project-wide sequence plus 7; preserve that sequence when rerunning releases. If migrating the pipeline to another Codemagic project, adjust the offset above the latest uploaded Apple build first.

TestFlight/App Store distribution handles iOS binary updates. The Windows/Android executable updater is intentionally unsupported on iOS. Catalogue content continues to refresh from Ryhze's website API.

## Current acceptance status

Apple compilation, signing, simulator execution, physical-device testing and TestFlight upload have not yet run. This Windows workspace does not provide Xcode, and no connected Apple build service has been identified. The configured pipeline is not evidence of a successful Apple build; do not advertise an iOS download until a signed artifact has passed the checks above.

## Native test runner update

The simulator checks now run through xcodebuild and Flutter's XCTest bridge instead of flutter test's VM-service attachment, which stalled in cloud runs. Screens, session seed and session restore remain separate phases on the same simulator. Each native phase has a 15-minute process limit; failures remain blocking and xcresult bundles are retained. This replacement still requires a successful cloud run before being marked verified.
