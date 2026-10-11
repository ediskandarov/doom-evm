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
const port = Number(option('--port', '19071')), prefix = option('--output-prefix', 'artifacts/local/doom2/menu/evm');
assert(Number.isInteger(port) && port > 1024 && port < 65536 && ![18880,8088].includes(port));
const budget = loadGasBudget(), gas = budget.gasHex, url = `http://127.0.0.1:${port}`;
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const word = n => BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');
const tail = bytes => word(bytes.length) + bytes.toString('hex').padEnd(Math.ceil(bytes.length/32)*64,'0');
const json = async path => JSON.parse(await readFile(path));
const artifact = await json('artifacts/local/doom2/production/out/Doom2.sol/Doom2.json'), store = await json('out/ResourceStore.sol/ResourceStore.json');
const method = name => { assert(artifact.methodIdentifiers[name],name); return '0x'+artifact.methodIdentifiers[name]; };
const metadata = typeof artifact.metadata === 'string' ? JSON.parse(artifact.metadata) : artifact.metadata;
const blob = await readFile('artifacts/local/doom2/wad/resources.bin'), bundle = await json('artifacts/local/doom2/wad/bundle.json');
assert.equal(sha(blob),bundle.blobSha256);
const directory = await readFile('artifacts/local/doom2/wad/directory.bin');
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
  const memory=async address=>words(await call(address,method('memoryStatus()')));
  const init=()=>method('initializeMenuWithMemoryProfile(bool,uint8)')+word(0)+word(3);
  await rollback(address,init(),'profile initializer driver authentication',other);
  await rollback(address,method('initializeMenuWithMemoryProfile(bool,uint8)')+word(0)+word(4),'unsupported memory profile');
  assert.deepEqual(await memory(address),[2,0,0,0,0]);
  const strictAddress=await deploy();await transaction(method('initializeGameStrict()'),strictAddress);
  assert.deepEqual(await memory(strictAddress),[0,1,0,0,0]);report.strictDiagnosticPolicyPreserved=true;
  const defaultAddress=await deploy();await transaction(method('initializeMenu(bool)')+word(0),defaultAddress);
  assert.deepEqual(await memory(defaultAddress),[2,0,0,0,0]);report.defaultPolicyPreserved=true;
  await transaction(init(),address);assert.deepEqual(await memory(address),[3,0,0,0,0]);
  await events(address,[],true,'DOOM II initial EVM menu');
  await events(address,key(13),true,'Commercial New Game goes directly to skills');assert.equal((await menu(address))[2],2);
  const seq=(counters.get(address)??0)+1;
  const startPacket=Buffer.from(key(13).flat());
  await rollback(address,method('stepEventsAndRender(bytes,uint32)')+word(64)+word(seq)+tail(startPacket),'underfunded fresh MAP01 startup after menu writes',driver,'0x5f5e100');
  assert.equal(await call(address,method('gameStarted()')),'0x'+word(0));assert.equal((await menu(address))[2],2);
  await events(address,key(13),true,'MAP01 startup retries same sequence');
  assert.deepEqual((await episode(address)).slice(0,5),[1,2,0,0,0]);assert.deepEqual(await memory(address),[3,1,1,1,1]);
  await events(address,[[0,119]],true,'MAP01 actual movement');const moved=await view(address);
  await events(address,key(27),true,'Escape menu pauses gameplay');const frozen=await game(address);
  await events(address,[],true,'Menu redraw leaves gameplay persisted');assert.deepEqual(await game(address),frozen);assert.deepEqual(await view(address),moved);
  await events(address,key(27),true,'Escape resumes cached Frame');assert.deepEqual(await game(address),frozen);
  await events(address,[],true,'Following gameplay tic resumes');assert.equal((await game(address))[1],frozen[1]+1);
  async function choose(map,skill=2){
    await events(address,key(27).concat(key(115),key(13)),false,'Open commercial Select Level');
    const item=(await menu(address))[3];let packet=[];
    const steps=(map-1-item+32)%32;for(let i=0;i<steps;++i)packet.push(...key(175));
    packet.push(...key(13));await events(address,packet,true,'Select MAP'+String(map).padStart(2,'0')+' skill screen');
    assert.equal((await menu(address))[6],map);
    let skillPacket=[];const current=(await menu(address))[3];for(let i=0;i<(skill-current+5)%5;++i)skillPacket.push(...key(175));skillPacket.push(...key(13));
    if(skill===4){await events(address,skillPacket,true,'Original Nightmare confirmation');assert.equal((await menu(address))[8],1);skillPacket=key(121);}
    await events(address,skillPacket,true,'Start MAP'+String(map).padStart(2,'0')+' skill '+skill);
    const status=await episode(address);assert.deepEqual(status.slice(0,4),[map,skill,0,0]);assert.deepEqual(await memory(address),[3,1,1,1,1]);
    const inventory=words(await call(address,method('playerInventory()')));assert.deepEqual(inventory.slice(0,4),[50,0,0,0]);
    report.selections.push({map,skill,leveltime:(await game(address))[1],noIntermission:status[7]===0,policyPersisted:true});console.log('PASS actual production selection',map,skill);
  }
  for(const skill of [0,1,3,4,2])await choose(1,skill);
  for(const map of [7,15,31,32])await choose(map);
  await rollback(address,method('newEpisodeGame(int32,int32,uint32)')+word(33)+word(2)+word((counters.get(address)??0)+1),'unsupported commercial map');
  report.pass=true;
} catch(error) { report.error=error.stack;process.exitCode=1;console.error(error.stack); }
finally {
  if(node?.pid&&node.exitCode===null&&node.signalCode===null)await new Promise(done=>{node.once('exit',done);node.kill('SIGTERM');setTimeout(()=>{if(node.exitCode===null)node.kill('SIGKILL');},1500).unref();});
  await log?.close();report.endedUtc=new Date().toISOString();report.stoppedOwnedAnvil=true;
  await writeFile(prefix+'.json',JSON.stringify(report,null,2)+'\n');console.log('Report',prefix+'.json');
}
