# Ryhze 1.1.6 verification

- Flutter analysis: no issues. Full Flutter suite: 102 tests passed.
- RACE card/detail interactions were exercised with mocked native discovery at 390px and 1280px. Captures of the card, expansion and completed detail were generated; desktop and phone completed layouts were visually inspected.
- Reveal checks confirm zero opacity throughout frame expansion, intermediate opacity and blur after completion, and no filter after the reveal finishes. Reduced motion reveals controls immediately.
- Existing tests cover admin visibility, local detection independent of update availability, library layouts at 320–1280px, game gallery navigation, interrupted artwork return, remembered sign-in and signed app updates.
- Windows release build and installer packaging passed. RACE process launching itself is unchanged; this release changes its entry point to the game-style detail card. No native editor launch was performed during this verification because the engine task was using the desktop.
- RACE's separate online installer remains unavailable until an engine release is published. Existing local RACE installations can be launched from the detail view.
- Android release build passed and APK signing identity matches the prior release. The publisher verified complete public Windows (35,009,033 bytes) and Android (108,534,250 bytes) downloads against the signed update index. Website tests: 22 passed; production build passed.
