// SPDX-License-Identifier: GPL-2.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import { gasHex, resolveGasBudget } from './budget.mjs';

test('browser uses exact configured decimal/hex budgets without a fixed ceiling', async () => {
  for (const value of [98765432100, '98765432100', '0x16fee0e524', 98765432100n]) {
    assert.equal(gasHex(value), '0x16fee0e524');
    assert.deepEqual(await resolveGasBudget(() => { throw Error('unexpected RPC'); }, { gasLimit: value }), { gas: '0x16fee0e524', source: 'config.gasLimit' });
  }
});

test('old browser configs discover budget from node block metadata', async () => {
  const calls = [];
  const rpc = async (method, params) => { calls.push({ method, params }); return { gasLimit: '0x123456789a' }; };
  assert.deepEqual(await resolveGasBudget(rpc, {}), { gas: '0x123456789a', source: 'latest block gasLimit' });
  assert.deepEqual(calls, [{ method: 'eth_getBlockByNumber', params: ['latest', false] }]);
});

test('invalid configured/node budgets fail without silently substituting a fixed limit', async () => {
  for (const value of [0, -1, 1.5, Number.MAX_SAFE_INTEGER + 1, '', 'zero', '0x0', null, false, '18446744073709551616']) {
    assert.throws(() => gasHex(value), /Invalid/);
    await assert.rejects(resolveGasBudget(() => { throw Error('no fallback'); }, { gasLimit: value }), /Invalid/);
  }
  await assert.rejects(resolveGasBudget(async () => ({}), {}), /unavailable/);
});
