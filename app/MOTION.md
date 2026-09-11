# Ryhze interaction motion

This is our Flutter implementation of the requested fluid tab and expanding-control behavior, retaining Ryhze typography, pale selection, dark glass surfaces, corners and existing easing. It does not use an Apple UI implementation.

Reference observation: the supplied 33.363-second recording shows discrete tab changes around 0-4 seconds, an enlarged/deformed moving tab surface around 5-18 seconds, and a source-grown menu around 22.5-22.7 seconds, reversing around 23.7-23.9. Touch locations are not encoded, so exact gesture thresholds cannot be measured from the video. Search expansion at the top is a requested extension, not a demonstrated action in the clip.

## Tabs

`ui/design.dart` owns BrowseTabs. One pointer owns the interaction until release/cancel. The pressed surface grows 8 percent over 180ms, tracks the pointer's clamped horizontal location without interpolation lag and stretches an additional 16 percent at the middle of the track. It settles over 300ms using the existing Ryhze curve. Release commits once; cancel or release more than 24 pixels vertically beyond the track restores the committed selection. A second pointer cannot take ownership or activate the other tab. Text buttons retain keyboard activation and selected semantics. Reduced motion disables enlargement/stretch/settling while keeping direct tracking functional.

## Expanding surfaces

`ui/expanding_surface.dart` owns a single reversible RawDialogRoute. The source button rectangle expands into a responsive top surface over 280ms. Full-size content is clipped and revealed inside the changing surface; text is not scaled. Dismissal during expansion reverses from the current progress. The caller waits for the reverse transition to complete before releasing overlay ownership. Search focuses its input after expansion, and dimensions account for safe areas and the software keyboard. Escape and backdrop dismissal remain available. Reduced motion opens/closes immediately.

`ui/shell.dart` uses this surface for Search and Account/settings, hiding the originating control while it owns the expanded surface. Existing title artwork expansion remains in ArtworkHero rather than introducing an unrelated card transition.

## Evidence

`test/motion_test.dart` covers held tracking, one-time commit, cancellation, outside release, second-pointer rejection, interrupted search expansion, focus, dismissal and reduced motion. Existing interaction checks cover 320-1920px windows at 150 percent display scaling. `integration_test/motion_test.dart` retains actual native Windows render frames under the caller-supplied RYHZE_SCREENSHOTS path; local evidence is `.private/qa/motion/`.

Native captures are sampled interaction frames, not a claim of frame-rate or pixel-identical reproduction of the supplied video. New source changes require release packaging before installed copies receive them.

11 September validation: full app suite 83 passed; final targeted motion suite 4 passed. Native Windows integration built and passed with sampled press/drag/search/menu frames. After visual inspection, tab label color switching was made immediate so text contrast does not lag behind the moving selection. No public update feed or installer was changed for this motion work.
