# Ryhze website

The new application lives here. The earlier root website remains a reference during migration.

## Stack

React and strict TypeScript, Vite, Motion, self-hosted fonts, and a Cloudflare Worker. Cloudflare D1 holds accounts and sessions; private R2 media is served through authenticated same-origin requests.

## Local development

Use Node 24 or newer. Run `npm ci`, then `npm run build` and `npm run preview` in this directory. The preview is at port 8790 and uses local Cloudflare storage. `npm run dev` provides the frontend development server while the Worker preview handles API requests.

Run `npm test` for security and routing checks. Run `npm run build` to validate TypeScript and create the production bundle. The Wrangler configuration publishes only `dist`, not the repository.

## Content

`server/catalog.json` is the public originals catalogue. `server/internal-catalog.json` is available only to signed-in members. Store public artwork under `public/art` and private artwork under `public/private-art`. Playable streams must use `/media/Films/...` or `/media/Games/...` and exist in the bound R2 bucket. Unavailable media has a deliberate empty state; do not substitute unlicensed streams or pretend a game build exists.

Brand decisions and component rules are documented in `docs/BRAND.md`.

## Release

Build and test before `npm run deploy`. The configuration targets the existing Ryhze domain and Cloudflare resources. Database migrations live in `../cloud/migrations`. Never copy local QA accounts or credentials to production. A production administrator must be explicitly authorized and must set their own password through a single-use invitation.

Before switching traffic, verify the administrator can sign in, catalogue content is approved, and private R2 access works. Retire old public media endpoints only after authenticated delivery has been verified. A successful build alone is not a production deployment.
