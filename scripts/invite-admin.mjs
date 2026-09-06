// Run once with Wrangler D1. The private output stays outside the deployed asset folder.
import { randomBytes, createHash } from 'node:crypto';
import fs from 'node:fs';
const value=randomBytes(32).toString('hex'),id=randomBytes(16).toString('hex'),expires=Math.floor(Date.now()/1000)+86400;
const name=process.argv[2]||'Andru';if(!/^[\w.@+-]{2,80}$/.test(name))throw Error('Invalid username');
fs.mkdirSync('.private',{recursive:true});
fs.writeFileSync('.private/admin-invite.sql',`INSERT OR IGNORE INTO users (id,username,role,created_at) VALUES ('${id}','${name}','admin',${Math.floor(Date.now()/1000)});\nINSERT INTO invites (token_hash,user_id,expires_at) SELECT '${createHash('sha256').update(value).digest('hex')}',id,${expires} FROM users WHERE username='${name}' AND role='admin';\n`);
fs.writeFileSync('.private/admin-setup.txt',`User ID: ${name}\nhttps://ryhze.com/activate#${value}\nExpires in 24 hours. Treat this link like a password.\n`);
console.log('Private one-time administrator invitation prepared.');
