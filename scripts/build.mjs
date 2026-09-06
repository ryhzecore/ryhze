import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.join(root, 'dist');
if (path.dirname(output) !== root || path.basename(output) !== 'dist') throw Error('Invalid output path');
// Keep watched directories in place on Windows; remove generated files only.
function clearFiles(dir) { for (const entry of fs.readdirSync(dir, { withFileTypes: true })) { const full = path.join(dir, entry.name); if (entry.isDirectory()) clearFiles(full); else fs.unlinkSync(full); } }
if (fs.existsSync(output)) clearFiles(output); else fs.mkdirSync(output);
const pages = ['index.html','login.html','activate.html','admin.html','lobby.html','player.html','game.html','privacy.html','contact.html','404.html','site-version.js','library-data.js'];
for (const file of pages) fs.copyFileSync(path.join(root,file),path.join(output,file));
fs.cpSync(path.join(root,'assets'),path.join(output,'assets'),{recursive:true});
for (const folder of ['Films','Games']) {
  const copyArtwork = dir => { for (const entry of fs.readdirSync(dir,{withFileTypes:true})) { const full=path.join(dir,entry.name); if(entry.isDirectory()&&!['Stream','Streams','Download'].includes(entry.name))copyArtwork(full);else if(entry.isFile()&&/\.(png|jpg|jpeg|webp|avif)$/i.test(entry.name)){const dest=path.join(output,path.relative(root,full));fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(full,dest);} } };
  if(fs.existsSync(path.join(root,folder)))copyArtwork(path.join(root,folder));
}
console.log('Built website assets only; no server code, credentials, tooling, or video files included.');
