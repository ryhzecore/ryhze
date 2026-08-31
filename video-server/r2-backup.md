# R2 backup streaming

The primary stream remains `https://video.ryhze.com`, served from this PC through Cloudflare Tunnel and Caddy.

The backup host is `https://r2-video.ryhze.com`, attached to the `ryhze-streams` R2 bucket. It uses the same object paths as the local project, such as:

`Films/Avengers%20Doomsday/Streams/Season%201/Episode%201/Steam1.mp4`

The website generator now emits `backupPublicUrl` for each stream. The player retries that URL automatically when the PC stream fails.

## One-time Cloudflare setup

1. Create the R2 bucket `ryhze-streams` in the Ryhze Cloudflare account.
2. Attach the custom domain `r2-video.ryhze.com` to the bucket and enable public access through that custom domain.
3. Set the bucket CORS policy to allow `GET`, `HEAD`, and `Range` requests from `https://ryhzecore.github.io` and `https://ryhze.com`.
4. Log in to Wrangler once, then run `./sync-r2-streams.ps1` from the project root whenever you want to refresh the backup library.

R2 is only used after the primary PC stream fails. No router ports need to be opened for the fallback.
