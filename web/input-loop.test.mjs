// SPDX-License-Identifier: GPL-2.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import { KeyboardInput, bindKeyboard } from './input.mjs';
import { FrameInbox, FRAME_TOPIC } from './protocol.mjs';
import { InputTransactions, GameplayLoop, LAST_INPUT_SELECTOR, GAME_STARTED_SELECTOR, INITIALIZE_GAME_SELECTOR, GAME_RESOURCES_PREPARED_SELECTOR, PREPARE_GAME_RESOURCES_SELECTOR } from './input-loop.mjs';

const word = n => BigInt(n).toString(16).padStart(64, '0');
const deferred = () => { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b; }); return { promise, resolve, reject }; };
const flush = async () => { for (let i = 0; i < 8; ++i) await Promise.resolve(); };
function frameLog(sequence, hash) {
  return { address: '0x1234', topics: [FRAME_TOPIC, '0x' + word(sequence), '0x' + word(sequence)],
    data: '0x' + word(2) + word(1) + word(96) + word(2) + '0102' + '0'.repeat(60),
    transactionHash: hash, logIndex: '0x0', blockNumber: '0x1' };
}
function fixture({ gameplay = true, started = true, sequence = 0, nativeZone = false, prepared = started } = {}) {
  const chain = { started, sequence, prepared }, calls = [], pending = new Map(), delivered = [];
  const inbox = new FrameInbox((frame, source) => delivered.push({ frame, source }));
  const env = { chain, calls, pending, delivered, inbox, sendError: null, receiptError: null, status: '0x1',
    wait: null, badSequence: false, duplicateWS: false, extraFrame: false, initializeEffect: true, prepareEffect: true, startupFrame: false, startupSequenceChange: false, receiptHook: null, preparedReadError: null };
  const rpc = async (method, params) => {
    calls.push({ method, params });
    if (method === 'eth_call') {
      if (params[0].data === LAST_INPUT_SELECTOR) return '0x' + word(chain.sequence);
      if (params[0].data === GAME_STARTED_SELECTOR) return '0x' + word(chain.started ? 1 : 0);
      if (params[0].data === GAME_RESOURCES_PREPARED_SELECTOR) { if (env.preparedReadError) throw env.preparedReadError; return '0x' + word(chain.prepared ? 1 : 0); }
      throw Error('Unexpected selector');
    }
    assert.equal(method, 'eth_sendTransaction');
    if (env.sendError) throw env.sendError;
    const hash = '0x' + word(pending.size + 1);
    pending.set(hash, params[0]); return hash;
  };
  env.mine = hash => {
    const tx = pending.get(hash);
    let logs = [];
    if (env.status === '0x1') {
      if (tx.data === PREPARE_GAME_RESOURCES_SELECTOR) { if (env.prepareEffect) chain.prepared = true; }
      else if (tx.data === INITIALIZE_GAME_SELECTOR) { if (env.initializeEffect) chain.started = true; }
      else {
        chain.sequence = Number(BigInt('0x' + tx.data.slice(74)));
        const log = frameLog(chain.sequence + (env.badSequence ? 1 : 0), hash);
        logs = [log];
        if (env.extraFrame) logs.push({ ...log, logIndex: '0x1' });
        if (env.duplicateWS) inbox.accept(log, 'ws');
      }
    }
    if (env.startupFrame && [INITIALIZE_GAME_SELECTOR, PREPARE_GAME_RESOURCES_SELECTOR].includes(tx.data)) logs = [frameLog(1, hash)];
    if (env.startupSequenceChange && [INITIALIZE_GAME_SELECTOR, PREPARE_GAME_RESOURCES_SELECTOR].includes(tx.data)) chain.sequence++;
    return { status: env.status, logs, transactionHash: hash };
  };
  const waitReceipt = async (_rpc, hash) => {
    if (env.receiptHook) await env.receiptHook(pending.get(hash));
    if (env.receiptError) throw env.receiptError;
    if (env.wait) await env.wait.promise;
    return env.mine(hash);
  };
  const client = new InputTransactions(rpc, { address: '0x1234', driver: '0xabcd', gameplay, nativeZone }, inbox, { waitReceipt });
  return { ...env, client, env };
}
function scheduler() {
  let id = 0;
  const tasks = new Map();
  return { tasks, schedule(fn, ms) { const key = ++id; tasks.set(key, { fn, ms }); return key; },
    cancel(key) { tasks.delete(key); }, async fire() {
      const entry = tasks.entries().next().value; assert(entry, 'expected scheduled tic');
      tasks.delete(entry[0]); return entry[1].fn();
    } };
}
function loopFixture(f) {
  const clock = scheduler(), keyboard = new KeyboardInput(), errors = [];
  const loop = new GameplayLoop(f.client, keyboard, { schedule: clock.schedule, cancel: clock.cancel,
    now: () => 0, onError: error => errors.push(error.message) });
  return { clock, keyboard, loop, errors };
}
const submitted = f => f.calls.filter(call => call.method === 'eth_sendTransaction').map(call => call.params[0]);

test('legacy deployment reads only its counter and keeps static zero-button ABI', async () => {
  const f = fixture({ gameplay: false, started: false, sequence: 7 }); await f.client.load();
  assert.deepEqual(f.calls.map(c => c.params[0].data), [LAST_INPUT_SELECTOR]);
  const mined = await f.client.nextFrame();
  assert.equal(mined.status, '0x1'); assert.equal(f.client.sequence, 8);
  const tx = submitted(f)[0]; assert.equal(BigInt('0x' + tx.data.slice(10, 74)), 0n);
  assert.equal(BigInt('0x' + tx.data.slice(74)), 8n); assert.equal(tx.from, '0xabcd');
  await assert.rejects(f.client.startGame(), /unavailable/);
});

test('explicit start initializes once, preserves static counter, and reload/resume reuses initialized state', async () => {
  const f = fixture({ started: false, sequence: 3 }); await f.client.load();
  await assert.rejects(f.client.nextFrame(1), /Start gameplay/); assert.equal(submitted(f).length, 0);
  await f.client.startGame(); assert.equal(f.client.started, true); assert.equal(f.client.sequence, 3);
  assert.equal(submitted(f)[0].data, INITIALIZE_GAME_SELECTOR);
  await f.client.nextFrame(257); assert.equal(f.client.sequence, 4);
  await f.client.startGame(); assert.equal(submitted(f).filter(tx => tx.data === INITIALIZE_GAME_SELECTOR).length, 1);
  f.chain.sequence = 12; await f.client.startGame(); assert.equal(f.client.sequence, 12);
});

test('single transaction lock rejects overlap during receipt wait', async () => {
  const f = fixture(); await f.client.load(); f.env.wait = deferred();
  const first = f.client.nextFrame(1); await flush();
  assert(f.client.busy); await assert.rejects(f.client.nextFrame(2), /pending/);
  assert.equal(submitted(f).length, 1); f.env.wait.resolve(); await first;
  assert.equal(f.client.sequence, 1); assert(f.client.canSend);
});

test('connection side effects occur only after valid exclusive command reservation', async () => {
  const f=fixture(); await f.client.load(); let disconnected=0;
  await assert.rejects(f.client.nextFrame(0x4000,{beforeSend:()=>++disconnected}),/mask/);
  assert.equal(disconnected,0);f.env.wait=deferred();
  const pending=f.client.nextFrame(0,{beforeSend:()=>++disconnected});await flush();
  await assert.rejects(f.client.nextFrame(0,{beforeSend:()=>++disconnected}),/pending/);
  assert.equal(disconnected,1);f.env.wait.resolve();await pending;
});

test('definite revert releases lock and does not consume input sequence', async () => {
  const f = fixture(); await f.client.load(); f.env.status = '0x0';
  await assert.rejects(f.client.nextFrame(1), /reverted/);
  assert.equal(f.client.sequence, 0); assert(f.client.canSend);
  f.env.status = '0x1'; await f.client.nextFrame(2); assert.equal(f.client.sequence, 1);
  assert.deepEqual(submitted(f).map(tx => Number(BigInt('0x' + tx.data.slice(74)))), [1, 1]);
});

for (const failure of ['send', 'receipt']) test(`${failure} uncertainty halts all subsequent inputs`, async () => {
  const f = fixture(); await f.client.load();
  if (failure === 'send') f.env.sendError = Error('Disconnected during send');
  else f.env.receiptError = Error('Receipt timeout');
  await assert.rejects(f.client.nextFrame(1), /Disconnected|timeout/);
  assert(f.client.uncertain); assert(f.client.busy); assert(!f.client.canSend);
  await assert.rejects(f.client.nextFrame(1), /outcome unknown/);
  await assert.rejects(f.client.load(), /unavailable/);
});

test('mined invalid Frame consumes counter and invalidates display channel', async () => {
  const f = fixture(); await f.client.load(); f.env.badSequence = true;
  await assert.rejects(f.client.nextFrame(1), /sequence mismatch/);
  assert.equal(f.client.sequence, 1); assert(f.client.invalidated); assert.equal(f.delivered.length, 0);
  await assert.rejects(f.client.nextFrame(1), /invalidated/);
});

test('multiple Frame logs invalidate channel while WS/receipt duplicate is accepted once', async () => {
  const f = fixture(); await f.client.load(); f.env.duplicateWS = true;
  await f.client.nextFrame(1); assert.equal(f.delivered.length, 1); assert.equal(f.inbox.duplicates, 1);
  f.env.duplicateWS = false; f.env.extraFrame = true;
  await assert.rejects(f.client.nextFrame(1), /exactly one/); assert(f.client.invalidated);
});

test('chain invalidation during pending transaction prevents receipt display', async () => {
  const f = fixture(); await f.client.load(); f.env.wait = deferred();
  const pending = f.client.nextFrame(0); await flush(); f.client.invalidate(); f.env.wait.resolve();
  await assert.rejects(pending, /invalidated/); assert.equal(f.delivered.length, 0);
});

test('initialization requires actual confirmed gameStarted and blocks concurrent start', async () => {
  const f = fixture({ started: false }); await f.client.load(); f.env.wait = deferred();
  const pending = f.client.startGame(); await flush();
  await assert.rejects(f.client.startGame(), /pending|outcome unknown/);
  f.env.initializeEffect = false; f.env.wait.resolve();
  await assert.rejects(pending, /not confirmed/); assert(f.client.invalidated); assert(f.client.uncertain);
});

test('uint32 sequence exhaustion and invalid packet fail before transaction submission', async () => {
  const f = fixture({ sequence: 0xffffffff }); await f.client.load();
  await assert.rejects(f.client.nextFrame(0), /sequence/); assert.equal(submitted(f).length, 0); assert(f.client.canSend);
  const other = fixture(); await other.client.load();
  await assert.rejects(other.client.nextFrame(0x4000), /mask/); assert.equal(submitted(other).length, 0); assert(other.client.canSend);
});

test('loop samples held keys once per accepted tic with no in-flight backlog', async () => {
  const f = fixture(); await f.client.load(); const { loop, keyboard, clock } = loopFixture(f);
  await loop.start(); keyboard.update('KeyW', true); f.env.wait = deferred();
  const first = clock.fire(); await flush();
  assert.equal(clock.tasks.size, 0); assert.equal(submitted(f).length, 1);
  keyboard.update('KeyW', false); keyboard.update('KeyD', true);
  f.env.wait.resolve(); await first; assert.equal(clock.tasks.size, 1);
  f.env.wait = null; await clock.fire();
  const txs = submitted(f); assert.deepEqual(txs.map(tx => Number(BigInt('0x' + tx.data.slice(10, 74)))), [1, 8]);
  assert.deepEqual(txs.map(tx => Number(BigInt('0x' + tx.data.slice(74)))), [1, 2]);
  assert.equal(clock.tasks.size, 1); loop.stop(); assert.equal(clock.tasks.size, 0);
});

test('stop during pending tic clears keys and prevents any successor transaction', async () => {
  const f = fixture(); await f.client.load(); const { loop, keyboard, clock } = loopFixture(f);
  await loop.start(); keyboard.update('ControlLeft', true); f.env.wait = deferred();
  const first = clock.fire(); await flush(); loop.stop();
  assert.equal(keyboard.sample(), 0); assert(!loop.running); assert.equal(clock.tasks.size, 0);
  await assert.rejects(loop.start(), /pending/);
  f.env.wait.resolve(); await first; assert.equal(clock.tasks.size, 0); assert.equal(submitted(f).length, 1);
  f.env.wait = null; await loop.start(); await clock.fire();
  assert.equal(Number(BigInt('0x' + submitted(f)[1].data.slice(10, 74))), 0); loop.stop();
});

test('stop during initialization settles initialization but does not send a tic', async () => {
  const f = fixture({ started: false }); await f.client.load(); const { loop, clock } = loopFixture(f);
  f.env.wait = deferred(); const pending = loop.start(); await flush(); loop.stop(); f.env.wait.resolve(); await pending;
  assert(f.client.started); assert.equal(clock.tasks.size, 0);
  assert.equal(submitted(f).length, 1); assert.equal(submitted(f)[0].data, INITIALIZE_GAME_SELECTOR);
});

test('loop error stops and clears held input; successful resume needs explicit Start', async () => {
  const f = fixture(); await f.client.load(); const { loop, keyboard, clock, errors } = loopFixture(f);
  await loop.start(); keyboard.update('Space', true); f.env.status = '0x0'; await clock.fire();
  assert(!loop.running); assert.equal(keyboard.sample(), 0); assert.equal(clock.tasks.size, 0);
  assert.deepEqual(errors, ['Transaction reverted']); f.env.status = '0x1';
  await loop.start(); await clock.fire(); assert.equal(f.client.sequence, 1); loop.stop();
});

test('blur and visibility stop active loop while inactive keys retain browser behavior', async () => {
  const f = fixture(); await f.client.load(); const { loop, keyboard, clock } = loopFixture(f);
  const target = new EventTarget(), document = new EventTarget(); document.hidden = false;
  const binding = bindKeyboard(target, keyboard, document, { enabled: () => loop.running, onReset: () => loop.stop() });
  const key = code => { const event = new Event('keydown', { cancelable: true }); event.code = code; target.dispatchEvent(event); return event; };
  assert(!key('Space').defaultPrevented); assert.equal(keyboard.sample(), 0);
  await loop.start(); assert(key('Space').defaultPrevented); assert.equal(keyboard.sample(), 64);
  target.dispatchEvent(new Event('blur')); assert(!loop.running); assert.equal(clock.tasks.size, 0); assert.equal(keyboard.sample(), 0);
  await loop.start(); key('KeyW'); document.hidden = true; document.dispatchEvent(new Event('visibilitychange'));
  assert(!loop.running); assert.equal(keyboard.sample(), 0); binding.dispose();
});

test('metadata must be canonical uint32/bool ABI words', async () => {
  for (const value of ['0x', '0x01', '0x' + word(2)]) {
    const client = new InputTransactions(async (_method, params) => params[0].data === LAST_INPUT_SELECTOR ? '0x' + word(0) : value,
      { address: '0x1234', gameplay: true }, { accept() {} });
    await assert.rejects(client.load(), /Malformed|Invalid/); assert(!client.loaded); assert(!client.busy);
  }
});

test('native-zone Start prepares then initializes under one lock without counters or Frames', async () => {
  const f = fixture({ nativeZone: true, started: false, sequence: 2 }); await f.client.load();
  f.env.wait = deferred(); const pending = f.client.startGame(); await flush();
  assert.equal(submitted(f).length, 1); assert.equal(submitted(f)[0].data, PREPARE_GAME_RESOURCES_SELECTOR);
  await assert.rejects(f.client.startGame(), /pending/); await assert.rejects(f.client.nextFrame(), /pending/);
  f.env.wait.resolve(); await pending;
  assert.deepEqual(submitted(f).map(tx => tx.data), [PREPARE_GAME_RESOURCES_SELECTOR, INITIALIZE_GAME_SELECTOR]);
  assert(f.client.prepared && f.client.started && f.client.canSend);
  assert.equal(f.client.sequence, 2); assert.equal(f.delivered.length, 0);
  await f.client.startGame(); assert.equal(submitted(f).length, 2);
});

test('prepared but uninitialized reload skips preparation and preserves legacy ABI calls', async () => {
  const f = fixture({ nativeZone: true, prepared: true, started: false }); await f.client.load();
  await f.client.startGame(); assert.deepEqual(submitted(f).map(tx => tx.data), [INITIALIZE_GAME_SELECTOR]);
  const legacy = fixture({ started: false }); await legacy.client.load(); await legacy.client.startGame();
  assert(!legacy.calls.some(call => call.params[0].data === GAME_RESOURCES_PREPARED_SELECTOR));
});

test('Stop during preparation settles it, defers initialization, and resume does not prepare twice', async () => {
  const f = fixture({ nativeZone: true, started: false }); await f.client.load();
  const { loop, clock, keyboard } = loopFixture(f); f.env.wait = deferred();
  const pending = loop.start(); await flush(); assert.equal(submitted(f)[0].data, PREPARE_GAME_RESOURCES_SELECTOR);
  keyboard.update('KeyW', true); loop.stop(); f.env.wait.resolve(); await pending;
  assert(f.client.prepared && !f.client.started); assert.equal(keyboard.sample(), 0); assert.equal(clock.tasks.size, 0);
  assert.deepEqual(submitted(f).map(tx => tx.data), [PREPARE_GAME_RESOURCES_SELECTOR]);
  f.env.wait = null; await loop.start(); assert(f.client.started); assert.equal(clock.tasks.size, 1);
  assert.deepEqual(submitted(f).map(tx => tx.data), [PREPARE_GAME_RESOURCES_SELECTOR, INITIALIZE_GAME_SELECTOR]); loop.stop();
});

test('prepare revert releases channel while prepare uncertainty prevents initialization', async () => {
  const reverted = fixture({ nativeZone: true, started: false }); await reverted.client.load(); reverted.env.status = '0x0';
  await assert.rejects(reverted.client.startGame(), /reverted/); assert(reverted.client.canSend); assert(!reverted.client.prepared);
  assert.deepEqual(submitted(reverted).map(tx => tx.data), [PREPARE_GAME_RESOURCES_SELECTOR]);
  const uncertain = fixture({ nativeZone: true, started: false }); await uncertain.client.load(); uncertain.env.receiptError = Error('Receipt timeout');
  await assert.rejects(uncertain.client.startGame(), /timeout/); assert(uncertain.client.uncertain && uncertain.client.busy);
  assert.deepEqual(submitted(uncertain).map(tx => tx.data), [PREPARE_GAME_RESOURCES_SELECTOR]);
});

test('initialization revert after preparation permits resume without duplicate preparation', async () => {
  const f = fixture({ nativeZone: true, started: false }); await f.client.load();
  f.env.receiptHook = async tx => { if (tx.data === INITIALIZE_GAME_SELECTOR) f.env.status = '0x0'; };
  await assert.rejects(f.client.startGame(), /reverted/); assert(f.client.prepared && !f.client.started && f.client.canSend);
  f.env.receiptHook = null; f.env.status = '0x1'; await f.client.startGame();
  assert.deepEqual(submitted(f).map(tx => tx.data), [PREPARE_GAME_RESOURCES_SELECTOR, INITIALIZE_GAME_SELECTOR, INITIALIZE_GAME_SELECTOR]);
});

test('preparation must confirm a canonical flag, unchanged counter, and no Frame', async () => {
  for (const fault of ['prepareEffect', 'startupFrame', 'startupSequenceChange']) {
    const f = fixture({ nativeZone: true, started: false }); await f.client.load();
    f.env[fault] = fault === 'prepareEffect' ? false : true;
    await assert.rejects(f.client.startGame(), /not confirmed|unexpectedly/);
    assert(f.client.invalidated && f.client.uncertain); assert.equal(submitted(f).length, 1);
  }
  const f = fixture({ nativeZone: true, started: false }); await f.client.load();
  f.env.receiptHook = async () => { f.env.preparedReadError = Error('Post-prepare read failed'); };
  await assert.rejects(f.client.startGame(), /read failed/); assert(f.client.uncertain); assert.equal(submitted(f).length, 1);
});

test('direct staged Start invalidated during pending preparation never submits initialization', async () => {
  const f = fixture({ nativeZone: true, started: false }); await f.client.load(); f.env.wait = deferred();
  const pending = f.client.startGame(); await flush();
  assert.deepEqual(submitted(f).map(tx => tx.data), [PREPARE_GAME_RESOURCES_SELECTOR]);
  f.client.invalidate(); f.env.wait.resolve();
  await assert.rejects(pending, /Session invalidated/);
  assert(f.chain.prepared && !f.chain.started); assert(f.client.invalidated);
  assert.deepEqual(submitted(f).map(tx => tx.data), [PREPARE_GAME_RESOURCES_SELECTOR]);
  await assert.rejects(f.client.startGame(), /Session invalidated/);
});
