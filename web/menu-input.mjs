// SPDX-License-Identifier: GPL-2.0-only
// Transport only: menu actions and selection live exclusively in the contract.
import { InputTransactions } from './input-loop.mjs';
import { eventStepData } from './input.mjs';
import { readWipe, PendingPresentationSend, ENABLE_WIPE_SELECTOR, STEP_WIPE_SELECTOR, wipeWord } from './wipe-input.mjs';
export const INITIALIZE_MENU_SELECTOR = '0x4d55b9e0';
export const MENU_MODE_SELECTOR = '0x10acb777';
export const MENU_STATUS_SELECTOR = '0x7df5b919';
export const usesEVMMenu = config => config.gameplay === true && config.rendererKind === 'doom-world-view' && config.menuMode !== false;

export class MenuTransactions extends InputTransactions {
  constructor(...args) { super(...args); this.menuReady = false; this.wipe = null; }
  async _menuReady() {
    const value = await this.rpc('eth_call', [{ to: this.config.address, data: MENU_MODE_SELECTOR }, 'latest']);
    if (!/^0x[\da-f]{64}$/i.test(value) || BigInt(value) > 1n) throw Error('Malformed menuMode');
    return BigInt(value) === 1n;
  }
  async load() {
    this.wipe = await readWipe(this.rpc, this.config.address);
    if (this.wipe) {
      this.presentationSend ??= new PendingPresentationSend(this.rpc, this.config);
      await this.presentationSend.recover();
    }
    await super.load(); this.menuReady = await this._menuReady();
  }
  async _send(data) {
    if (!this.presentationSend) return super._send(data);
    return this.presentationSend.send(data, (tx, hash, settled) => super._send(data, tx, hash, settled));
  }
  async refreshWipe() {
    if (this.wipe) this.wipe = await readWipe(this.rpc, this.config.address);
    this._state();
  }
  async nextWipe() {
    this._available();
    if (!this.wipe?.active) throw Error('No active EVM wipe');
    const sequence = this.sequence + 1;
    const result = await this._submitStep(STEP_WIPE_SELECTOR + wipeWord(sequence), sequence, { presentation: 'wipe' }, true, () => {});
    return result;
  }
  async _afterStep() { this.started = await this._started(); await this.refreshWipe(); }
  async episodeControl(...args) {
    if (this.wipe?.active) throw Error('EVM wipe in progress; gameplay input is suspended');
    return super.episodeControl(...args);
  }
  async startGame({ shouldContinue = () => true } = {}) {
    this._available();
    if (this.config.rawKeyboard !== true || this.config.productionUI !== true) throw Error('EVM menu requires raw keyboard and production UI');
    this.busy = true; this.pending = true; this._state();
    try {
      this.sequence = await this._counter(); this.started = await this._started(); this.menuReady = await this._menuReady();
      this._startupValid();
      if (!this.menuReady) {
        if (this.started) throw Error('This deployment already uses a legacy startup profile');
        if (!shouldContinue()) return;
        const mined = await this._send(INITIALIZE_MENU_SELECTOR + (this.config.uiFullscreen === true ? '1' : '0').padStart(64,'0'));
        this.uncertain = true; this._startupFrameCheck(mined);
        this.menuReady = await this._menuReady();
        if (!this.menuReady || await this._counter() !== this.sequence || await this._started()) {
          this.invalidated = true; throw Error('Menu initialization was not confirmed');
        }
        this._startupValid(); this.uncertain = false;
      }
      if (this.wipe && !this.wipe.enabled) {
        const mined = await this._send(ENABLE_WIPE_SELECTOR);
        this._startupFrameCheck(mined); await this.refreshWipe();
        if (!this.wipe?.enabled) throw Error('EVM wipe opt-in was not confirmed');
      }
    } finally { this.busy = this.uncertain; this.pending = false; this._state(); }
  }
  async nextEvents(events, { beforeSend = () => {}, draw = true } = {}) {
    this._available();
    if (this.wipe?.active) throw Error('EVM wipe in progress; gameplay input is suspended');
    if (!this.menuReady) throw Error('Initialize the EVM menu before sending events');
    const sequence = this.sequence + 1;
    const result = await this._submitStep(eventStepData(events,sequence,draw), sequence, { events:[...events] }, draw, beforeSend);
    this._state(); return result;
  }
  async menuStatus() {
    const data = await this.rpc('eth_call', [{ to:this.config.address,data:MENU_STATUS_SELECTOR }, 'latest']);
    if (!/^0x([\da-f]{64}){9}$/i.test(data)) throw Error('Malformed menu status');
    const values = data.slice(2).match(/.{64}/g).map(n=>Number(BigInt.asIntN(256,BigInt('0x'+n))));
    if (![0,1].includes(values[0]) || ![0,1].includes(values[1]) || ![0,1].includes(values[8])) throw Error('Malformed menu status flags');
    return Object.fromEntries(['enabled','active','screen','item','skull','animation','map','skill','confirmation'].map((key,i)=>[key,values[i]]));
  }
}
