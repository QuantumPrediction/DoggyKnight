const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createHash, webcrypto } = require('node:crypto');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { runInNewContext } = require('node:vm');
const { gzipSync } = require('node:zlib');

const source = readFileSync(join(__dirname, '../../export/web/transport.js'), 'utf8');

function fixture() {
  const files = new Map();
  const manifest = {};
  function add(name, bytes, type) {
    const parts = [0, 4].map((start, index) => {
      const path = 'payload/' + name + '-' + index;
      files.set('/game/' + path, gzipSync(bytes.subarray(start, index === 0 ? 4 : undefined)));
      return path;
    });
    manifest[name] = { parts, type, size: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex') };
  }
  add('index.wasm', Buffer.from([0, 97, 115, 109, 1, 0, 0, 0]), 'application/wasm');
  add('index.pck', Buffer.from('the six chapters'), 'application/octet-stream');
  const baseURI = 'https://example.test/game/';
  const api = runInNewContext(source + '\n;({ gameFetch, checkGameFiles })', {
    URL, Response, ReadableStream, DecompressionStream, AbortController, WebAssembly,
    crypto: webcrypto, document: { baseURI },
    async fetch(path) {
      const key = new URL(path, baseURI).pathname;
      return files.has(key) ? new Response(files.get(key)) : new Response(null, { status: 404 });
    },
  });
  return { files, manifest, ...api };
}

test('nested hosting verifies both files and compiles the reassembled engine', async () => {
  const { manifest, checkGameFiles } = fixture();
  const seen = [];
  await checkGameFiles(manifest, name => seen.push(name));
  assert.deepEqual(seen, ['index.wasm', 'index.pck']);
});

test('a missing part reports its HTTP failure', async () => {
  const { manifest, files, checkGameFiles } = fixture();
  files.delete('/game/payload/index.pck-1');
  await assert.rejects(checkGameFiles(manifest, () => {}), /index\.pck-1 \(404\)/);
});

test('a valid gzip stream with changed, same-length game bytes fails the fingerprint', async () => {
  const { manifest, files, checkGameFiles } = fixture();
  files.set('/game/payload/index.pck-0', gzipSync(Buffer.from('oops')));
  await assert.rejects(checkGameFiles(manifest, () => {}), /檔案內容與此版本不符/);
});
