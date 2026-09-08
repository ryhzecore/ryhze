# Ryhze

The rebuilt Ryhze website is in [`next/`](next/README.md): React, TypeScript, Vite and a Cloudflare Worker with D1 authentication and private R2 media. Earlier root-level website files remain as concept and migration references. Use the new application for further development.

## Develop and verify

Use Node.js 24 or newer. From `next/`, run `npm ci`, `npm test`, `npm run build`, and `npm run preview`. Local development uses Wrangler's isolated local D1/R2 storage; it is not a production streaming server. See the [web brand rules](next/docs/BRAND.md) and [validation record](next/docs/VALIDATION.md).

## Deploy

From `next/`, run `npm run deploy` while signed in to the correct Cloudflare account, after approving and verifying production account setup. Routes protect `ryhze.com` and `www.ryhze.com`. The GitHub Pages workflow publishes only a redirect so it cannot become an alternative public copy of protected pages. Never upload the repository root as website content.

## Accounts

Access is invitation-only. The administrator signs in at `/login` and manages invitations and disabled accounts at `/admin`. Invitation links expire after 24 hours and work once. Issuing a new link resets a member's password when they complete it. Do not send passwords through GitHub, chat, or email.

Initial administrator setup: run `node scripts/invite-admin.mjs USER_ID`, then `npx wrangler d1 execute ryhze-auth --remote --file .private/admin-invite.sql`. Deliver the generated `.private/admin-setup.txt` only to the intended administrator. Never commit `.private`.

Passwords use salted scrypt (N=32768, r=8, p=3). Sessions use random 256-bit opaque tokens, stored as hashes in D1 and transported in host-only Secure, HttpOnly, SameSite=Lax cookies. Sessions expire after 12 hours or 30 days when remembered. Logout revokes the server record. Every private page and media request is checked by the Worker before asset lookup. Mutation requests require the same Origin and JSON. Login is rate-limited. Admin APIs require an admin session. HTML prohibits inline scripts via CSP.

## Media

Bucket: `ryhze-streams`. Media is served through `/media/Films/...` or `/media/Games/...` after authentication. Public bucket URLs and custom R2 domains must remain disabled. Do not publish public backup URLs.

The new catalogue is maintained in `next/server/catalog.json` (public originals) and `next/server/internal-catalog.json` (authenticated references). Root sync tools belong to the earlier website. The media object must exist in R2 before publishing its catalogue entry. Large media files are excluded from GitHub and the static asset build.

## Privacy and cookies

Only essential sign-in cookies are used. Saved titles are browser preferences, scoped to the signed-in user. There are no advertising trackers or live viewer telemetry. Expired sessions, invitations, and rate-limit records are cleaned up daily.

## Motion

Smooth animations are the requested site default. The account menu offers a reduced-animation setting saved in the browser and shared with embedded players. Button and search hover effects scale from their centres; the Films/Games selector slides while library content fades between modes. Keyboard focus remains visible without automatically outlining the Back button on pointer entry.
