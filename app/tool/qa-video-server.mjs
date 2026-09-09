import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
const fixture = await readFile(new URL('../.private/qa/playback.mp4', import.meta.url));
createServer((request, response) => {
  if (request.url !== '/playback.mp4') { response.writeHead(404); response.end(); return; }
  response.writeHead(200, {'Content-Type': 'video/mp4', 'Content-Length': fixture.length});
  response.end(fixture);
}).listen(8871, '127.0.0.1', () => process.stdout.write('Local Android test fixture ready on port 8871.\n'));
