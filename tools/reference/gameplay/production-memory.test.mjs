// SPDX-License-Identifier: GPL-2.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import { cloneMemorySource, constructorData, BOUNDARIES } from './production-memory.mjs';
const methods = prepare => (prepare ? ['prepareGameResources'] : []).concat(['initializeGame', 'step', 'stepAndRender', 'renderFrame']);
const source = prepare => `// contract Doom is Fake { function step() external {} }
pragma solidity 0.8.37;
import {Base} from "./WadResources.sol";
contract Doom is Base {
${methods(prepare).map(name => `function ${name}() external { string memory ignored = "braces } { return;"; if (true) { originalWork(); } }`).join('\n')}
function originalWork() private {}
}`;

test('source clone inserts external markers without changing original statements; comments/strings do not corrupt boundaries', () => {
  const original = source(true), result = cloneMemorySource(original, '/repo/src/evm/Doom.sol', '/repo');
  assert(result.source.includes('contract DoomMemoryProbe is Base'));
  assert(result.source.includes('from "src/evm/WadResources.sol"'));
  assert.equal(result.record.boundaries.length, 5);
  for (const [name, stage] of Object.entries(BOUNDARIES)) {
    const body = result.source.slice(result.source.indexOf(`function ${name}()`));
    assert(body.indexOf('originalWork();') < body.indexOf(`_memoryBoundary(${stage});`));
    assert.equal(result.source.split(`_memoryBoundary(${stage});`).length - 1, 1);
  }
  assert.equal(result.source.split('originalWork();').length - 1, 5);
  assert.equal(result.source.split('return gasleft();').length - 1, 1);
  assert(result.record.scope.includes('not an exact untouched-production peak'));
});

test('legacy clone has no preparation marker and unchanged four original boundaries', () => {
  const result = cloneMemorySource(source(false), '/repo/src/evm/Doom.sol', '/repo');
  assert.equal(result.record.boundaries.length, 4); assert(!result.source.includes('_memoryBoundary(1);'));
});

test('clone rejects early return, ambiguous/missing external entry points and observer-name collisions', () => {
  assert.throws(() => cloneMemorySource(source(true).replace('originalWork();', 'return;')), /early return/);
  assert.throws(() => cloneMemorySource(source(true).replaceAll('function step()', 'function another()')), /missing/);
  assert.throws(() => cloneMemorySource(source(true).replaceAll('function step() external', 'function step() internal')), /external/);
  assert.throws(() => cloneMemorySource(source(true) + '\nfunction memorySize() {}'), /collision/);
});

test('constructor encoding keeps ordinary ordered chunk addresses and packed resource directory', () => {
  const addresses = ['0x' + '11'.repeat(20), '0x' + '22'.repeat(20)], directory = Buffer.from('000102', 'hex');
  const value = constructorData(addresses, directory);
  const one = i => BigInt('0x' + value.slice(i * 64, (i + 1) * 64));
  assert.equal(one(0), 64n); assert.equal(one(1), 160n); assert.equal(one(2), 2n);
  assert.equal(one(3), BigInt(addresses[0])); assert.equal(one(4), BigInt(addresses[1])); assert.equal(one(5), 3n);
  assert.equal(value.slice(6 * 64, 6 * 64 + 6), '000102'); assert.equal(value.length, 7 * 64);
});
