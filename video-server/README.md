# Ryhze video hosting

The public site is hosted on GitHub Pages. The direct-home option uses Caddy on
the Windows PC and your router forwards HTTPS to that PC. `video.ryhze.com`
points to your current public IPv4 address. This avoids a VPS, but it does mean
your public IP is discoverable through DNS and the PC/router must stay online.

The earlier tunnel files (`vps.Caddyfile` and `pc.Caddyfile`) remain available
if you later decide to return to the private-IP design.

## Pieces

- PC: Caddy using `direct.Caddyfile`.
- Router: reserve the PC LAN address, then forward TCP 443 → that address's
  TCP 443. Forward TCP 80 as well if you want Caddy's HTTP→HTTPS redirect.
- DNS: an `A` record `video.ryhze.com` pointing to the home public IPv4 address.
- If the public IP changes, use a DNS provider's DDNS updater or change the A
  record; a hostname alone cannot keep a changing address up to date.

Caddy automatically obtains and renews HTTPS certificates after DNS resolves.
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
