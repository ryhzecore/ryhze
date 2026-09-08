# Release validation

Checked locally on 8 September 2026.

- Strict TypeScript and the optimized Vite build pass.
- Thirteen automated catalogue, routing and security checks pass. Coverage includes forged sessions, private artwork/catalogue access, password login, logout revocation, disabled/expired sessions, invitation reuse, malformed requests, rate limits, CSRF rejection, media ranges, administrator permissions and public security headers.
- Browser checks cover Games/Films navigation, title opening and Back, mobile sign-in, and responsive layouts at 320, 390 and 1440 px widths.
- Cloudflare deployment dry-run passes and resolves the expected D1, R2 and static asset bindings.
- A temporary Mozilla CC0 video verified actual authenticated local R2 playback, pause, mute, seeking and playback completion. Controls sit beneath the video. The test found and fixed a mobile panel overflow. The temporary title was removed from the release catalogue.
- Public content identifies Larcenous Driftscape as in development and its artwork as a concept, not gameplay. No playable original game or licensed film asset has been supplied in this catalogue.

Production activation is separate from local validation. The production D1 database currently has no users. Administrator provisioning requires explicit approval of the account and role; production sign-in and domain delivery must be verified after that setup. No production release is claimed by this document.
