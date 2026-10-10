// SPDX-License-Identifier: GPL-2.0-only
// Ordinary CREATE and real menu/gameplay transactions. Expected bytes are comparison-only.
import { readFile, writeFile, mkdir, open } from 'node:fs/promises';
import { spawn, execFileSync } from 'node:child_process';
import { connect } from 'node:net';
import { resolve, dirname } from 'node:path';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import { decodeFrame, FRAME_TOPIC } from '../../../web/protocol.mjs';
import { decodeFramePalette, FRAME_PALETTE_TOPIC } from '../../../web/ui-palette.mjs';
import { loadGasBudget } from '../../execution-budget.mjs';
import { serve } from '../../transport/serve.mjs';

const args = process.argv.slice(2), option = (name, fallback) => args.includes(name) ? args[args.indexOf(name)+1] : fallback;
const port = Number(option('--port', '18781')), prefix = option('--output-prefix', 'artifacts/phase4/menu/evm');
assert(Number.isInteger(port) && port > 1024 && port < 65536 && ![18880,8088].includes(port));
const budget = loadGasBudget(), gas = budget.gasHex, url = `http://127.0.0.1:${port}`;
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const word = n => BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');
const tail = bytes => word(bytes.length) + bytes.toString('hex').padEnd(Math.ceil(bytes.length/32)*64,'0');
const json = async path => JSON.parse(await readFile(path));
const artifact = await json('out/Doom.sol/Doom.json'), store = await json('out/ResourceStore.sol/ResourceStore.json');
const method = name => { assert(artifact.methodIdentifiers[name],name); return '0x'+artifact.methodIdentifiers[name]; };
const metadata = typeof artifact.metadata === 'string' ? JSON.parse(artifact.metadata) : artifact.metadata;
const blob = await readFile('artifacts/local/wad/resources.bin'), bundle = await json('artifacts/local/wad/bundle.json');
assert.equal(sha(blob),bundle.blobSha256);
const directory = await readFile('test/fixtures/phase2_data/directory.bin');
const report = { kind:'evm-menu-production', pass:false, startedUtc:new Date().toISOString(),
  executionBudget:budget, compiler:{version:metadata.compiler.version,settings:metadata.settings},
  resourceIdentity:bundle.resourceIdentity, sourceHashes:{}, operations:[], frames:[], inputs:[], rollbacks:[], selections:[] };
await mkdir(dirname(prefix),{recursive:true});
let node, log, id=0, driver, other, httpServer, priorConfig, priorPalette;
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
  report.sourceHashes['tools/reference/menu/evm.mjs']=sha(await readFile('tools/reference/menu/evm.mjs'));
  await new Promise((done,fail)=>{const socket=connect({host:'127.0.0.1',port});socket.once('connect',()=>{socket.destroy();fail(Error('Occupied port'));});socket.once('error',error=>error.code==='ECONNREFUSED'?done():fail(error));});
  log=await open(prefix+'.anvil.log','w');
  const nodeArgs=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--disable-block-gas-limit','--no-request-size-limit','--memory-limit','1073741824','--prune-history','64','--silent'];
  node=spawn(resolve('.toolchain/bin/anvil'),nodeArgs,{stdio:['ignore',log.fd,log.fd]});
  node.on('error',error=>{report.runtimeError=error.message;});
  await until(async()=>{if(node.exitCode!==null)throw Error(await readFile(prefix+'.anvil.log','utf8'));try{return await rpc('web3_clientVersion');}catch{return false;}},'Anvil');
  await rpc('anvil_setBlockGasLimit',[gas]);await rpc('evm_mine');[driver,other]=await rpc('eth_accounts');
  report.runtime={port,args:nodeArgs,client:await rpc('web3_clientVersion')};
  const addresses=[], receipts=[];
  for(let p=0;p<blob.length;p+=16384) {
    const bytes=blob.subarray(p,p+16384),result=await transaction(store.bytecode.object+word(32)+tail(bytes));
    assert.equal(await rpc('eth_getCode',[result.receipt.contractAddress,'latest']),'0x00'+bytes.toString('hex'));
    addresses.push(result.receipt.contractAddress);receipts.push({transaction:result.receipt.transactionHash,gas:result.gas});
    if(addresses.length%300===0)console.log('Verified resource CREATE',addresses.length);
  }
  report.resources={chunks:addresses.length,allRuntimeBytesExact:true,cumulativeGas:receipts.reduce((sum,r)=>sum+r.gas,0),receiptsSha256:sha(JSON.stringify(receipts))};
  const array=word(addresses.length)+addresses.map(a=>a.slice(2).padStart(64,'0')).join('');
  const constructor=word(64)+word(64+array.length/2)+array+tail(directory);
  async function deploy() {
    const result=await transaction(artifact.bytecode.object+constructor), address=result.receipt.contractAddress;
    const runtime=Buffer.from(artifact.deployedBytecode.object.slice(2),'hex');
    for(const spans of Object.values(artifact.deployedBytecode.immutableReferences))for(const span of spans)Buffer.from(word(driver),'hex').copy(runtime,span.start);
    assert.equal(await rpc('eth_getCode',[address,'latest']),'0x'+runtime.toString('hex'));
    report.operations.push({operation:'CREATE Doom',address,transaction:result.receipt.transactionHash,gas:result.gas,runtimeBytes:runtime.length,runtimeSha256:sha(runtime)});
    return address;
  }
  const address=await deploy();
  if(args.includes('--play')) {
    priorConfig=await readFile('web/config.local.json').catch(()=>null);priorPalette=await readFile('web/palette.local.json').catch(()=>null);
    await writeFile('web/config.local.json',JSON.stringify(configuration(address),null,2)+'\n');
    await writeFile('web/palette.local.json',await readFile('artifacts/local/wad/palette.json'));
    const httpPort=Number(option('--http-port','18782'));assert(![18880,8088,port].includes(httpPort));httpServer=await serve(httpPort);
    console.log(`EVM menu ready: http://127.0.0.1:${httpPort}. Use arrows, Enter, Escape. Ctrl-C stops only this launcher's runtimes.`);
    report.pass=true;await new Promise(done=>{process.once('SIGINT',done);process.once('SIGTERM',done);});
  } else {
    await rollback(address,method('initializeMenu(bool)')+word(0),'menu driver authentication',other);
    const initialized=await transaction(method('initializeMenu(bool)')+word(0),address);
    assert.equal(initialized.receipt.logs.length,0);assert.equal(await call(address,method('gameStarted()')), '0x'+word(0));
    assert.equal(await call(address,method('inputSeq()')),'0x'+word(0));
    report.operations.push({operation:'initializeMenu',gas:initialized.gas,transaction:initialized.receipt.transactionHash,noGameStartup:true,noFrame:true});
    await events(address,[],true,'Initial EVM main menu');
    assert.deepEqual((await menu(address)).slice(0,4),[1,1,0,0]);
    await rollback(address,method('initializeMenu(bool)')+word(0),'duplicate menu initialization');
    await rollback(address,method('initializeEpisode(int32,int32,bool)')+word(1)+word(2)+word(0),'legacy initializer cannot replace active menu');
    await rollback(address,method('stepEventsAndRender(bytes,uint32)')+word(64)+word(99)+tail(Buffer.from([])),'bad menu sequence');
    const sequence=(counters.get(address)??0)+1;
    await rollback(address,method('stepEventsAndRender(bytes,uint32)')+word(64)+word(sequence)+tail(Buffer.from([0,175,2,119])),'invalid event after navigation');
    await rollback(address,method('stepEventsAndRender(bytes,uint32)')+word(64)+word(sequence)+tail(Buffer.from([0])),'odd event bytes');
    await rollback(address,method('stepEventsAndRender(bytes,uint32)')+word(64)+word(sequence)+tail(Buffer.alloc(130)),'oversized packet');
    await events(address,key(13),true,'New Game episode selection');
    await events(address,key(13),true,'Original skill default',await readFile('test/fixtures/evm_menu/skill-2.bin'));
    await events(address,key(13),true,'New Game E1M1');
    const previousFirstFrame=await readFile('artifacts/phase4/menu/checkpoint-c-attempt2-frame-3.pixels');
    assert.equal(report.frames.at(-1).pixelSha256,sha(previousFirstFrame),'authenticated context reuse preserves previous first gameplay Frame');
    report.firstGameplayFrameMatchesCheckpointC=true;
    assert.deepEqual((await episode(address)).slice(0,5),[1,2,0,0,0]);assert.deepEqual((await game(address)).slice(1),[1,100,0,1]);
    // Menu opening stops a previously held movement/fire/weapon state. Its
    // redraws and unknown keys never advance gameplay or any cheat recognizer.
    await events(address,[[0,119],[0,157],[0,49]],false,'held gameplay inputs');
    await events(address,key(27),true,'Escape opens gameplay menu');
    const frozen={game:await game(address),view:await view(address),cheat:await call(address,method('cheatStatus()')),ui:await call(address,method('uiStatus()'))};
    const cursor=await call(address,method('cheatSequence(uint8)')+word(0));
    for(let i=0;i<3;++i)await events(address,i===0?text('iddqd').concat(key(157),key(49)):[],true,'Menu pause redraw '+i);
    assert.deepEqual(await game(address),frozen.game);assert.deepEqual(await view(address),frozen.view);
    assert.equal(await call(address,method('cheatStatus()')),frozen.cheat);assert.equal(await call(address,method('uiStatus()')),frozen.ui);
    assert.equal(await call(address,method('cheatSequence(uint8)')+word(0)),cursor);assert.equal(words(frozen.cheat).at(-1),0);
    await events(address,key(27),true,'Escape resumes cached gameplay');assert.deepEqual(await game(address),frozen.game);
    await events(address,[],true,'Ordinary gameplay resumes');assert.equal((await game(address))[1],frozen.game[1]+1);
    // Change inventory through original cheat input, then prove direct selection
    // reinitializes it through deferred G_DoNewGame, never G_ExitLevel/WI_Start.
    await events(address,text('idkfa'),false,'mutate inventory before new-game selection');
    const enriched=await call(address,method('playerInventory()'));
    for(let map=1;map<=9;++map) {
      await events(address,key(27),false,'open Select Level');
      await events(address,key(115).concat(key(13)),true,'SELECT LEVEL');
      assert.equal((await menu(address))[2],3);
      await events(address,key(48+map).concat(key(13)),true,'E1M'+map+' skill selection');
      await events(address,key(13),true,'Direct new game E1M'+map);
      const status=await episode(address), state=await game(address), inventory=words(await call(address,method('playerInventory()')));
      assert.deepEqual(status.slice(0,5),[map,2,0,0,0]);assert.deepEqual(state.slice(1),[1,100,0,1]);
      assert.deepEqual(inventory.slice(0,8),[50,0,0,0,200,50,300,50]);
      assert.deepEqual(inventory.slice(8,14),[0,0,0,0,0,0]);assert.deepEqual(inventory.slice(14),[1,1,0,0,0,0,0,0,0]);
      assert.equal(status[7],0);assert.equal(status[8],0);assert.notEqual(await call(address,method('playerInventory()')),enriched);
      report.selections.push({map,skill:status[1],state:status[2],leveltime:state[1],freshInventory:true,noIntermission:true,inputSeq:counters.get(address)});
      console.log('PASS menu-selected E1M'+map);
    }
    // Original Nightmare confirmation cancel and accepted fresh-game semantics.
    await events(address,key(27).concat(key(110),key(13),key(13),key(110),key(13)),true,'Nightmare confirmation');
    assert.equal((await menu(address))[8],1);
    await events(address,key(110),true,'Nightmare cancellation');assert.equal((await episode(address))[1],2);
    await events(address,key(27).concat(key(110),key(13),key(13),key(110),key(13)),true,'Nightmare confirm again');
    await events(address,key(121),true,'Nightmare accepted');assert.deepEqual((await episode(address)).slice(0,4),[1,4,0,0]);
    await events(address,key(27).concat(key(110),key(13),key(13),key(104),key(13)),true,'Original easy skill');
    assert.equal((await episode(address))[1],1);
    for(const [skill,hotkey] of [[0,105],[3,117]]) {
      await events(address,key(27).concat(key(110),key(13),key(13),key(hotkey),key(13)),true,'Original skill '+skill);
      assert.equal((await episode(address))[1],skill);
    }
    // Explicit game pause remains paused through menu open/close and redraws.
    await events(address,key(255),true,'Gameplay Pause');const pauseTime=(await game(address))[1];
    await events(address,key(27),true,'Menu while explicitly paused');await events(address,[],true,'Paused menu redraw');await events(address,key(27),true,'Escape retains explicit pause');
    assert.equal((await game(address))[1],pauseTime);assert.equal((await episode(address))[4],1);
    await events(address,key(255),true,'Resume explicit pause');assert.equal((await episode(address))[4],0);
    // Accepted raw-input startup remains available on a distinct legacy instance.
    const legacy=await deploy();await transaction(method('initializeGameInput(bool)')+word(0),legacy);
    const native=await readFile('artifacts/local/menu-legacy-native/frame-000001.bin');
    await events(legacy,[[0,119],[0,182]],true,'Legacy raw-input first native frame',native);
    report.legacy={rawInitializer:true,frameABIUnchanged:true,nativeFirstFrameExact:true};
    const staticAddress=await deploy();await transaction(method('renderFrame()'),staticAddress);report.legacy.staticRenderBeforeGameplay=true;
    // Fresh heavy-map initialization uses the same menu and authenticated factory
    // as the first user selection. An OOG after menu state writes proves complete
    // atomic rollback of startup, sequence and emitted logs; retry uses the same seq.
    const heavy=await deploy();await transaction(method('initializeMenu(bool)')+word(0),heavy);
    await events(heavy,key(115).concat(key(13),key(55),key(13)),true,'Fresh E1M7 skill screen');
    const heavySeq=(counters.get(heavy)??0)+1, heavyPacket=Buffer.from(key(13).flat());
    await rollback(heavy,method('stepEventsAndRender(bytes,uint32)')+word(64)+word(heavySeq)+tail(heavyPacket),'OOG after menu writes during fresh heavy startup',driver,'0x5f5e100');
    assert.equal(await call(heavy,method('gameStarted()')),'0x'+word(0));assert.equal((await menu(heavy))[2],2);
    await events(heavy,key(13),true,'Fresh E1M7 startup after rollback');assert.deepEqual((await episode(heavy)).slice(0,4),[7,2,0,0]);
    report.freshHeavyStartup={map:7,retriedSameSequence:true,noIntermission:true};
    report.freshSelections=[{map:7,state:0,leveltime:1,skill:2}];
    for(const map of [1,2,3,4,5,6,8,9]) {
      const fresh=await deploy();await transaction(method('initializeMenu(bool)')+word(0),fresh);
      await events(fresh,key(115).concat(key(13),key(48+map),key(13)),false,'Fresh E1M'+map+' menu selection');
      await events(fresh,key(13),true,'Fresh first-game E1M'+map);
      const state=await episode(fresh),status=await game(fresh);
      assert.deepEqual(state.slice(0,5),[map,2,0,0,0]);assert.deepEqual(status.slice(1),[1,100,0,1]);
      report.freshSelections.push({map,state:state[2],leveltime:status[1],skill:state[1]});console.log('PASS fresh first-game E1M'+map);
    }
    if(args.includes('--browser')) {
      const browserAddress=await deploy(), configPath=prefix+'.config.json';await writeFile(configPath,JSON.stringify(configuration(browserAddress),null,2)+'\n');
      const browser=spawn(process.execPath,['tools/transport/menu-browser-check.mjs','--config',configPath,'--output-prefix',prefix+'-browser'],{stdio:'inherit'});
      assert.equal(await new Promise((done,fail)=>{browser.once('error',fail);browser.once('exit',done);}),0,'Chrome menu gate');
      report.browserEvidence=prefix+'-browser.json';
    }
    report.pass=true;
  }
} catch(error) { report.error=error.stack;process.exitCode=1;console.error(error.stack); }
finally {
  if(httpServer)await new Promise(done=>httpServer.close(done));
  if(priorConfig)await writeFile('web/config.local.json',priorConfig);if(priorPalette)await writeFile('web/palette.local.json',priorPalette);
  if(node?.pid&&node.exitCode===null&&node.signalCode===null)await new Promise(done=>{node.once('exit',done);node.kill('SIGTERM');setTimeout(()=>{if(node.exitCode===null)node.kill('SIGKILL');},1500).unref();});
  await log?.close();report.endedUtc=new Date().toISOString();report.stoppedOwnedAnvil=true;
  await writeFile(prefix+'.json',JSON.stringify(report,null,2)+'\n');
}
