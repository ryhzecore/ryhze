import fs from 'node:fs';import {passwordHash} from '../cloud/worker.mjs';
fs.mkdirSync('.private',{recursive:true});
const encoded=await passwordHash('Local-QA-only-long-password');
fs.writeFileSync('.private/local-qa.sql',`INSERT OR REPLACE INTO users (id,username,password,role,created_at) VALUES ('local-qa','MobileTest','${encoded}','admin',1);`);
