import test from 'node:test';
import assert from 'node:assert/strict';
import worker from './worker.mjs';

const release = { path: '/releases/1.0.2/Ryhze-1.0.2-Windows-Setup.exe', bytes: 3, sha256: 'abc' };
const index = JSON.stringify({ payload: Buffer.from(JSON.stringify({ releases: [release] })).toString('base64') });
const requests = [];
const env = { RELEASES: { async get(key) {
  requests.push(key);
  if (key === 'updates/stable.json') return { text: async () => index };
  if (key === release.path.slice(1)) return { size: 3, body: new Uint8Array([1,2,3]) };
  throw new Error('Must never access other objects');
} } };
test('serves index without caching and only the explicitly listed package', async () => {
  const response = await worker.fetch(new Request('https://updates.test/stable.json'), env);
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  assert.equal(await response.text(), index);
  const download = await worker.fetch(new Request(`https://updates.test${release.path}`), env);
  assert.equal(download.status, 200);
  assert.equal(download.headers.get('Content-Length'), '3');
  assert.deepEqual([...new Uint8Array(await download.arrayBuffer())], [1,2,3]);
});
test('blocks private media and arbitrary releases', async () => {
  for (const path of ['/Films/private.mp4', '/.private/update-signing.pem', '/releases/1.0.1/other.exe']) {
    assert.equal((await worker.fetch(new Request(`https://updates.test${path}`), env)).status, 404);
  }
});
test('does not provide public mutation endpoints', async () => {
  assert.equal((await worker.fetch(new Request('https://updates.test/stable.json', { method: 'PUT', body: 'bad' }), env)).status, 405);
});
test('missing index fails gracefully', async () => {
  assert.equal((await worker.fetch(new Request('https://updates.test/stable.json'), { RELEASES: { get: async () => null } })).status, 503);
});
