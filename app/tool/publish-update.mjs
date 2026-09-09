import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const app = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const root = path.dirname(app);
const [_, version, buildText] = /^version: ([0-9.]+)\+(\d+)$/m.exec(fs.readFileSync(path.join(app, 'pubspec.yaml'), 'utf8')) || [];
if (!version) throw new Error('Set version and build in pubspec.yaml.');
const build = Number(buildText);
const source = fs.readFileSync(path.join(app, 'lib/core/updates.dart'), 'utf8');
if (!source.includes(`appVersion = '${version}'`) || !source.includes(`appBuild = ${build};`)) {
  throw new Error('Update appVersion and appBuild to match pubspec.yaml before building.');
}
if (!fs.readFileSync(path.join(app, 'tool/update-windows.ps1')).equals(
  fs.readFileSync(path.join(app, 'assets/update/update-windows.ps1')))) {
  throw new Error('Copy the Windows update helper into assets/update before building.');
}
const notesPath = process.argv.find(arg => arg.startsWith('--notes='))?.slice(8);
if (!notesPath) throw new Error('Provide --notes=<UTF-8 release notes text file>. Use --publish after reviewing the generated index.');
const notes = fs.readFileSync(path.resolve(notesPath), 'utf8').trim();
if (!notes || notes.length > 4000) throw new Error('Release notes must contain 1–4000 characters.');
const key = crypto.createPrivateKey(fs.readFileSync(path.join(app, '.private/update-signing.pem')));
const publicKey = JSON.parse(fs.readFileSync(path.join(app, 'updates/public-key.json')));
const rawPublic = Buffer.from(crypto.createPublicKey(key).export({ format: 'jwk' }).x, 'base64url').toString('base64');
if (rawPublic !== publicKey.publicKey || !source.includes(rawPublic)) throw new Error('Signing key does not match the app.');
const releases = [];
for (const [platform, suffix] of [['windows', 'Windows-Setup.exe'], ['android', 'Android.apk']]) {
  const filename = `Ryhze-${version}-${suffix}`;
  const file = path.join(root, 'releases', filename);
  const hash = crypto.createHash('sha256');
  for await (const chunk of fs.createReadStream(file)) hash.update(chunk);
  releases.push({ platform, version, build, path: `/releases/${version}/${filename}`,
    bytes: fs.statSync(file).size, sha256: hash.digest('hex'), notes });
}
const payload = Buffer.from(JSON.stringify({ schema: 1, publishedAt: new Date().toISOString(), releases }));
const envelope = JSON.stringify({ keyId: publicKey.keyId, payload: payload.toString('base64'),
  signature: crypto.sign(null, payload, key).toString('base64') }, null, 2) + '\n';
const manifest = path.join(app, '.private/stable.json');
fs.writeFileSync(manifest, envelope);
console.log(`Prepared signed Ryhze ${version}+${build} update index.`);
if (!process.argv.includes('--publish')) process.exit(0);
const origin = 'https://ryhze-updates.live-insights.workers.dev';
const previous = await fetch(`${origin}/stable.json`);
if (previous.ok) {
  const oldEnvelope = await previous.json();
  const oldPayload = Buffer.from(oldEnvelope.payload, 'base64');
  if (!crypto.verify(null, oldPayload, crypto.createPublicKey(key), Buffer.from(oldEnvelope.signature, 'base64'))) throw new Error('Existing index signature is invalid.');
  const old = JSON.parse(oldPayload).releases;
  for (const release of releases) {
    const existing = old.find(r => r.platform === release.platform);
    if (existing && (existing.build > build ||
        (existing.version === version && existing.sha256 !== release.sha256) ||
        (existing.build === build && (existing.sha256 !== release.sha256 || existing.path !== release.path)))) {
      throw new Error('A published build is immutable. Increase version/build and rebuild.');
    }
  }
} else if (previous.status !== 503) throw new Error(`Cannot inspect existing index (${previous.status}).`);
function upload(key, file, type) {
  const result = spawnSync(process.execPath, [path.join(root, 'node_modules/wrangler/bin/wrangler.js'),
    'r2', 'object', 'put', `ryhze-streams/${key}`, '--file', file, '--remote', '--content-type', type],
    { stdio: 'inherit', cwd: root });
  if (result.status !== 0) throw new Error(`Upload failed: ${key}. Update index has not been promoted.`);
}
// Upload immutable artifacts first. The signed index is promoted only after both succeed.
for (const r of releases) upload(r.path.slice(1), path.join(root, 'releases', r.path.split('/').at(-1)),
  r.platform === 'android' ? 'application/vnd.android.package-archive' : 'application/octet-stream');
upload('updates/stable.json', manifest, 'application/json');
const verifiedIndex = await fetch(`${origin}/stable.json`).then(r => r.text());
if (verifiedIndex !== envelope) throw new Error('Published index verification failed.');
for (const r of releases) {
  const response = await fetch(`${origin}${r.path}`);
  if (!response.ok) throw new Error(`Published download failed: ${r.platform}`);
  const hash = crypto.createHash('sha256');
  let size = 0;
  for await (const chunk of response.body) { hash.update(chunk); size += chunk.length; }
  if (hash.digest('hex') !== r.sha256 || size !== r.bytes) throw new Error(`Published package verification failed: ${r.platform}`);
  console.log(`Verified public ${r.platform} download (${size} bytes).`);
}
console.log(`Ryhze ${version} is live for in-app updates.`);
// Keep the website's installer cards and download routes on the same release.
const websiteManifest = path.join(root, 'next/server/releases.json');
fs.writeFileSync(websiteManifest, JSON.stringify(releases.map(r => ({
  platform: r.platform, version: r.version, filename: r.path.split('/').at(-1),
  bytes: r.bytes, sha256: r.sha256,
})), null, 2) + '\n');
console.log('Website release manifest synchronized. Validate and deploy next/ to publish its updated installer cards.');
