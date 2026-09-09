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
xcrun simctl bootstatus "$RYHZE_SIMULATOR_ID" -b
flutter test integration_test/website_parity_test.dart -d "$RYHZE_SIMULATOR_ID"
flutter test integration_test/remember_session_test.dart -d "$RYHZE_SIMULATOR_ID" --no-uninstall --dart-define=RYHZE_SESSION_PHASE=seed
flutter test integration_test/remember_session_test.dart -d "$RYHZE_SIMULATOR_ID" --no-uninstall --dart-define=RYHZE_SESSION_PHASE=restore
