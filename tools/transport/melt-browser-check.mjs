// SPDX-License-Identifier: GPL-2.0-only
// Ordinary CREATE and real menu/gameplay transactions. Expected bytes are comparison-only.
import { readFile, writeFile, mkdir, open, mkdtemp, rm } from 'node:fs/promises';
import { spawn, execFileSync } from 'node:child_process';
import { connect } from 'node:net';
import { resolve, dirname, join } from 'node:path';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import { decodeFrame, expandPalette, FRAME_TOPIC } from '../../web/protocol.mjs';
import { decodeFramePalette, FRAME_PALETTE_TOPIC } from '../../web/ui-palette.mjs';
import { loadGasBudget } from '../execution-budget.mjs';
import { serve } from './serve.mjs';
import {tmpdir} from 'node:os';

const args = process.argv.slice(2), option = (name, fallback) => args.includes(name) ? args[args.indexOf(name)+1] : fallback;
const profileName=option('--profile','freedoom');
assert(['freedoom','ultimate','doom2'].includes(profileName));
const resourceRoot=profileName==='freedoom'?'artifacts/local/wad':`artifacts/local/${profileName}/wad`;
const port = Number(option('--port', '19121')), prefix = option('--output-prefix', `artifacts/local/browser-melt/${profileName}`);
assert(Number.isInteger(port) && port > 1024 && port < 65536 && ![18880,8088].includes(port));
const budget = loadGasBudget(), gas = budget.gasHex, url = `http://127.0.0.1:${port}`;
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const word = n => BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');
const tail = bytes => word(bytes.length) + bytes.toString('hex').padEnd(Math.ceil(bytes.length/32)*64,'0');
const json = async path => JSON.parse(await readFile(path));
const artifact = await json(profileName==='doom2'?'out/Doom2.sol/Doom2.json':'out/Doom.sol/Doom.json'), store = await json('out/ResourceStore.sol/ResourceStore.json');
const method = name => { assert(artifact.methodIdentifiers[name],name); return '0x'+artifact.methodIdentifiers[name]; };
const metadata = typeof artifact.metadata === 'string' ? JSON.parse(artifact.metadata) : artifact.metadata;
const blob = await readFile(resourceRoot+'/resources.bin'), bundle = await json(resourceRoot+'/bundle.json');
assert.equal(sha(blob),bundle.blobSha256);
const directory=Buffer.alloc(bundle.lumps.length*16);
bundle.lumps.forEach((l,i)=>{Buffer.from(l.nameHex,'hex').copy(directory,i*16);directory.writeUInt32LE(l.offset,i*16+8);directory.writeUInt32LE(l.length,i*16+12)});
const report = { kind:'production-browser-evm-melt',profile:profileName, pass:false, startedUtc:new Date().toISOString(),
  executionBudget:budget, compiler:{version:metadata.compiler.version,settings:metadata.settings},
  resourceIdentity:bundle.resourceIdentity, sourceHashes:{}, operations:[], frames:[], inputs:[], rollbacks:[], selections:[] };
await mkdir(dirname(prefix),{recursive:true});
let node, log, id=0, driver, other, httpServer, priorConfig, priorPalette, browser, chromeProfile, socket;
const sleep = ms => new Promise(done => setTimeout(done,ms));
async function rpc(name,params=[]) {
  const response = await fetch(url,{method:'POST',headers:{'content-type':'application/json'},
    body:JSON.stringify({jsonrpc:'2.0',id:++id,method:name,params}),signal:AbortSignal.timeout(300000)});
  assert(response.ok); const data = await response.json();
  if(data.error) throw Object.assign(Error(name+JSON.stringify(data.error)),{rpcError:data.error});
  return data.result;
}
async function until(check,label) { const end=Date.now()+300000; while(Date.now()<end) { const value=await check();if(value)return value;await sleep(20); } throw Error('Timeout '+label); }
async function transaction(data,to,status='0x1',from=driver,transactionGas=gas) {
  const start=performance.now(), hash=await rpc('eth_sendTransaction',[{from,data,gas:transactionGas,...(to?{to}:{})}]);
  const receipt=await until(()=>rpc('eth_getTransactionReceipt',[hash]),'receipt');
  if(receipt.status!==status) { try { await rpc('eth_call',[{from,to,data,gas},'latest']); } catch(error) { report.failedTransaction={hash,error:error.rpcError};console.error(report.failedTransaction); } }
  assert.equal(receipt.status,status,hash+' gas '+BigInt(receipt.gasUsed));
  return {receipt,gas:Number(BigInt(receipt.gasUsed)),milliseconds:performance.now()-start};
}
const call = (address,data) => rpc('eth_call',[{from:driver,to:address,data,gas},'latest']);
const words = data => data.slice(2).match(/.{64}/g).map(n=>Number(BigInt.asIntN(256,BigInt('0x'+n))));
const menu = async address => words(await call(address,method('menuStatus()')));
const game = async address => words(await call(address,method('gameStatus()')));
const episode = async address => words(await call(address,method('episodeStatus()')));
const view = async address => words(await call(address,method('playerView()')));
const counters = new Map();
async function frame(result,label,expected) {
  const logs=result.receipt.logs.filter(log=>log.topics[0]===FRAME_TOPIC);assert.equal(logs.length,1);
  const f=decodeFrame(logs[0]), pal=decodeFramePalette(result.receipt.logs.find(log=>log.topics[0]===FRAME_PALETTE_TOPIC),f);
  assert.equal(f.pixels.length,64000);if(expected)assert.equal(sha(f.pixels),sha(expected),label+' native indexes');
  const path=`${prefix}-frame-${report.frames.length}.pixels`;await writeFile(path,f.pixels);
  report.frames.push({label,transaction:result.receipt.transactionHash,inputSeq:f.inputSeq,frameId:String(f.frameId),
    pixelSha256:sha(f.pixels),paletteSha256:sha(pal.rgb),palette:pal.palette,nativeExact:!!expected,pixelsPath:path,gas:result.gas,milliseconds:result.milliseconds});
  await writeFile(prefix+'.json',JSON.stringify(report,null,2)+'\n');return f;
}
async function events(address,packet=[],draw=true,label='keyboard',expected) {
  const sequence=(counters.get(address)??Number(BigInt(await call(address,method('inputSeq()')))))+1;
  const bytes=Buffer.from(packet.flat()), result=await transaction(method(draw?'stepEventsAndRender(bytes,uint32)':'stepEvents(bytes,uint32)')+word(64)+word(sequence)+tail(bytes),address);
  counters.set(address,sequence);report.inputs.push({address,sequence,events:packet,draw,transaction:result.receipt.transactionHash,gas:result.gas,milliseconds:result.milliseconds});
  if(draw)await frame(result,label,expected);else assert.equal(result.receipt.logs.length,0);return result;
}
const key = n => [[0,n],[1,n]];
const text = value => [...value].flatMap(c=>key(c.charCodeAt(0)));
async function rollback(address,data,label,from=driver,transactionGas=gas) {
  const before=await rpc('eth_getProof',[address,[],'latest']);const result=await transaction(data,address,'0x0',from,transactionGas);
  const after=await rpc('eth_getProof',[address,[],'latest']);assert.equal(after.storageHash,before.storageHash);assert.equal(result.receipt.logs.length,0);
  report.rollbacks.push({label,transaction:result.receipt.transactionHash,storageRoot:before.storageHash,gasLimit:Number(BigInt(transactionGas)),allStorageUnchanged:true,noLogs:true});
}
const configuration = address => ({rpcUrl:url,wsUrl:url.replace('http','ws'),address,driver,
  rendererKind:'doom-world-view',gameplay:true,productionUI:true,rawKeyboard:true,episodeMode:true,menuMode:true,
  uiFullscreen:false,deploymentBlock:'0x0',paletteUrl:'/palette.local.json',paletteKind:'wad',resourceIdentity:bundle.resourceIdentity,gasLimit:budget.gasLimit});
try {
  for(const [path,identity] of Object.entries(metadata.sources)) {
    const bytes=await readFile(path);assert.equal(execFileSync(resolve('.toolchain/bin/cast'),['keccak'],{input:'0x'+bytes.toString('hex'),encoding:'utf8',maxBuffer:1048576}).trim(),identity.keccak256,'source drift '+path);
    report.sourceHashes[path]=sha(bytes);
  }
  for(const path of ['web/menu-app.mjs','web/menu-input.mjs','web/wipe-input.mjs','web/input-loop.mjs','web/protocol.mjs','tools/transport/melt-browser-check.mjs'])report.sourceHashes[path]=sha(await readFile(path));
  await new Promise((done,fail)=>{const s=connect({host:'127.0.0.1',port});s.once('connect',()=>{s.destroy();fail(Error('Occupied port'));});s.once('error',e=>e.code==='ECONNREFUSED'?done():fail(e));});
  log=await open(prefix+'.anvil.log','w');
  const nodeArgs=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--disable-block-gas-limit','--no-request-size-limit','--memory-limit','1073741824','--silent'];
  node=spawn(resolve('.toolchain/bin/anvil'),nodeArgs,{stdio:['ignore',log.fd,log.fd]});
  await until(async()=>{if(node.exitCode!==null)throw Error('Anvil exited');try{return await rpc('web3_clientVersion');}catch{return false;}},'Anvil');
  await rpc('anvil_setBlockGasLimit',[gas]);await rpc('evm_mine');[driver,other]=await rpc('eth_accounts');report.runtime={port,args:nodeArgs,client:await rpc('web3_clientVersion')};
  const addresses=[],receipts=[];
  for(let p=0;p<blob.length;p+=16384){const bytes=blob.subarray(p,p+16384),r=await transaction(store.bytecode.object+word(32)+tail(bytes));
    assert.equal(await rpc('eth_getCode',[r.receipt.contractAddress,'latest']),'0x00'+bytes.toString('hex'));addresses.push(r.receipt.contractAddress);receipts.push({hash:r.receipt.transactionHash,gas:r.gas});
    if(addresses.length%400===0)console.log('Verified CREATE resources',addresses.length);
  }
  report.resources={chunks:addresses.length,allRuntimeBytesExact:true,totalGas:receipts.reduce((n,r)=>n+r.gas,0),receiptsSha256:sha(JSON.stringify(receipts))};
  const array=word(addresses.length)+addresses.map(a=>a.slice(2).padStart(64,'0')).join('');
  const deployed=await transaction(artifact.bytecode.object+word(64)+word(64+array.length/2)+array+tail(directory));const address=deployed.receipt.contractAddress;
  const runtime=Buffer.from(artifact.deployedBytecode.object.slice(2),'hex');
  for(const spans of Object.values(artifact.deployedBytecode.immutableReferences))for(const span of spans)Buffer.from(word(driver),'hex').copy(runtime,span.start);
  assert.equal(await rpc('eth_getCode',[address,'latest']),'0x'+runtime.toString('hex'));
  report.deployment={address,hash:deployed.receipt.transactionHash,gas:deployed.gas,runtimeBytes:runtime.length,runtimeSha256:sha(runtime)};
  const initializer=profileName==='doom2'?'initializeMenuWithMemoryProfile(bool,uint8)':'initializeMenuWithPolicy(bool,uint8)';
  await transaction(method(initializer)+word(0)+word(3),address);
  const config=configuration(address);config.deploymentBlock=deployed.receipt.blockNumber;config.gameName=profileName;
  priorConfig=await readFile('web/config.local.json').catch(()=>null);priorPalette=await readFile('web/palette.local.json').catch(()=>null);
  await writeFile('web/config.local.json',JSON.stringify(config,null,2)+'\n');await writeFile('web/palette.local.json',await readFile(resourceRoot+'/palette.json'));
  httpServer=await serve(0);chromeProfile=await mkdtemp(join(tmpdir(),'doom-melt-chrome-'));
  browser=spawn(process.env.CHROME_BIN??'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',['--headless=new','--no-first-run','--no-default-browser-check','--disable-background-networking','--remote-debugging-port=0',`--user-data-dir=${chromeProfile}`,'about:blank'],{stdio:['ignore','ignore','pipe']});
  let stderr='';browser.stderr.on('data',b=>stderr+=b);browser.on('error',e=>stderr+=e.message);
  const debug=await until(async()=>{if(browser.exitCode!==null)throw Error(stderr);try{return(await readFile(join(chromeProfile,'DevToolsActivePort'),'utf8')).split('\n')[0];}catch{return false;}},'Chrome');
  const tabs=await(await fetch(`http://127.0.0.1:${debug}/json/list`)).json();socket=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);
  await new Promise((done,fail)=>{socket.addEventListener('open',done,{once:true});socket.addEventListener('error',fail,{once:true});});
  let cdpId=0;const pending=new Map();socket.addEventListener('message',e=>{const r=JSON.parse(e.data),p=pending.get(r.id);if(p){pending.delete(r.id);clearTimeout(p.timer);r.error?p.reject(Error(JSON.stringify(r.error))):p.resolve(r.result);}});
  const command=(method,params={})=>new Promise((resolve,reject)=>{const id=++cdpId;pending.set(id,{resolve,reject,timer:setTimeout(()=>reject(Error('CDP timeout '+method)),300000)});socket.send(JSON.stringify({id,method,params}));});
  const evaluate=async expression=>{const r=await command('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(r.exceptionDetails.exception?.description??r.exceptionDetails.text);return r.result.value;};
  await command('Page.enable');
  // Control only the timer. Original DOM input, transaction controller and Canvas are intact.
  await command('Page.addScriptToEvaluateOnNewDocument',{source:`Object.defineProperty(window,'fixtureClient',{configurable:true,get(){return this.__meltClient},set(c){this.__meltClient=c;c.loop.schedule=fn=>{window.__tick=fn;return 1};c.loop.cancel=()=>{window.__tick=null};}});`});
  const ready=(oldDocument)=>until(async()=>{if(oldDocument===await evaluate('performance.timeOrigin'))return false;const p=await evaluate('window.__transportProof');if(p?.errors?.length)throw Error(p.errors.join('\n'));return p?.ready&&await evaluate('!window.fixtureClient.transactions.pending&&!window.fixtureClient.loop.starting');},'browser ready');
  await command('Page.navigate',{url:`http://127.0.0.1:${httpServer.address().port}/`});await ready();
  const wipe=()=>call(address,method('wipeStatus()')).then(words);
  assert.deepEqual((await wipe()).slice(0,3),[1,1,0]);report.browserAutoOptIn=true;
  async function canvas(label,expectedHash){
    const p=await evaluate('window.__transportProof');assert.deepEqual(p.errors,[]);const last=p.frames.at(-1),r=await rpc('eth_getTransactionReceipt',[last.transactionHash]);
    const f=decodeFrame(r.logs.find(l=>l.topics[0]===FRAME_TOPIC)),pal=decodeFramePalette(r.logs.find(l=>l.topics[0]===FRAME_PALETTE_TOPIC),f);
    assert.equal(p.latestPixelsHex,Buffer.from(f.pixels).toString('hex'));assert.equal(p.latestPalette.rgbHex,Buffer.from(pal.rgb).toString('hex'));
    const rgba=await evaluate(`(async()=>{const b=document.querySelector('#frame').getContext('2d').getImageData(0,0,320,200).data;return [...new Uint8Array(await crypto.subtle.digest('SHA-256',b))].map(n=>n.toString(16).padStart(2,'0')).join('')})()`);
    assert.equal(rgba,sha(expandPalette(f,pal.rgb)));if(expectedHash)assert.equal(sha(f.pixels),expectedHash);
    report.frames.push({label,hash:r.transactionHash,frameId:String(f.frameId),sequence:f.inputSeq,indexedSha256:sha(f.pixels),paletteSha256:sha(pal.rgb),palette:pal.palette,rgbaSha256:rgba,allCanvasPixelsExact:true,gas:Number(BigInt(r.gasUsed))});
    await writeFile(prefix+'.json',JSON.stringify(report,null,2)+'\n');return f;
  }
  const sequence=()=>call(address,method('inputSeq()')).then(d=>Number(BigInt(d)));
  async function tick(){const start=performance.now();await evaluate('(async()=>{await window.__tick();return true})()');await until(()=>evaluate('!window.fixtureClient.transactions.pending'),'tick settled');
    const accepted=await sequence();await until(()=>evaluate(`window.__transportProof.frames.at(-1)?.inputSeq===${accepted}`),'Canvas accepted sequence');return performance.now()-start;}
  async function keys(codes){await evaluate(`for(const code of ${JSON.stringify(codes)}){window.dispatchEvent(new KeyboardEvent('keydown',{code,bubbles:true,cancelable:true}));window.dispatchEvent(new KeyboardEvent('keyup',{code,bubbles:true,cancelable:true}));}true`);return tick();}
  await canvas('Automatic title menu');await keys(['Enter']);await canvas('New Game selection');
  if(profileName!=='doom2'){await keys(['Enter']);await canvas('Original skill selection');}
  const startFrame=await canvas('Pre-wipe start screen');const startPath=prefix+'-start.indexed8';await writeFile(startPath,startFrame.pixels);
  const totalStart=performance.now(),firstMs=await keys(['Enter']);const first=await canvas('First EVM melt from real menu New Game');
  assert.equal((await wipe())[2],1);const firstSequence=first.inputSeq;
  const frozen={game:await call(address,method('gameStatus()')),view:await call(address,method('playerView()')),episode:await call(address,method('episodeStatus()')),ui:await call(address,method('uiStatus()'))};
  const firstWipeGas=report.frames.at(-1).gas;const seed=(words(frozen.ui)[7]-64+256)&255;
  await rollback(address,method('stepWipe(uint32)')+word(firstSequence),'duplicate presentation request');
  await rollback(address,method('stepEventsAndRender(bytes,uint32)')+word(64)+word(firstSequence+1)+tail(Buffer.from([0,119])),'racing player input');
  await rollback(address,method('setUIFullscreen(bool)')+word(1),'palette/UI control during wipe');
  await rollback(address,method('saveGame(uint8,bytes,uint64,uint32)')+word(0)+word(128)+word(0)+word(firstSequence+1)+tail(Buffer.from('MELT')),'snapshot save during wipe');
  await rollback(address,method('loadGame(uint8,uint64,uint32)')+word(0)+word(0)+word(firstSequence+1),'snapshot load during wipe');
  await rollback(address,method('restartEpisode(uint32)')+word(firstSequence+1),'restart during wipe');
  await rollback(address,method('stepWipe(uint32)')+word(firstSequence+1),'wrong driver',other);
  await rollback(address,method('stepWipe(uint32)')+word(firstSequence+1),'underfunded presentation rollback',driver,'0xf4240');
  await evaluate("document.querySelector('#wipe-notice button').click();true");assert.equal(await evaluate('window.fixtureClient.loop.running'),false);
  const pausedSequence=await sequence();await sleep(100);assert.equal(await sequence(),pausedSequence);report.explicitPauseNoWorldTics=true;
  await evaluate("document.querySelector('#wipe-notice button:last-child').click();true");await until(()=>evaluate('!!window.__tick&&!window.fixtureClient.loop.starting'),'wipe resume');
  // Lose the actual mined send response. Reload reconciles sender/nonce, no second send.
  await evaluate(`const t=window.fixtureClient.transactions,real=t.rpc;let injected=false;t.rpc=async(...a)=>{const r=await real(...a);if(a[0]==='eth_sendTransaction'&&!injected){injected=true;await t.waitReceipt(real,r);throw Error('Injected lost wipe response')}return r};true`);
  await tick();assert.equal(await sequence(),pausedSequence+1);assert.equal(await evaluate('window.fixtureClient.transactions.canSend'),false);
  const oldDocument=await evaluate('performance.timeOrigin');await command('Page.reload');await ready(oldDocument);assert.equal(await sequence(),pausedSequence+2); // One genuine startup continuation.
  assert.equal((await wipe())[2],1);report.reloadRecoveredWithoutDuplicate=true;await canvas('Reload resumed exact persistent wipe');
  const pendingSequence=await sequence();await rpc('evm_setAutomine',[false]);
  await evaluate('window.__tick();true');
  await until(()=>evaluate('!!window.fixtureClient.transactions.presentationSend.pending?.hash'),'known unmined wipe');
  const pendingHash=await evaluate('window.fixtureClient.transactions.presentationSend.pending.hash');
  assert.equal(await rpc('eth_getTransactionReceipt',[pendingHash]),null);
  const oldPendingDocument=await evaluate('performance.timeOrigin');await command('Page.reload');
  await until(async()=>{if(oldPendingDocument===await evaluate('performance.timeOrigin'))return false;return await evaluate('window.__transportProof?.errors.some(e=>e.includes("outcome unknown"))');},'reload refuses unmined retry');
  assert.equal(await sequence(),pendingSequence);const accountPending=await rpc('eth_getTransactionCount',[driver,'pending']);
  await sleep(100);assert.equal(await rpc('eth_getTransactionCount',[driver,'pending']),accountPending);
  await rpc('evm_setAutomine',[true]);await rpc('evm_mine');
  const minedPending=await until(()=>rpc('eth_getTransactionReceipt',[pendingHash]),'mine original pending wipe');assert.equal(minedPending.status,'0x1');
  const oldRecoveryDocument=await evaluate('performance.timeOrigin');await command('Page.reload');await ready(oldRecoveryDocument);
  assert.equal(await sequence(),pendingSequence+2);report.knownUnminedReloadNoRetry=true;await canvas('Known unmined wipe recovered after original mining');
  const steps=[];while((await wipe())[2]){
    const before=await sequence(),milliseconds=await tick();const f=await canvas('EVM melt presentation step');assert.equal(f.inputSeq,before+1);
    for(const [key,signature] of [['game','gameStatus()'],['view','playerView()'],['episode','episodeStatus()'],['ui','uiStatus()']])assert.equal(await call(address,method(signature)),frozen[key],key+' frozen through wipe');
    steps.push({milliseconds,gas:report.frames.at(-1).gas});
  }
  const end=await canvas('Exact final EVM endpoint');const endPath=prefix+'-end.indexed8';await writeFile(endPath,end.pixels);
  const logs=await rpc('eth_getLogs',[{address,fromBlock:deployed.receipt.blockNumber,toBlock:'latest',topics:[FRAME_TOPIC]}]);
  const frames=logs.map(decodeFrame).filter(f=>f.inputSeq>=firstSequence&&f.inputSeq<=end.inputSeq);
  const nativeDir=prefix+'-native';execFileSync('python3',['tools/reference/full_videos/wipe-frames.py','--start',startPath,'--end',endPath,'--seed',String(seed),'--output',nativeDir]);
  const native=await json(nativeDir+'/manifest.json');assert.equal(frames.length,native.frames.length);
  for(let i=0;i<frames.length;i++)assert.equal(sha(frames[i].pixels),native.frames[i].sha256,'native original step '+(i+1));
  let totalGas=0;for(const f of frames)totalGas+=Number(BigInt((await rpc('eth_getTransactionReceipt',[f.log.transactionHash])).gasUsed));
  report.wipe={steps:frames.length,seed,allNativeFramesExact:true,nativeManifestSha256:sha(await readFile(nativeDir+'/manifest.json')),totalGas,totalWallMs:performance.now()-totalStart,firstTransactionMs:firstMs,continuationSteps:steps,worldAndUITicsFrozen:true,finalExact:true};
  await evaluate("window.dispatchEvent(new KeyboardEvent('keydown',{code:'ArrowUp',bubbles:true,cancelable:true}));true");await tick();const moving=await canvas('Normal gameplay resumes');assert.notEqual(await call(address,method('playerView()')),frozen.view);assert.equal((await wipe())[2],0);
  await evaluate("window.dispatchEvent(new KeyboardEvent('keyup',{code:'ArrowUp',bubbles:true,cancelable:true}));true");await tick();
  await keys(['Escape']);await canvas('Gameplay menu opens without wipe');assert.equal((await wipe())[2],0);
  await keys(['Escape']);await canvas('Gameplay menu closes without wipe');assert.equal((await wipe())[2],0);
  report.normalGameplayAndMenu=true;
  // A second real menu New Game forces a same-GS_LEVEL wipe; uninterrupted timing.
  await keys(['Escape','Enter']);if(profileName!=='doom2')await keys(['Enter']);
  const restartStart=await canvas('Menu before same-state forced New Game');
  const restartWallStart=performance.now(),restartFirstMs=await keys(['Enter']);
  const restartFirst=await canvas('Forced same-state EVM wipe');assert.equal((await wipe())[2],1);
  const restartSteps=[{milliseconds:restartFirstMs,gas:report.frames.at(-1).gas}];
  const restartFrozen=await call(address,method('gameStatus()'));
  while((await wipe())[2]){const milliseconds=await tick();await canvas('Uninterrupted forced wipe');assert.equal(await call(address,method('gameStatus()')),restartFrozen);restartSteps.push({milliseconds,gas:report.frames.at(-1).gas});}
  const restartWallMs=performance.now()-restartWallStart,restartEnd=await canvas('Forced wipe exact endpoint');
  const restartSeed=(words(await call(address,method('uiStatus()')))[7]-64+256)&255;
  const restartStartPath=prefix+'-restart-start.indexed8',restartEndPath=prefix+'-restart-end.indexed8';await writeFile(restartStartPath,restartStart.pixels);await writeFile(restartEndPath,restartEnd.pixels);
  const restartNativeDir=prefix+'-restart-native';execFileSync('python3',['tools/reference/full_videos/wipe-frames.py','--start',restartStartPath,'--end',restartEndPath,'--seed',String(restartSeed),'--output',restartNativeDir]);
  const restartNative=await json(restartNativeDir+'/manifest.json'),restartLogs=await rpc('eth_getLogs',[{address,fromBlock:deployed.receipt.blockNumber,toBlock:'latest',topics:[FRAME_TOPIC]}]);
  const restartFrames=restartLogs.map(decodeFrame).filter(f=>f.inputSeq>=restartFirst.inputSeq&&f.inputSeq<=restartEnd.inputSeq);assert.equal(restartFrames.length,restartNative.frames.length);
  for(let i=0;i<restartFrames.length;i++)assert.equal(sha(restartFrames[i].pixels),restartNative.frames[i].sha256,'forced native step '+(i+1));
  report.uninterruptedWipe={steps:restartFrames.length,seed:restartSeed,totalWallMs:restartWallMs,totalGas:restartSteps.reduce((n,s)=>n+s.gas,0),transactions:restartSteps,allNativeFramesExact:true,worldFrozen:true,nativeManifestSha256:sha(await readFile(restartNativeDir+'/manifest.json'))};
  // Same-source, opt-out deployment provides a measured first-frame baseline.
  const legacyDeploy=await transaction(artifact.bytecode.object+word(64)+word(64+array.length/2)+array+tail(directory));const legacyAddress=legacyDeploy.receipt.contractAddress;
  await transaction(method(initializer)+word(0)+word(3),legacyAddress);
  let legacySeq=0;const legacyEvents=packet=>transaction(method('stepEventsAndRender(bytes,uint32)')+word(64)+word(++legacySeq)+tail(Buffer.from(packet)),legacyAddress);
  await legacyEvents([]);await legacyEvents([0,13,1,13]);if(profileName!=='doom2')await legacyEvents([0,13,1,13]);
  const legacyStart=await legacyEvents([0,13,1,13]);const legacyFrame=decodeFrame(legacyStart.receipt.logs.find(l=>l.topics[0]===FRAME_TOPIC));
  assert.equal(sha(legacyFrame.pixels),sha(end.pixels),'opt-out and wiped endpoints identical');
  assert.deepEqual(words(await call(legacyAddress,method('wipeStatus()'))).slice(0,3),[1,0,0]);
  report.costComparison={firstWipeNewGameGas:firstWipeGas,legacyNewGameGas:legacyStart.gas,firstFrameDeltaGas:firstWipeGas-legacyStart.gas,legacyNewGameWallMs:legacyStart.milliseconds,presentationOnlyGas:totalGas-firstWipeGas,firstEndpointExactlyMatchesLegacy:true};
  for(const [path,digest] of Object.entries(report.sourceHashes))assert.equal(sha(await readFile(path)),digest,'source changed during verification '+path);
  report.browser=await command('Browser.getVersion');report.pass=true;
  const image=await command('Page.captureScreenshot',{format:'png'});await writeFile(prefix+'.png',Buffer.from(image.data,'base64'));
  console.log('PASS',profileName,JSON.stringify({steps:frames.length,totalGas,seconds:report.wipe.totalWallMs/1000}));
} catch(error){report.error=error.stack;process.exitCode=1;console.error(error.stack);
  if(socket?.readyState===1){let id=987654;const result=await new Promise(done=>{const timer=setTimeout(()=>done(null),2000);const listen=e=>{const r=JSON.parse(e.data);if(r.id===id){clearTimeout(timer);socket.removeEventListener('message',listen);done(r.result)}};socket.addEventListener('message',listen);socket.send(JSON.stringify({id,method:'Runtime.evaluate',params:{expression:'({errors:window.__transportProof?.errors,loop:window.fixtureClient&&{running:window.fixtureClient.loop.running,starting:window.fixtureClient.loop.starting,epoch:window.fixtureClient.loop.epoch},transactions:window.fixtureClient&&{sequence:window.fixtureClient.transactions.sequence,busy:window.fixtureClient.transactions.busy,uncertain:window.fixtureClient.transactions.uncertain,wipe:window.fixtureClient.transactions.wipe},journal:window.fixtureClient?.transactions.presentationSend?.pending})',returnByValue:true}}))});report.browserFailureState=result?.result?.value;console.error(report.browserFailureState);}
}
finally {
  socket?.close();
  for(const child of [browser,node])if(child?.pid&&child.exitCode===null&&child.signalCode===null)await new Promise(done=>{child.once('exit',done);child.kill('SIGTERM');setTimeout(()=>{if(child.exitCode===null)child.kill('SIGKILL');},1500).unref();});
  if(httpServer)await new Promise(done=>httpServer.close(done));if(chromeProfile)await rm(chromeProfile,{recursive:true,force:true});await log?.close();
  if(priorConfig)await writeFile('web/config.local.json',priorConfig);else await rm('web/config.local.json',{force:true});
  if(priorPalette)await writeFile('web/palette.local.json',priorPalette);else await rm('web/palette.local.json',{force:true});
  report.endedUtc=new Date().toISOString();report.stoppedOwnedRuntimes=true;await writeFile(prefix+'.json',JSON.stringify(report,null,2)+'\n');
}
