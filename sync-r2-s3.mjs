import fs from 'node:fs';
import path from 'node:path';
import { S3Client } from '@aws-sdk/client-s3';
import { Upload } from '@aws-sdk/lib-storage';

const root = process.argv[2] ? path.resolve(process.argv[2]) : process.cwd();
const bucket = process.env.R2_BUCKET || 'ryhze-streams';
const accountId = process.env.R2_ACCOUNT_ID || 'e120ad8b4234f7c9641ac44e0bee43c4';
const accessKeyId = process.env.R2_ACCESS_KEY_ID;
const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
if (!accessKeyId || !secretAccessKey) {
  throw new Error('Set R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY before uploading.');
}

const client = new S3Client({
  region: 'auto',
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: { accessKeyId, secretAccessKey }
});
const allowed = new Set(['.mp4', '.webm', '.m4v', '.mov', '.ogv', '.ogg', '.m4a', '.mp3', '.wav', '.aac']);

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const full = path.join(dir, entry.name);
    return entry.isDirectory() ? walk(full) : [full];
  });
}

const files = walk(root).filter(file => {
  const rel = path.relative(root, file).replaceAll('\\', '/');
  return /^(Films|Games)\//.test(rel) && allowed.has(path.extname(file).toLowerCase());
}).filter(file => {
  const web = `${path.join(path.dirname(file), path.basename(file, path.extname(file)))}-web${path.extname(file)}`;
  return !fs.existsSync(web) || file.toLowerCase().endsWith('-web' + path.extname(file).toLowerCase());
});

for (const file of files) {
  const key = path.relative(root, file).replaceAll('\\', '/');
  const size = fs.statSync(file).size;
  if (!size) continue;
  process.stdout.write(`Uploading ${key} (${(size / 1073741824).toFixed(2)} GiB)\n`);
  await new Upload({
    client,
    params: { Bucket: bucket, Key: key, Body: fs.createReadStream(file) },
    partSize: 64 * 1024 * 1024,
    queueSize: 3,
    leavePartsOnError: false
  }).done();
}
console.log('R2 S3 upload complete.');
