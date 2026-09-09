# Website changes carried into app 1.0.6

Reference: the current `next/src` website and completed changes in the Website task, checked on 9 September 2026.

| Website change | Native application |
| --- | --- |
| Smooth rounded surfaces and hierarchy | Smooth superellipse clipping and borders; 32px cards/artwork, 28px account/search popovers, 44px desktop and 36px phone detail panels. Capsules and circular controls retain their proportions. |
| Translucent frames and fading header backgrounds | Detail sheet uses the website's translucent fill; the detail and browsing headers use top-to-bottom translucent gradients. |
| Back-button focus without outer halo | Focus stays on the button border; Back does not create an outer hover shadow. |
| Artwork continuously expands and returns | A single opaque artwork image flies above the fading sheet for game and film frames. Interrupted return is covered; Reduced motion disables flight. |
| Game frame fits the viewport | Game artwork uses 16:9 with a maximum height of 55% of the viewport. Film controls stay outside the picture. |
| Ambient sound starts automatically | Enabled by default for signed-in members; saved mute choices remain authoritative. Audio pauses while a detail is open or the application is inactive. |
| Latest public titles and thumbnails | Bundled catalogue and public GTA VI/Valorant PNG assets synchronized with the website. Live catalogue remains authoritative after refresh. |
| Ryhze introduction homepage | Available from the wordmark and account menu. Brand story and film/series/game links are included. The installed app offers App updates and a link for installation on another device. |
| Circular search/save controls | Existing equal-width/height controls retained, with phone-width regression coverage. |

Native adaptations: installed applications open directly into browsing. The website's acquisition choices become navigation, App updates and cross-device installation links inside an already installed app. Native playback, OS secure session storage and platform installers are retained. Windows and Android are the distributable targets available on this workstation; Apple platform source shares these UI changes but requires an Apple build/signing environment for release.
