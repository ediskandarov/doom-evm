#!/usr/bin/env node
// SPDX-License-Identifier: GPL-2.0-only
// Separate source-mapped marker clone; never edits production or invokes Forge.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import assert from 'node:assert/strict';
import { instrumentGasMarkers } from '../phase2_data/instrument.mjs';
import { FRAME_TOPIC, decodeFrame } from '../../../web/protocol.mjs';
import { loadGasBudget } from '../../execution-budget.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const word = value => BigInt.asUintN(256, BigInt(value)).toString(16).padStart(64, '0');
const tail = bytes => word(bytes.length) + bytes.toString('hex').padEnd(Math.ceil(bytes.length / 32) * 64, '0');
export const BOUNDARIES = { prepareGameResources: 1, initializeGame: 2, step: 3, stepAndRender: 4, renderFrame: 5 };
const MEMORY_SIGNATURE = 'MemoryBoundary(uint32,uint256)';
function codeOnly(source) {
  return source.replace(/\/\*[\s\S]*?\*\/|\/\/[^\n]*|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/g,
    token => token.replace(/[^\n]/g, ' '));
}

export function cloneMemorySource(original, productionPath = resolve(root, 'src/evm/Doom.sol'), projectRoot = root) {
  assert(!original.includes('function memorySize(') && !original.includes('MemoryBoundary('), 'measurement symbol collision');
  let source = original.replace(/from\s+"(\.[^"]+)"/g, (_match, path) => `from "${relative(projectRoot, resolve(dirname(productionPath), path))}"`);
  const masked = codeOnly(source), declarations = [...masked.matchAll(/\bcontract\s+Doom\s+is\b/g)];
  assert.equal(declarations.length, 1, 'expected one original Doom declaration');
  source = source.slice(0, declarations[0].index) + source.slice(declarations[0].index).replace(/contract\s+Doom\s+is/, 'contract DoomMemoryProbe is');
  const stripped = codeOnly(source), insertions = [], boundaries = [];
  for (const [name, stage] of Object.entries(BOUNDARIES)) {
    const matches = [...stripped.matchAll(new RegExp('\\bfunction\\s+' + name + '\\s*\\(', 'g'))];
    if (matches.length === 0 && name === 'prepareGameResources') continue; // Accepted legacy source profile.
    assert.equal(matches.length, 1, 'missing/ambiguous measured method ' + name);
    const begin = matches[0].index, open = stripped.indexOf('{', begin); assert(open >= 0);
    assert(/\bexternal\b/.test(stripped.slice(begin, open)), 'external boundary required ' + name);
    let end = open + 1, depth = 1;
    while (depth) { assert(end < stripped.length, 'unterminated method'); if (stripped[end] === '{') depth++; if (stripped[end] === '}') depth--; end++; }
    assert(!/\breturn\b/.test(stripped.slice(open + 1, end - 1)), 'early return bypasses boundary observation ' + name);
    insertions.push({ at: end - 1, text: `\n        _memoryBoundary(${stage});\n    ` });
    boundaries.push({ name, stage, sourceStart: begin, sourceEnd: end });
  }
  const end = stripped.lastIndexOf('}'); assert(end >= 0);
  insertions.push({ at: end, text: `\n    event MemoryBoundary(uint32 indexed stage, uint256 highWaterBytes);\n\n    function memorySize() private view returns (uint256) { return gasleft(); }\n\n    function _memoryBoundary(uint32 stage) private {\n        // Source-map this GAS only to MSIZE after compiling the separate clone.\n        // Observer log encoding follows the measured engine boundary.\n        emit MemoryBoundary(stage, memorySize());\n    }\n` });
  for (const edit of insertions.sort((a, b) => b.at - a.at)) source = source.slice(0, edit.at) + edit.text + source.slice(edit.at);
  return { source, record: { productionPath: relative(root, productionPath), productionSourceSha256: sha(original), cloneSourceSha256: sha(source), boundaries,
    changes: ['Project-root import paths, contract name only, end-of-external-call marker, private observer helper/event. No original statement replaced or reordered.'],
    scope: 'Engine-boundary clone high-water excludes following observer log encoding and separate external call/precompile frames; not an exact untouched-production peak.' } };
}

export function constructorData(addresses, directory) {
  const packed = word(addresses.length) + addresses.map(address => address.slice(2).padStart(64, '0')).join('');
  return word(64) + word(64 + packed.length / 2) + packed + tail(directory);
}

function runtimeWithDriver(bytecode, artifact, driver) {
  const runtime = Buffer.from(bytecode);
  const refs = Object.values(artifact.deployedBytecode.immutableReferences ?? {});
  assert.equal(refs.length, 1, 'only driver immutable expected');
  for (const ref of refs[0]) { assert.equal(ref.length, 32); Buffer.from(word(driver), 'hex').copy(runtime, ref.start); }
  return '0x' + runtime.toString('hex');
}

async function main() {
  process.chdir(root);
  const args = process.argv.slice(2), option = (name, fallback) => args.includes(name) ? args[args.indexOf(name) + 1] : fallback;
  const output = option('--output-prefix', 'artifacts/local/gameplay-production-zone-atomic-memory');
  const sourcePath = option('--source', 'src/evm/Doom.sol');
  const budget = loadGasBudget(), stagedInitialization = args.includes('--staged-initialization');
  const clonePath = option('--clone-source', 'artifacts/local/production-memory/DoomMemoryProbe.sol');
  await mkdir(dirname(output), { recursive: true });
  if (args.includes('--generate')) {
    const original = await readFile(sourcePath, 'utf8'), generated = cloneMemorySource(original, resolve(root, sourcePath));
    await mkdir(dirname(clonePath), { recursive: true }); await writeFile(clonePath, generated.source);
    await writeFile(output + '.source.json', JSON.stringify(generated.record, null, 2) + '\n');
    console.log(JSON.stringify({ generated: clonePath, sourceHashes: generated.record, next: `.toolchain/bin/forge build ${clonePath} (root compiler slot only)` }));
    return;
  }
  const resourcesPath = option('--resources-report', null); assert(resourcesPath, '--resources-report is required');
  const previous = JSON.parse(await readFile(resourcesPath, 'utf8'));
  const url = option('--rpc', previous.node.rpcUrl); assert(['127.0.0.1', 'localhost', '[::1]'].includes(new URL(url).hostname));
  const nativePath = option('--native', 'artifacts/local/gameplay-browser-native');
  const limit = Number(option('--limit', 'Infinity')); assert(limit === Infinity || (Number.isInteger(limit) && limit >= 0));
  const native = JSON.parse(await readFile(nativePath + '/manifest.json', 'utf8'));
  const packets = JSON.parse(await readFile(nativePath + '/packets.json', 'utf8'));
  const players = JSON.parse(await readFile(nativePath + '/players.json', 'utf8'));
  const production = JSON.parse(await readFile('out/Doom.sol/Doom.json', 'utf8'));
  const probe = JSON.parse(await readFile(option('--artifact', 'out/DoomMemoryProbe.sol/DoomMemoryProbe.json'), 'utf8'));
  const generated = cloneMemorySource(await readFile(sourcePath, 'utf8'), resolve(root, sourcePath));
  assert.equal(await readFile(clonePath, 'utf8'), generated.source, 'clone no longer corresponds to frozen production');
  const patched = instrumentGasMarkers(probe, generated.source);
  const report = { kind: 'production-engine-boundary-clone-msize', pass: false, source: generated.record,
    instrumentation: patched.report, resourcesReport: resourcesPath, resourcesReportSha256: sha(await readFile(resourcesPath)),
    resourceIdentity: previous.resourceIdentity, rpcUrl: url, executionBudget: budget, stagedInitialization, boundaries: [], deployments: [], comparisons: [], sourceHashes: {},
    notes: ['Separate ordinary CREATE only, same authenticated resource chunks rechecked byte-for-byte. No etch/setCode or supplied gameplay/pixels.',
      'Final MSIZE is monotonic high-water of the current EVM call frame through the marker. It excludes later observer log encoding and memory of separate external/precompile frames.',
      'Marker clone source/code generation may alter memory reuse relative to untouched production. These are measured clone engine-boundary peaks, not exact untouched-production peaks.',
      'Patched and unpatched clone differ only in source-mapped GAS->MSIZE, identical2gas/+1stack and bytecode layout; gas/state/frame equality is checked. Ordinary production is compared separately.'] };
  let rpcId = 0;
  async function rpc(method, params = []) {
    const response = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ jsonrpc: '2.0', id: ++rpcId, method, params }), signal: AbortSignal.timeout(300000) });
    assert(response.ok); const value = await response.json(); assert(!value.error, JSON.stringify(value.error)); return value.result;
  }
  const gas = budget.gasHex;
  async function tx(driver, data, address) {
    const hash = await rpc('eth_sendTransaction', [{ from: driver, data, gas, ...(address ? { to: address } : {}) }]);
    const end = Date.now() + 180000; let mined;
    while (!mined && Date.now() < end) { mined = await rpc('eth_getTransactionReceipt', [hash]); if (!mined) await new Promise(done => setTimeout(done, 25)); }
    assert(mined); assert.equal(mined.status, '0x1', hash); return mined;
  }
  const method = name => { assert(production.methodIdentifiers[name]); assert.equal(production.methodIdentifiers[name], probe.methodIdentifiers[name]); return '0x' + production.methodIdentifiers[name]; };
  const memoryTopic = execFileSync(resolve('.toolchain/bin/cast'), ['sig-event', MEMORY_SIGNATURE], { encoding: 'utf8' }).trim();
  async function compactState(address, driver) {
    const base = { from: driver, to: address, gas };
    const reads = [];
    for (const name of ['gameStarted()', 'inputSeq()', 'frameId()', ...(stagedInitialization ? ['gameResourcesPrepared()'] : [])]) {
      reads.push([name, await rpc('eth_call', [{ ...base, data: method(name) }, 'latest'])]);
    }
    if (BigInt(reads.find(row => row[0] === 'gameStarted()')[1]) === 1n) {
      for (const name of ['gameStatus()', 'playerView()']) reads.push([name, await rpc('eth_call', [{ ...base, data: method(name) }, 'latest'])]);
    }
    const proof = await rpc('eth_getProof', [address, [], 'latest']); return { reads, storageRoot: proof.storageHash };
  }
  function nativeFields(state, row) {
    const groups = [
      ['gameStatus()', ['gametic', 'leveltime', 'health', 'armor', 'weapon'], ['leveltime', 'health', 'armor', 'weapon']],
      ['playerView()', ['x', 'y', 'z', 'angle', 'momx', 'momy', 'momz', 'viewz', 'prndindex'], ['x', 'y', 'z', 'momx', 'momy', 'momz', 'viewz']]
    ];
    const expected = { gametic: row.gametic, leveltime: row.leveltime, health: row.playerHealth, armor: row.armorpoints, weapon: row.readyweapon,
      ...Object.fromEntries(groups[1][1].map(name => [name, name === 'angle' ? row.angle >>> 0 : row[name]])) };
    for (const [methodName, names, signed] of groups) {
      const hex = state.reads.find(pair => pair[0] === methodName)[1]; assert.equal(hex.length, 2 + 64 * names.length);
      names.forEach((name, i) => {
        const value = BigInt('0x' + hex.slice(2 + i * 64, 66 + i * 64));
        assert.equal(Number(signed.includes(name) ? BigInt.asIntN(256, value) : value), expected[name], 'native state field ' + name);
      });
    }
  }
  try {
    for (const artifact of [production, probe]) {
      const metadata = typeof artifact.metadata === 'string' ? JSON.parse(artifact.metadata) : artifact.metadata;
      for (const [path, id] of Object.entries(metadata.sources)) {
        const bytes = await readFile(path); report.sourceHashes[relative(root, resolve(path))] = sha(bytes);
        assert.equal(execFileSync(resolve('.toolchain/bin/cast'), ['keccak'], { input: '0x' + bytes.toString('hex'), encoding: 'utf8' }).trim(), id.keccak256, 'artifact source mismatch');
      }
    }
    for (const path of ['tools/reference/gameplay/production-memory.mjs', 'tools/reference/phase2_data/instrument.mjs', 'tools/execution-budget.mjs', 'execution-budget.json']) report.sourceHashes[path] = sha(await readFile(path));
    const bundle = JSON.parse(await readFile('artifacts/local/wad/bundle.json', 'utf8'));
    assert.deepEqual(bundle.resourceIdentity, previous.resourceIdentity); assert.deepEqual(native.resourceIdentity, bundle.resourceIdentity);
    for (const [name, hash] of Object.entries(native.files)) assert.equal(sha(await readFile(nativePath + '/' + name)), hash);
    const blob = await readFile('artifacts/local/wad/resources.bin'); assert.equal(sha(blob), bundle.blobSha256);
    const addresses = previous.deployment.chunks; assert.equal(addresses.length, 1755); assert.equal(new Set(addresses).size, 1755);
    for (let i = 0; i < addresses.length; i++) assert.equal(await rpc('eth_getCode', [addresses[i], 'latest']), '0x00' + blob.subarray(i * 16384, (i + 1) * 16384).toString('hex'));
    const directory = await readFile('test/fixtures/phase2_data/directory.bin'), encoded = constructorData(addresses, directory);
    const [driver] = await rpc('eth_accounts'); report.client = await rpc('web3_clientVersion');
    await rpc('anvil_setBlockGasLimit', [gas]); report.configuredNodeBudget = { method: 'anvil_setBlockGasLimit', gasHex: gas };
    const creations = [production.bytecode.object, probe.bytecode.object, '0x' + patched.creation.toString('hex')];
    const expectedRuntimes = [Buffer.from(production.deployedBytecode.object.slice(2), 'hex'), Buffer.from(probe.deployedBytecode.object.slice(2), 'hex'), patched.runtime];
    for (let i = 0; i < 3; i++) {
      const receipt = await tx(driver, creations[i] + encoded), address = receipt.contractAddress;
      assert.equal(await rpc('eth_getCode', [address, 'latest']), runtimeWithDriver(expectedRuntimes[i], i === 0 ? production : probe, driver));
      report.deployments.push({ kind: ['ordinary', 'marker-gas', 'marker-msize'][i], address, gas: Number(BigInt(receipt.gasUsed)), transactionHash: receipt.transactionHash });
    }
    const scenarios = [{ name: 'renderFrame()', stage: 5 }, ...(stagedInitialization ? [{ name: 'prepareGameResources()', stage: 1 }] : []),
      { name: 'initializeGame()', stage: 2 }, ...packets.slice(0, Math.min(limit, packets.length)).map(row => ({ name: row.render ? 'stepAndRender(uint32,uint32)' : 'step(uint32,uint32)', stage: row.render ? 4 : 3, ...row }))];
    let sequence = 1, tic = 0;
    for (const scenario of scenarios) {
      const input = scenario.tic ? method(scenario.name) + word(scenario.mask) + word(++sequence) : method(scenario.name);
      const receipts = [];
      for (const deployment of report.deployments) receipts.push(await tx(driver, input, deployment.address));
      assert.equal(receipts[1].gasUsed, receipts[2].gasUsed, 'GAS->MSIZE clone gas mismatch');
      const states = [];
      for (const deployment of report.deployments) states.push(await compactState(deployment.address, driver));
      assert.deepEqual(states[1], states[0], 'marker clone differs from ordinary production'); assert.deepEqual(states[2], states[0], 'MSIZE clone differs from ordinary production');
      const frames = receipts.map(receipt => receipt.logs.filter(log => log.topics[0] === FRAME_TOPIC).map(decodeFrame));
      assert.equal(frames[0].length, [4, 5].includes(scenario.stage) ? 1 : 0, 'unexpected frame count');
      assert.equal(frames[1].length, frames[0].length); assert.equal(frames[2].length, frames[0].length);
      for (let i = 0; i < frames[0].length; i++) {
        assert.deepEqual(frames[1][i].pixels, frames[0][i].pixels); assert.deepEqual(frames[2][i].pixels, frames[0][i].pixels);
        assert.equal(frames[1][i].frameId, frames[0][i].frameId); assert.equal(frames[2][i].inputSeq, frames[0][i].inputSeq);
        if (scenario.tic) assert.deepEqual(Buffer.from(frames[0][i].pixels), await readFile(`${nativePath}/frame-${String(scenario.tic).padStart(6, '0')}.bin`));
      }
      const observed = receipts[2].logs.filter(log => log.topics[0] === memoryTopic); assert.equal(observed.length, 1);
      assert.equal(Number(BigInt(observed[0].topics[1])), scenario.stage); assert.match(observed[0].data, /^0x[\da-f]{64}$/i);
      const bytes = Number(BigInt(observed[0].data)); assert(Number.isSafeInteger(bytes) && bytes >= 128 && bytes % 32 === 0);
      if (scenario.tic) tic = scenario.tic;
      const started = BigInt(states[0].reads.find(row => row[0] === 'gameStarted()')[1]) === 1n;
      if (started) nativeFields(states[0], players[tic]);
      report.boundaries.push({ method: scenario.name, stage: scenario.stage, tic, highWaterBytes: bytes, ordinaryGas: Number(BigInt(receipts[0].gasUsed)), cloneGas: Number(BigInt(receipts[2].gasUsed)), transactionHash: receipts[2].transactionHash });
      report.comparisons.push({ method: scenario.name, tic, allStorageRootsEqual: true, allExportedStateEqual: true, frameCount: frames[0].length, cloneGasEqual: true, nativeStatusCameraExact: started });
      console.log(`PASS memory boundary ${scenario.name} tic${tic}: ${bytes} bytes; ordinary/clone state+Frames exact`);
    }
    report.executedTics = tic; report.nativeStreamTics = packets.length; report.completeNativeStream = tic === packets.length;
    report.pass = true;
  } catch (error) { report.error = String(error); throw error; }
  finally { await writeFile(output + '.json', JSON.stringify(report, null, 2) + '\n'); }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
