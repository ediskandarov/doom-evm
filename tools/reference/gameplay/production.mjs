#!/usr/bin/env node
// SPDX-License-Identifier: GPL-2.0-only
// Ordinary production CREATE, authenticated WAD code, original keyboard/native oracle.
// Native files are comparison inputs only. No host world/pixels enter the contract.
import { readFile, writeFile, mkdir, open } from 'node:fs/promises';
import { spawn, execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { connect } from 'node:net';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import { FRAME_TOPIC, decodeFrame, FrameInbox, FrameSubscription, backfill } from '../../../web/protocol.mjs';
import { validatePalette } from '../../../web/palette.mjs';
import { loadGasBudget } from '../../execution-budget.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..'); process.chdir(root);
const args = process.argv.slice(2), option = (name, fallback) => args.includes(name) ? args[args.indexOf(name) + 1] : fallback;
const nativeZone = args.includes('--native-zone'), stagedInitialization = args.includes('--staged-initialization');
const budget = loadGasBudget();
const port = Number(option('--port', nativeZone ? '18679' : '18579')), prefix = option('--output-prefix', stagedInitialization ? 'artifacts/local/gameplay-production-staged-budget' : nativeZone ? 'artifacts/local/gameplay-production-zone-atomic' : 'artifacts/local/gameplay-production-legacy-budget');
const nativePath = option('--native', 'artifacts/local/gameplay-production-native');
const limit = Number(option('--limit', 'Infinity')), keepNode = args.includes('--keep-node');
const externalRpc = option('--rpc', null), resourcesReportPath = option('--resources-report', null);
assert(Number.isInteger(port) && port > 1024 && port < 65536);
assert(limit === Infinity || (Number.isInteger(limit) && limit >= 0));
await mkdir(dirname(prefix), { recursive: true });
const sha = data => createHash('sha256').update(data).digest('hex');
const word = value => BigInt.asUintN(256, BigInt(value)).toString(16).padStart(64, '0');
const tail = data => word(data.length) + data.toString('hex').padEnd(Math.ceil(data.length / 32) * 64, '0');
const bundle = JSON.parse(await readFile('artifacts/local/wad/bundle.json', 'utf8'));
const blob = await readFile('artifacts/local/wad/resources.bin'), directory = await readFile('test/fixtures/phase2_data/directory.bin');
assert.equal(sha(blob), bundle.blobSha256);
const native = JSON.parse(await readFile(nativePath + '/manifest.json', 'utf8'));
assert.equal(native.kind, 'original-keyboard-production-oracle'); assert.deepEqual(native.resourceIdentity, bundle.resourceIdentity);
for (const [name, digest] of Object.entries(native.files)) assert.equal(sha(await readFile(nativePath + '/' + name)), digest, 'native fixture drift ' + name);
const packets = JSON.parse(await readFile(nativePath + '/packets.json', 'utf8'));
const players = JSON.parse(await readFile(nativePath + '/players.json', 'utf8'));
assert.equal(packets.length, native.tics); assert.equal(players.length, packets.length + 1);
// Root owns Forge scheduling. This tool NEVER invokes Forge or rewrites production.
const artifact = JSON.parse(await readFile('out/Doom.sol/Doom.json', 'utf8'));
const chunk = JSON.parse(await readFile('out/ResourceStore.sol/ResourceStore.json', 'utf8'));
const metadata = typeof artifact.metadata === 'string' ? JSON.parse(artifact.metadata) : artifact.metadata;
const method = name => { const value = artifact.methodIdentifiers[name]; assert(value, 'missing production ABI ' + name); return '0x' + value; };
if (stagedInitialization) { method('gameResourcesPrepared()'); method('prepareGameResources()'); }
const errorSelector = name => execFileSync(resolve('.toolchain/bin/cast'), ['sig', name], { encoding: 'utf8' }).trim();
const gas = budget.gasHex, url = externalRpc ?? `http://127.0.0.1:${port}`, wsUrl = option('--ws', url.replace(/^http/, 'ws'));
assert(['127.0.0.1', 'localhost', '[::1]'].includes(new URL(url).hostname), 'only an explicit local RPC is supported');
let rpcId = 0, server, logFile, subscription;
const report = {
  kind: 'production-keyboard-gameplay-ordinary-evm', pass: false, nativeZone, stagedInitialization, executionBudget: budget,
  scope: 'Unmodified production Doom, one held keyboard packet per original tic; all five gameStatus and nine playerView fields after every tic; selected complete indexed8 Frames.',
  resourceIdentity: bundle.resourceIdentity, nativeManifestSha256: sha(await readFile(nativePath + '/manifest.json')),
  gasLimit: budget.gasLimit, comparisons: [], frames: [], rejections: [], sourceHashes: {},
  notes: ['No setCode/etch, probe substitutions, authentication bypass, host state injection, native-provided geometry, visibility, or pixels.',
    'Production gas includes the actual storage load/save, gameplay and optional rendering/event work. Native whole-world records are diagnostic only.',
    'Native snapshots are before each selected renderer pass; exported camera/status/RNG fields are unaffected by rendering.',
    'Selected frame cadence matches native exactly; no-render step keeps simulation independent of display cadence.']
};
async function rpc(method, params = []) {
  const response = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ jsonrpc: '2.0', id: ++rpcId, method, params }), signal: AbortSignal.timeout(300000) });
  assert(response.ok, 'RPC HTTP ' + response.status); const data = await response.json();
  if (data.error) throw Object.assign(Error(`${method}: ${JSON.stringify(data.error)}`), { rpcError: data.error });
  return data.result;
}
const sleep = ms => new Promise(done => setTimeout(done, ms));
async function waitFor(test, label, duration = 180000) {
  const end = Date.now() + duration;
  while (Date.now() < end) { const value = await test(); if (value) return value; await sleep(25); }
  throw Error('Timeout ' + label);
}
async function transaction(from, data, to, expectedStatus = '0x1') {
  const start = performance.now(), hash = await rpc('eth_sendTransaction', [{ from, data, gas, ...(to ? { to } : {}) }]);
  const mined = await waitFor(() => rpc('eth_getTransactionReceipt', [hash]), 'mined transaction');
  assert.equal(mined.status, expectedStatus, `unexpected transaction status ${hash}, gas ${BigInt(mined.gasUsed)}`);
  return { receipt: mined, ms: performance.now() - start, gas: Number(BigInt(mined.gasUsed)) };
}
function abiWords(hex, names, signed = []) {
  assert.match(hex, /^0x(?:[\da-f]{64})+$/i); assert.equal(hex.length, 2 + names.length * 64);
  return Object.fromEntries(names.map((name, i) => {
    const full = BigInt('0x' + hex.slice(2 + i * 64, 66 + i * 64));
    const value = signed.includes(name) ? BigInt.asIntN(256, full) : full;
    assert(Number.isSafeInteger(Number(value)), 'unsafe ABI integer ' + name); return [name, Number(value)];
  }));
}
async function call(address, data, from) { return rpc('eth_call', [{ to: address, data, gas, ...(from ? { from } : {}) }, 'latest']); }
const statusNames = ['gametic', 'leveltime', 'health', 'armor', 'weapon'];
const viewNames = ['x', 'y', 'z', 'angle', 'momx', 'momy', 'momz', 'viewz', 'prndindex'];
async function observation(address) {
  const [status, view] = await Promise.all([call(address, method('gameStatus()')), call(address, method('playerView()'))]);
  return { ...abiWords(status, statusNames, statusNames.slice(1)), ...abiWords(view, viewNames, viewNames.filter(n => !['angle', 'prndindex'].includes(n))) };
}
function expected(player) {
  return { gametic: player.gametic, leveltime: player.leveltime, health: player.playerHealth, armor: player.armorpoints, weapon: player.readyweapon,
    ...Object.fromEntries(viewNames.map(name => [name, name === 'angle' ? player.angle >>> 0 : player[name]])) };
}
async function compare(address, tic, execution = null) {
  const actual = await observation(address), original = expected(players[tic]);
  for (const [field, value] of Object.entries(original)) if (actual[field] !== value) {
    report.firstDifference = { tic, field, native: value, evm: actual[field] };
    await writeFile(prefix + '.mismatch.json', JSON.stringify({ ...report.firstDifference, native: original, evm: actual }, null, 2) + '\n');
    throw Error(JSON.stringify(report.firstDifference));
  }
  report.comparisons.push({ tic, fields: actual, ...(execution ? { method: execution.method, mask: execution.mask, sequence: execution.sequence,
    transactionHash: execution.receipt.transactionHash, gas: execution.gas, ms: execution.ms } : {}) });
}
async function stableState(address) {
  const [started, sequence, frameId, proof] = await Promise.all([call(address, method('gameStarted()')), call(address, method('inputSeq()')),
    call(address, method('frameId()')), rpc('eth_getProof', [address, [], 'latest'])]);
  // Account storage root binds all persistent state, including fields absent from the compact ABI.
  assert.match(proof.storageHash, /^0x[\da-f]{64}$/i);
  const resourcesPrepared = stagedInitialization ? await call(address, method('gameResourcesPrepared()')) : undefined;
  return { started, sequence, frameId, storageRoot: proof.storageHash, codeHash: proof.codeHash, ...(stagedInitialization ? { resourcesPrepared } : {}) };
}
async function rejection(label, from, address, data, errorName) {
  const before = await stableState(address), selector = errorSelector(errorName.includes('(') ? errorName : errorName + '()');
  let rejected = false;
  try { await call(address, data, from); }
  catch (error) {
    assert(error.rpcError, 'unexpected call failure');
    const detail = error.rpcError.data;
    const revertData = typeof detail === 'string' ? detail : detail?.data;
    assert.equal(revertData?.slice(0, 10), selector, label + ' revert selector'); rejected = true;
  }
  assert(rejected, label + ' must revert in eth_call');
  const result = await transaction(from, data, address, '0x0'); assert.equal(result.receipt.logs.length, 0);
  assert.deepEqual(await stableState(address), before, label + ' changed persistent storage');
  report.rejections.push({ label, error: errorName, selector, transactionHash: result.receipt.transactionHash, gas: result.gas, allStorageRollback: true });
}
function runtimeFor(driver) {
  const runtime = Buffer.from(artifact.deployedBytecode.object.slice(2), 'hex');
  const immutable = Object.values(artifact.deployedBytecode.immutableReferences ?? {});
  assert.equal(immutable.length, 1, 'only production driver immutable expected');
  for (const entry of immutable[0]) { assert.equal(entry.length, 32); Buffer.from(word(driver), 'hex').copy(runtime, entry.start); }
  return '0x' + runtime.toString('hex');
}
async function frame(result, address, sequence, frameId, nativeFrame, label, inbox, wsLogs, fallback = false) {
  assert.equal(result.receipt.logs.length, 1); const log = result.receipt.logs[0];
  assert.equal(log.address.toLowerCase(), address.toLowerCase()); assert.equal(log.topics[0], FRAME_TOPIC);
  inbox.accept(log, 'receipt'); const decoded = decodeFrame(log);
  assert.equal(decoded.inputSeq, sequence); assert.equal(decoded.frameId, BigInt(frameId));
  assert.equal(decoded.width, 320); assert.equal(decoded.height, 200); assert.equal(decoded.pixels.length, 64000);
  const original = await readFile(nativeFrame), actual = Buffer.from(decoded.pixels);
  if (!actual.equals(original)) {
    let count = 0, first = -1; for (let i = 0; i < 64000; i++) if (actual[i] !== original[i]) { count++; if (first < 0) first = i; }
    report.firstDifference = { label, field: 'framebuffer', pixelDiffCount: count, firstPixel: first, native: original[first], evm: actual[first] };
    await writeFile(prefix + '.mismatch-frame.bin', actual); throw Error(JSON.stringify(report.firstDifference));
  }
  if (!fallback) {
    await waitFor(() => wsLogs.has(log.transactionHash), 'Frame WS notification', 30000);
    assert.equal(wsLogs.get(log.transactionHash).data, log.data); assert.deepEqual(wsLogs.get(log.transactionHash).topics, log.topics);
  }
  report.frames.push({ label, sequence, frameId, sha256: sha(actual), pixelDiffCount: 0, wsEqualsReceipt: !fallback,
    receiptFallback: fallback, transactionHash: result.receipt.transactionHash, gas: result.gas, ms: result.ms });
}
try {
  // Bind current source to the compiler artifact before any deployment. Cast performs
  // only Keccak hashing here, never a build; mismatched artifacts fail immediately.
  for (const [path, identity] of Object.entries(metadata.sources)) {
    const source = await readFile(path); report.sourceHashes[path] = sha(source);
    const digest = execFileSync(resolve('.toolchain/bin/cast'), ['keccak'], { input: '0x' + source.toString('hex'), encoding: 'utf8', maxBuffer: 1024 * 1024 }).trim();
    assert.equal(digest, identity.keccak256, 'artifact source drift ' + path);
  }
  for (const path of ['tools/reference/gameplay/production.py', 'tools/reference/gameplay/production.mjs', 'foundry.toml', 'tools/execution-budget.mjs', 'execution-budget.json']) report.sourceHashes[path] = sha(await readFile(path));
  let nodeArgs = null;
  if (!externalRpc) {
    await new Promise((done, fail) => { const socket = connect({ host: '127.0.0.1', port });
      socket.once('connect', () => { socket.destroy(); fail(Error('Refusing occupied port')); }); socket.once('error', error => error.code === 'ECONNREFUSED' ? done() : fail(error)); });
    nodeArgs = ['--host', '127.0.0.1', '--port', String(port), '--hardfork', 'cancun', '--disable-code-size-limit', '--disable-block-gas-limit', '--memory-limit', '1073741824', '--silent'];
    logFile = await open(prefix + '.anvil.log', 'w');
    server = spawn(resolve('.toolchain/bin/anvil'), nodeArgs, { detached: true, stdio: ['ignore', 'ignore', logFile.fd] });
    let spawnError; server.on('error', error => { spawnError = error; });
    await waitFor(async () => { if (spawnError) throw spawnError; assert.equal(server.exitCode, null, 'Anvil exited'); try { return await rpc('web3_clientVersion'); } catch { return false; } }, 'Anvil startup', 30000);
    await rpc('anvil_setBlockGasLimit', [gas]);
  }
  const [driver, other] = await rpc('eth_accounts'); assert(driver && other);
  report.client = await rpc('web3_clientVersion'); report.nodeArgs = nodeArgs;
  report.node = { ...(server ? { pid: server.pid } : {}), rpcUrl: url, wsUrl, external: !!externalRpc };
  report.externalNodeSettingsUnverified = !!externalRpc;
  if (externalRpc) {
    await rpc('anvil_setBlockGasLimit', [gas]);
    report.configuredExternalNodeBudget = { method: 'anvil_setBlockGasLimit', gasHex: gas };
  }
  // Materialize the configured block budget before any engine transaction.
  await rpc('evm_mine');
  const budgetBlock = await rpc('eth_getBlockByNumber', ['latest', false]);
  assert.equal(BigInt(budgetBlock.gasLimit), BigInt(budget.gasLimit), 'node block budget does not match configured policy');
  report.verifiedNodeBudget = { blockNumber: budgetBlock.number, blockGasLimit: Number(BigInt(budgetBlock.gasLimit)), configuredGasLimit: budget.gasLimit };
  report.compiler = { version: metadata.compiler.version, settings: metadata.settings };
  const addresses = [], uploadStart = performance.now(); let chunkGas = 0;
  let resourcesReport;
  if (resourcesReportPath) {
    resourcesReport = JSON.parse(await readFile(resourcesReportPath, 'utf8'));
    assert.deepEqual(resourcesReport.resourceIdentity, bundle.resourceIdentity, 'cached resource identity');
    assert.equal(resourcesReport.deployment.chunks.length, 1755);
    assert.equal(new Set(resourcesReport.deployment.chunks).size, 1755, 'duplicate cached chunks');
  }
  for (let pos = 0; pos < blob.length; pos += 16384) {
    const bytes = blob.subarray(pos, pos + 16384);
    let address;
    if (resourcesReport) address = resourcesReport.deployment.chunks[addresses.length];
    else {
      const result = await transaction(driver, chunk.bytecode.object + word(32) + tail(bytes));
      address = result.receipt.contractAddress; chunkGas += result.gas;
    }
    assert.equal(await rpc('eth_getCode', [address, 'latest']), '0x00' + bytes.toString('hex'));
    addresses.push(address);
    if (addresses.length % 250 === 0) console.log(`Verified ordinary resource runtime ${addresses.length}/1755${resourcesReport ? ' (reused)' : ''}`);
  }
  assert.equal(addresses.length, 1755);
  report.resources = { reused: !!resourcesReport, sourceReport: resourcesReportPath,
    ...(resourcesReportPath ? { sourceReportSha256: sha(await readFile(resourcesReportPath)) } : {}),
    allBytesRechecked: true, identityExact: true, newlyUploadedChunkGas: chunkGas };
  const addr = word(addresses.length) + addresses.map(value => value.slice(2).padStart(64, '0')).join('');
  const constructor = word(64) + word(64 + addr.length / 2) + addr + tail(directory);
  const deploy = await transaction(driver, artifact.bytecode.object + constructor), address = deploy.receipt.contractAddress;
  const runtime = runtimeFor(driver); assert.equal(await rpc('eth_getCode', [address, 'latest']), runtime);
  assert.equal(await call(address, method('driver()')), '0x' + word(driver));
  report.deployment = { address, transactionHash: deploy.receipt.transactionHash, gas: deploy.gas, ms: deploy.ms,
    runtimeBytes: (runtime.length - 2) / 2, runtimeSha256: sha(Buffer.from(runtime.slice(2), 'hex')),
    all1755AuthenticatedResourceRuntimesVerified: true, chunks: addresses, chunkGas, uploadMs: performance.now() - uploadStart };
  const wsLogs = new Map(), delivered = [];
  const inbox = new FrameInbox((value, source) => delivered.push({ frameId: String(value.frameId), source }));
  subscription = new FrameSubscription(wsUrl, address, log => { wsLogs.set(log.transactionHash, log); inbox.accept(log, 'ws'); });
  await subscription.connect();
  assert.equal(await call(address, method('gameStarted()')), '0x' + word(0));
  if (stagedInitialization) {
    assert.equal(await call(address, method('gameResourcesPrepared()')), '0x' + word(0));
    await rejection('non-driver resource preparation', other, address, method('prepareGameResources()'), 'NotDriver');
    await rejection('initialize before resource preparation', driver, address, method('initializeGame()'), 'GameResourcesNotPrepared');
  }
  await rejection('non-driver initialize', other, address, method('initializeGame()'), 'NotDriver');
  await rejection('step before startup', driver, address, method('step(uint32,uint32)') + word(0) + word(1), 'GameNotStarted');
  await rejection('held movement before startup', driver, address, method('stepAndRender(uint32,uint32)') + word(1) + word(1), 'UnsupportedButtons');
  await rejection('sequence zero before startup', driver, address, method('stepAndRender(uint32,uint32)') + word(0) + word(0), 'BadSequence');
  const renderer = JSON.parse(await readFile('test/fixtures/renderer/manifest.json', 'utf8'));
  assert.deepEqual(renderer.resourceIdentity, bundle.resourceIdentity);
  const staticCase = renderer.cases.find(row => row.name === 'full-angle0'); assert(staticCase);
  const staticFramePath = 'test/fixtures/renderer/' + staticCase.name + '/pixels.bin';
  assert.equal(sha(await readFile(staticFramePath)), staticCase.frameSha256);
  const staticTx = await transaction(driver, method('renderFrame()'), address);
  await frame(staticTx, address, 1, 1, staticFramePath, 'static-before-start', inbox, wsLogs);
  if (stagedInitialization) {
    const preparation = await transaction(driver, method('prepareGameResources()'), address);
    assert.equal(preparation.receipt.logs.length, 0);
    assert.equal(await call(address, method('gameResourcesPrepared()')), '0x' + word(1));
    assert.equal(await call(address, method('gameStarted()')), '0x' + word(0));
    assert.equal(await call(address, method('inputSeq()')), '0x' + word(1));
    assert.equal(await call(address, method('frameId()')), '0x' + word(1));
    report.preparation = { gas: preparation.gas, ms: preparation.ms, transactionHash: preparation.receipt.transactionHash, emitsFrame: false, inputSeq: 1, frameId: 1 };
    await rejection('resource preparation twice', driver, address, method('prepareGameResources()'), 'GameResourcesAlreadyPrepared');
  }
  const startup = await transaction(driver, method('initializeGame()'), address); assert.equal(startup.receipt.logs.length, 0);
  report.startup = { gas: startup.gas, ms: startup.ms, transactionHash: startup.receipt.transactionHash, emitsFrame: false };
  assert.equal(await call(address, method('gameStarted()')), '0x' + word(1));
  assert.equal(await call(address, method('inputSeq()')), '0x' + word(1)); await compare(address, 0);
  console.log('PASS production startup: all 14 native fields, static Frame preserved');
  if (stagedInitialization) await rejection('resource preparation after initialization', driver, address, method('prepareGameResources()'), 'GameAlreadyStarted');
  await rejection('initialize twice', driver, address, method('initializeGame()'), 'GameAlreadyStarted');
  await rejection('non-driver step', other, address, method('step(uint32,uint32)') + word(0) + word(2), 'NotDriver');
  await rejection('non-driver frame', other, address, method('stepAndRender(uint32,uint32)') + word(0) + word(2), 'NotDriver');
  await rejection('non-driver renderFrame', other, address, method('renderFrame()'), 'NotDriver');
  await rejection('repeated accepted sequence', driver, address, method('step(uint32,uint32)') + word(0) + word(1), 'BadSequence');
  await rejection('skipped sequence', driver, address, method('stepAndRender(uint32,uint32)') + word(0) + word(3), 'BadSequence');
  await rejection('zero sequence after startup', driver, address, method('step(uint32,uint32)') + word(0) + word(0), 'BadSequence');
  await rejection('reserved input bits', driver, address, method('step(uint32,uint32)') + word(1 << 14) + word(2), 'UnsupportedInputBits(uint32)');
  await rejection('invalid weapon request', driver, address, method('stepAndRender(uint32,uint32)') + word(10 << 10) + word(2), 'InvalidWeaponRequest(uint8)');
  let nextSequence = 2, frameId = 1, fallbackUsed = false;
  for (const packet of packets.slice(0, Math.min(limit, packets.length))) {
    const name = packet.render ? 'stepAndRender(uint32,uint32)' : 'step(uint32,uint32)';
    const fallback = packet.render && packet.tic === native.frames[1].tic;
    if (fallback) subscription.close();
    const execution = { ...(await transaction(driver, method(name) + word(packet.mask) + word(nextSequence), address)), method: name, mask: packet.mask, sequence: nextSequence };
    await compare(address, packet.tic, execution);
    assert.equal(await call(address, method('inputSeq()')), '0x' + word(nextSequence));
    if (packet.render) {
      await frame(execution, address, nextSequence, ++frameId, `${nativePath}/frame-${String(packet.tic).padStart(6, '0')}.bin`, 'tic-' + packet.tic, inbox, wsLogs, fallback);
      if (fallback) {
        const before = delivered.length; await subscription.connect(); await backfill(rpc, address, execution.receipt.blockNumber, inbox);
        assert.equal(delivered.length, before, 'backfill redisplayed receipt fallback'); fallbackUsed = true;
      }
    } else assert.equal(execution.receipt.logs.length, 0, 'no-render tic emitted a Frame');
    nextSequence++;
    if (packet.tic % 10 === 0 || packet.tic === packets.length) console.log(`PASS production tic ${packet.tic}/${packets.length}, ${report.frames.length - 1} live Frames exact`);
  }
  report.transport = { delivered, duplicates: inbox.duplicates, stale: inbox.stale, receiptFallbackVerified: fallbackUsed };
  // Fresh ordinary deployment shares only authenticated immutable resource code,
  // not gameplay/storage. Root's real browser gate can start from static transport.
  const browserDeploy = await transaction(driver, artifact.bytecode.object + constructor), browserAddress = browserDeploy.receipt.contractAddress;
  assert.equal(await rpc('eth_getCode', [browserAddress, 'latest']), runtime);
  assert.equal(await call(browserAddress, method('gameStarted()')), '0x' + word(0));
  assert.equal(await call(browserAddress, method('inputSeq()')), '0x' + word(0));
  if (stagedInitialization) assert.equal(await call(browserAddress, method('gameResourcesPrepared()')), '0x' + word(0));
  const palette = JSON.parse(await readFile('web/palette.local.json', 'utf8'));
  await validatePalette(palette, bundle.resourceIdentity, 'wad');
  const paletteBytes = JSON.stringify(palette, null, 2) + '\n';
  await writeFile(prefix + '.palette.json', paletteBytes);
  if (!args.includes('--no-web-palette-write')) await writeFile('web/palette.local.json', paletteBytes);
  const config = { rpcUrl: url, wsUrl, address: browserAddress, driver, rendererKind: 'doom-world-view', gameplay: true,
    referenceCase: staticCase.name, deploymentBlock: browserDeploy.receipt.blockNumber,
    paletteUrl: '/palette.local.json', paletteKind: 'wad', resourceIdentity: bundle.resourceIdentity, gasLimit: budget.gasLimit, stagedInitialization, ...(nativeZone ? { nativeZone: true } : {}) };
  await writeFile(prefix + '.config.json', JSON.stringify(config, null, 2) + '\n');
  report.browserDeployment = { address: browserAddress, transactionHash: browserDeploy.receipt.transactionHash, gas: browserDeploy.gas,
    deploymentBlock: browserDeploy.receipt.blockNumber,
    configPath: prefix + '.config.json', palettePath: prefix + '.palette.json', gameStarted: false, inputSeq: 0, ...(stagedInitialization ? { gameResourcesPrepared: false } : {}) };
  report.executedTics = report.comparisons.length - 1; report.completeNativeStream = report.executedTics === packets.length;
  report.pass = true;
  console.log(JSON.stringify({ pass: true, completeNativeStream: report.completeNativeStream, tics: report.executedTics,
    liveFrames: report.frames.length - 1, rejections: report.rejections.length, browserConfig: prefix + '.config.json', keepNode }));
} catch (error) { report.error = String(error); throw error; }
finally {
  subscription?.close();
  report.nodeKeptRunning = !!(report.pass && keepNode && server?.pid && server.exitCode === null);
  await writeFile(prefix + '.json', JSON.stringify(report, null, 2) + '\n');
  if (server?.pid && server.exitCode === null) {
    if (report.nodeKeptRunning) server.unref();
    else await new Promise(done => { server.once('exit', done); server.kill('SIGTERM'); setTimeout(() => { if (server.exitCode === null) server.kill('SIGKILL'); }, 1500).unref(); });
  }
  await logFile?.close();
}
