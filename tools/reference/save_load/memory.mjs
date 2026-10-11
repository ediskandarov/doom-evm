// SPDX-License-Identifier: GPL-2.0-only
// Production, observation-only clone, and same-gas source-mapped MSIZE clone.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {connect} from 'node:net';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {instrumentGasMarkers} from '../phase2_data/instrument.mjs';
import {eventStepData} from '../../../web/input.mjs';
import {decodeSlot} from './browser-features.mjs';
const args=process.argv.slice(2),opt=(n,d)=>args.includes(n)?args[args.indexOf(n)+1]:d;
const port=Number(opt('--port','19397')),dir=opt('--output','artifacts/local/save-load/memory-real');
const resources=opt('--resources','/Users/eduard/sandbox/doom-evm/artifacts/local/wad');
assert(![18880,8088].includes(port));await mkdir(dir,{recursive:true});
const sha=b=>createHash('sha256').update(b).digest('hex'),json=async p=>JSON.parse(await readFile(p));
const word=n=>BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');
const tail=b=>word(b.length)+b.toString('hex').padEnd(Math.ceil(b.length/32)*64,'0');
const production=await json('out/Doom.sol/Doom.json'),probe=await json('out/DoomSaveMemoryProbe.sol/DoomSaveMemoryProbe.json');
const cloneSource=await readFile('artifacts/local/save-load/memory/DoomSaveMemoryProbe.sol','utf8');
const clone=await json('artifacts/local/save-load/memory/source.json');
assert.equal(clone.originalSourceSha256,sha(await readFile('src/evm/Doom.sol')));
assert.equal(clone.cloneSourceSha256,sha(Buffer.from(cloneSource)));
const patched=instrumentGasMarkers(probe,cloneSource),store=await json('out/ResourceStore.sol/ResourceStore.json');
const bundle=await json(resources+'/bundle.json'),blob=await readFile(resources+'/resources.bin');assert.equal(sha(blob),bundle.blobSha256);
const directory=Buffer.alloc(bundle.lumps.length*16);for(let i=0;i<bundle.lumps.length;i++){const l=bundle.lumps[i];Buffer.from(l.nameHex,'hex').copy(directory,i*16);directory.writeUInt32LE(l.offset,i*16+8);directory.writeUInt32LE(l.length,i*16+12);}
const gas='0x2540be400';let child,id=0,from,sequence=0,memoryTopic,frameTopic,paletteTopic;
const report={kind:'production save-load gas/time and source-mapped memory boundary',pass:false,startedUtc:new Date().toISOString(),port,gasLimit:10000000000,memoryLimit:1073741824,clone,instrumentation:patched.report,resourceIdentity:bundle.resourceIdentity,transactions:[],measurements:[],sourceHashes:{},notes:[
 'Ordinary CREATE only. Production has no instrumentation. Separate clone adds only end-of-save/load observers; GAS and MSIZE clones must match gas, root digests, state, frames and palettes.',
 'Memory is current EVM call frame MSIZE immediately after production save/load and Frame/Palette encoding, before following observer encoding; SHA256 precompile has a separate frame.',
 'Payload words plus slot headers describe reachable logical storage; trie/database bytes and unreachable old restore tails are not measured.',
 'Wall time includes local RPC and transaction mining. Costs exclude the original keyboard/menu navigation packets.']};
for(const p of Object.keys(production.metadata.sources))report.sourceHashes[p]=sha(await readFile(p));
async function rpc(method,params=[]){const r=await fetch('http://127.0.0.1:'+port,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(300000)});const b=await r.json();if(b.error)throw Error(method+JSON.stringify(b.error));return b.result;}
async function send(data,to,label){const start=performance.now(),hash=await rpc('eth_sendTransaction',[{from,data,gas,...(to?{to}:{})}]);let r;while(!(r=await rpc('eth_getTransactionReceipt',[hash])))await new Promise(f=>setTimeout(f,20));assert.equal(r.status,'0x1',label+' reverted');const row={label,hash,gas:Number(BigInt(r.gasUsed)),seconds:(performance.now()-start)/1000};if(label!=='resource')report.transactions.push(row);return {r,row};}
const data=(sig,body='')=>'0x'+production.methodIdentifiers[sig]+body;
const call=async(a,sig,body='')=>rpc('eth_call',[{from,to:a,data:data(sig,body),gas},'latest']);
const outputs=r=>r.logs.filter(l=>[frameTopic,paletteTopic].includes(l.topics[0])).map(l=>({topics:l.topics,data:l.data}));
let addresses;
async function state(){const sigs=['gameStatus()','playerView()','playerInventory()','uiStatus()','episodeStatus()','inputSeq()','frameId()'];const values=await Promise.all(addresses.map(a=>Promise.all(sigs.map(s=>call(a,s)))));assert.deepEqual(values[1],values[0]);assert.deepEqual(values[2],values[0]);return values[0];}
async function slots(n){const v=await Promise.all(addresses.map(a=>call(a,'readSaveSlot(uint8)',word(n))));const s=v.map(decodeSlot);for(const x of s){assert(x.occupied&&x.compatible);delete x.engine;}assert.deepEqual(s[1],s[0]);assert.deepEqual(s[2],s[0]);return s[0];}
async function three(sig,body,label){const r=[];for(const a of addresses)r.push(await send(data(sig,body),a,label));assert.equal(r[1].r.gasUsed,r[2].r.gasUsed,'GAS/MSIZE gas mismatch');assert.deepEqual(outputs(r[1].r),outputs(r[0].r));assert.deepEqual(outputs(r[2].r),outputs(r[0].r));
 const started=await Promise.all(addresses.map(a=>call(a,'gameStarted()')));assert.equal(started[1],started[0]);assert.equal(started[2],started[0]);
 if(BigInt(started[0]))await state();else{const menu=await Promise.all(addresses.map(a=>call(a,'menuStatus()')));assert.equal(menu[1],menu[0]);assert.equal(menu[2],menu[0]);}return r;}
async function events(packet,label){return three('stepEventsAndRender(bytes,uint32)',eventStepData(Uint8Array.from(packet),++sequence).slice(10),label);}
async function measure(operation,revision){const before=await state();const body=operation==='load'?word(0)+word(revision)+word(++sequence):word(0)+word(128)+word(revision)+word(++sequence)+tail(Buffer.from('MEMORY CHECK'));
 const r=await three(operation==='load'?'loadGame(uint8,uint64,uint32)':'saveGame(uint8,bytes,uint64,uint32)',body,operation);const saved=await slots(0),after=await state();assert.deepEqual(after.slice(0,5),operation==='load'?checkpointState.slice(0,5):before.slice(0,5),'save/load advanced or changed restored game');
 const log=r[2].r.logs.find(l=>l.topics[0]===memoryTopic);assert(log);const highWaterBytes=Number(BigInt('0x'+log.data.slice(66,130)));
 report.measurements.push({operation,revision:saved.revision,byteLength:saved.size,payloadWords:saved.size/32,description:saved.description,digest:saved.digest,productionGas:r[0].row.gas,seconds:r[0].row.seconds,observerGas:r[1].row.gas,highWaterBytes,productionObserverStateAndFrameEqual:true,gasMsizeIdenticalGas:true});return {saved,outputs:outputs(r[0].r)};
}
let checkpointState;
try{
 await new Promise((done,fail)=>{const s=connect({host:'127.0.0.1',port});s.once('connect',()=>{s.destroy();fail(Error('Occupied dedicated port'));});s.once('error',e=>e.code==='ECONNREFUSED'?done():fail(e));});
 const argv=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--gas-limit','10000000000','--memory-limit','1073741824','--no-request-size-limit','--prune-history','2','--transaction-block-keeper','2','--silent'];child=spawn(resolve('.toolchain/bin/anvil'),argv,{stdio:'ignore'});report.runtime={ownedPid:child.pid,args:argv};
 for(let n=0;;n++){try{[from]=await rpc('eth_accounts');break;}catch(e){if(n>100)throw e;await new Promise(f=>setTimeout(f,100));}}
 const topic=s=>rpc('web3_sha3',['0x'+Buffer.from(s).toString('hex')]);memoryTopic=await topic('MemoryBoundary(uint8,uint256)');frameTopic=await topic('Frame(uint64,uint32,uint16,uint16,bytes)');paletteTopic=await topic('FramePalette(uint64,uint32,uint32,int32,uint8,bytes)');
 const chunks=[];for(let p=0;p<blob.length;p+=16384){const b=blob.subarray(p,p+16384),{r}=await send(store.bytecode.object+word(32)+tail(b),undefined,'resource');assert.equal(await rpc('eth_getCode',[r.contractAddress,'latest']),'0x00'+b.toString('hex'));chunks.push(r.contractAddress);}
 const array=word(chunks.length)+chunks.map(a=>a.slice(2).padStart(64,'0')).join(''),constructor=word(64)+word(64+array.length/2)+array+tail(directory);
 addresses=[];for(const creation of [production.bytecode.object,probe.bytecode.object,'0x'+patched.creation.toString('hex')])addresses.push((await send(creation+constructor,undefined,'CREATE')).r.contractAddress);
 await three('initializeMenuWithPolicy(bool,uint8)',word(1)+word(3),'menu policy3');
 // Existing original menus: NEW GAME -> Episode One -> medium, then movement.
 await events([0,13,0,13,0,13],'original menu startup');
 await events([0,0xad],'movement');await events([1,0xad],'movement release');
 checkpointState=await state();const saved=await measure('save',0);
 await events([0,0xad,0,0x9d],'combat');await events([1,0xad,1,0x9d],'combat release');assert.notDeepEqual((await state()).slice(0,2),checkpointState.slice(0,2));
 const loaded=await measure('load',1);
 // Frame envelopes intentionally have newer monotonic counters; data pixels and
 // palette/state are separately compared by three(), and rooted digest below.
 const overwritten=await measure('overwrite',1);assert.equal(overwritten.saved.digest,saved.saved.digest);assert.equal(loaded.saved.digest,saved.saved.digest);
 report.pass=true;console.log(JSON.stringify(report.measurements,null,2));
}catch(error){report.error=String(error.stack??error);throw error;}
finally{
 if(child?.pid&&child.exitCode===null&&child.signalCode===null)await new Promise(done=>{child.once('exit',done);child.kill('SIGTERM');setTimeout(()=>{if(child.exitCode===null)child.kill('SIGKILL');},3000).unref();});
 report.endedUtc=new Date().toISOString();report.stoppedOwnedRuntime=!!child;await writeFile(dir+'/report.json',JSON.stringify(report,null,2)+'\n');
 await mkdir('artifacts/save-load',{recursive:true});await writeFile('artifacts/save-load/production-memory.json',JSON.stringify({...report,rawReportSha256:sha(await readFile(dir+'/report.json'))},null,2)+'\n');
}
