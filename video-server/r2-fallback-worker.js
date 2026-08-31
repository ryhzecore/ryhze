export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== 'GET' && request.method !== 'HEAD' && request.method !== 'OPTIONS') {
      return new Response('Method not allowed', { status: 405 });
    }
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders() });
    }

    const key = decodeURIComponent(url.pathname.replace(/^\/+/, ''));
    if (!key || key === 'health') return new Response('ok', { headers: corsHeaders() });

    // Prefer the PC tunnel while it is online.
    const primary = new URL(`https://video.ryhze.com/${encodeURI(key)}`);
    try {
      const response = await fetch(new Request(primary, request));
      if (response.ok || response.status === 206 || response.status === 304) return withCors(response);
    } catch {}

    // Fall back to the matching R2 object when the PC is offline.
    const object = await env.R2_BUCKET.get(key, { range: request.headers });
    if (!object) return new Response('Not found', { status: 404, headers: corsHeaders() });
    const headers = new Headers(object.httpMetadata);
    headers.set('Accept-Ranges', 'bytes');
    headers.set('Content-Length', String(object.range ? object.range.length : object.size));
    if (object.range) headers.set('Content-Range', `bytes ${object.range.offset}-${object.range.offset + object.range.length - 1}/${object.size}`);
    Object.entries(corsHeaders()).forEach(([k, v]) => headers.set(k, v));
    return new Response(request.method === 'HEAD' ? null : object.body, { headers });
  },
};

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
    'Access-Control-Allow-Headers': 'Range, Content-Type',
    'Access-Control-Expose-Headers': 'Accept-Ranges, Content-Length, Content-Range, ETag',
  };
}

function withCors(response) {
  const headers = new Headers(response.headers);
  Object.entries(corsHeaders()).forEach(([k, v]) => headers.set(k, v));
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
}
