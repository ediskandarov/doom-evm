// SPDX-License-Identifier: GPL-2.0-only
// Browser transport policy only; no engine behavior or fixed gas ceiling here.
export function gasHex(value) {
  if (typeof value === 'number' && !Number.isSafeInteger(value)) throw Error('Invalid gas budget');
  if (!['number', 'string', 'bigint'].includes(typeof value) || !/^(?:[1-9]\d*|0x[\da-f]+)$/i.test(String(value))) throw Error('Invalid gas budget');
  const budget = BigInt(value);
  if (budget <= 0n || budget > 0xffffffffffffffffn) throw Error('Invalid gas budget');
  return '0x' + budget.toString(16);
}

export async function resolveGasBudget(rpc, config) {
  if (config.gasLimit !== undefined) return { gas: gasHex(config.gasLimit), source: 'config.gasLimit' };
  const block = await rpc('eth_getBlockByNumber', ['latest', false]);
  if (!block || block.gasLimit === undefined) throw Error('Node block gas budget unavailable');
  return { gas: gasHex(block.gasLimit), source: 'latest block gasLimit' };
}
