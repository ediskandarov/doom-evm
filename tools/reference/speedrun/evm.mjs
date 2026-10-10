// SPDX-License-Identifier: GPL-2.0-only
// Ordinary CREATE and receipt proof; exact native bytes are comparison data only.
import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {connect} from 'node:net';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {gunzipSync, gzipSync} from 'node:zlib';
import assert from 'node:assert/strict';
import {loadGasBudget} from '../../execution-budget.mjs';
import {fields, difference} from './dsg1.mjs';

const args = process.argv.slice(2);
const option = (name, fallback) => args.includes(name) ? args[args.indexOf(name) + 1] : fallback;
const base = resolve(option('--artifacts', 'artifacts/local/speedrun-e1m1'));
const port = Number(option('--port', '18620'));
const batch = Number(option('--batch', '5'));
const prefix = resolve(option('--output-prefix', base + '/evm'));
assert(Number.isInteger(port) && port > 1024 && port < 65536 && ![8545, 18880, 8088].includes(port));
assert(Number.isInteger(batch) && batch >= 1 && batch <= 25);
await mkdir(resolve(prefix, '..'), {recursive: true});
const json = async file => JSON.parse(await readFile(file, 'utf8'));
const sha = b => createHash('sha256').update(b).digest('hex');
const word = n => BigInt.asUintN(256, BigInt(n)).toString(16).padStart(64, '0');
const tail = b => word(b.length) + b.toString('hex').padEnd(Math.ceil(b.length / 32) * 64, '0');
const uint = (b, at) => Number(BigInt('0x' + b.subarray(at, at + 32).toString('hex')));
const abiBytes = (b, at) => {
  const offset = uint(b, at), size = uint(b, offset);
  assert(offset + 32 + size <= b.length);
  return b.subarray(offset + 32, offset + 32 + size);
};
const native = await json(base + '/native-result.json');
assert(native.exitReached && native.allProfilesExact, 'Verified native exit is required');
const tape = await json(base + '/tape.json');
const demo = await readFile(base + '/source-download');
assert.equal(sha(demo), native.demoSha256);
assert.equal(tape.commands.length, 370);
const commands = Buffer.concat(tape.commands.slice(0, native.executedTics).map(row => Buffer.from(row.rawHex, 'hex')));
assert(commands.equals(demo.subarray(13, 13 + native.executedTics * 4)), 'Verbatim original tape required');
const decoded = gunzipSync(await readFile(base + '/native-states.delta.bin.gz'));
const states = [], raw = []; let pos = 0, previous = Buffer.alloc(0);
while (pos < decoded.length) {
  const size = decoded.readUInt32BE(pos); pos += 4;
  assert(size % 4 === 0 && pos + size <= decoded.length);
  const state = Buffer.alloc(size);
  for (let i = 0; i < size; i++) state[i] = decoded[pos + i] ^ (previous[i] ?? 0);
  states.push(state); const length = Buffer.alloc(4); length.writeUInt32BE(size); raw.push(length, state);
  previous = state; pos += size;
}
assert.equal(sha(Buffer.concat(raw)), native.statesSha256);
assert.equal(states.length, native.executedTics + 1);
states.forEach(fields);
const bundle = await json(base + '/wad/bundle.json');
const blob = await readFile(base + '/wad/resources.bin');
const directory = await readFile('test/fixtures/phase2_data/directory.bin');
assert.equal(sha(blob), bundle.blobSha256);
assert.equal(bundle.resourceIdentity.wadSha256, native.wadSha256);
const artifact = await json('out/SpeedrunProbe.sol/SpeedrunProbe.json');
const store = await json('out/ResourceStore.sol/ResourceStore.json');
const method = name => '0x' + artifact.methodIdentifiers[name];
const budget = loadGasBudget(), gas = budget.gasHex;
assert.equal(artifact.metadata.compiler.version, '0.8.37+commit.f401782d');
assert.equal(artifact.metadata.settings.evmVersion, 'cancun');
assert.equal(artifact.metadata.settings.viaIR, true);
const sourceHashes = {};
for (const file of Object.keys(artifact.metadata.sources)) sourceHashes[file] = sha(await readFile(file));
for (const file of ['foundry.toml', 'execution-budget.json', 'tools/reference/speedrun/evm.mjs',
                    'tools/reference/speedrun/dsg1.mjs', 'tools/reference/speedrun/replay.py']) {
  sourceHashes[file] = sha(await readFile(file));
}
const report = {kind: 'real-freedoom-e1m1-shorttic-ordinary-evm', pass: false,
  startedUTC: new Date().toISOString(), sourceHashes, demoSha256: sha(demo),
  originalCommandBytesSha256: sha(commands), nativeStatesSha256: native.statesSha256,
  resourceIdentity: bundle.resourceIdentity, port, batch, executionBudget: budget,
  compiler: {version: artifact.metadata.compiler.version, settings: artifact.metadata.settings},
  abiSha256: sha(JSON.stringify(artifact.abi)), executedTics: 0, verifiedTics: 0, replayTransactions: [],
  notes: ['Test adapter, not production Doom.step performance or production API acceptance.',
    'Exact original command bytes only; no native gameplay states supplied to EVM.',
    'No rendering/UI/progression; stops at original GA_COMPLETED. Full DSG1 compared at every tic.',
    'Gas includes observation events and storage; wall time includes local RPC/mining and comparison. Deployment/startup reported separately.']};
let id = 0, child, stderr = '', replayStart;
const deploymentReceipts = [], replayReceipts = [], actual = [];
async function rpc(method, params = []) {
  const response = await fetch(`http://127.0.0.1:${port}`, {method: 'POST', headers: {'content-type': 'application/json'},
    body: JSON.stringify({jsonrpc: '2.0', id: ++id, method, params}), signal: AbortSignal.timeout(300000)});
  const data = await response.json();
  if (data.error) throw Error(method + ': ' + JSON.stringify(data.error));
  return data.result;
}
const sleep = ms => new Promise(r => setTimeout(r, ms));
async function send(from, data, to) {
  const began = performance.now();
  const tx = await rpc('eth_sendTransaction', [{from, data, gas, ...(to ? {to} : {})}]);
  const deadline = Date.now() + 300000;
  for (;;) {
    const receipt = await rpc('eth_getTransactionReceipt', [tx]);
    if (receipt) return {receipt, elapsedMs: performance.now() - began};
    if (Date.now() > deadline) throw Error('Receipt timeout: ' + tx);
    await sleep(25);
  }
}
async function compare(state, tic) {
  const diff = difference(states[tic], state);
  if (diff) {
    report.firstDifference = {tic, ...diff};
    await writeFile(prefix + '.mismatch-native.bin', states[tic]);
    await writeFile(prefix + '.mismatch-evm.bin', state);
    throw Error('DSG1 divergence: ' + JSON.stringify(report.firstDifference));
  }
}
function observation(log, address) {
  assert.equal(log.address, address);
  assert.equal(log.topics.length, 1);
  const data = Buffer.from(log.data.slice(2), 'hex');
  return {tic: uint(data, 0), state: abiBytes(data, 32)};
}
try {
  await new Promise((done, fail) => {
    const socket = connect({host: '127.0.0.1', port});
    socket.once('connect', () => {socket.destroy(); fail(Error('Refusing occupied port ' + port));});
    socket.once('error', error => error.code === 'ECONNREFUSED' ? done() : fail(error));
    socket.setTimeout(1000, () => {socket.destroy(); fail(Error('Port availability timed out'));});
  });
  report.serverArgs = ['--host', '127.0.0.1', '--port', String(port), '--hardfork', 'cancun',
    '--disable-code-size-limit', '--gas-limit', String(budget.gasLimit), '--memory-limit', '1073741824', '--silent'];
  child = spawn(resolve('.toolchain/bin/anvil'), report.serverArgs, {stdio: ['ignore', 'ignore', 'pipe']});
  report.ownedAnvilPid = child.pid;
  let startError; child.on('error', e => startError = e); child.stderr.on('data', b => stderr += b);
  const deadline = Date.now() + 15000;
  for (;;) {
    if (startError) throw startError;
    assert.equal(child.exitCode, null, stderr);
    try {report.client = await rpc('web3_clientVersion'); break;} catch (e) {if (Date.now() > deadline) throw e;}
    await sleep(50);
  }
  const [from] = await rpc('eth_accounts');
  const chunks = [], start = performance.now();
  for (let at = 0; at < blob.length; at += 16384) {
    const b = blob.subarray(at, at + 16384);
    const {receipt} = await send(from, store.bytecode.object + word(32) + tail(b));
    deploymentReceipts.push(receipt); assert.equal(receipt.status, '0x1');
    assert.equal(await rpc('eth_getCode', [receipt.contractAddress, 'latest']), '0x00' + b.toString('hex'));
    chunks.push(receipt.contractAddress);
    if (chunks.length % 300 === 0) console.log(`Resource CREATE/readback ${chunks.length}/1755`);
  }
  assert.equal(chunks.length, 1755);
  const addresses = word(chunks.length) + chunks.map(a => a.slice(2).padStart(64, '0')).join('');
  const constructor = word(64) + word(64 + addresses.length / 2) + addresses + tail(directory);
  const {receipt: deployed} = await send(from, artifact.bytecode.object + constructor);
  deploymentReceipts.push(deployed); assert.equal(deployed.status, '0x1');
  const address = deployed.contractAddress;
  // solc emits zero placeholders for immutable driver; ordinary CREATE binds
  // each listed 32-byte site to this deployment sender. Verify all other bytes.
  const expectedRuntime = Buffer.from(artifact.deployedBytecode.object.slice(2), 'hex');
  for (const sites of Object.values(artifact.deployedBytecode.immutableReferences)) {
    for (const site of sites) {
      assert.equal(site.length, 32);
      Buffer.from(from.slice(2).padStart(64, '0'), 'hex').copy(expectedRuntime, site.start);
    }
  }
  const actualRuntime = Buffer.from((await rpc('eth_getCode', [address, 'latest'])).slice(2), 'hex');
  assert(actualRuntime.equals(expectedRuntime), 'Deployed runtime differs outside expected immutable driver');
  report.deployment = {address, transaction: deployed.transactionHash, chunks: chunks.length,
    allResourceRuntimeBytesVerified: true, elapsedMs: performance.now() - start,
    totalGas: deploymentReceipts.reduce((n, r) => n + Number(BigInt(r.gasUsed)), 0),
    probeGas: Number(BigInt(deployed.gasUsed)), runtimeSha256: sha(actualRuntime),
    immutableReferences: artifact.deployedBytecode.immutableReferences, immutableDriver: from};
  const init = await send(from, method('initialize()'), address);
  replayReceipts.push(init.receipt); assert.equal(init.receipt.status, '0x1');
  assert.equal(init.receipt.logs.length, 1);
  const initial = observation(init.receipt.logs[0], address); assert.equal(initial.tic, 0);
  actual.push(initial.state); await compare(initial.state, 0);
  report.startup = {transaction: init.receipt.transactionHash, gas: Number(BigInt(init.receipt.gasUsed)),
    elapsedMs: init.elapsedMs, nativeSha256: sha(states[0]), evmSha256: sha(initial.state), exact: true};
  console.log('PASS E1M1 skill0 startup: exact full original-C DSG1');
  replayStart = performance.now();
  for (let tic = 0; tic < native.executedTics; tic += batch) {
    const count = Math.min(batch, native.executedTics - tic);
    const {receipt, elapsedMs} = await send(from, method('advance(bytes)') + word(32) + tail(commands.subarray(tic * 4, (tic + count) * 4)), address);
    replayReceipts.push(receipt);
    report.replayTransactions.push({firstTic: tic + 1, tics: count, hash: receipt.transactionHash,
      status: receipt.status, gas: Number(BigInt(receipt.gasUsed)), elapsedMs});
    assert.equal(receipt.status, '0x1', 'Advance reverted at tic ' + (tic + 1));
    assert.equal(receipt.logs.length, count);
    report.executedTics += count;
    for (const [i, log] of receipt.logs.entries()) {
      const o = observation(log, address); assert.equal(o.tic, tic + i + 1);
      actual.push(o.state); await compare(o.state, o.tic); report.verifiedTics = o.tic;
    }
    if (report.verifiedTics % 25 === 0 || report.verifiedTics === native.executedTics) {
      console.log(`PASS exact original world ${report.verifiedTics}/${native.executedTics} tics; gas ${Number(BigInt(receipt.gasUsed))}`);
    }
  }
  report.replayElapsedMs = performance.now() - replayStart;
  const final = abiBytes(Buffer.from((await rpc('eth_call', [{from, to: address, data: method('snapshot()'), gas}, 'latest'])).slice(2), 'hex'), 0);
  await compare(final, native.executedTics);
  const finalFields = fields(final);
  const get = name => finalFields.find(r => r.field === name)?.value;
  assert.equal(get('global.gameaction'), 6, 'Genuine original GA_COMPLETED required');
  assert.equal(get('global.secretexit'), 0);
  assert.equal(get('global.leveltime'), 279);
  assert.equal(get('player.cheats'), 0);
  report.exit = {reached: true, gameaction: get('global.gameaction'), secretexit: get('global.secretexit'),
    leveltime: get('global.leveltime'), inGameSeconds: get('global.leveltime') / 35,
    nativeExitLine: native.profiles[0].exitEvents[0][4], finalStoredDSG1Exact: true, finalStateSha256: sha(final)};
  report.pass = true;
} catch (error) {
  report.error = String(error); console.error(report.error); process.exitCode = 1;
} finally {
  report.endedUTC = new Date().toISOString();
  if (replayStart !== undefined && report.replayElapsedMs === undefined) report.partialReplayElapsedMs = performance.now() - replayStart;
  report.replayTransactionCount = report.replayTransactions.length;
  report.totalReplayGas = report.replayTransactions.reduce((n, r) => n + r.gas, 0);
  report.gasPerExecutedTic = report.executedTics ? report.totalReplayGas / report.executedTics : null;
  report.replayTransactionElapsedMs = report.replayTransactions.reduce((n, r) => n + r.elapsedMs, 0);
  const output = Buffer.concat(actual.flatMap(state => {const length = Buffer.alloc(4); length.writeUInt32BE(state.length); return [length, state];}));
  report.actualStateStreamSha256 = sha(output);
  await writeFile(prefix + '.states.bin.gz', gzipSync(output, {mtime: 0}));
  await writeFile(prefix + '.deployment-receipts.json.gz', gzipSync(JSON.stringify(deploymentReceipts)));
  await writeFile(prefix + '.replay-receipts.json.gz', gzipSync(JSON.stringify(replayReceipts)));
  report.deploymentReceiptsSha256 = sha(await readFile(prefix + '.deployment-receipts.json.gz'));
  report.replayReceiptsSha256 = sha(await readFile(prefix + '.replay-receipts.json.gz'));
  if (child?.pid && child.exitCode === null && child.signalCode === null) {
    await new Promise(done => {
      const timer = setTimeout(() => {child.kill('SIGKILL'); done();}, 2000);
      child.once('exit', () => {clearTimeout(timer); done();}); child.kill('SIGTERM');
    });
  }
  report.ownedRuntimeStopped = child?.exitCode !== null || child?.signalCode !== null;
  await writeFile(prefix + '.json', JSON.stringify(report, null, 2) + '\n');
  await writeFile(prefix + '.anvil-stderr.log', stderr);
  console.log(JSON.stringify({pass: report.pass, executedTics: report.executedTics,
    verifiedTics: report.verifiedTics, totalReplayGas: report.totalReplayGas,
    replayElapsedMs: report.replayElapsedMs, output: prefix + '.json'}));
}
