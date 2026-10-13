// SPDX-License-Identifier: GPL-2.0-only
// Presentation transport only. All melt state and pixels remain in contract storage.
export const WIPE_STATUS_SELECTOR = '0x295e88a0';
export const ENABLE_WIPE_SELECTOR = '0xb3649600';
export const STEP_WIPE_SELECTOR = '0x0b3aaa6e';
export const CHEAT_STATUS_SELECTOR = '0x5e2ffcdd';
export const wipeWord = n => BigInt(n).toString(16).padStart(64, '0');

// Reload has no physical held keys. Queue their original keyup events for the
// first ordinary input packet after the wipe; presentation steps never tick them.
export async function heldKeyReleases(rpc, address) {
  const data = await rpc('eth_call', [{ to: address, data: CHEAT_STATUS_SELECTOR }, 'latest']);
  if (!/^0x([\da-f]{64}){12}$/i.test(data)) throw Error('Malformed held-key status');
  const held = BigInt('0x' + data.slice(-64)), events = [];
  for (let key = 0; key < 256; ++key) if ((held >> BigInt(key)) & 1n) events.push(1, key);
  return events;
}

export function suspendWipeKeys(keyboard) {
  keyboard.clear();
  if (!keyboard.raw) return;
  const releases = [];
  for (let i = 0; i < keyboard.events.length; i += 2)
    if (keyboard.events[i] === 1) releases.push(1, keyboard.events[i + 1]);
  keyboard.events = releases;
}

export async function readWipe(rpc, address) {
  let data;
  try { data = await rpc('eth_call', [{ to: address, data: WIPE_STATUS_SELECTOR }, 'latest']); }
  catch (error) {
    // An absent selector may revert on old deployments. Network failures and
    // other RPC errors must not silently disable the feature.
    if (error.rpcError && /execution reverted/i.test(error.rpcError.message)
        && (!error.rpcError.data || error.rpcError.data === '0x')) return null;
    throw error;
  }
  if (data === '0x') return null;
  if (!/^0x([\da-f]{64}){6}$/i.test(data)) throw Error('Malformed wipe status');
  const values = data.slice(2).match(/.{64}/g).map(n => BigInt('0x' + n));
  if (values[0] !== 1n || values[1] > 1n || values[2] > 1n || values[3] > 0xffffffffn)
    throw Error('Unsupported wipe protocol');
  return { version: 1, enabled: values[1] === 1n, active: values[2] === 1n, progress: Number(values[3]),
    from: Number(BigInt.asIntN(256, values[4])), to: Number(BigInt.asIntN(256, values[5])) };
}

// Kept before submission, including an unknown-hash send. Reload only clears a
// journal after finding a mined transaction with the exact sender/nonce.
export class PendingPresentationSend {
  constructor(rpc, config, storage = globalThis.localStorage, locks = globalThis.navigator?.locks) {
    this.rpc = rpc; this.config = config; this.storage = storage; this.locks = locks;
    this.key = `doom-evm-presentation|${config.rpcUrl}|${config.address.toLowerCase()}|${config.driver.toLowerCase()}`;
  }
  get pending() { return JSON.parse(this.storage?.getItem(this.key) ?? 'null'); }
  async exclusive(action) {
    if (!this.storage) throw Error('Durable browser storage is required for wipe transactions');
    if (!this.locks) throw Error('Browser transaction locks are required for wipe transactions');
    return this.locks.request(this.key, { ifAvailable: true }, lock => {
      if (!lock) throw Error('Another tab owns this presentation transaction');
      return action();
    });
  }
  async recover() {
    return this.exclusive(async () => {
      const pending = this.pending;
      if (!pending) return;
      let hash = pending.hash;
      if (!hash) {
        const latest = BigInt(await this.rpc('eth_blockNumber'));
        const first = BigInt(pending.block);
        if (latest - first > 4096n) throw Error('Pending transaction history exceeds recovery range');
        for (let n = first; n <= latest && !hash; ++n) {
          const block = await this.rpc('eth_getBlockByNumber', ['0x' + n.toString(16), true]);
          hash = block?.transactions.find(tx => tx.from.toLowerCase() === this.config.driver.toLowerCase()
            && BigInt(tx.nonce) === BigInt(pending.nonce))?.hash;
        }
      }
      const mined = hash && await this.rpc('eth_getTransactionReceipt', [hash]);
      if (!mined || !['0x0', '0x1'].includes(mined.status))
        throw Error('Presentation transaction outcome unknown; wait for mining and reload. No retry was sent.');
      const canonical = await this.rpc('eth_getBlockByNumber', [mined.blockNumber, false]);
      const transaction = await this.rpc('eth_getTransactionByHash', [hash]);
      if (!canonical || canonical.hash !== mined.blockHash || !transaction
          || transaction.from.toLowerCase() !== this.config.driver.toLowerCase()
          || BigInt(transaction.nonce) !== BigInt(pending.nonce))
        throw Error('Presentation receipt is not canonical for the recorded sender/nonce; no retry was sent');
      this.storage.removeItem(this.key);
    });
  }
  async send(data, send) {
    return this.exclusive(async () => {
      if (this.pending) throw Error('Presentation transaction outcome unknown; reload to reconcile');
      const nonce = await this.rpc('eth_getTransactionCount', [this.config.driver, 'pending']);
      const block = await this.rpc('eth_blockNumber');
      const pending = { nonce, block, hash: null, data };
      this.storage.setItem(this.key, JSON.stringify(pending));
      return send({ nonce }, hash => {
        pending.hash = hash; this.storage.setItem(this.key, JSON.stringify(pending));
      }, () => this.storage.removeItem(this.key));
    });
  }
}
