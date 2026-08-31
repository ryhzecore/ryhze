# R2 backup streaming

The primary stream remains `https://video.ryhze.com`, served from this PC through Cloudflare Tunnel and Caddy.

The backup bucket is attached to `https://r2-video.ryhze.com`. For browser seeking, the generated library currently uses Cloudflare's managed R2 endpoint (`pub-7e02d448a41c4dbabd5711a9c5f799f0.r2.dev`), which has verified `206 Partial Content` range responses. The custom domain remains available as an alias.

`Films/Avengers%20Doomsday/Streams/Season%201/Episode%201/Steam1.mp4`

The website generator now emits `backupPublicUrl` for each stream. The player retries that URL automatically when the PC stream fails.

## Current Cloudflare status

The R2 backup is configured in the Ryhze Cloudflare account:

- Bucket: `ryhze-streams` (APAC, Standard)
- Public HTTPS domain: `https://r2-video.ryhze.com`
- TLS: active (minimum TLS 1.2)
- Browser CORS: configured for the GitHub Pages and Ryhze site origins

The bucket is currently ready to receive objects. The upload step below is still required before any title can fall back to R2.

## One-time Cloudflare setup

1. The bucket, custom domain, and CORS policy are already configured.
2. Create an R2 API token with **Object Read & Write** permission scoped to `ryhze-streams`. Wrangler OAuth is enough for bucket administration, but large video uploads use the S3-compatible API (the Wrangler object command is limited to 300 MiB).
3. Set the S3 credentials locally (never commit them):

   ```powershell
   $env:R2_ACCESS_KEY_ID = '...'
   $env:R2_SECRET_ACCESS_KEY = '...'
   ```

4. Upload the library with the included multipart uploader. From the project root, set the two credentials and run:

   ```powershell
   .\setup-r2-upload.ps1
   ```

   The helper prompts locally for both values (the secret is hidden) and clears them from the process after the upload.

   It uses the S3 endpoint `https://<account-id>.r2.cloudflarestorage.com`, region `auto`, and 64 MiB multipart chunks so feature-length files work reliably.

For small test assets, `./sync-r2-streams.ps1` can still use Wrangler. Wrangler’s object command rejects files larger than 300 MiB, so it is not suitable for the feature-length videos.

The upload script uses Wrangler's remote R2 upload path, so no router changes or inbound ports are needed. It preserves the same `Films/...` and `Games/...` object paths used by the player, including the generated `-web.mp4` files when they are present.

R2 is only used after the primary PC stream fails. No router ports need to be opened for the fallback.
