// SPDX-License-Identifier: GPL-2.0-only
// Ordinary production CREATE and original keyboard inputs. Oracle bytes are outputs only.
import { readFile, writeFile, mkdir, open } from 'node:fs/promises';
import { spawn, execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { connect } from 'node:net';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
import { FRAME_TOPIC, decodeFrame, FrameInbox, FrameSubscription, backfill } from '../../../web/protocol.mjs';
import { decodeFramePalette, FRAME_PALETTE_TOPIC } from '../../../web/ui-palette.mjs';
import { loadGasBudget } from '../../execution-budget.mjs';

const args=process.argv.slice(2), option=(n,d)=>args.includes(n)?args[args.indexOf(n)+1]:d;
const port=Number(option('--port','18721')), prefix=option('--output-prefix','artifacts/local/input-runtime/production');
assert(Number.isInteger(port)&&port>1024&&port<65536&&![18579,18880,8088].includes(port));
const nativePath=option('--native','artifacts/local/input-runtime-native'), budget=loadGasBudget(), gas=budget.gasHex;
const url=`http://127.0.0.1:${port}`, ws=url.replace('http','ws');
const sha=b=>createHash('sha256').update(b).digest('hex');
const word=n=>BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');
const tail=b=>word(b.length)+b.toString('hex').padEnd(Math.ceil(b.length/32)*64,'0');
const native=JSON.parse(await readFile(nativePath+'/manifest.json'));
assert.equal(native.kind,'original-production-input-runtime-oracle');
for(const [name,digest] of Object.entries(native.files))assert.equal(sha(await readFile(nativePath+'/'+name)),digest,name);
const packets=JSON.parse(await readFile(nativePath+'/packets.json'));
const players=JSON.parse(await readFile(nativePath+'/players.json'));
const ui=JSON.parse(await readFile(nativePath+'/ui.json'));
const runtimeStates=JSON.parse(await readFile(nativePath+'/runtime.json'));
const eventData=(name,events,seq)=>method(name)+word(64)+word(seq)+tail(Buffer.from(events.flat()));
const artifact=JSON.parse(await readFile('out/Doom.sol/Doom.json'));
const chunk=JSON.parse(await readFile('out/ResourceStore.sol/ResourceStore.json'));
const metadata=typeof artifact.metadata==='string'?JSON.parse(artifact.metadata):artifact.metadata;
const method=n=>{assert(artifact.methodIdentifiers[n],n);return '0x'+artifact.methodIdentifiers[n];};
const blob=await readFile('artifacts/local/wad/resources.bin');
const bundle=JSON.parse(await readFile('artifacts/local/wad/bundle.json'));
const directory=await readFile('test/fixtures/phase2_data/directory.bin');
assert.equal(sha(blob),bundle.blobSha256);assert.deepEqual(native.resourceIdentity,bundle.resourceIdentity);
await mkdir(resolve(prefix,'..'),{recursive:true});
const report={kind:'production-input-runtime-ordinary-evm',pass:false,startedUtc:new Date().toISOString(),executionBudget:budget,
  nativeManifestSha256:sha(await readFile(nativePath+'/manifest.json')),resourceIdentity:bundle.resourceIdentity,
    compiler:{version:metadata.compiler.version,settings:metadata.settings},sourceHashes:{},comparisons:[],frames:[],rejections:[],modes:[]};
let node,logFile,subscription,id=0;
async function rpc(method,params=[]){
  const r=await fetch(url,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(300000)});
  assert(r.ok);const b=await r.json();if(b.error)throw Object.assign(Error(JSON.stringify(b.error)),{rpcError:b.error});return b.result;
}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function until(fn,label){const end=Date.now()+180000;while(Date.now()<end){const r=await fn();if(r)return r;await sleep(20);}throw Error('Timeout '+label);}
async function tx(from,data,to,status='0x1'){
  const start=performance.now(),hash=await rpc('eth_sendTransaction',[{from,data,gas,...(to?{to}:{})}]);
  const receipt=await until(()=>rpc('eth_getTransactionReceipt',[hash]),'receipt');assert.equal(receipt.status,status,hash);
  return {receipt,gas:Number(BigInt(receipt.gasUsed)),ms:performance.now()-start};
}
const call=(address,data)=>rpc('eth_call',[{to:address,data,gas},'latest']);
function words(hex){return hex.slice(2).match(/.{64}/g).map(x=>BigInt('0x'+x));}
async function rollback(address,from,data,error){
  const before=await rpc('eth_getProof',[address,[],'latest']);
  let failed=false;try{await rpc('eth_call',[{from,to:address,data,gas},'latest']);}catch(e){
    const expected=execFileSync(resolve('.toolchain/bin/cast'),['sig',error],{encoding:'utf8'}).trim();
    const actual=typeof e.rpcError?.data==='string'?e.rpcError.data:e.rpcError?.data?.data;
    assert.equal(actual?.slice(0,10),expected);failed=true;
  }assert(failed,error);
  const r=await tx(from,data,address,'0x0'),after=await rpc('eth_getProof',[address,[],'latest']);
  assert.equal(after.storageHash,before.storageHash);assert.equal(r.receipt.logs.length,0);
  report.rejections.push({error,transactionHash:r.receipt.transactionHash,gas:r.gas,allStorageRollback:true});
}
async function compare(address,packet,r){
  const expected=players[packet.tic];
  const status=words(await call(address,method('gameStatus()'))),view=words(await call(address,method('playerView()')));
  const names=['gametic','leveltime','playerHealth','armorpoints','readyweapon','x','y','z','angle','momx','momy','momz','viewz','prndindex'];
  [...status,...view].forEach((n,i)=>assert.equal(Number(['gametic','angle','prndindex'].includes(names[i])?n:BigInt.asIntN(256,n)),names[i]==='angle'?expected[names[i]]>>>0:expected[names[i]],`tic${packet.tic} ${names[i]}`));
  const data=await call(address,method('uiStatus()')),raw=words(data),nativeUI=ui[packet.tic-1];
  assert.equal(raw[0],1n);assert.equal(raw[1],BigInt(packet.fullscreen));
  const fields=['clock','face','facecount','palette','revision','rndindex','messageOn','messageCounter'];
  fields.forEach((n,i)=>assert.equal(Number(BigInt.asIntN(256,raw[i+2])),nativeUI[n],`tic${packet.tic} UI ${n}`));
  assert.equal(raw[10],352n);assert.equal(raw[11],81n);assert.equal(data.slice(2+384*2,2+(384+81)*2),nativeUI.messageHex,'all NUL/stale message bytes');
  const inventory=words(await call(address,method('playerInventory()')));
  ['ammoClip','ammoShell','ammoCell','ammoMissile'].forEach((n,i)=>assert.equal(Number(inventory[i]),expected[n]));
  assert.deepEqual(inventory.slice(4,8).map(Number),[200,50,300,50]);
  assert.deepEqual(inventory.slice(8,14).map(Number),nativeUI.cards);assert.deepEqual(inventory.slice(14).map(Number),nativeUI.weapons);
  assert.equal(await call(address,method('inputSeq()')),'0x'+word(packet.tic+1));
  const original=runtimeStates[packet.tic-1];
  const cheat=words(await call(address,method('cheatStatus()')));
  assert.deepEqual(cheat.slice(0,11).map(n=>Number(BigInt.asIntN(256,n))),original.cheatWords,'all cheat/player/pending request fields');
  assert.equal(cheat[11],BigInt('0x'+original.gamekeydownHex),'all native held keys');
  assert.deepEqual(words(await call(address,method('automapStatus()'))).map(n=>Number(BigInt.asIntN(256,n))),original.automapWords,'all exposed native AM fields');
  for(let i=0;i<10;i++)assert.deepEqual(words(await call(address,method('automapMark(uint8)')+word(i))).map(n=>Number(BigInt.asIntN(256,n))),original.marks.slice(i*2,i*2+2),'native mark ring');
  for(let i=0;i<15;i++){
    const data=await call(address,method('cheatSequence(uint8)')+word(i)),parts=words(data),seq=original.sequences[i];
    assert.equal(Number(parts[1]),seq.cursor,'native parser cursor '+i);
    assert.equal(data.slice(2+96*2,2+(96+Number(parts[2]))*2),seq.hex,'native mutable parser bytes '+i);
  }
  const unused=words(await call(address,method('cheatSequence(uint8)')+word(15)));
  assert.equal(unused[1],0n,'standalone IDDT recognizer is never called');
  const flags=Buffer.alloc(original.lineFlags.length*2);original.lineFlags.forEach((n,i)=>flags.writeUInt16BE(n,i*2));
  const discovery=words(await call(address,method('automapDiscovery()')));
  assert.equal(Number(discovery[0]),original.lineFlags.filter(n=>n&256).length,'native discovery count');
  assert.equal(discovery[1].toString(16).padStart(64,'0'),sha(flags),'every original ordered linedef flag');
  report.comparisons.push({tic:packet.tic,events:packet.events,draw:packet.render,fullscreen:packet.fullscreen,nativeScalarFields:74,parserSequences:15,markerCoordinates:20,allLineFlagsExact:true,
    ui:nativeUI,transactionHash:r.receipt.transactionHash,gas:r.gas,ms:r.ms});
}
try{
  for(const [path,identity] of Object.entries(metadata.sources)){
    const b=await readFile(path);assert.equal(execFileSync(resolve('.toolchain/bin/cast'),['keccak'],{input:'0x'+b.toString('hex'),encoding:'utf8',maxBuffer:1024*1024}).trim(),identity.keccak256,'artifact drift '+path);report.sourceHashes[path]=sha(b);
  }
  for(const path of ['foundry.toml','execution-budget.json','tools/reference/input-runtime/production.mjs','tools/reference/input-runtime/reference.py','web/app.mjs','web/input.mjs','web/input-loop.mjs','web/ui-palette.mjs'])report.sourceHashes[path]=sha(await readFile(path));
  await new Promise((done,fail)=>{const s=connect({host:'127.0.0.1',port});s.once('connect',()=>{s.destroy();fail(Error('Refusing occupied port'));});s.once('error',e=>e.code==='ECONNREFUSED'?done():fail(e));});
  logFile=await open(prefix+'.anvil.log','w');
  const nodeArgs=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--disable-block-gas-limit','--memory-limit','1073741824','--silent'];
  node=spawn(resolve('.toolchain/bin/anvil'),nodeArgs,{stdio:['ignore','ignore',logFile.fd]});
  let spawnError;node.on('error',e=>spawnError=e);
  await until(async()=>{if(spawnError)throw spawnError;if(node.exitCode!==null)throw Error('Anvil exited');try{return await rpc('web3_clientVersion');}catch{return false;}},'Anvil');
  report.node={pid:node.pid,rpcUrl:url,wsUrl:ws,args:nodeArgs,client:await rpc('web3_clientVersion')};
  await rpc('anvil_setBlockGasLimit',[gas]);await rpc('evm_mine');
  assert.equal(BigInt((await rpc('eth_getBlockByNumber',['latest',false])).gasLimit),BigInt(budget.gasLimit));
  const [driver,other]=await rpc('eth_accounts'),addresses=[];let chunkGas=0;const uploadStart=performance.now();
  for(let p=0;p<blob.length;p+=16384){
    const bytes=blob.subarray(p,p+16384),r=await tx(driver,chunk.bytecode.object+word(32)+tail(bytes));
    assert.equal(await rpc('eth_getCode',[r.receipt.contractAddress,'latest']),'0x00'+bytes.toString('hex'));addresses.push(r.receipt.contractAddress);chunkGas+=r.gas;
    if(addresses.length%250===0)console.log('Authenticated resource runtime',addresses.length,'/1755');
  }
  const addr=word(addresses.length)+addresses.map(a=>a.slice(2).padStart(64,'0')).join('');
  const constructor=word(64)+word(64+addr.length/2)+addr+tail(directory);
  async function deploy(){
    const r=await tx(driver,artifact.bytecode.object+constructor),address=r.receipt.contractAddress;
    const runtime=Buffer.from(artifact.deployedBytecode.object.slice(2),'hex');
    for(const spans of Object.values(artifact.deployedBytecode.immutableReferences))for(const s of spans)Buffer.from(word(driver),'hex').copy(runtime,s.start);
    assert.equal(await rpc('eth_getCode',[address,'latest']),'0x'+runtime.toString('hex'));return {address,...r,runtimeSha256:sha(runtime)};
  }
  const deployment=await deploy(),address=deployment.address;
  report.deployment={address,transactionHash:deployment.receipt.transactionHash,gas:deployment.gas,ms:deployment.ms,runtimeSha256:deployment.runtimeSha256,
    runtimeBytes:(artifact.deployedBytecode.object.length-2)/2,chunks:addresses,chunkGas,uploadMs:performance.now()-uploadStart};
  const wsLogs=new Map(),inbox=new FrameInbox(()=>{});
  subscription=new FrameSubscription(ws,address,l=>{wsLogs.set(l.transactionHash,l);inbox.accept(l,'ws');});await subscription.connect();
  async function checkFrame(r,tic,frameId,fallback=false){
    const logs=r.receipt.logs,staticFrame=tic===0;assert.equal(logs.length,staticFrame?1:2);
    const log=logs.find(l=>l.topics[0]===FRAME_TOPIC),frame=decodeFrame(log);inbox.accept(log,'receipt');
    assert.equal(frame.frameId,BigInt(frameId));assert.equal(frame.inputSeq,tic+1);
    const path=staticFrame?'test/fixtures/renderer/full-angle0/pixels.bin':`${nativePath}/frame-${String(tic).padStart(6,'0')}.bin`;
    const expected=await readFile(path);assert.equal(Buffer.compare(Buffer.from(frame.pixels),expected),0,`all native Frame pixels tic${tic}`);
    let palette;
    if(!staticFrame){palette=decodeFramePalette(logs.find(l=>l.topics[0]===FRAME_PALETTE_TOPIC),frame);
      assert.equal(Buffer.compare(Buffer.from(palette.rgb),await readFile(`${nativePath}/palette-${String(tic).padStart(6,'0')}.bin`)),0,'all native gamma palette bytes');}
    if(!fallback){await until(()=>wsLogs.has(log.transactionHash),'Frame WS');assert.deepEqual(wsLogs.get(log.transactionHash).data,log.data);}
    report.frames.push({tic,frameId,pixelSha256:sha(expected),pixelDiffCount:0,palette:palette?.palette,paletteSha256:palette?sha(palette.rgb):null,
      transactionHash:r.receipt.transactionHash,gas:r.gas,ms:r.ms,wsEqualsReceipt:!fallback,receiptFallback:fallback});
  }
  await rollback(address,other,method('initializeGameInput(bool)')+word(0),'NotDriver()');
  await rollback(address,driver,method('setUIFullscreen(bool)')+word(1),'UINotEnabled()');
  await checkFrame(await tx(driver,method('renderFrame()'),address),0,1);
  const startup=await tx(driver,method('initializeGameInput(bool)')+word(0),address);assert.equal(startup.receipt.logs.length,0);
  report.startup={transactionHash:startup.receipt.transactionHash,gas:startup.gas,ms:startup.ms};
  await rollback(address,driver,method('initializeGameInput(bool)')+word(1),'GameAlreadyStarted()');
  await rollback(address,other,method('setUIFullscreen(bool)')+word(1),'NotDriver()');
  await rollback(address,driver,eventData('stepEvents(bytes,uint32)',[],1),'BadSequence()');
  await rollback(address,driver,method('step(uint32,uint32)')+word(0)+word(2),'RawInputRequired()');
  await rollback(address,other,eventData('stepEvents(bytes,uint32)',[],2),'NotDriver()');
  const code=[...Buffer.from('iddqd')].flatMap(k=>[[0,k],[1,k]]);
  await rollback(address,driver,eventData('stepEventsAndRender(bytes,uint32)',[...code,[2,0]],2),'InvalidKeyboardEvents()');
  await rollback(address,driver,method('stepEvents(bytes,uint32)')+word(64)+word(2)+tail(Buffer.from([0])),'InvalidKeyboardEvents()');
  await rollback(address,driver,eventData('stepEvents(bytes,uint32)',Array(65).fill([0,105]),2),'InvalidKeyboardEvents()');
  let full=false,frameId=1;
  for(const p of packets){
    if(p.fullscreen!==full){const before=await call(address,method('inputSeq()'));const r=await tx(driver,method('setUIFullscreen(bool)')+word(p.fullscreen),address);
      assert.equal(r.receipt.logs.length,0);assert.equal(await call(address,method('inputSeq()')),before);report.modes.push({beforeTic:p.tic,fullscreen:p.fullscreen,transactionHash:r.receipt.transactionHash});full=p.fullscreen;}
    const fallback=p.name==='IDDT-things-stage';if(fallback)subscription.close();
    const r=await tx(driver,eventData(p.render?'stepEventsAndRender(bytes,uint32)':'stepEvents(bytes,uint32)',p.events,p.tic+1),address);
    await compare(address,p,r);
    if(p.render){await checkFrame(r,p.tic,++frameId,fallback);if(fallback){const before=inbox.latest;await subscription.connect();await backfill(rpc,address,r.receipt.blockNumber,inbox);assert.equal(inbox.latest,before);}}
    else assert.equal(r.receipt.logs.length,0,'no-render UI tick');
    if(p.tic%20===0||p.tic===packets.length)console.log('PASS production Cheats/Automap tic',p.tic,'/',packets.length);
  }
  report.transport={duplicates:inbox.duplicates,frames:report.frames.length,receiptFallback:true};
  const browser=await deploy();
  const config={rpcUrl:url,wsUrl:ws,address:browser.address,driver,rendererKind:'doom-world-view',gameplay:true,productionUI:true,rawKeyboard:true,uiFullscreen:false,
    deploymentBlock:browser.receipt.blockNumber,paletteUrl:'/palette.local.json',paletteKind:'wad',resourceIdentity:bundle.resourceIdentity,gasLimit:budget.gasLimit};
  await writeFile('web/palette.local.json',await readFile('artifacts/local/wad/palette.json'));
  await writeFile(prefix+'.config.json',JSON.stringify(config,null,2)+'\n');
  if(args.includes('--browser')){
    const start=performance.now();const child=spawn(process.execPath,['tools/transport/input-runtime-browser-check.mjs','--config',prefix+'.config.json','--native',nativePath,'--output-prefix',prefix+'-browser'],{stdio:'inherit'});
    const code=await new Promise((done,fail)=>{child.once('error',fail);child.once('exit',done);});assert.equal(code,0,'Chrome UI gate');report.browserMs=performance.now()-start;
  }
  report.pass=true;
}catch(e){report.error=e.stack;process.exitCode=1;console.error(e.stack);}
finally{
  subscription?.close();
  if(node?.pid&&node.exitCode===null)await new Promise(done=>{node.once('exit',done);node.kill('SIGTERM');setTimeout(()=>{if(node.exitCode===null)node.kill('SIGKILL');},1500).unref();});
  await logFile?.close();report.endedUtc=new Date().toISOString();report.stoppedOwnedRuntime=true;
  await writeFile(prefix+'.json',JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({pass:report.pass,tics:report.comparisons.length,frames:report.frames.length,evidence:prefix+'.json'}));
}
