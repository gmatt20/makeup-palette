import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { dirname, resolve, sep, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const types = { '.html': 'text/html', '.mjs': 'text/javascript', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.glb': 'model/gltf-binary', '.usdz': 'model/vnd.usdz+zip' };
const port = Number(process.env.PORT || 4173);
createServer(async (request, response) => {
  try {
    if (!['GET', 'HEAD'].includes(request.method)) { response.writeHead(405); response.end(); return; }
    const path = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    let base = resolve(root, 'preview'), relative = path === '/' ? 'index.html' : path.slice(1);
    if (path.startsWith('/assets/')) { base = resolve(root, 'Sources/MakeupFace/Resources'); relative = path.slice(8); }
    if (path.startsWith('/vendor/')) { base = resolve(root, 'node_modules/three'); relative = path.slice(8); }
    const file = resolve(base, relative);
    if (!file.startsWith(base + sep) || !(await stat(file)).isFile()) { response.writeHead(404); response.end('Not found'); return; }
    response.writeHead(200, { 'Content-Type': types[extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    if (request.method === 'HEAD') { response.end(); return; }
    createReadStream(file).on('error', () => response.destroy()).pipe(response);
  } catch { response.writeHead(404); response.end('Not found'); }
}).listen(port, '127.0.0.1', () => console.log(`Face preview: http://127.0.0.1:${port}`));
