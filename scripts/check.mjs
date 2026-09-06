import fs from 'node:fs';import vm from 'node:vm';
for(const file of fs.readdirSync('.').filter(name=>name.endsWith('.html'))){const text=fs.readFileSync(file,'utf8');if(/<script(?![^>]*\bsrc=)[^>]*>\s*\S/i.test(text))throw Error('Inline script in '+file);if(/\bon(click|load|error)=/i.test(text))throw Error('Inline event handler in '+file);}
for(const file of fs.readdirSync('assets').filter(name=>name.endsWith('.js')))new vm.Script(fs.readFileSync('assets/'+file,'utf8'),{filename:file});
for(const file of ['auth.js'])if(fs.existsSync(file))throw Error('Legacy client authentication remains.');
console.log('Page scripts parse; no inline handlers or client-side password files remain.');
