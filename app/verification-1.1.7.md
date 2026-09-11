# Ryhze 1.1.7 verification

- Phone layout tests cover 320, 360, 390 and 430 logical pixels, regular and admin accounts, and top/bottom system insets. They check logo/action alignment, circular controls, tabs beneath the actions, reachable hero action and Library navigation.
- Captures were generated at all four widths. The 360px regular and 320px admin layouts were visually inspected after the logo and fonts loaded.
- Full regression run: 108 passed with two obsolete header-order assertions. After updating those assertions to match the requested layout, all 17 interaction/mobile tests passed. Final Flutter analysis reported no issues.
- Android system bars now request the app's dark background and light icons. Actual system-bar rendering on the user's Android device has not been inspected.
- Windows release build and installer packaging passed. Android release build passed and APK signature verification matches the existing Ryhze signing certificate.
- The publisher uploaded both artifacts and the signed index but its Node download check stalled. Independent curl downloads completed and matched the index exactly: Windows 35,006,409 bytes; Android 108,534,242 bytes. The verified index was then used to synchronize website release metadata. All 22 website tests and the production build passed.
