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
const configPath = option('--config', 'artifacts/local/input-runtime/production.config.json');
const nativePath = option('--native', 'artifacts/local/input-runtime-native');
const palettePath = option('--palette', 'web/palette.local.json');
const prefix = option('--output-prefix', 'artifacts/local/input-runtime/browser');
const sha = value => createHash('sha256').update(value).digest('hex');
const config = JSON.parse(await readFile(configPath, 'utf8'));
config.menuMode = false; // Preserve this inherited legacy raw-input/browser gate.
const palette = JSON.parse(await readFile(palettePath, 'utf8'));
const native = JSON.parse(await readFile(resolve(nativePath, 'manifest.json'), 'utf8'));
const packets = JSON.parse(await readFile(resolve(nativePath, 'packets.json'), 'utf8'));
const players = JSON.parse(await readFile(resolve(nativePath, 'players.json'), 'utf8'));
assert.equal(config.gameplay, true);
assert.equal(config.productionUI, true);
assert.equal(native.kind, 'original-production-input-runtime-oracle');
assert.deepEqual(native.resourceIdentity, config.resourceIdentity);
assert.equal(config.rawKeyboard, true);
assert.equal(packets.length, native.tics);
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
const report = { kind: 'production-input-runtime-chrome-keyboard-canvas', pass: false, config,
  nativeManifestSha256: sha(await readFile(resolve(nativePath, 'manifest.json'))),
  runtimeSha256: sha(Buffer.from(runtime.slice(2), 'hex')),
  scope: 'Actual Chrome Start and original DOM raw key events; browser event queue/transaction loop, no-render browser transport, EVM Cheats/Automap/UI and native indexed/palette/Canvas proofs. Controlled scheduling fixes transaction/tic boundaries; browser computes no gameplay or map pixels.',
  initialSequence, frames: [], sources: {} };
for (const path of ['tools/transport/input-runtime-browser-check.mjs', 'web/app.mjs', 'web/input.mjs',
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
    const client=window.fixtureClient;
    client.loop.schedule=fn=>{window.__nextInputTick=fn;return 1;};
    client.loop.cancel=()=>{window.__nextInputTick=null;};
    document.querySelector('#game-start').click();return true;
  })()`);
  await until(()=>evaluate('window.fixtureClient.loop.running && !window.fixtureClient.loop.starting && !window.fixtureClient.transactions.pending'), 'raw Start initialized');
  const codes=new Map([[9,'Tab'],[13,'Enter'],[32,'Space'],[44,'Comma'],[45,'Minus'],[46,'Period'],[59,'Semicolon'],[61,'Equal'],
    [0xad,'ArrowUp'],[0xaf,'ArrowDown'],[0xac,'ArrowLeft'],[0xae,'ArrowRight'],[0xb6,'ShiftLeft'],[0x9d,'ControlLeft'],[0xb8,'AltLeft'],[216,'F12'],[255,'Pause']]);
  for(let key=97;key<=122;key++)codes.set(key,'Key'+String.fromCharCode(key-32));
  for(let key=48;key<=57;key++)codes.set(key,'Digit'+String.fromCharCode(key));
  const word=n=>BigInt(n).toString(16).padStart(64,'0');
  let fullscreen=false;
  for(const packet of packets){
    if(packet.fullscreen!==fullscreen){
      const hash=await rpc('eth_sendTransaction',[{from:config.driver,to:config.address,data:signature('setUIFullscreen(bool)')+word(packet.fullscreen?1:0),gas:'0x'+BigInt(config.gasLimit).toString(16)}]);
      await until(async()=>{const mined=await rpc('eth_getTransactionReceipt',[hash]);if(!mined)return false;assert.equal(mined.status,'0x1');assert.equal(mined.logs.length,0);return true;},'viewport change');
      fullscreen=packet.fullscreen;
    }
    const dom=packet.events.map(([kind,key])=>({type:kind===0?'keydown':'keyup',code:codes.get(key)}));
    assert(dom.every(e=>e.code),'every source key has native DOM translation');
    const captured=await evaluate(`(() => {
      for(const event of ${JSON.stringify(dom)}) window.dispatchEvent(new KeyboardEvent(event.type,{code:event.code,bubbles:true,cancelable:true}));
      return [...window.fixtureClient.keyboard.packet()];
    })()`);
    assert.deepEqual(captured,packet.events.flat(),'browser forwards original ordered events only');
    const fallback=packet.name==='IDDT-things-stage';
    if(!packet.render){
      await evaluate(`(async()=>{const c=window.fixtureClient,e=c.keyboard.packet();await c.transactions.nextEvents(e,{draw:false});c.keyboard.acknowledge(e.length);return true;})()`);
    }else if(fallback){
      await evaluate(`(async()=>{const c=window.fixtureClient;c.loop.running=false;try{await c.nextFrame({disconnect:true});}finally{c.loop.running=true;}return true;})()`);
    }else{
      await evaluate('(async()=>{await window.__nextInputTick();return true;})()');
    }
    const seq=initialSequence+packet.tic;
    assert.equal(Number(BigInt(await rpc('eth_call',[{to:config.address,data:signature('inputSeq()')},'latest']))),seq);
    await comparePlayer(packet.tic);
    if(!packet.render)continue;
    const record=await until(()=>evaluate(`(() => {
      const p=window.__transportProof;if(p.errors.length)throw Error(p.errors.join(' | '));
      if(p.frames.at(-1)?.inputSeq!==${seq})return false;
      const canvas=document.querySelector('#frame'),rgba=canvas.getContext('2d').getImageData(0,0,320,200).data;
      return {frame:p.frames.at(-1),pixels:p.latestPixelsHex,palette:p.latestPalette,rgba:[...rgba]};
    })()`),'Canvas input '+packet.tic);
    const mined=await rpc('eth_getTransactionReceipt',[record.frame.transactionHash]);assert.equal(mined.status,'0x1');
    const frame=decodeFrame(mined.logs.find(l=>l.topics[0]===FRAME_TOPIC));
    const expected=await readFile(resolve(nativePath,`frame-${String(packet.tic).padStart(6,'0')}.bin`));
    const rgb=await readFile(resolve(nativePath,`palette-${String(packet.tic).padStart(6,'0')}.bin`));
    assert.equal(Buffer.compare(Buffer.from(frame.pixels),expected),0,'all native EVM indexes');
    assert.equal(record.pixels,expected.toString('hex'),'all browser indexed pixels');
    assert.equal(record.palette.rgbHex,rgb.toString('hex'),'all native gamma/palette bytes');
    assert.equal(Buffer.compare(Buffer.from(record.rgba),Buffer.from(expandPalette(frame,rgb))),0,'all Canvas RGBA pixels');
    report.frames.push({tic:packet.tic,name:packet.name,events:packet.events,inputSeq:seq,frameId:record.frame.frameId,
      source:record.frame.source,transactionHash:record.frame.transactionHash,gas:Number(BigInt(mined.gasUsed)),
      pixelSha256:sha(expected),rgbaSha256:sha(Buffer.from(record.rgba)),paletteSha256:sha(rgb),
      all64000NativePixelsExact:true,allCanvasPixelsExact:true,nativeFieldsExact:14});
    if(['god-completion','open-map','IDDT-things-stage','pending-warp-keeps-current-level'].includes(packet.name)){
      const screenshot=await command('Page.captureScreenshot',{format:'png'});await mkdir(dirname(prefix),{recursive:true});
      await writeFile(prefix+'-tic'+packet.tic+'.png',Buffer.from(screenshot.data,'base64'));
    }
    console.log('PASS Chrome raw input',packet.tic,packet.name,'native/receipt/Canvas exact');
  }
  const proof=await evaluate('window.__transportProof');assert(proof.fallbackVerified);assert(proof.duplicates>=2);
  report.fallbackVerified=true;report.duplicates=proof.duplicates;report.executedTics=packets.length;
  // No keys remain held: blur stops the scheduled successor without another tic.
  await evaluate(`(() => {window.dispatchEvent(new Event('blur'));return true;})()`);
  await until(()=>evaluate('!window.fixtureClient.loop.running && !window.fixtureClient.transactions.pending'),'blur stops raw loop');
  assert.equal(Number(BigInt(await rpc('eth_call',[{to:config.address,data:signature('inputSeq()')},'latest']))),initialSequence+packets.length);
  report.blurStopsBeforeNextCommand=true;
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
