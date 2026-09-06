# Ryhze

Ryhze runs on Cloudflare Workers with static assets, D1 authentication, and private R2 media. The website does not depend on a PC tunnel, Caddy, or a local streaming service.

## Develop and verify

Use Node.js 22 or newer. Run `npm ci`, `npm test`, `npm run build`, and `npm run dev`. Local development uses Wrangler's isolated local D1/R2 storage; it is not a production streaming server.

## Deploy

Run `npm run build` and `npm run deploy` while signed in to the correct Cloudflare account. Routes protect `ryhze.com` and `www.ryhze.com`. GitHub Pages only publishes a redirect so it cannot become an alternative public copy of protected pages. Never upload the repository root as website content.

## Accounts

Access is invitation-only. The administrator signs in at `/login` and manages invitations and disabled accounts at `/admin`. Invitation links expire after 24 hours and work once. Issuing a new link resets a member's password when they complete it. Do not send passwords through GitHub, chat, or email.

Initial administrator setup: run `node scripts/invite-admin.mjs USER_ID`, then `npx wrangler d1 execute ryhze-auth --remote --file .private/admin-invite.sql`. Deliver the generated `.private/admin-setup.txt` only to the intended administrator. Never commit `.private`.

Passwords use salted scrypt (N=32768, r=8, p=3). Sessions use random 256-bit opaque tokens, stored as hashes in D1 and transported in host-only Secure, HttpOnly, SameSite=Lax cookies. Sessions expire after 12 hours or 30 days when remembered. Logout revokes the server record. Every private page and media request is checked by the Worker before asset lookup. Mutation requests require the same Origin and JSON. Login is rate-limited. Admin APIs require an admin session. HTML prohibits inline scripts via CSP.

## Media

Bucket: `ryhze-streams`. Media is served through `/media/Films/...` or `/media/Games/...` after authentication. Public bucket URLs and custom R2 domains must remain disabled. Do not publish public backup URLs.

`sync-library.ps1` updates the catalog from local title metadata and artwork; `sync-r2-s3.mjs` is an optional one-off cloud uploader using environment credentials. These are authoring tools, not streaming services. Existing cloud catalog entries should be retained if the original media is no longer stored on this computer. The media object must exist in R2 before publishing its catalog entry. Large media files are excluded from GitHub and the static asset build.

## Privacy and cookies

Only essential sign-in cookies are used. Saved titles are browser preferences, scoped to the signed-in user. There are no advertising trackers or live viewer telemetry. Expired sessions, invitations, and rate-limit records are cleaned up daily.

## Motion

Smooth animations are the requested site default. The account menu offers a reduced-animation setting saved in the browser and shared with embedded players. Button and search hover effects scale from their centres; the Films/Games selector slides while library content fades between modes. Keyboard focus remains visible without automatically outlining the Back button on pointer entry.
