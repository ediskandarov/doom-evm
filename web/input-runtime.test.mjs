// SPDX-License-Identifier: GPL-2.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import { RawKeyboardInput, nativeKey, eventStepData, bindKeyboard, EVENTS_STEP_SELECTOR, EVENTS_NO_RENDER_SELECTOR } from './input.mjs';
import { InputTransactions, GameplayLoop, INITIALIZE_GAME_INPUT_SELECTOR, LAST_INPUT_SELECTOR, GAME_STARTED_SELECTOR } from './input-loop.mjs';
import { FRAME_TOPIC, FrameInbox } from './protocol.mjs';

const word = n => BigInt(n).toString(16).padStart(64, '0');
const deferred = () => { let resolve; const promise = new Promise(r => resolve = r); return { promise, resolve }; };
const flush = async () => { for (let i = 0; i < 20; ++i) await Promise.resolve(); };

test('native translation preserves unshifted original key numbers and raw repeat/order', () => {
  const k = new RawKeyboardInput();
  assert.equal(nativeKey('KeyD'), 100); assert.equal(nativeKey('Digit0'), 48);
  assert.equal(nativeKey('ArrowUp'), 0xad); assert.equal(nativeKey('F12'), 216);
  assert.equal(nativeKey('ShiftRight'), 0xb6); assert.equal(nativeKey('Pause'), 255);
  assert.equal(nativeKey('Unidentified'), undefined);
  for (const [code, key] of Object.entries({ Semicolon: 59, Quote: 39, BracketLeft: 91,
    BracketRight: 93, Backslash: 92, Backquote: 96, Slash: 47, IntlBackslash: 60 })) assert.equal(nativeKey(code), key);
  for (const [code, down] of [['KeyI', true], ['KeyD', true], ['KeyD', true], ['KeyD', false]]) k.update(code, down);
  assert.deepEqual([...k.packet()], [0, 105, 0, 100, 0, 100, 1, 100]);
  const first = k.packet(); k.update('KeyQ', true); k.acknowledge(first.length);
  assert.deepEqual([...k.packet()], [0, 113], 'events arriving during a receipt wait survive acknowledgement');
  k.clear(); assert.deepEqual([...k.packet()], [0, 113, 1, 105, 1, 113]);
});

test('ordered event batches retain backlog and encode exact bounded dynamic ABI', () => {
  const k = new RawKeyboardInput();
  for (let i = 0; i < 70; ++i) k.update('KeyD', true);
  assert.equal(k.packet().length, 128); k.acknowledge(128); assert.equal(k.packet().length, 12);
  const events = Uint8Array.of(0, 9, 1, 9);
  assert.equal(eventStepData(events, 7), EVENTS_STEP_SELECTOR + word(64) + word(7) + word(4) + '00090109'.padEnd(64, '0'));
  assert.equal(eventStepData(new Uint8Array(), 8, false), EVENTS_NO_RENDER_SELECTOR + word(64) + word(8) + word(0));
  for (const bad of [[], Uint8Array.of(0), Uint8Array.of(2, 0), new Uint8Array(130)]) assert.throws(() => eventStepData(bad, 1));
  for (const sequence of [0, -1, 2 ** 32, 1.5]) assert.throws(() => eventStepData(events, sequence));
});

function fixture({ started = true } = {}) {
  const state = { started, sequence: 0, sent: [], status: '0x1', wait: null, unknown: false };
  const inbox = new FrameInbox(() => {});
  const rpc = async (method, params) => {
    if (method === 'eth_call') {
      if (params[0].data === LAST_INPUT_SELECTOR) return '0x' + word(state.sequence);
      if (params[0].data === GAME_STARTED_SELECTOR) return '0x' + word(state.started);
      throw Error('Unexpected read');
    }
    assert.equal(method, 'eth_sendTransaction');
    state.sent.push(params[0].data); return '0x' + word(state.sent.length);
  };
  const waitReceipt = async (_rpc, hash) => {
    if (state.wait) await state.wait.promise;
    if (state.unknown) throw Error('Connection lost after submission');
    const data = state.sent[Number(BigInt(hash)) - 1]; let logs = [];
    if (state.status === '0x1') {
      if (data.startsWith(INITIALIZE_GAME_INPUT_SELECTOR)) state.started = true;
      else {
        state.sequence = Number(BigInt('0x' + data.slice(74, 138)));
        if (data.startsWith(EVENTS_STEP_SELECTOR)) logs = [{ address: '0x1234',
          topics: [FRAME_TOPIC, '0x' + word(state.sequence), '0x' + word(state.sequence)],
          data: '0x' + word(2) + word(1) + word(96) + word(2) + '0102'.padEnd(64, '0'),
          transactionHash: hash, logIndex: '0x0', blockNumber: '0x1' }];
      }
    }
    return { status: state.status, logs, transactionHash: hash };
  };
  const client = new InputTransactions(rpc, { rawKeyboard: true, productionUI: true, gameplay: true,
    address: '0x1234', driver: '0xabcd', gasLimit: 10000000000 }, inbox, { waitReceipt });
  return { state, client };
}

test('raw startup is explicit; rendered/no-render packets share sequence and transaction lock', async () => {
  const { state, client } = fixture({ started: false }); await client.load();
  await assert.rejects(client.nextEvents(new Uint8Array()), /Start raw/);
  await client.startGame(); assert.equal(state.sent[0], INITIALIZE_GAME_INPUT_SELECTOR + word(0));
  await assert.rejects(client.nextFrame(0), /raw keyboard/);
  state.wait = deferred(); const first = client.nextEvents(Uint8Array.of(0, 105));
  await assert.rejects(client.nextEvents(Uint8Array.of(1, 105)), /pending/);
  state.wait.resolve(); await first; state.wait = null;
  assert.equal(client.sequence, 1);
  const mined = await client.nextEvents(Uint8Array.of(1, 105), { draw: false });
  assert.equal(client.sequence, 2); assert.equal(mined.logs.length, 0);
});

test('stop during a pending raw tic settles it then flushes releases in one no-render tic', async () => {
  const { state, client } = fixture(); await client.load();
  const keyboard = new RawKeyboardInput(), tasks = [], errors = [];
  const loop = new GameplayLoop(client, keyboard, { schedule: fn => { tasks.push(fn); return tasks.length; },
    cancel: () => {}, onError: e => errors.push(e.message) });
  await loop.start(); keyboard.update('ArrowRight', true); state.wait = deferred();
  const pending = tasks.shift()(); await flush(); loop.stop();
  assert.equal(state.sent.length, 1); state.wait.resolve(); await pending;
  assert.equal(state.sent.length, 2); assert(state.sent[1].startsWith(EVENTS_NO_RENDER_SELECTOR));
  assert.equal(state.sent[1].slice(202, 206), '01ae');
  assert.equal(keyboard.events.length, 0); assert.equal(client.sequence, 2); assert.deepEqual(errors, []);
});

test('raw failures retain packet and stop without automatic mutation retry', async () => {
  for (const unknown of [false, true]) {
    const { state, client } = fixture(); await client.load();
    const keyboard = new RawKeyboardInput(), tasks = [], errors = [];
    const loop = new GameplayLoop(client, keyboard, { schedule: fn => { tasks.push(fn); return 1; }, cancel: () => {}, onError: e => errors.push(e.message) });
    await loop.start(); keyboard.update('KeyD', true);
    state.unknown = unknown; state.status = '0x0'; await tasks.shift()(); await flush();
    assert.equal(state.sent.length, 1); assert.equal(client.sequence, 0); assert(!loop.running);
    assert.deepEqual([...keyboard.packet()], [0, 100, 1, 100]); assert.equal(errors.length, 1);
    if (unknown) assert(client.uncertain);
  }
});

test('raw blur creates releases, preserves pending events and blocks inactive input', () => {
  const target = new EventTarget(), visibility = new EventTarget(); visibility.hidden = false;
  const k = new RawKeyboardInput(); let enabled = true;
  const binding = bindKeyboard(target, k, visibility, { enabled: () => enabled, onReset: () => enabled = false });
  const send = (type, code) => { const e = new Event(type, { cancelable: true }); e.code = code; target.dispatchEvent(e); return e; };
  assert(send('keydown', 'Tab').defaultPrevented);
  target.dispatchEvent(new Event('blur'));
  assert.deepEqual([...k.packet()], [0, 9, 1, 9]);
  send('keydown', 'KeyD'); send('keyup', 'Tab'); assert.equal(k.events.length, 4);
  binding.dispose();
});
