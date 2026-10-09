// SPDX-License-Identifier: GPL-2.0-only
// Isolated DOM/RPC/WS wiring proof. It does not claim a real browser or EVM gate.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { FRAME_TOPIC } from './protocol.mjs';
import { INITIALIZE_GAME_SELECTOR, GAME_STARTED_SELECTOR, LAST_INPUT_SELECTOR, GAME_RESOURCES_PREPARED_SELECTOR, PREPARE_GAME_RESOURCES_SELECTOR } from './input-loop.mjs';

const palette = JSON.parse(await readFile(new URL('./palette.synthetic.json', import.meta.url), 'utf8'));
const word = value => BigInt(value).toString(16).padStart(64, '0');
const until = async predicate => { for (let i = 0; i < 1000 && !predicate(); ++i) await Promise.resolve(); assert(predicate(), 'expected asynchronous control state'); };
let version = 0;

async function appFixture({ gameplay = false, autotest = false, started = false, nativeZone = false, prepared = started } = {}) {
  const saved = Object.fromEntries(['window', 'document', 'location', 'fetch', 'WebSocket', 'ImageData'].map(key => [key, globalThis[key]]));
  const nodes = [], selectors = new Map(), sockets = new Set(), logs = [], transactions = [];
  const window = new EventTarget(), document = new EventTarget(); document.hidden = false;
  class Element extends EventTarget {
    constructor(tag = '') { super(); this.tag = tag; this.style = {}; this.textContent = ''; this.disabled = false; this.attributes = {}; this.children = []; nodes.push(this); }
    setAttribute(name, value) { this.attributes[name] = value; }
    append(...items) { this.children.push(...items); }
    before() {}
    click() { if (!this.disabled) this.dispatchEvent(new Event('click')); }
  }
  for (const selector of ['#status', '#step', '#frame', '.eyebrow', 'h1', '.pill', 'p']) selectors.set(selector, new Element());
  const canvas = selectors.get('#frame');
  const context = { image: null, putImageData(image) { this.image = image; }, getImageData() { return this.image; } };
  canvas.getContext = () => context;
  document.querySelector = selector => selectors.get(selector) ?? nodes.find(node => '#' + node.id === selector);
  document.createElement = tag => new Element(tag);
  const config = { rpcUrl: 'http://local.invalid/rpc', wsUrl: 'ws://local.invalid/ws', address: '0x1234', driver: '0xabcd',
    deploymentBlock: '0x0', rendererKind: 'doom-world-view', paletteUrl: '/palette.json', paletteKind: 'synthetic', resourceIdentity: palette.resourceIdentity };
  if (gameplay) config.gameplay = true;
  if (nativeZone) config.nativeZone = true;
  const chain = { started, prepared, sequence: 0, frame: 0 }, pending = new Map();
  function notify(socket, object) { const event = new Event('message'); event.data = JSON.stringify(object); socket.dispatchEvent(event); }
  class Socket extends EventTarget {
    constructor() { super(); sockets.add(this); queueMicrotask(() => this.dispatchEvent(new Event('open'))); }
    send(data) { const request = JSON.parse(data); queueMicrotask(() => notify(this, { id: request.id, result: '0x1' })); }
    close() { sockets.delete(this); this.dispatchEvent(new Event('close')); }
  }
  function mine(hash) {
    const tx = pending.get(hash); if (tx.receipt) return tx.receipt;
    let emitted = [];
    if (tx.data === PREPARE_GAME_RESOURCES_SELECTOR) chain.prepared = true;
    else if (tx.data === INITIALIZE_GAME_SELECTOR) chain.started = true;
    else {
      chain.sequence = Number(BigInt('0x' + tx.data.slice(74))); ++chain.frame;
      const pixels = Buffer.alloc(64000, 7).toString('hex');
      const log = { address: config.address, topics: [FRAME_TOPIC, '0x' + word(chain.frame), '0x' + word(chain.sequence)],
        data: '0x' + word(320) + word(200) + word(96) + word(64000) + pixels,
        transactionHash: hash, logIndex: '0x0', blockNumber: '0x' + chain.frame.toString(16) };
      logs.push(log); emitted = [log];
      for (const socket of sockets) queueMicrotask(() => notify(socket, { method: 'eth_subscription', params: { result: log } }));
    }
    tx.receipt = { status: '0x1', logs: emitted, transactionHash: hash }; return tx.receipt;
  }
  globalThis.window = window; globalThis.document = document; globalThis.location = { search: autotest ? '?autotest=1' : '' };
  globalThis.WebSocket = Socket;
  globalThis.ImageData = class { constructor(data, width, height) { this.data = data; this.width = width; this.height = height; } };
  globalThis.fetch = async (url, options) => {
    if (url === '/config.local.json') return { json: async () => config };
    if (url === '/palette.json') return { json: async () => palette };
    assert.equal(url, config.rpcUrl, 'isolated test must not access network');
    const request = JSON.parse(options.body); let result;
    if (request.method === 'eth_call') {
      const data = request.params[0].data;
      if (data === LAST_INPUT_SELECTOR) result = '0x' + word(chain.sequence);
      else if (data === GAME_STARTED_SELECTOR && gameplay) result = '0x' + word(chain.started ? 1 : 0);
      else if (data === GAME_RESOURCES_PREPARED_SELECTOR && gameplay && nativeZone) result = '0x' + word(chain.prepared ? 1 : 0);
      else throw Error('Unexpected metadata selector');
    } else if (request.method === 'eth_getLogs') result = [...logs];
    else if (request.method === 'eth_sendTransaction') {
      const hash = '0x' + word(pending.size + 1), tx = { ...request.params[0], hash };
      transactions.push(tx); pending.set(hash, tx); result = hash;
    } else if (request.method === 'eth_getTransactionReceipt') result = mine(request.params[0]);
    else throw Error('Unexpected RPC method');
    return { ok: true, json: async () => ({ jsonrpc: '2.0', id: request.id, result }) };
  };
  try {
    await import('./app.mjs?isolated=' + (++version));
    assert.deepEqual(window.__transportProof.errors, []);
  } catch (error) {
    for (const [key, value] of Object.entries(saved)) { if (value === undefined) delete globalThis[key]; else globalThis[key] = value; }
    throw error;
  }
  return { window, document, config, chain, transactions, context,
    client: window.fixtureClient, proof: window.__transportProof,
    cleanup() {
      window.dispatchEvent(new Event('beforeunload'));
      for (const [key, value] of Object.entries(saved)) { if (value === undefined) delete globalThis[key]; else globalThis[key] = value; }
    } };
}

test('old static DOM/autotest remains zero-button WS→receipt→Canvas flow', async () => {
  const f = await appFixture({ autotest: true });
  try {
    assert(f.proof.ready && f.proof.done && f.proof.fallbackVerified); assert(f.proof.duplicates >= 2);
    assert.equal(f.proof.frames.length, 2); assert.equal(f.proof.inputs.length, 2);
    assert.deepEqual(f.transactions.map(tx => Number(BigInt('0x' + tx.data.slice(10, 74)))), [0, 0]);
    assert.deepEqual(f.proof.frames.map(frame => frame.inputSeq), [1, 2]);
    assert.equal(f.context.image.data.length, 256000); assert.equal(f.proof.latestPixelsHex.length, 128000);
    assert.equal(f.document.querySelector('#game-start'), undefined); assert.equal(f.client.startGame, undefined);
  } finally { f.cleanup(); }
});

test('capable deployment still does not initialize merely loading/autotesting', async () => {
  const f = await appFixture({ gameplay: true, autotest: true });
  try {
    assert(f.proof.done && f.proof.gameplayAvailable); assert(!f.chain.started);
    assert.equal(f.transactions.filter(tx => tx.data === INITIALIZE_GAME_SELECTOR).length, 0);
    assert.equal(f.document.querySelector('#game-start').textContent, 'Start game →');
    await f.client.startGame({ run: false }); assert(f.chain.started);
    await f.client.nextFrame({ buttons: 257 });
    assert.equal(f.proof.inputs.at(-1).mask, 257); assert.equal(f.proof.frames.at(-1).inputSeq, 3);
    assert.equal(f.document.querySelector('#step').textContent, 'Step one tic →');
  } finally { f.cleanup(); }
});

test('actual Start/Stop wiring samples DOM keyboard, pauses on blur, and resumes without duplicate initialize', async () => {
  const f = await appFixture({ gameplay: true });
  try {
    const tasks = new Map(); let id = 0;
    f.client.loop.schedule = fn => { tasks.set(++id, fn); return id; };
    f.client.loop.cancel = key => tasks.delete(key);
    const start = f.document.querySelector('#game-start'), stop = f.document.querySelector('#game-stop');
    start.click(); await until(() => tasks.size === 1); assert(f.client.loop.running); assert.equal(tasks.size, 1);
    const event = new Event('keydown', { cancelable: true }); event.code = 'KeyW'; f.window.dispatchEvent(event);
    assert(event.defaultPrevented);
    const [key, tick] = tasks.entries().next().value; tasks.delete(key); await tick();
    assert.equal(f.proof.inputs.at(-1).mask, 1); assert.equal(tasks.size, 1);
    await assert.rejects(f.client.nextFrame(), /Stop continuous/);
    stop.click(); assert(!f.client.loop.running); assert.equal(tasks.size, 0); assert.equal(f.client.keyboard.sample(), 0);
    assert.equal(start.textContent, 'Resume game →');
    start.click(); await until(() => tasks.size === 1); assert(f.client.loop.running); assert.equal(tasks.size, 1);
    f.window.dispatchEvent(new Event('blur')); assert(!f.client.loop.running); assert.equal(tasks.size, 0);
    assert.equal(f.transactions.filter(tx => tx.data === INITIALIZE_GAME_SELECTOR).length, 1);
    assert.deepEqual(f.proof.errors, []);
  } finally { f.cleanup(); }
});

test('native-zone capable autotest remains static; explicit Start serializes preparation and initialization', async () => {
  const f = await appFixture({ gameplay: true, nativeZone: true, autotest: true });
  try {
    assert(f.proof.done && f.proof.nativeZoneAvailable); assert(!f.chain.prepared && !f.chain.started);
    assert.equal(f.transactions.length, 2); assert.equal(f.chain.sequence, 2); assert.equal(f.chain.frame, 2);
    await f.client.startGame({ run: false });
    assert.deepEqual(f.transactions.slice(2).map(tx => tx.data), [PREPARE_GAME_RESOURCES_SELECTOR, INITIALIZE_GAME_SELECTOR]);
    assert(f.proof.resourcesPrepared && f.proof.gameStarted); assert.equal(f.chain.sequence, 2); assert.equal(f.chain.frame, 2);
    await f.client.nextFrame({ buttons: 257 }); assert.equal(f.chain.sequence, 3); assert.equal(f.proof.frames.length, 3);
    await f.client.startGame({ run: false }); assert.equal(f.transactions.length, 5);
  } finally { f.cleanup(); }
});

test('native-zone prepared reload starts without preparing again', async () => {
  const f = await appFixture({ gameplay: true, nativeZone: true, prepared: true });
  try {
    assert(f.proof.resourcesPrepared && !f.proof.gameStarted);
    await f.client.startGame({ run: false });
    assert.deepEqual(f.transactions.map(tx => tx.data), [INITIALIZE_GAME_SELECTOR]);
  } finally { f.cleanup(); }
});
