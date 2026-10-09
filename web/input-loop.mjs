// SPDX-License-Identifier: GPL-2.0-only
// One accepted packet advances one EVM tic. No movement/world/pixel computation here.
import { FRAME_TOPIC, decodeFrame, receipt } from './protocol.mjs';
import { inputStepData } from './input.mjs';

// Generated with pinned cast sig. Existing Frame/step ABI remains unchanged.
export const GAME_STARTED_SELECTOR = '0x5e123ce4';
export const INITIALIZE_GAME_SELECTOR = '0xa0a1f49b';
export const LAST_INPUT_SELECTOR = '0x3464285a';
export const GAME_RESOURCES_PREPARED_SELECTOR = '0x8874965d';
export const PREPARE_GAME_RESOURCES_SELECTOR = '0x4cc5dc3f';

function uintWord(data, maximum, label) {
  if (!/^0x[\da-f]{64}$/i.test(data)) throw Error(`Malformed ${label}`);
  const value = BigInt(data);
  if (value > maximum) throw Error(`Invalid ${label}`);
  return Number(value);
}

export class InputTransactions {
  constructor(rpc, config, inbox, { waitReceipt = receipt, onState = () => {}, onFrame = () => {} } = {}) {
    this.rpc = rpc; this.config = config; this.inbox = inbox;
    this.waitReceipt = waitReceipt; this.onState = onState; this.onFrame = onFrame;
    this.sequence = 0; this.started = false; this.prepared = false; this.busy = false;
    this.uncertain = false; this.invalidated = false; this.loaded = false; this.pending = false;
  }
  get canSend() { return this.loaded && !this.busy && !this.uncertain && !this.invalidated; }
  _state() { this.onState(this); }
  _available() {
    if (this.invalidated) throw Error('Session invalidated; reload after checking the local chain');
    if (this.pending) throw Error('Previous transaction still pending');
    if (this.uncertain) throw Error('Transaction outcome unknown; reload to reconcile the chain');
    if (this.busy) throw Error('Previous transaction still pending');
    if (!this.loaded) throw Error('Input state not loaded');
  }
  async _counter() {
    return uintWord(await this.rpc('eth_call', [{ to: this.config.address, data: LAST_INPUT_SELECTOR }, 'latest']), 0xffffffffn, 'input counter');
  }
  async _started() {
    return uintWord(await this.rpc('eth_call', [{ to: this.config.address, data: GAME_STARTED_SELECTOR }, 'latest']), 1n, 'gameStarted') === 1;
  }
  async _prepared() {
    return uintWord(await this.rpc('eth_call', [{ to: this.config.address, data: GAME_RESOURCES_PREPARED_SELECTOR }, 'latest']), 1n, 'gameResourcesPrepared') === 1;
  }
  async load() {
    if (this.busy || this.uncertain || this.invalidated) throw Error('Input channel unavailable');
    this.busy = true; this.pending = true; this._state();
    try {
      this.sequence = await this._counter();
      if (this.config.gameplay === true) this.started = await this._started();
      if (this.config.gameplay === true && this.config.nativeZone === true) this.prepared = await this._prepared();
      this.loaded = true;
    } finally { this.busy = false; this.pending = false; this._state(); }
  }
  invalidate() { this.invalidated = true; this._state(); }

  async _send(data) {
    // A transport failure may follow submission: retain the lock until a reload
    // reconciles counters. Only an actual mined receipt settles the transaction.
    this.uncertain = true;
    const hash = await this.rpc('eth_sendTransaction', [{ from: this.config.driver, to: this.config.address, data, gas: '0x3b9aca00' }]);
    const mined = await this.waitReceipt(this.rpc, hash);
    if (mined?.status !== '0x0' && mined?.status !== '0x1') throw Error('Malformed transaction receipt');
    this.uncertain = false;
    if (mined.status === '0x0') throw Error('Transaction reverted');
    return mined;
  }

  _startupFrameCheck(mined) {
    if (mined.logs.some(log => log.address?.toLowerCase() === this.config.address.toLowerCase()
      && log.topics?.[0]?.toLowerCase() === FRAME_TOPIC)) {
      this.invalidated = true; throw Error('Startup transaction unexpectedly emitted a Frame');
    }
  }
  async startGame({ shouldContinue = () => true } = {}) {
    this._available();
    if (this.config.gameplay !== true) throw Error('Gameplay unavailable for this deployment');
    this.busy = true; this.pending = true; this._state();
    try {
      // Reload/resume can follow frames from another local controller. Reads precede
      // submission and the contract remains authoritative about sequence acceptance.
      this.sequence = await this._counter();
      this.started = await this._started();
      if (!this.started) {
        if (this.config.nativeZone === true) {
          this.prepared = await this._prepared();
          if (!this.prepared) {
            if (!shouldContinue()) return;
            const mined = await this._send(PREPARE_GAME_RESOURCES_SELECTOR);
            this.uncertain = true;
            this._startupFrameCheck(mined);
            this.prepared = await this._prepared();
            const sequence = await this._counter();
            if (!this.prepared || sequence !== this.sequence) {
              this.invalidated = true; throw Error('Game resource preparation was not confirmed');
            }
            this.uncertain = false; this._state();
          }
        }
        // Stop may occur while preparation is pending. Its accepted receipt is
        // settled, but initialization is a future transaction and must wait for Start.
        if (!shouldContinue()) return;
        const mined = await this._send(INITIALIZE_GAME_SELECTOR);
        // Mined initialization is confirmed separately; it need not emit a Frame.
        this.uncertain = true;
        this._startupFrameCheck(mined);
        this.started = await this._started();
        const sequence = await this._counter();
        if (!this.started || sequence !== this.sequence) { this.invalidated = true; throw Error('Game initialization was not confirmed'); }
        this.uncertain = false;
      }
    } finally { this.busy = this.uncertain; this.pending = false; this._state(); }
  }

  async nextFrame(mask = 0, { beforeSend = () => {} } = {}) {
    this._available();
    if (!this.started && mask !== 0) throw Error('Start gameplay before sending keys');
    const sequence = this.sequence + 1;
    const data = inputStepData(mask, sequence); // Validation occurs before taking the lock.
    this.busy = true; this.pending = true; this._state();
    try {
      beforeSend(); // Run only after packet validation and exclusive channel reservation.
      const mined = await this._send(data);
      // The accepted sequence is consumed even if subsequent display verification fails.
      this.sequence = sequence;
      if (this.invalidated) throw Error('Session invalidated; reload after checking the local chain');
      try {
        const logs = mined.logs.filter(log => log.address?.toLowerCase() === this.config.address.toLowerCase()
          && log.topics?.[0]?.toLowerCase() === FRAME_TOPIC);
        if (logs.length !== 1) throw Error('Frame transaction must emit exactly one Frame');
        const frame = decodeFrame(logs[0]);
        if (frame.inputSeq !== sequence) throw Error('Frame input sequence mismatch');
        this.inbox.accept(logs[0], 'receipt');
        this.onFrame({ mask, sequence, transactionHash: mined.transactionHash, frameId: String(frame.frameId) });
      } catch (error) { this.invalidated = true; throw error; }
      return mined;
    } finally { this.busy = this.uncertain; this.pending = false; this._state(); }
  }
}

export class GameplayLoop {
  constructor(transactions, keyboard, { schedule = (fn, ms) => setTimeout(fn, ms), cancel = clearTimeout,
    now = () => performance.now(), onState = () => {}, onError = () => {}, minimumPeriod = 1000 / 35 } = {}) {
    this.transactions = transactions; this.keyboard = keyboard;
    this.schedule = schedule; this.cancel = cancel; this.now = now;
    this.onState = onState; this.onError = onError; this.minimumPeriod = minimumPeriod;
    this.running = false; this.starting = false; this.epoch = 0; this.timer = null;
  }
  _state() { this.onState(this); }
  stop() {
    this.running = false; ++this.epoch; this.keyboard.clear();
    if (this.timer !== null) this.cancel(this.timer);
    this.timer = null; this._state();
  }
  async start() {
    if (this.running) return false;
    if (this.starting || this.transactions.busy) throw Error('Previous transaction still pending');
    this.keyboard.clear(); this.running = true; this.starting = true;
    const epoch = ++this.epoch; this._state();
    try {
      await this.transactions.startGame({ shouldContinue: () => this.running && epoch === this.epoch });
      if (this.running && epoch === this.epoch) this._schedule(epoch, 0);
      return true;
    } catch (error) { this.stop(); throw error; }
    finally { this.starting = false; this._state(); }
  }
  _schedule(epoch, delay) {
    this.timer = this.schedule(() => { this.timer = null; return this._tick(epoch); }, delay);
  }
  async _tick(epoch) {
    if (!this.running || epoch !== this.epoch) return;
    const started = this.now();
    try {
      const held = this.keyboard.sample();
      await this.transactions.nextFrame(held);
      if (this.running && epoch === this.epoch) this._schedule(epoch, Math.max(0, this.minimumPeriod - (this.now() - started)));
    } catch (error) { this.stop(); this.onError(error); }
  }
}
