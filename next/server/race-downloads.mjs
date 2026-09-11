import { createPublicKey, verify } from 'node:crypto';
import key from '../../app/updates/public-key.json' with { type: 'json' };
const response = (data, status = 200) => new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'private, no-store' } });
export async function raceDownloads(request, env) {
  if (!['GET','HEAD'].includes(request.method)) return response({ error: 'Method not allowed' }, 405);
  const manifest = await env.MEDIA.get('race/updates/stable.json');
  if (!manifest) return response({ available: false, message: 'A verified RACE installer is not available yet.' });
  const envelopeText = await manifest.text();
  const envelope = JSON.parse(envelopeText);
  const payload = Buffer.from(envelope.payload, 'base64');
  const publicKey = createPublicKey({ key: { kty: 'OKP', crv: 'Ed25519', x: Buffer.from(key.publicKey, 'base64').toString('base64url') }, format: 'jwk' });
  if (envelope.keyId !== key.keyId || !verify(null, payload, publicKey, Buffer.from(envelope.signature, 'base64'))) return response({ error: 'RACE release verification failed.' }, 503);
  const data = JSON.parse(payload);
  const releases = Array.isArray(data.releases) ? data.releases.filter(r => r.platform === 'windows') : [];
  const release = releases.length === 1 ? releases[0] : null;
  if (release && (!Number.isSafeInteger(release.build) || release.build <= 0 || !Number.isSafeInteger(release.bytes) || release.bytes <= 0 || release.bytes > 1024 * 1024 * 1024 || !/^[0-9a-f]{64}$/.test(release.sha256) || typeof release.notes !== 'string' || release.notes.length > 4000)) return response({ error: 'Invalid RACE release.' }, 503);
  if (data.schema !== 1 || data.product !== 'race' || !release || !/^\d+\.\d+\.\d+$/.test(release.version) || release.path !== `/api/admin/race/releases/${release.version}/RACE-${release.version}-Windows-Setup.exe`) return response({ error: 'Invalid RACE release.' }, 503);
  const path = new URL(request.url).pathname;
  if (path === '/api/admin/race/manifest') return new Response(envelopeText, { headers: { 'Content-Type': 'application/json', 'Cache-Control': 'private, no-store' } });
  if (path !== release.path) return response({ error: 'Release not found.' }, 404);
  const object = await env.MEDIA.get(`race/releases/${release.version}/RACE-${release.version}-Windows-Setup.exe`);
  if (!object || object.size !== release.bytes) return response({ error: 'RACE package unavailable.' }, 503);
  return new Response(request.method === 'HEAD' ? null : object.body, { headers: {
    'Content-Type': 'application/octet-stream', 'Content-Length': String(release.bytes),
    'Content-Disposition': `attachment; filename="RACE-${release.version}-Windows-Setup.exe"`,
    'Cache-Control': 'private, no-store', 'X-Checksum-SHA256': release.sha256,
  } });
}
