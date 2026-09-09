// Only the signed public update index and its explicitly listed packages are public.
export default {
  async fetch(request, env) {
    if (!['GET', 'HEAD'].includes(request.method)) return new Response('Method not allowed', { status: 405 });
    const path = new URL(request.url).pathname;
    const index = await env.RELEASES.get('updates/stable.json');
    if (!index) return new Response('Updates temporarily unavailable', { status: 503 });
    const envelope = await index.text();
    if (path === '/stable.json') return new Response(request.method === 'HEAD' ? null : envelope, {
      headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' },
    });
    let release;
    try {
      const payload = JSON.parse(atob(JSON.parse(envelope).payload));
      release = payload.releases.find(item => item.path === path);
    } catch { return new Response('Updates temporarily unavailable', { status: 503 }); }
    if (!release || !/^\/releases\/[0-9.]+\/Ryhze-[a-zA-Z0-9.+-]+\.(exe|apk)$/.test(path)) {
      return new Response('Not found', { status: 404 });
    }
    const object = await env.RELEASES.get(path.slice(1));
    if (!object || object.size !== release.bytes) return new Response('Download temporarily unavailable', { status: 503 });
    return new Response(request.method === 'HEAD' ? null : object.body, { headers: {
      'Content-Type': path.endsWith('.apk') ? 'application/vnd.android.package-archive' : 'application/octet-stream',
      'Content-Disposition': `attachment; filename="${path.split('/').at(-1)}"`,
      'Content-Length': String(object.size),
      'Cache-Control': 'public, max-age=31536000, immutable',
      'X-Checksum-SHA256': release.sha256,
      'X-Content-Type-Options': 'nosniff',
    } });
  },
};
