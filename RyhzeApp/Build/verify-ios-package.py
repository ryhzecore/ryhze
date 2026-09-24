"""Reject desktop executables accidentally bundled as iOS Flutter assets."""

import sys
import zipfile
from pathlib import PurePosixPath


def verify_package(path):
    with zipfile.ZipFile(path) as package:
        names = package.namelist()
        if "Payload/Runner.app/Info.plist" not in names:
            raise ValueError("Missing iPhone application in IPA")
        forbidden = [
            name
            for name in names
            if "/flutter_assets/" in name
            and (
                "/assets/update/" in name
                or PurePosixPath(name).suffix.lower()
                in {".py", ".pyc", ".ps1", ".sh", ".bat", ".cmd", ".exe", ".dll"}
            )
        ]
        if forbidden:
            raise ValueError("Desktop code in iPhone package: " + ", ".join(forbidden))
    print("Verified iPhone package: no desktop updater or executable assets")


if __name__ == "__main__":
    verify_package(sys.argv[1])
