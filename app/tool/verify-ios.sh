#!/usr/bin/env bash
# Run on a Mac with Xcode and a downloaded iOS simulator runtime.
set -euo pipefail
cd "$(dirname "$0")/.."
RYHZE_SIMULATOR_ID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
phones = [d for runtime, group in devices.items() if "iOS" in runtime
          for d in group if d.get("isAvailable") and "iPhone" in d["name"]]
if not phones:
    sys.exit("Install an iOS simulator runtime in Xcode before running verification.")
phones.sort(key=lambda d: d["state"] != "Booted")
print(phones[0]["udid"])
')"
if ! xcrun simctl list devices booted | grep -Fq "$RYHZE_SIMULATOR_ID"; then
  xcrun simctl boot "$RYHZE_SIMULATOR_ID"
fi
python3 tool/run-bounded.py 300 xcrun simctl bootstatus "$RYHZE_SIMULATOR_ID" -b
run_test() {
  local phase="$1"
  local target="$2"
  shift 2
  # Preserve app data while ensuring the previous test process is gone.
  xcrun simctl terminate "$RYHZE_SIMULATOR_ID" com.ryhze.ryhze 2>/dev/null || true
  echo "Preparing native XCTest: $phase"
  python3 tool/run-bounded.py 600 flutter build ios --simulator --debug --config-only --target="$target" "$@"
  local flutter_root
  flutter_root="$(sed -n 's/^FLUTTER_ROOT=//p' ios/Flutter/Generated.xcconfig | tr -d '\r')"
  python3 tool/run-bounded.py 900 xcodebuild test \
    -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug \
    -destination "platform=iOS Simulator,id=$RYHZE_SIMULATOR_ID" \
    -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
    -resultBundlePath "build/ios-test-results/$phase.xcresult" \
    "HEADER_SEARCH_PATHS=\$(inherited) $flutter_root/packages/integration_test/ios/integration_test/Sources/integration_test/include" \
    CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
    CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
    PROVISIONING_PROFILE_SPECIFIER= 2>&1 | tee "build/ios-test-results/$phase.log"
  python3 tool/check-ios-test-log.py "$phase" "build/ios-test-results/$phase.log"
}
mkdir -p build/ios-test-results
run_test screens integration_test/website_parity_test.dart
run_test session-seed integration_test/remember_session_test.dart --dart-define=RYHZE_SESSION_PHASE=seed
run_test session-restore integration_test/remember_session_test.dart --dart-define=RYHZE_SESSION_PHASE=restore
