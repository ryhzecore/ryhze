# Ryhze 1.1.2

- Removes the separate Discover / Installed games navigation. Installed games is now a category in the main Games catalogue, alongside the existing categories.
- Installed titles use the same artwork cards, typography, footer layout, hover lift, focus effects, smooth corners and artwork transitions as other Ryhze games.
- Expanded galleries add previous/next arrow buttons, left/right keyboard navigation, a media counter, and an animated thumbnail selection. Escape closes the view.
- Library setup, discovery, folder selection and preferences remain available under Manage games. Start, Resume, Close game and last-played tracking are preserved.
- Respects reduced-motion preferences and pauses background music while viewing installed-game media.

# Ryhze 1.1.1

- Pauses background music while an installed game's footage/detail view is open, and restores the user's sound preference on return.
- Includes the complete Windows game library introduced in 1.1.0.

# Ryhze 1.1.0

- Windows adds Installed games under Games, with an explicit permission choice before discovery and process activity checks.
- Discovers Steam libraries across configured drives, Epic installations and Valorant. Other games can be added by executable path; Steam folders can be added manually.
- Start, Resume, Close game and confirmed Force stop use detected game processes, with full executable/creation-time validation before controlling a process.
- Paths and last-played history persist locally; tracking can be disabled and history cleared.
- Expanded game views show official artwork, all available Steam screenshots and trailers, with original-store links and clear media availability states.
- Android remains on the shared version; Windows game discovery/control is not exposed on phones.

# Ryhze 1.0.6

- Matches the Website task's current corner hierarchy: 32px smooth surfaces, 28px popovers, 44px desktop and 36px mobile detail sheets, capsule buttons and circular icons.
- Translucent detail sheets and top-to-bottom header gradients; Back uses an inset focus border without an outer hover shadow.
- Opaque artwork travels into both game artwork and film-player frames and returns to the original card. Game artwork fits within 55% of the viewport height; player controls remain outside the picture.
- Adds the Ryhze brand introduction through the wordmark and account menu, with working film/game links, App updates and cross-device downloads. Installed apps continue to open directly into browsing.
- Ambient sound defaults on for signed-in members, retaining an explicitly saved mute setting.
- Bundled public catalogue, Valorant and GTA VI artwork match the current website. Existing sign-in persistence and signed internet updates are retained.

# Ryhze 1.0.5

- Remember me is now selected by default, keeping sign-in across app restarts for up to 30 days without saving passwords.
- Saved sessions remain valid when connectivity switches between Ryhze's main and backup service addresses. Unrelated addresses never receive the session.
- Unchecking Remember me, signing out and session expiry continue to clear saved authentication.

# Ryhze 1.0.4

- Fixed successful sign-ins returning to the sign-in form when a network response took longer than a frame. The form now survives catalogue refresh and safely navigates after authentication.
- Sign-in and invitation completion guard against a screen being closed while a request is pending.
- The entire title card lifts by three pixels on hover, including its status, categories and save button, matching the website. Artwork zoom/preview remains specific to artwork hover. Reduced motion disables the lift.

# Ryhze 1.0.3

- Automatic update checks and an in-app update notice, with a permanent App updates menu entry.
- Internet downloads with progress, cancellation, retry, and reuse of verified completed downloads.
- Signed release information and SHA-256 package verification, including another check immediately before installation. Older builds and untrusted download paths are rejected.
- Windows installation and automatic reopening in the same installation folder; Android installation through the system confirmation screen with application/signing identity checks.
- Existing saved lists, preferences and account storage are preserved during an upgrade.
- Dedicated live update service and a repeatable publishing tool for future releases.
- Windows waits for a verified installer handoff before closing and supports installation folders containing spaces.

Versions 1.0.0 and 1.0.1 need this version installed once to gain in-app updates. Automatic checks run while the app is open; downloading and installation are initiated by the user.

# Ryhze 1.0.1

This update corrects layout and interaction differences between the native application and the Ryhze web app.

- Games and Films now share exact dimensions with the sliding selection highlight, with centered labels and consistent hit targets.
- Buttons have visible hover, press, disabled, and keyboard-focus states. Hover animation does not move surrounding controls. State changes during rendering are deferred safely.
- Artwork cards use the web app's aspect ratios, overlaid titles, category labels, arrow placement, and metadata. Mouse hover and keyboard focus enlarge the card and its artwork smoothly.
- Authenticated video previews start after a short hover or focus, stop on exit, and stop behind search, account, and detail panels. Reduced motion disables preview playback and scaling.
- Header sizes and responsive breakpoints, hero spacing, action icon order, studio section, footer, search placement, detail panels, sign-in layout, and editorial sections follow the website's design.
- Playback controls sit together beneath the video. Speed, ten-second seeking, and volume remain available through Playback options. Full-screen and return-to-artwork actions stay accessible.
- Page switching uses one scroll controller and prevents interaction with outgoing content. Clicking outside a title closes its panel.
- GTA VI and Valorant artwork are stored as genuine PNG images, correcting the Android decoding failure caused by AVIF content under PNG filenames.

The application uses the same account service and existing local preference keys. The Android package retains its release-signing identity and increases its version code to 2.
