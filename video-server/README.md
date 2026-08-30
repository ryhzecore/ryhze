# Ryhze video tunnel

The public site is hosted on GitHub Pages. `video.ryhze.com` points to a small
public VPS running Caddy. The VPS connects to the Windows PC over WireGuard;
the PC makes the outbound tunnel connection, so no home-router port forwarding
is needed and visitors do not see the home IP. The VPS relays the video bytes.

## Pieces

- VPS: Caddy using `vps.Caddyfile`, with TCP 443 and UDP 51820 allowed.
- PC: Caddy using `pc.Caddyfile`, listening only on the WireGuard interface.
- DNS: an `A` record `video.ryhze.com` pointing to the VPS public IPv4 address.
- WireGuard: VPS tunnel address `10.8.0.1`, PC tunnel address `10.8.0.2`, with
  `PersistentKeepalive = 25` on the PC peer for CGNAT/NAT-friendly operation.

Caddy automatically obtains and renews HTTPS certificates after DNS resolves.
Its file server and reverse proxy preserve HTTP range requests, so seeking in
the browser video player works normally.

The repository does not contain the large video files. They remain on the PC
under `Films`/`Games`; `sync-library.ps1` emits both a local URL (for the
desktop app) and a `https://video.ryhze.com/...` URL (for GitHub Pages).

## Remaining one-time values

The tunnel cannot be activated until the VPS exists. Record its public IPv4
address and provide it for the DNS `A` record and WireGuard peer configuration.
No router credentials are needed.
