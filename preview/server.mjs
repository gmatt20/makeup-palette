import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { dirname, resolve, sep, extname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const types = {
  '.html': 'text/html',
  '.mjs': 'text/javascript',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.glb': 'model/gltf-binary',
  '.usdz': 'model/vnd.usdz+zip',
};

function under(base, file) {
  const rel = relative(base, file);
  return rel && !rel.startsWith('..') && !rel.includes(`..${sep}`);
}

async function handle(request, response) {
  try {
    if (!['GET', 'HEAD'].includes(request.method)) {
      response.writeHead(405);
      response.end();
      return;
    }
    const path = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    let base = resolve(root, 'preview');
    let target = path === '/' ? 'index.html' : path.slice(1);
    if (path.startsWith('/assets/')) {
      base = resolve(root, 'Sources/MakeupFace/Resources');
      target = path.slice(8);
    }
    if (path.startsWith('/vendor/')) {
      base = resolve(root, 'node_modules/three');
      target = path.slice(8);
    }
    const file = resolve(base, target);
    if (!under(base, file) || !(await stat(file)).isFile()) {
      response.writeHead(404);
      response.end('Not found');
      return;
    }
    response.writeHead(200, {
      'Content-Type': types[extname(file)] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    if (request.method === 'HEAD') {
      response.end();
      return;
    }
    createReadStream(file).on('error', () => response.destroy()).pipe(response);
  } catch {
    response.writeHead(404);
    response.end('Not found');
  }
}

const preferred = Number(process.env.PORT || 4173);
const server = createServer(handle);

function listen(port, attemptsLeft) {
  server.once('error', error => {
    if (error.code === 'EADDRINUSE' && attemptsLeft > 0) {
      listen(port + 1, attemptsLeft - 1);
      return;
    }
    throw error;
  });
  server.listen(port, '127.0.0.1', () => {
    console.log(`Face preview: http://127.0.0.1:${port}`);
  });
}

listen(preferred, 20);
