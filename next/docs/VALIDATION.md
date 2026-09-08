# Release validation

Checked locally on 8 September 2026.

- Strict TypeScript and the optimized Vite build pass.
- Thirteen automated catalogue, routing and security checks pass. Coverage includes forged sessions, private artwork/catalogue access, password login, logout revocation, disabled/expired sessions, invitation reuse, malformed requests, rate limits, CSRF rejection, media ranges, administrator permissions and public security headers.
- Browser checks cover Games/Films navigation, title opening and Back, mobile sign-in, and responsive layouts at 320, 390 and 1440 px widths.
- Cloudflare deployment dry-run passes and resolves the expected D1, R2 and static asset bindings.
- A temporary Mozilla CC0 video verified actual authenticated local R2 playback, pause, mute, seeking and playback completion. Controls sit beneath the video. The test found and fixed a mobile panel overflow. The temporary title was removed from the release catalogue.
- Public content identifies Larcenous Driftscape as in development and its artwork as a concept, not gameplay. No playable original game or licensed film asset has been supplied in this catalogue.

## Cloudflare publication

Published on 8 September 2026 at `https://ryhze-web.live-insights.workers.dev`. Deployment version: `1f568d58-1bdb-4b48-afae-aed361b637c5`.

The user approved Andru as the production administrator. The account and a 24-hour single-use invitation are created; the administrator sets the password personally. The private invitation file is excluded from Git and deployment assets.

Live checks confirm the public page and catalogue load, anonymous private catalogue/media requests fail, private artwork redirects to sign-in, and an invalid password receives the expected rejection. Browser verification confirms the deployed home renders. The old public R2 URL is disabled and its public custom domain removed.

The nameservers were switched at Namecheap to `johnathan.ns.cloudflare.com` and `joselyn.ns.cloudflare.com` on 8 September 2026. Cloudflare and Google public resolvers confirm the new delegation. HTTPS requests to the Cloudflare destination for `ryhze.com` return the new website and catalogue; `www.ryhze.com` redirects to the primary domain. Some recursive DNS caches may temporarily retain the earlier GitHub address.

The existing Zoho MX, SPF, DKIM and DMARC records are preserved. An obsolete duplicate forwarding SPF record in Cloudflare was replaced with the existing GitHub domain verification TXT record that had not been copied previously. Authoritative DNS checks confirm the expected mail routing and single SPF record.

GitHub Pages publishes only a redirect to the deployed Cloudflare address, so cached DNS and the GitHub Pages URL cannot continue serving the old application or cause a redirect loop through a stale primary-domain DNS answer.
