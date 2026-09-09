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
  # Preserve app data while ensuring the previous test process is gone.
  xcrun simctl terminate "$RYHZE_SIMULATOR_ID" com.ryhze.ryhze 2>/dev/null || true
  python3 tool/run-bounded.py 600 flutter test "$@" -d "$RYHZE_SIMULATOR_ID" --timeout=2m
}
run_test integration_test/website_parity_test.dart
run_test integration_test/remember_session_test.dart --no-uninstall --dart-define=RYHZE_SESSION_PHASE=seed
run_test integration_test/remember_session_test.dart --no-uninstall --dart-define=RYHZE_SESSION_PHASE=restore
