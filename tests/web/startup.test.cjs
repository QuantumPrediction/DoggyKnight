const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { runInNewContext } = require('node:vm');

const html = readFileSync(join(__dirname, '../../export/web/shell.html'), 'utf8');
const script = html.match(/<script>([\s\S]+?)<\/script>/)[1].replace('$GODOT_CONFIG', '{}');
const offline = new TypeError('Failed to fetch');

async function visit(options = {}) {
  const values = options.values || new Map();
  const controls = Object.fromEntries(['stage', 'canvas', 'cover', 'status', 'progress', 'retry'].map(id =>
    [id, { hidden: id === 'retry', getBoundingClientRect: () => ({ width: 360 }), focus() {} }]));
  const events = {};
  const timers = [];
  const page = { reloads: 0, controls, values, events, timers };
  class Engine {
    static getMissingFeatures() { return options.missing || []; }
    async startGame(config) {
      page.exit = config.onExit;
      if (options.start) await options.start(page);
    }
  }
  runInNewContext(script, {
    document: { getElementById: id => controls[id] }, URLSearchParams, Engine,
    ResizeObserver: class { observe() {} }, devicePixelRatio: 1,
    location: { pathname: '/play/', search: options.search || '', reload: () => page.reloads++ },
    navigator: { onLine: options.online !== false },
    sessionStorage: {
      getItem: key => values.get(key),
      setItem(key, value) {
        if (options.denyStorage) throw new Error('Storage disabled');
        values.set(key, value);
      },
      removeItem: key => values.delete(key),
    },
    window: { addEventListener: (name, handler) => { events[name] = handler; },
      checkGameFiles: async () => { throw offline; } },
    console: { error() {}, warn() {} }, setTimeout: f => timers.push(f),
  });
  await new Promise(setImmediate);
  timers.forEach(f => f());
  return page;
}

const failFetch = async () => { throw offline; };

test('a startup fetch rejection reopens once, then offers manual retry on persistent failure', async () => {
  const first = await visit({ start: failFetch });
  assert.equal(first.reloads, 1);
  assert.equal(first.controls.retry.hidden, true);
  const second = await visit({ start: failFetch, values: first.values });
  assert.equal(second.reloads, 0);
  assert.equal(second.controls.retry.hidden, false);
});

test('successful startup clears the retry and keeps the running game and its exit screen visible', async () => {
  const failed = await visit({ start: failFetch });
  const game = await visit({ values: failed.values, start: async page => {
    page.events.unhandledrejection({ reason: offline });
  } });
  assert.equal(game.reloads, 0);
  assert.equal(game.values.size, 0);
  assert.equal(game.controls.cover.hidden, true);
  game.events.error({ error: offline });
  game.exit(0);
  assert.equal(game.controls.cover.hidden, false);
  assert.equal(game.controls.status.textContent, '已離開遊戲。');
  assert.equal(game.reloads, 0);
});

test('offline, denied storage, missing graphics, diagnostics and non-network errors offer manual controls', async () => {
  for (const opts of [{ online: false }, { denyStorage: true }, { missing: ['WebGL 2'] },
    { search: '?check=1' }, { start: async () => { throw new Error('Invalid game data'); } }]) {
    const result = await visit({ start: failFetch, ...opts });
    assert.equal(result.reloads, 0);
    assert.equal(result.controls.retry.hidden, false);
  }
});

test('an exit during startup cancels a scheduled reload and keeps its status', async () => {
  const page = await visit({ start: async current => {
    current.events.error({ error: offline });
    current.exit(1);
  } });
  assert.equal(page.reloads, 0);
  assert.match(page.controls.status.textContent, /遊戲中斷/);
});
