// Passed only to the official Godot engine. Other page requests use the browser's native fetch.
function gameFetch(manifest, request, options) {
  const url = new URL(typeof request === 'string' ? request : request.url, document.baseURI);
  const name = url.pathname.split('/').pop();
  const asset = Object.hasOwn(manifest, name) ? manifest[name] : null;
  if (!asset || url.href !== new URL(name, document.baseURI).href) return fetch(request, options);
  if (typeof DecompressionStream === 'undefined') {
    return Promise.reject(new Error('This browser needs gzip DecompressionStream support.'));
  }
  let index = 0;
  let active = null;
  const cancellation = new AbortController();
  const stream = new ReadableStream({
    async pull(controller) {
      while (true) {
        if (!active) {
          if (index === asset.parts.length) {
            controller.close();
            return;
          }
          const path = asset.parts[index++];
          const response = await fetch(new URL(path, url), { signal: cancellation.signal });
          if (!response.ok) throw new Error('Could not load ' + path + ' (' + response.status + ')');
          active = response.body.pipeThrough(new DecompressionStream('gzip')).getReader();
        }
        const chunk = await active.read();
        if (!chunk.done) {
          controller.enqueue(chunk.value);
          return;
        }
        active.releaseLock();
        active = null;
      }
    },
    cancel() {
      cancellation.abort();
      return active?.cancel().catch(() => {});
    },
  });
  return Promise.resolve(new Response(stream, {
    headers: { 'Content-Type': asset.type, 'Content-Length': String(asset.size) },
  }));
}

// Run only when a tester opens the file-check link. Normal launches do not download twice.
async function checkGameFiles(manifest, onFile) {
  for (const [name, asset] of Object.entries(manifest)) {
    onFile(name);
    const response = await gameFetch(manifest, name);
    const bytes = await response.arrayBuffer();
    const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));
    const hex = Array.from(hash, value => value.toString(16).padStart(2, '0')).join('');
    if (bytes.byteLength !== asset.size || hex !== asset.sha256) {
      throw new Error('檔案內容與此版本不符。 ' + name);
    }
    if (asset.type === 'application/wasm') await WebAssembly.compile(bytes);
  }
}
