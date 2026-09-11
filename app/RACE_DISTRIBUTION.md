# RACE integration

The Engine tab, catalogue editing, and private RACE download endpoints require an enabled server account whose role is `admin` and whose username is Andru or Leo (case insensitive). The app repeats this check for navigation. Download authorization is enforced by the server on every request.

The existing public Ryhze update feed must never contain RACE packages. RACE has a separate private release route. Until the engine owner supplies a qualified installer, `/api/admin/race/manifest` returns `available: false`; there is no fabricated download.

## Installer contract

The Windows installer must install a relocatable `race_editor.exe` and every runtime dependency beneath its chosen installation directory. It must record `InstallDir` (string), `Version` (string), and `Build` (positive integer) in `HKCU\Software\RACE`. Exit code zero and the installed build marker are required before Ryhze reports installation complete. Projects must survive updates and uninstallation.

The library includes RACE only when the registered executable exists. Its entry leads to the Engine controls. Installer size is limited to 1 GiB by the current signed release validator.

## Private release contract

R2 bucket: `ryhze-streams`.

- Immutable installer object: `race/releases/VERSION/RACE-VERSION-Windows-Setup.exe`.
- Promote the signed envelope last: `race/updates/stable.json`.
- Authenticated route: `/api/admin/race/releases/VERSION/RACE-VERSION-Windows-Setup.exe`.

Use the established Ryhze Ed25519 release key and key ID. The signed UTF-8 payload contains `schema: 1`, `product: "race"`, `publishedAt`, and exactly one Windows entry in `releases`. Its fields are `platform`, `version`, monotonically increasing `build`, authenticated `path`, `bytes`, lowercase hexadecimal `sha256`, and `notes` (maximum 4000 characters). Envelope fields are `keyId`, base64 `payload`, and base64 `signature`.

Verify relocation, the installed registry identity, upgrade preservation, installer cancellation, package bytes and hash before promotion. Never overwrite an existing version or build with different bytes. Preserve the previous installer and signed manifest for rollback. The app verifies signatures before offering an update and verifies the complete downloaded package before starting setup.
