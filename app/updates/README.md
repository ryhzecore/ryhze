# Ryhze update publishing

Windows and direct-download Android builds check the dedicated update service on launch, every six hours, and when resumed after six hours. The account menu always has App updates; a newer build also displays a dismissible notice. Downloads and installation require a user action. A closed app does not check in the background.

The production origin is `https://ryhze-updates.live-insights.workers.dev`. This separate Cloudflare Worker reads the `updates/stable.json` signed index and only serves the two package paths listed in it. It cannot expose private films, credentials, or arbitrary bucket files. Website deployments are independent.

The app pins the Ed25519 public key in `lib/core/updates.dart`. The signing key is local at `.private/update-signing.pem`, excluded from Git and all release packages. Keep a secure backup alongside the existing Android release keystore. Future updates must retain both keys. A Windows Authenticode certificate is separate from this update signature.

## Publish a release

1. Increase `version`/build in `pubspec.yaml` and `appVersion`/`appBuild` in `lib/core/updates.dart`. Builds must increase for every release. Do not reuse a published version or replace its files.
2. Run the app tests and build Windows and the signed Android APK using the existing release signing identity. Run `tool/package-windows.ps1`, then copy the APK to `../releases/Ryhze-VERSION-Android.apk`.
3. Write concise UTF-8 release notes. Run from the repository root:

   `node app/tool/publish-update.mjs --notes=app/updates/notes-VERSION.txt`

4. Review the generated `.private/stable.json` and final release packages. Publish with the same command plus `--publish`. The script uploads both packages first, then promotes the signed index, downloads the public packages, and verifies their complete hashes. It uses the existing Wrangler Cloudflare login.
5. The publisher also synchronizes `next/server/releases.json`. Run the website tests and build, then deploy the website so its installer cards and `/downloads/android` and `/downloads/windows` routes serve the same release. Website tests reject a release version that differs from the native app.

Deploy infrastructure changes with `node node_modules/wrangler/bin/wrangler.js deploy --config app/updates/wrangler.jsonc`. Normal releases only need the publishing script.

For the native Windows handoff regression, build `integration_test/windows_update_handoff.dart` in debug mode with `--dart-define=RYHZE_UPDATE_QA=true`. Copy the complete Debug runner into an isolated `.private/qa/` directory (include spaces in the directory name), then launch that copy. It downloads the production package, exercises the actual installer helper, and reopens the release. Verify the reopened executable hash, version and `install.log`. The test entry point refuses to run outside that isolated directory. Running the installer changes the per-user shortcut/installation registration, so finish by installing the release into the user's normal installation directory. Do not distribute the QA runner.

Existing versions 1.0.0 and 1.0.1 need one manual installation of 1.0.3 to gain the updater. The local Windows copy was upgraded during this implementation. Android retains its data when installed over the existing app with the same key; uninstalling first would remove data. Version 1.0.2 was used during release verification; use 1.0.3 for the corrected Windows installer handoff.

Apple versions are not distributed through this service. A future Play Store edition must use Play's update mechanism and omit the direct APK installation permission. The APK here is the directly distributed Ryhze edition.

## Failure handling

The app rejects invalid signatures, untrusted paths, redirects, incorrect sizes/hashes, and older/equal builds. Downloads use a private cache and temporary file; only a completely verified package becomes installable. Cancelled downloads are removed before retry. Completed downloads can be reused after restarting, after their hash is checked again. Windows verifies the hash again before waiting for the old process, installing into its current directory, checking the new version, and reopening. Failures are reported in a dialog and `install.log` next to the cached package. Android independently checks the application ID, signing certificate, and version before opening the system installer.
