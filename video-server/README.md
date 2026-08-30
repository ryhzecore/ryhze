# Ryhze video hosting

The public site is hosted on GitHub Pages. The Cloudflare Tunnel option uses
Caddy on the Windows PC and cloudflared publishes it at `video.ryhze.com`.
The router does not need inbound port forwarding; the PC only needs outbound
connectivity to Cloudflare.

The earlier tunnel files (`vps.Caddyfile` and `pc.Caddyfile`) remain available
if you later decide to return to the private-IP design.

## Pieces

- PC: Caddy using `local.Caddyfile`, listening on `http://127.0.0.1:80`.
- PC: cloudflared using `C:\Users\crnjl\.cloudflared\config.yml`.
- DNS: a Cloudflare-managed CNAME for `video.ryhze.com` created with
  `cloudflared tunnel route dns`.
- Router: no inbound 80/443 forwarding is required.

Caddy serves HTTP only on the local side; Cloudflare terminates public HTTPS.
Its file server supports HTTP range requests, so seeking in the browser video
player works normally.

The repository does not contain the large video files. They remain on the PC
under `Films`/`Games`; `sync-library.ps1` emits both a local URL (for the
desktop app) and a `https://video.ryhze.com/...` URL (for GitHub Pages).

## CGNAT check and remaining one-time values

The PC currently reports public IPv4 `116.88.112.178` and LAN address
`192.168.0.102`. Before forwarding, compare the router's WAN/Internet IPv4
with `116.88.112.178`. If they differ, or the router WAN address is in
`100.64.0.0/10`, the ISP is using CGNAT and direct forwarding will not work;
use the tunnel option instead. No router credentials need to be shared with
the website.
