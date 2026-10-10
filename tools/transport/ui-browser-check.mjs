// SPDX-License-Identifier: GPL-2.0-only
// Actual Chrome keyboard -> ordinary EVM -> native indexed8 Frame -> Canvas gate.
import { spawn } from 'node:child_process';
import { readFile, writeFile, mkdtemp, mkdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve, dirname, join } from 'node:path';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import { serve } from './serve.mjs';
import { makeRpc, decodeFrame, expandPalette, FRAME_TOPIC } from '../../web/protocol.mjs';

const args = process.argv.slice(2);
const option = (name, fallback) => args.includes(name) ? args[args.indexOf(name) + 1] : fallback;
const configPath = option('--config', 'artifacts/local/ui/production.config.json');
const nativePath = option('--native', 'artifacts/local/ui-native');
const palettePath = option('--palette', 'web/palette.local.json');
const prefix = option('--output-prefix', 'artifacts/local/ui/browser');
const sha = value => createHash('sha256').update(value).digest('hex');
const config = JSON.parse(await readFile(configPath, 'utf8'));
const palette = JSON.parse(await readFile(palettePath, 'utf8'));
const native = JSON.parse(await readFile(resolve(nativePath, 'manifest.json'), 'utf8'));
const packets = JSON.parse(await readFile(resolve(nativePath, 'packets.json'), 'utf8'));
const players = JSON.parse(await readFile(resolve(nativePath, 'players.json'), 'utf8'));
assert.equal(config.gameplay, true);
assert.equal(config.productionUI, true);
assert.equal(native.kind, 'original-production-ui-oracle');
assert.deepEqual(native.resourceIdentity, config.resourceIdentity);
assert.equal(packets.length, 210);
for (const [name, digest] of Object.entries(native.files)) {
  assert.equal(sha(await readFile(resolve(nativePath, name))), digest, `native identity: ${name}`);
}
const rpc = makeRpc(config.rpcUrl);
const artifact = JSON.parse(await readFile('out/Doom.sol/Doom.json', 'utf8'));
const runtime = await rpc('eth_getCode', [config.address, 'latest']);
const normalizeRuntime = hex => {
  const bytes = Buffer.from(hex.slice(2), 'hex');
  for (const spans of Object.values(artifact.deployedBytecode.immutableReferences ?? {})) {
    for (const { start, length } of spans) bytes.fill(0, start, start + length);
  }
  return bytes;
};
assert.equal(sha(normalizeRuntime(runtime)), sha(normalizeRuntime(artifact.deployedBytecode.object)), 'deployed source runtime after compiler-recorded immutable slots');
const signature = name => '0x' + artifact.methodIdentifiers[name];
const driverWord = await rpc('eth_call', [{ to: config.address, data: signature('driver()') }, 'latest']);
assert.equal('0x' + driverWord.slice(-40), config.driver.toLowerCase(), 'deployed immutable driver');
const startFlag = await rpc('eth_call', [{ to: config.address, data: signature('gameStarted()') }, 'latest']);
assert.equal(BigInt(startFlag), 0n, 'browser gate needs a fresh uninitialized game');
const initialSequence = Number(BigInt(await rpc('eth_call', [{ to: config.address, data: signature('inputSeq()') }, 'latest'])));
await writeFile('web/config.local.json', JSON.stringify(config, null, 2) + '\n');
await writeFile('web/palette.local.json', JSON.stringify(palette, null, 2) + '\n');
const report = { kind: 'production-ui-chrome-keyboard-canvas', pass: false, config,
  nativeManifestSha256: sha(await readFile(resolve(nativePath, 'manifest.json'))),
  runtimeSha256: sha(Buffer.from(runtime.slice(2), 'hex')),
  scope: '210 original tics: actual Chrome Start/Resume keyboard for selected rendered tics, receipt fallback at actual pickup tic64, no-render original command transactions between Frames; original UI palette/fullscreen/HUD expiry.',
  initialSequence, frames: [], sources: {} };
for (const path of ['tools/transport/ui-browser-check.mjs', 'web/app.mjs', 'web/input.mjs',
  'web/input-loop.mjs', 'web/protocol.mjs', 'web/palette.mjs', 'web/ui-palette.mjs', 'src/evm/Doom.sol']) {
  report.sources[path] = sha(await readFile(path));
}
let chrome, server, profile, cdp;
const sleep = ms => new Promise(done => setTimeout(done, ms));
async function until(check, label) {
  const deadline = Date.now() + 45000;
  while (Date.now() < deadline) { const result = await check(); if (result) return result; await sleep(10); }
  throw Error('Timeout: ' + label);
}
async function stop(child) {
  if (!child?.pid || child.exitCode !== null || child.signalCode !== null) return;
  await new Promise(done => {
    let timer; const finish = () => { clearTimeout(timer); done(); };
    child.once('exit', finish); child.kill('SIGTERM');
    timer = setTimeout(() => { child.kill('SIGKILL'); timer = setTimeout(finish, 1500); }, 1500);
  });
}
function decodedWords(hex) {
  const data = Buffer.from(hex.slice(2), 'hex'); assert.equal(data.length % 32, 0);
  return Array.from({ length: data.length / 32 }, (_, i) => BigInt('0x' + data.subarray(i * 32, i * 32 + 32).toString('hex')));
}
async function comparePlayer(tic) {
  const status = decodedWords(await rpc('eth_call', [{ to: config.address, data: signature('gameStatus()') }, 'latest']));
  const view = decodedWords(await rpc('eth_call', [{ to: config.address, data: signature('playerView()') }, 'latest']));
  const names = ['gametic', 'leveltime', 'playerHealth', 'armorpoints', 'readyweapon', 'x', 'y', 'z', 'angle', 'momx', 'momy', 'momz', 'viewz', 'prndindex'];
  const unsigned = new Set(['gametic', 'angle', 'prndindex']);
  [...status, ...view].forEach((word, i) => {
    const value = unsigned.has(names[i]) ? Number(word) : Number(BigInt.asIntN(256, word));
    const expected = names[i] === 'angle' ? players[tic][names[i]] >>> 0 : players[tic][names[i]];
    assert.equal(value, expected, `native field tic ${tic}: ${names[i]}`);
  });
}
try {
  server = await serve(0);
  profile = await mkdtemp(join(tmpdir(), 'doom-gameplay-chrome-'));
  chrome = spawn(process.env.CHROME_BIN ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    ['--headless=new', '--no-first-run', '--no-default-browser-check', '--disable-background-networking',
      '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
  let chromeError = ''; chrome.stderr.on('data', bytes => chromeError += bytes);
  chrome.on('error', error => chromeError += error.message);
  const debugPort = await until(async () => {
    if (chrome.exitCode !== null) throw Error(chromeError);
    try { return (await readFile(join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]; } catch { return false; }
  }, 'Chrome start');
  const tabs = await (await fetch(`http://127.0.0.1:${debugPort}/json/list`)).json();
  cdp = new WebSocket(tabs.find(tab => tab.type === 'page').webSocketDebuggerUrl);
  await new Promise((done, fail) => { cdp.addEventListener('open', done, { once: true }); cdp.addEventListener('error', fail, { once: true }); });
  let id = 0; const pending = new Map();
  cdp.addEventListener('message', event => {
    const reply = JSON.parse(event.data), request = pending.get(reply.id);
    if (request) { pending.delete(reply.id); clearTimeout(request.timer); reply.error ? request.reject(Error(JSON.stringify(reply.error))) : request.resolve(reply.result); }
  });
  const command = (method, params = {}) => new Promise((resolve, reject) => {
    const key = ++id; pending.set(key, { resolve, reject, timer: setTimeout(() => { pending.delete(key); reject(Error('CDP timeout: ' + method)); }, 15000) });
    cdp.send(JSON.stringify({ id: key, method, params }));
  });
  const evaluate = async expression => {
    const result = await command('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (result.exceptionDetails) throw Error(result.exceptionDetails.exception?.description ?? result.exceptionDetails.text);
    return result.result.value;
  };
  await command('Page.enable');
  await command('Emulation.setDeviceMetricsOverride', { width: 1100, height: 900, deviceScaleFactor: 1, mobile: false });
  await command('Page.navigate', { url: `http://127.0.0.1:${server.address().port}/` });
  await until(async () => {
    const proof = await evaluate('window.__transportProof');
    if (proof?.errors?.length) throw Error(proof.errors.join('\n'));
    return proof?.ready;
  }, 'gameplay page ready');
  await evaluate(`(() => {
    window.__gameplayFrames = []; window.__gameplayExpected = -1;
    const client = window.fixtureClient, original = client.inbox.onFrame;
    client.inbox.onFrame = (frame, source) => {
      original(frame, source);
      if (frame.inputSeq !== window.__gameplayExpected) return;
      client.stopGame();
      (async () => {
        while (window.__transportProof.frames.at(-1)?.inputSeq !== frame.inputSeq) {
          if (window.__transportProof.errors.length) return;
          await new Promise(done => setTimeout(done, 10));
        }
        const canvas = document.querySelector('#frame');
        const rgba = canvas.getContext('2d').getImageData(0, 0, 320, 200).data;
        const bytes = await crypto.subtle.digest('SHA-256', rgba);
        window.__gameplayFrames.push({ inputSeq: frame.inputSeq, frameId: String(frame.frameId), source,
          transactionHash: frame.log.transactionHash, pixels: window.__transportProof.latestPixelsHex,
          palette: window.__transportProof.latestPalette,
          rgbaSha256: [...new Uint8Array(bytes)].map(x => x.toString(16).padStart(2, '0')).join('') });
      })();
    };
    return true;
  })()`);
  const codes = ['KeyW', 'KeyS', 'KeyA', 'KeyD', 'ArrowLeft', 'ArrowRight', 'Space', 'ControlLeft', 'ShiftLeft', 'AltLeft'];
  const word = n => BigInt(n).toString(16).padStart(64, '0');
  let fullscreen = false;
  for (const packet of packets) {
    if (packet.fullscreen !== fullscreen) {
      const hash = await rpc('eth_sendTransaction', [{ from: config.driver, to: config.address,
        data: signature('setUIFullscreen(bool)') + word(packet.fullscreen ? 1 : 0), gas: '0x'+BigInt(config.gasLimit).toString(16) }]);
      await until(async () => { const mined = await rpc('eth_getTransactionReceipt', [hash]); if (!mined) return false; assert.equal(mined.status, '0x1'); assert.equal(mined.logs.length, 0); return true; }, 'viewport change');
      fullscreen = packet.fullscreen;
    }
    if (!packet.render) {
      const hash = await rpc('eth_sendTransaction', [{ from: config.driver, to: config.address,
        data: signature('step(uint32,uint32)') + word(packet.mask) + word(initialSequence + packet.tic), gas: '0x'+BigInt(config.gasLimit).toString(16) }]);
      await until(async () => { const mined = await rpc('eth_getTransactionReceipt', [hash]); if (!mined) return false; assert.equal(mined.status, '0x1'); assert.equal(mined.logs.length, 0); return true; }, 'no-render tic');
      continue;
    }
    const seq = initialSequence + packet.tic;
    if (packet.tic !== 64) {
      const keys = codes.filter((_, bit) => packet.mask & (1 << bit));
      await evaluate(`(() => { window.__gameplayExpected = ${seq};
        document.querySelector('#game-start').click();
        for (const code of ${JSON.stringify(keys)}) window.dispatchEvent(new KeyboardEvent('keydown', { code, bubbles: true, cancelable: true }));
        return { running: window.fixtureClient.loop.running, held: window.fixtureClient.keyboard.sample() };
      })()`).then(state => { assert(state.running); assert.equal(state.held, packet.mask); });
    } else {
      await evaluate(`(async () => { window.__gameplayExpected = ${seq};
        await window.fixtureClient.transactions.load();
        await window.fixtureClient.nextFrame({ buttons: ${packet.mask}, disconnect: true }); return true;
      })()`);
    }
    const record = await until(async () => {
      const value = await evaluate(`({ record: window.__gameplayFrames.at(-1), busy: window.fixtureClient.transactions.busy,
        pending: window.fixtureClient.transactions.pending, running: window.fixtureClient.loop.running, errors: window.__transportProof.errors })`);
      if (value.errors.length) throw Error(value.errors.join('\n'));
      return value.record?.inputSeq === seq && value.record.rgbaSha256 && !value.busy && !value.pending && !value.running ? value.record : false;
    }, 'accepted browser tic ' + packet.tic);
    const mined = await rpc('eth_getTransactionReceipt', [record.transactionHash]); assert.equal(mined.status, '0x1');
    const frame = decodeFrame(mined.logs.find(log => log.address.toLowerCase() === config.address.toLowerCase()
      && log.topics[0] === FRAME_TOPIC));
    const expected = await readFile(resolve(nativePath, `frame-${String(packet.tic).padStart(6, '0')}.bin`));
    assert.equal(frame.inputSeq, seq); assert.equal(frame.pixels.length, 64000);
    assert.equal(Buffer.compare(Buffer.from(frame.pixels), expected), 0, 'all native pixels tic ' + packet.tic);
    assert.equal(record.pixels, expected.toString('hex'), 'all browser indexed pixels tic ' + packet.tic);
    assert.equal(record.rgbaSha256, sha(expandPalette(frame, await readFile(resolve(nativePath, `palette-${String(packet.tic).padStart(6, '0')}.bin`)))), 'all Canvas pixels tic ' + packet.tic);
    const originalPalette = await readFile(resolve(nativePath, `palette-${String(packet.tic).padStart(6, '0')}.bin`));
    assert.equal(record.palette.rgbHex, originalPalette.toString('hex'), 'all EVM-selected palette bytes');
    await comparePlayer(packet.tic);
    report.frames.push({ tic: packet.tic, mask: packet.mask, inputSeq: seq, frameId: record.frameId,
      source: record.source, transactionHash: record.transactionHash, gas: Number(BigInt(mined.gasUsed)),
      pixelSha256: sha(expected), rgbaSha256: record.rgbaSha256, palette: record.palette.palette, paletteSha256: sha(originalPalette), all64000NativePixelsExact: true, allCanvasPixelsExact: true, nativeFieldsExact: 14 });
    if ([64, 70, 203, 204].includes(packet.tic)) {
      const screenshot = await command('Page.captureScreenshot', { format: 'png' });
      await mkdir(dirname(prefix), { recursive: true });
      await writeFile(prefix + '-tic' + packet.tic + '.png', Buffer.from(screenshot.data, 'base64'));
    }
    console.log(`PASS Chrome gameplay tic ${packet.tic}: mask ${packet.mask}, native/receipt/Canvas exact`);
  }
  const proof = await evaluate('window.__transportProof');
  assert(proof.fallbackVerified); assert(proof.duplicates >= 2);
  report.fallbackVerified = true; report.duplicates = proof.duplicates;
  // Blur while starting cancels future sampling before a tic can be sent.
  await evaluate(`(() => { document.querySelector('#game-start').click(); window.dispatchEvent(new Event('blur')); return true; })()`);
  await until(() => evaluate('!window.fixtureClient.loop.starting && !window.fixtureClient.transactions.pending'), 'blur settles metadata reads');
  assert.equal(Number(BigInt(await rpc('eth_call', [{ to: config.address, data: signature('inputSeq()') }, 'latest']))), initialSequence + packets.length);
  report.blurStopsBeforeNextCommand = true;
  assert(report.frames.some(f => f.palette === 10), 'real pickup bonus palette observed');
  assert(report.frames.some(f => f.tic === 204), 'HUD expiry Canvas observed');
  report.viewportTransitions = [70, 101]; report.executedTics = packets.length;
  report.browser = await command('Browser.getVersion');
  const screenshot = await command('Page.captureScreenshot', { format: 'png' });
  await mkdir(dirname(prefix), { recursive: true }); await writeFile(prefix + '.png', Buffer.from(screenshot.data, 'base64'));
  report.screenshot = prefix + '.png'; report.pass = true;
} catch (error) { report.error = error.message; process.exitCode = 1; console.error(error.message); }
finally {
  await mkdir(dirname(prefix), { recursive: true }); await writeFile(prefix + '.json', JSON.stringify(report, null, 2) + '\n');
  cdp?.close(); await stop(chrome);
  if (server) await new Promise(done => server.close(done));
  if (profile) await rm(profile, { recursive: true, force: true });
}
