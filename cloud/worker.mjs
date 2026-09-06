import { randomBytes, createHash, scrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
const derive = promisify(scrypt);
const cookieName = '__Host-ryhze_session';
const now = () => Math.floor(Date.now() / 1000);
const hash = value => createHash('sha256').update(value).digest('hex');
const token = () => randomBytes(32).toString('hex');
const json = (body, status = 200, headers = {}) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...headers } });
const fail = (message, status = 400) => json({ error: message }, status);
const redirect = location => new Response(null, { status: 303, headers: { Location: location, 'Cache-Control': 'no-store' } });
export async function passwordHash(password, salt = randomBytes(16).toString('hex')) {
  const key = await derive(password, salt, 32, { N: 32768, r: 8, p: 3, maxmem: 64 * 1024 * 1024 });
  return `scrypt$32768$8$3$${salt}$${key.toString('hex')}`;
}
async function passwordValid(password, stored) {
  const encoded = stored || 'scrypt$32768$8$3$00000000000000000000000000000000$' + '0'.repeat(64);
  const parts = encoded.split('$');
  const actual = (await passwordHash(password, parts[4])).split('$')[5];
  return timingSafeEqual(Buffer.from(actual, 'hex'), Buffer.from(parts[5], 'hex')) && !!stored;
}
function sessionToken(request) {
  return request.headers.get('Cookie')?.split(';').map(v => v.trim()).find(v => v.startsWith(cookieName + '='))?.slice(cookieName.length + 1) || '';
}
async function session(request, env) {
  const value = sessionToken(request);
  if (!/^[a-f0-9]{64}$/.test(value)) return null;
  return env.DB.prepare('SELECT u.id, u.username, u.role FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=? AND s.expires_at>? AND u.disabled=0').bind(hash(value), now()).first();
}
async function startSession(env, user, remember) {
  const value = token(), seconds = remember ? 30 * 86400 : 12 * 3600;
  await env.DB.prepare('INSERT INTO sessions (token_hash,user_id,expires_at) VALUES (?,?,?)').bind(hash(value), user.id, now() + seconds).run();
  return json({ user: { username: user.username, role: user.role } }, 200, { 'Set-Cookie': `${cookieName}=${value}; Path=/; HttpOnly; Secure; SameSite=Lax${remember ? '; Max-Age=' + seconds : ''}` });
}
async function limited(env, key, limit) {
  const record = await env.DB.prepare('INSERT INTO rate_limits (key,count,expires_at) VALUES (?,1,?) ON CONFLICT(key) DO UPDATE SET count=CASE WHEN expires_at<=? THEN 1 ELSE count+1 END,expires_at=CASE WHEN expires_at<=? THEN excluded.expires_at ELSE expires_at END RETURNING count').bind(key, now() + 900, now(), now()).first();
  return record.count > limit;
}
async function bodyJson(request) {
  if (!request.headers.get('Content-Type')?.startsWith('application/json')) throw new Error('JSON required');
  const reader = request.body?.getReader();
  if (!reader) throw new Error('Body required');
  let size = 0, chunks = [];
  while (true) { const { done, value } = await reader.read(); if (done) break; size += value.length; if (size > 4096) { await reader.cancel(); throw new Error('Too large'); } chunks.push(value); }
  const value = JSON.parse(Buffer.concat(chunks).toString());
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Object required');
  return value;
}
function safeNext(value) { return /^\/(?!\/)/.test(value || '') && !/[\\\r\n]/.test(value) ? value : '/menu/'; }
async function media(request, env, pathname) {
  let key;
  try { key = decodeURIComponent(pathname.slice('/media/'.length)); } catch { return fail('Invalid media path'); }
  if (!/^(Films|Games)\//.test(key) || key.split('/').some(p => p === '..' || p === '.') || key.includes('\\')) return fail('Not found', 404);
  const head = await env.MEDIA.head(key);
  if (!head) return fail('This media is not available yet.', 404);
  const headers = new Headers({ 'Cache-Control': 'private, no-store', 'Accept-Ranges': 'bytes', ETag: head.httpEtag, 'Content-Type': 'application/octet-stream' });
  head.writeHttpMetadata(headers);
  headers.set('Cache-Control', 'private, no-store');
  if (request.headers.get('If-None-Match') === head.httpEtag) return new Response(null, { status: 304, headers });
  let start = 0, end = head.size - 1, partial = false;
  const range = request.headers.get('Range');
  if (range && (!request.headers.has('If-Range') || request.headers.get('If-Range') === head.httpEtag)) {
    const match = /^bytes=(\d*)-(\d*)$/.exec(range);
    if (!match || (!match[1] && !match[2])) return new Response(null, { status: 416, headers: { 'Content-Range': `bytes */${head.size}` } });
    if (!match[1]) start = Math.max(0, head.size - Number(match[2]));
    else { start = Number(match[1]); if (match[2]) end = Math.min(end, Number(match[2])); }
    if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start > end || start >= head.size) return new Response(null, { status: 416, headers: { 'Content-Range': `bytes */${head.size}` } });
    partial = true;
  }
  headers.set('Content-Length', String(Math.max(0, end - start + 1)));
  if (partial) headers.set('Content-Range', `bytes ${start}-${end}/${head.size}`);
  if (request.method === 'HEAD') return new Response(null, { status: partial ? 206 : 200, headers });
  const object = await env.MEDIA.get(key, partial ? { range: { offset: start, length: end - start + 1 } } : {});
  return new Response(object?.body || null, { status: partial ? 206 : 200, headers });
}
const publicPaths = new Set(['/', '/index.html', '/login', '/login.html', '/activate', '/activate.html', '/privacy', '/privacy.html', '/contact', '/contact.html', '/favicon.ico']);
async function handle(request, env) {
  const url = new URL(request.url), path = url.pathname;
  if (url.hostname === 'www.ryhze.com') return redirect('https://ryhze.com' + path + url.search);
  if (url.hostname === 'video.ryhze.com') return fail('Use the signed-in Ryhze media player.', 410);
  if (request.method === 'OPTIONS') return fail('Cross-origin requests are not allowed.', 403);
  if (!['GET','HEAD','POST'].includes(request.method)) return fail('Method not allowed', 405);
  if (request.method === 'POST' && request.headers.get('Origin') !== url.origin) return fail('Invalid request origin.', 403);
  if (path === '/api/health') return json({ ok: true, media: 'Cloudflare R2' });
  const user = await session(request, env);
  if (path === '/api/session') return user ? json({ user: { username: user.username, role: user.role } }) : fail('Sign in required.', 401);
  if (path === '/api/login' && request.method === 'POST') {
    let body; try { body = await bodyJson(request); } catch { return fail('Invalid request.'); }
    const username = String(body.username || '').trim().toLowerCase(), password = String(body.password || '');
    if (!username || username.length > 80 || password.length > 256) return fail('Incorrect user ID or password.', 401);
    const ipKey = hash((request.headers.get('CF-Connecting-IP') || 'local') + now().toString().slice(0, -5));
    if (await limited(env, 'ip:' + ipKey, 30) || await limited(env, 'user:' + hash(username), 10)) return fail('Too many attempts. Try again in 15 minutes.', 429);
    const account = await env.DB.prepare('SELECT * FROM users WHERE username=? COLLATE NOCASE').bind(username).first();
    if (!await passwordValid(password, account?.password) || account.disabled) return fail('Incorrect user ID or password.', 401);
    return startSession(env, account, body.remember === true);
  }
  if (path === '/api/activate' && request.method === 'POST') {
    let body; try { body = await bodyJson(request); } catch { return fail('Invalid request.'); }
    if (!/^[a-f0-9]{64}$/.test(body.token || '') || typeof body.password !== 'string' || body.password.length < 12 || body.password.length > 256) return fail('Use a valid invitation and a password of 12–256 characters.');
    if (await limited(env, 'activate:' + hash(request.headers.get('CF-Connecting-IP') || 'local'), 10)) return fail('Too many attempts. Try again later.', 429);
    const invite = await env.DB.prepare('SELECT i.user_id FROM invites i JOIN users u ON u.id=i.user_id WHERE i.token_hash=? AND i.expires_at>? AND i.used=0 AND u.disabled=0').bind(hash(body.token), now()).first();
    if (!invite) return fail('This invitation is invalid or expired.', 400);
    const encoded = await passwordHash(body.password);
    // Consumption and password replacement are one atomic database transaction.
    const result = await env.DB.batch([
      env.DB.prepare('UPDATE users SET password=? WHERE id=? AND EXISTS (SELECT 1 FROM invites WHERE token_hash=? AND used=0 AND expires_at>?)').bind(encoded, invite.user_id, hash(body.token), now()),
      env.DB.prepare('UPDATE invites SET used=1 WHERE user_id=?').bind(invite.user_id),
      env.DB.prepare('DELETE FROM sessions WHERE user_id=?').bind(invite.user_id)
    ]);
    if (!result[0].meta.changes) return fail('This invitation is invalid or expired.', 400);
    return json({ ok: true });
  }
  if (path === '/api/logout' && request.method === 'POST') {
    await env.DB.prepare('DELETE FROM sessions WHERE token_hash=?').bind(hash(sessionToken(request))).run();
    return json({ ok: true }, 200, { 'Set-Cookie': `${cookieName}=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0` });
  }
  if (path.startsWith('/api/admin/')) {
    if (user?.role !== 'admin') return fail('Administrator access required.', 403);
    if (path === '/api/admin/users' && request.method === 'GET') return json((await env.DB.prepare('SELECT id,username,role,disabled FROM users ORDER BY created_at').all()).results);
    if (path === '/api/admin/invite' && request.method === 'POST') {
      let body; try { body = await bodyJson(request); } catch { return fail('Invalid request.'); }
      const name = String(body.username || '').trim();
      if (!/^[\w.@+-]{2,80}$/.test(name)) return fail('Use 2–80 letters, numbers, or email characters.');
      let account = await env.DB.prepare('SELECT id FROM users WHERE username=? COLLATE NOCASE').bind(name).first();
      if (!account) { account = { id: token() }; await env.DB.prepare('INSERT INTO users (id,username,created_at) VALUES (?,?,?)').bind(account.id, name, now()).run(); }
      const value = token();
      await env.DB.batch([env.DB.prepare('UPDATE invites SET used=1 WHERE user_id=?').bind(account.id),env.DB.prepare('INSERT INTO invites (token_hash,user_id,expires_at) VALUES (?,?,?)').bind(hash(value), account.id, now() + 86400)]);
      return json({ url: url.origin + '/activate#' + value });
    }
    if (path === '/api/admin/disable' && request.method === 'POST') {
      let body; try { body = await bodyJson(request); } catch { return fail('Invalid request.'); }
      if (body.id === user.id) return fail('You cannot disable your own account.');
      await env.DB.batch([env.DB.prepare('UPDATE users SET disabled=1 WHERE id=?').bind(String(body.id)), env.DB.prepare('DELETE FROM sessions WHERE user_id=?').bind(String(body.id))]);
      return json({ ok: true });
    }
    return fail('Not found', 404);
  }
  if (path.startsWith('/api/')) return fail('Not found', 404);
  const publicAsset = /^\/assets\/(motion\.js|theme\.css|auth-ui\.js|site-ui\.js|ryhze-wordmark\.png)$/.test(path);
  if (!publicPaths.has(path) && !publicAsset && !user) return path.startsWith('/media/') ? fail('Sign in required.', 401) : redirect('/login?next=' + encodeURIComponent(safeNext(path + url.search)));
  if (path.startsWith('/media/')) return ['GET','HEAD'].includes(request.method) ? media(request, env, path) : fail('Method not allowed', 405);
  if (path.startsWith('/admin') && user?.role !== 'admin') return fail('Administrator access required.', 403);
  if (request.method !== 'GET' && request.method !== 'HEAD') return fail('Method not allowed', 405);
  if (['/menu/games/', '/menu/games/index.html'].includes(path)) return redirect('/menu/?mode=games');
  if (path === '/menu/films/player.html') return redirect('/player.html' + url.search);
  const mapped = ({ '/': '/index.html', '/login': '/login.html', '/activate': '/activate.html', '/privacy': '/privacy.html', '/contact': '/contact.html', '/admin': '/admin.html', '/menu': '/lobby.html', '/menu/': '/lobby.html', '/menu/index.html': '/lobby.html', '/menu/films/': '/lobby.html', '/menu/films/index.html': '/lobby.html' })[path] || path;
  const assetUrl = new URL(request.url); assetUrl.pathname = mapped;
  return env.ASSETS.fetch(new Request(assetUrl, request));
}
export default {
  async fetch(request, env) {
    let response;
    try { response = await handle(request, env); } catch (error) { console.error('Request failed:', error.name); response = fail('Something went wrong. Please try again.', 503); }
    const result = new Response(response.body, response);
    result.headers.set('X-Content-Type-Options', 'nosniff');
    result.headers.set('Referrer-Policy', 'same-origin');
    result.headers.set('X-Frame-Options', 'SAMEORIGIN');
    result.headers.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
    result.headers.set('Strict-Transport-Security', 'max-age=31536000');
    result.headers.set('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:; media-src 'self' blob:; connect-src 'self'; frame-src 'self'; frame-ancestors 'self'; base-uri 'none'; object-src 'none'; form-action 'self'");
    if (!new URL(request.url).pathname.startsWith('/assets/')) result.headers.set('Cache-Control', 'private, no-store');
    return result;
  },
  async scheduled(event, env) { await env.DB.batch(['sessions','invites','rate_limits'].map(table => env.DB.prepare(`DELETE FROM ${table} WHERE expires_at<?`).bind(now()))); }
};
