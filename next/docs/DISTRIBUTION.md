# Ryhze homepage and installers

`/` is the brand homepage. Games and films remain at `/games` and `/films`. The homepage uses Ryhze identity assets and editorial copy, independently of the catalogue's featured titles. Install opens a responsive platform selector; Open web app enters the existing browser experience. The header and footer wordmarks return to `/`.

## Release artifacts

The existing native application's version 1.0.0 installers are distributed through the Worker:

| Route | R2 key |
| --- | --- |
| `/downloads/windows` | `releases/1.0.0/Ryhze-1.0.0-Windows-Setup.exe` |
| `/downloads/android` | `releases/1.0.0/Ryhze-1.0.0-Android.apk` |

`server/releases.json` records the filenames, byte counts and SHA-256 checksums. Both the UI and download handler use this manifest. The handler allows only these exact artifacts, supports GET/HEAD and single byte ranges, and sets attachment filenames. A missing object or unexpected size returns 503. It does not expose arbitrary R2 keys or relax authenticated media access. The R2 bucket remains private; no public bucket endpoint is needed.

The APK uses the native app's release signing identity. The Windows installer is not Authenticode-signed; its download card explains the possible publisher notice. Signing keys, SDKs, build output and installer binaries are not committed to the website repository or its static asset bundle.

## Updating a release

1. Build and validate the native application's installers with its existing signing identity.
2. Compute each file's SHA-256 and size. Upload to a new versioned R2 key with Wrangler's authenticated `r2 object put --remote` command.
3. Update the manifest, run `npm test` and `npm run build`, then deploy the Worker.
4. Check public HEAD responses, a resumed byte range and the complete downloaded file's checksum against the local release.

Never overwrite a versioned artifact with a different build. Keep prior artifacts available for rollback. Future Apple installers require separately validated and signed releases; the homepage offers the web app for those devices.

## Validation

The homepage was checked at desktop, 390 px and 320 px phone widths, including the platform selector, keyboard focus, checksums and navigation into the web app and back home. Automated tests cover the public home route, exact download allowlist, metadata, ranges, invalid methods and missing artifacts, alongside the existing authentication and private-media tests.
