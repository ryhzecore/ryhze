"""Reject XCTest success when the expected Dart tests were not executed."""
import pathlib
import re
import sys


def validate(phase, output):
    minimum = {"screens": 8, "session-seed": 1, "session-restore": 1}[phase]
    passed = set(re.findall(r"Test Case '-\[RunnerTests (\w+)\]' passed", output))
    if len(passed) < minimum or "** TEST SUCCEEDED **" not in output:
        raise ValueError(f"{phase}: expected at least {minimum} passing native tests, got {len(passed)}")
    if phase.startswith("session-") and not any(
        "RememberedSessionAcrossNativeProcessRestart" in name for name in passed
    ):
        raise ValueError(f"{phase}: remembered-session test was not executed")
    return len(passed)


if __name__ == "__main__":
    phase, filename = sys.argv[1:]
    count = validate(phase, pathlib.Path(filename).read_text(errors="replace"))
    print(f"Verified {phase}: {count} native tests passed")
