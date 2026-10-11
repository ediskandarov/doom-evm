// SPDX-License-Identifier: GPL-2.0-only
// Original input playback and authenticated EVM frames; no host game/UI pixel logic.
import {readFile,writeFile,mkdir,rename,unlink,copyFile} from 'node:fs/promises';
import {createReadStream,createWriteStream} from 'node:fs';
import {gzipSync,gunzipSync,createGunzip} from 'node:zlib';
import {spawn,execFileSync} from 'node:child_process';
import {connect} from 'node:net';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {pipeline} from 'node:stream/promises';
import assert from 'node:assert/strict';
import {dumpChain} from './runtime.mjs';
import {decodeFrame,FRAME_TOPIC} from '../../../web/protocol.mjs';
import {difference,fields} from '../speedrun/dsg1.mjs';
const argv=process.argv.slice(2),opt=(key,fallback)=>argv.includes(key)?argv[argv.indexOf(key)+1]:fallback;
const map=Number(opt('--map','1')),port=Number(opt('--port',String(18940+map)));
assert(map>=1 && map<=9 && Number.isInteger(map));assert(port>1024 && port<65536 && ![8088,18880,8545].includes(port));
const root=resolve('.'),out=resolve(opt('--output',`artifacts/local/full-videos/E1M${map}/attempt-1`));
const base=resolve(`artifacts/local/ultimate-speedruns/E1M${map}`+(map===8?'/alternatives/sedlo-046':''));
await mkdir(out+'/frames',{recursive:true});await mkdir(out+'/receipts',{recursive:true});
const sha=b=>createHash('sha256').update(b).digest('hex'),json=async p=>JSON.parse(await readFile(p,'utf8'));
const word=n=>BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0'),tail=b=>word(b.length)+b.toString('hex').padEnd(Math.ceil(b.length/32)*64,'0');
const uint=(b,at)=>Number(BigInt('0x'+b.subarray(at,at+32).toString('hex'))),signed=(b,at)=>Number(BigInt.asIntN(256,BigInt('0x'+b.subarray(at,at+32).toString('hex'))));
const bytes=(b,at)=>{let offset=uint(b,at),n=uint(b,offset);assert(offset+32+n<=b.length);return b.subarray(offset+32,offset+32+n);};
const native=await json(base+'/native-result.json'),tape=await json(base+'/tape.json'),source=await json(base+'/source.json'),demo=await readFile(base+'/source-download');
if(!native.exitReached){
 const d=await json(base+'/native-domain.json');assert([3,5].includes(map)&&d.pass&&d.profile==='initial-zero-zone');
 assert.equal(d.nativeResultSha256,sha(await readFile(base+'/native-result.json')));assert.equal(d.nativeStatesSha256,native.statesSha256);assert.equal(d.demoSha256,native.demoSha256);assert.equal(d.wadSha256,native.wadSha256);
 assert(d.profiles.filter(p=>p.name!=='sanitize-fill').every(p=>p.allStateBytesEqual&&p.exit[0]===native.executedTics&&p.exit[2]===6));
 for(const [file,digest]of Object.entries(d.sourceHashes))assert.equal(sha(await readFile(file)),digest);
}
assert.equal(sha(demo),native.demoSha256);assert.equal(tape.commands.length,source.totalDemoTics);
const commands=Buffer.concat(tape.commands.map(x=>Buffer.from(x.rawHex,'hex')));assert(commands.equals(demo.subarray(13,13+commands.length)));assert.equal(demo[13+commands.length],0x80);
const delta=gunzipSync(await readFile(base+'/native-states.delta.bin.gz'));let pos=0,prev=Buffer.alloc(0);const states=[];
while(pos<delta.length){let n=delta.readUInt32BE(pos);pos+=4;let row=Buffer.alloc(n);for(let i=0;i<n;i++)row[i]=delta[pos+i]^(prev[i]??0);pos+=n;states.push(row);prev=row;}
assert.equal(states.length,native.executedTics+1);
const observer=resolve(opt('--observer','artifacts/local/full-videos/observer'));
const artifact=await json(observer+'/out/FullSpeedrunProbe.sol/FullSpeedrunProbe.json'),store=await json(observer+'/out/ResourceStore.sol/ResourceStore.json');
assert.equal(artifact.metadata.compiler.version,'0.8.37+commit.f401782d');assert.equal(artifact.metadata.settings.viaIR,true);assert.equal(artifact.metadata.settings.evmVersion,'cancun');
const bundle=await json('artifacts/local/ultimate-speedruns/wad/bundle.json'),blob=await readFile('artifacts/local/ultimate-speedruns/wad/resources.bin'),directory=await readFile('artifacts/local/ultimate-speedruns/wad/directory.bin');assert.equal(sha(blob),bundle.blobSha256);assert.equal(bundle.resourceIdentity.wadSha256,native.wadSha256);
const gasLimit=Number(opt('--gas-limit','10000000000')),gas='0x'+BigInt(gasLimit).toString(16),memory=Number(opt('--memory-limit','1073741824'));
assert(gasLimit>=10000000000 && memory>=1073741824);
const sourceHashes={};for(const file of Object.keys(artifact.metadata.sources))sourceHashes[file]=sha(await readFile(file));
for(const file of ['tools/reference/full_videos/record-short-finale.mjs','tools/reference/full_videos/runtime.mjs','foundry.toml','execution-budget.json'])sourceHashes[file]=sha(await readFile(file));
const identity={map,engineCommitSHA:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),sourceHashes,demoSha256:sha(demo),commandBytesSha256:sha(commands),nativeStateSha256:native.statesSha256,resourceIdentity:bundle.resourceIdentity,abiSha256:sha(JSON.stringify(artifact.abi)),gasLimit,memory};
identity.presentationPolicy='original-WI-edges-105-v1';if(!native.exitReached)identity.nativeProfile='initial-zero-zone';
let report={identity,pass:false,startedUTC:new Date().toISOString(),frames:[],transactions:[],demoTics:0,gameplayTics:0,continuationTics:0,menuFrames:0,wipeFrames:0,intermissionFrames:0,finaleFrames:0,gameplayFrames:0,gameplayCaptures:0,nextCommand:0,phase:'init',nativeGameplayComparisons:0};
let checkpoint;
if(argv.includes('--resume')){checkpoint=await json(out+'/checkpoint.json');assert.deepEqual(checkpoint.identity,identity,'frozen identity drift');report=checkpoint.report;report.pass=false;delete report.error;report.resumeSessions??=[];report.resumeSessions.push(new Date().toISOString());for(const frame of report.frames)assert.equal(sha(await readFile(out+'/'+frame.file)),frame.sha256);}
else if(argv.includes('--fork-checkpoint')){
 const parent=resolve(opt('--fork-checkpoint','')),cp=await json(parent+'/checkpoint.json');
 assert.equal(cp.identity.map,identity.map);for(const key of ['demoSha256','commandBytesSha256','nativeStateSha256','resourceIdentity','abiSha256','gasLimit','memory'])assert.deepEqual(cp.identity[key],identity[key],key);
 for(const [file,digest]of Object.entries(cp.identity.sourceHashes))if(file.includes('/observer-v2/') || file==='foundry.toml'||file==='execution-budget.json')assert.equal(identity.sourceHashes[file],digest,'EVM identity drift');
 assert(cp.report.gameplayTics<=native.executedTics && cp.report.nextCommand<=native.executedTics && !cp.report.continuationTics,'Fork requires untouched gameplay checkpoint');
 assert.equal(sha(await readFile(cp.chain.file)),cp.chain.sha256);
 report=structuredClone(cp.report);report.identity=identity;report.pass=false;delete report.error;delete report.endedUTC;
 report.checkpointLineage={parentCheckpoint:parent+'/checkpoint.json',parentCheckpointSHA256:sha(await readFile(parent+'/checkpoint.json')),parentIdentity:cp.identity,inheritedTransactions:report.transactions.length,inheritedFrames:report.frames.length,inheritedRPCSeconds:report.transactions.reduce((n,t)=>n+t.elapsedMs,0)/1000,parentRecording:parent+'/recording.json'};
 report.startedUTC=new Date().toISOString();report.policyFork=true;report.resumeSessions=[];
 for(const f of report.frames){assert.equal(sha(await readFile(parent+'/'+f.file)),f.sha256);assert.equal(sha(await readFile(parent+'/'+f.paletteFile)),f.paletteSha256);await copyFile(parent+'/'+f.file,out+'/'+f.file);await copyFile(parent+'/'+f.paletteFile,out+'/'+f.paletteFile);}
 for(const t of report.transactions){assert.equal(sha(await readFile(parent+'/'+t.file)),t.receiptSha256);await copyFile(parent+'/'+t.file,out+'/'+t.file);}
 checkpoint={...cp,identity,report};
}
else {try{await readFile(out+'/checkpoint.json');throw Error('Existing checkpoint requires --resume');}catch(e){if(e.code!=='ENOENT')throw e;}}
let child,stderr='',id=0,from,address,interrupted=false;process.on('SIGTERM',()=>interrupted=true);process.on('SIGINT',()=>interrupted=true);
async function rpc(method,params=[]){const r=await fetch(`http://127.0.0.1:${port}`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(300000)});const j=await r.json();if(j.error)throw Error(method+': '+JSON.stringify(j.error));return j.result;}
const method=name=>'0x'+artifact.methodIdentifiers[name];
async function call(name,data=''){return Buffer.from((await rpc('eth_call',[{from,to:address,data:method(name)+data,gas},'latest'])).slice(2),'hex');}
async function send(data,to,kind){const began=performance.now(),hash=await rpc('eth_sendTransaction',[{from,data,gas,...(to?{to}:{})}]);let r;while(!(r=await rpc('eth_getTransactionReceipt',[hash])))await new Promise(f=>setTimeout(f,25));
 const compressed=gzipSync(JSON.stringify(r),{level:1}),file='receipts/'+hash+'.json.gz';await writeFile(out+'/'+file,compressed);
 report.transactions.push({kind,hash,file,receiptSha256:sha(compressed),gas:Number(BigInt(r.gasUsed)),elapsedMs:performance.now()-began,status:r.status});return r;
}
async function snapshot(tic){const b=bytes(await call('snapshot()'),0);let diff=difference(states[tic],b);assert(!diff,'Canonical gameplay mismatch '+JSON.stringify({tic,...diff}));return b;}
let topics;
async function frameReceipt(r){assert.equal(r.status,'0x1','Frame transaction reverted');
 const f=r.logs.find(x=>x.topics[0]===FRAME_TOPIC);if(!f)return false;let frame=decodeFrame(f);assert.equal(Number(frame.frameId),report.frames.length+1);
 const p=r.logs.find(x=>x.topics[0]===topics.presentation),pal=r.logs.find(x=>x.topics[0]===topics.palette);assert(p&&pal);
 const data=Buffer.from(p.data.slice(2),'hex'),paletteData=Buffer.from(pal.data.slice(2),'hex'),rgb=bytes(paletteData,32),pixels=Buffer.from(frame.pixels);assert.equal(rgb.length,768);
 const seq=report.frames.length+1,stem='frames/'+String(seq).padStart(6,'0'),kind=uint(data,0),demoTic=uint(data,32),gameplayTic=uint(data,64),rng=uint(data,96),state=signed(data,128),stage=signed(data,160),count=signed(data,192),stats=bytes(data,224);
 const samples=r.logs.find(x=>x.topics[0]===topics.virtual);const rawSamples=samples?bytes(Buffer.from(samples.data.slice(2),'hex'),0):Buffer.alloc(0);assert.equal(rawSamples.length%512,0);
 const virtualSamples=[];const names='sourceBlock physicalOffset headerBlock headerOffset relative fieldOffset targetOffset virtualPointer sourceByte drawnPixel x y sampleIndex logicalLength sourceOffset provenance'.split(' ');
 for(let at=0;at<rawSamples.length;at+=512){const s=Object.fromEntries(names.map((n,i)=>[n,uint(rawSamples,at+i*32)]));assert([4,5].includes(s.provenance));assert(s.x<320&&s.y<200);let pointer=BigInt(s.virtualPointer);assert.equal(s.sourceByte,Number((pointer>>BigInt((s.relative-s.fieldOffset)*8))&255n));if(s.provenance===5)assert.equal(pointer,0x2000000000n+BigInt(s.targetOffset));else if(s.fieldOffset!==8)assert.equal(pointer,0x1000000000n+BigInt(s.targetOffset));s.finalPixel=pixels[s.y*320+s.x];s.drawnValueSurvives=s.finalPixel===s.drawnPixel;s.virtualPointer='0x'+pointer.toString(16);virtualSamples.push(s);}
 await writeFile(out+'/'+stem+'.indexed8',pixels);await writeFile(out+'/'+stem+'.palette',rgb);
 const row={frameId:seq,kind,demoTic,gameplayTic,rng,state,stage,count,statsHex:stats.toString('hex'),file:stem+'.indexed8',paletteFile:stem+'.palette',sha256:sha(pixels),paletteSha256:sha(rgb),paletteBank:signed(paletteData,0),transactionHash:r.transactionHash,virtualSamples};
 report.frames.push(row);report[['gameplayFrames','menuFrames','wipeFrames','intermissionFrames','finaleFrames'][kind]]++;
 return row;
}
async function doFrame(name,data=''){const before=await call('savedDigest()');const r=await send(method(name)+data,address,name);const result=await frameReceipt(r);assert((await call('savedDigest()')).equals(before),'Presentation changed saved gameplay');return result;}
async function drainWipe(){while(BigInt('0x'+(await call('wipeActive()')).toString('hex'))!==0n)await doFrame('stepWipe()');}
async function saveCheckpoint(){const name='checkpoint-'+report.frames.length+'.chain.gz',chain=await dumpChain(out+'/'+name,port);const data={identity,chain,report,timeUTC:new Date().toISOString()};await writeFile(out+'/checkpoint.json.tmp',JSON.stringify(data));await rename(out+'/checkpoint.json.tmp',out+'/checkpoint.json');await writeFile(out+'/recording.json',JSON.stringify(report,null,2)+'\n');}
try {
 await new Promise((done,fail)=>{const s=connect({host:'127.0.0.1',port});s.once('connect',()=>{s.destroy();fail(Error('Refusing occupied port '+port));});s.once('error',e=>e.code==='ECONNREFUSED'?done():fail(e));});
 const args=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--gas-limit',String(gasLimit),'--memory-limit',String(memory),'--no-request-size-limit','--prune-history','2','--transaction-block-keeper','2','--silent'];
 if(checkpoint){assert.equal(sha(await readFile(checkpoint.chain.file)),checkpoint.chain.sha256);await pipeline(createReadStream(checkpoint.chain.file),createGunzip(),createWriteStream(out+'/restore.json'));args.push('--load-state',out+'/restore.json');}
 child=spawn(resolve('.toolchain/bin/anvil'),args,{stdio:['ignore','ignore','pipe']});child.stderr.on('data',b=>stderr+=b);report.ownedPid=child.pid;report.serverArgs=args;let started=Date.now();
 while(true){assert.equal(child.exitCode,null,stderr);try{report.client=await rpc('web3_clientVersion');break;}catch(e){if(Date.now()-started>15000)throw e;}await new Promise(f=>setTimeout(f,50));}
 [from]=await rpc('eth_accounts');topics={};for(const [key,s]of Object.entries({palette:'FramePalette(uint64,int32,bytes)',presentation:'Presentation(uint64,uint8,uint32,uint32,uint32,uint32,int32,int32,int32,bytes)',virtual:'VirtualSamples(uint32,bytes)'}))topics[key]=await rpc('web3_sha3',['0x'+Buffer.from(s).toString('hex')]);
 // Presentation has four uint32 after uint8: demoTic,gameplayTic,rng; fix signature from ABI.
 const event=artifact.abi.find(x=>x.name==='Presentation');topics.presentation=await rpc('web3_sha3',['0x'+Buffer.from('Presentation('+event.inputs.map(x=>x.type).join(',')+')').toString('hex')]);
 if(checkpoint){address=report.address;await unlink(out+'/restore.json');assert.equal(sha(Buffer.from((await rpc('eth_getCode',[address,'latest'])).slice(2),'hex')),report.runtimeSha256);for(let i=0;i<report.chunks.length;i++)assert.equal(await rpc('eth_getCode',[report.chunks[i],'latest']),'0x00'+blob.subarray(i*16384,(i+1)*16384).toString('hex'));await snapshot(report.gameplayTics);assert.equal(Number(BigInt('0x'+(await call('frameId()')).toString('hex'))),report.frames.length);}
 else {
  const chunks=[];for(let at=0;at<blob.length;at+=16384){const b=blob.subarray(at,at+16384),r=await send(store.bytecode.object+word(32)+tail(b),undefined,'resource');assert.equal(r.status,'0x1');assert.equal(await rpc('eth_getCode',[r.contractAddress,'latest']),'0x00'+b.toString('hex'));chunks.push(r.contractAddress);}
  const addresses=word(chunks.length)+chunks.map(x=>x.slice(2).padStart(64,'0')).join('');const r=await send(artifact.bytecode.object+word(64)+word(64+addresses.length/2)+addresses+tail(directory),undefined,'deployment');assert.equal(r.status,'0x1');address=r.contractAddress;report.address=address;report.chunks=chunks;report.runtimeSha256=sha(Buffer.from((await rpc('eth_getCode',[address,'latest'])).slice(2),'hex'));
  const init=await send(method('initializeMap(uint8,int32,int32,bool)')+word(3)+word(map)+word(tape.header.skill)+word(tape.header.nomonsters),address,'startup');assert.equal(init.status,'0x1');await snapshot(0);report.nativeGameplayComparisons=1;
  for(let i=0;i<35;i++)await doFrame('title()');report.phase='gameplay';await saveCheckpoint();
 }
 const checkpointEvery=Number(opt('--checkpoint-every','100')),stopAfter=Number(opt('--stop-after-tic','0'));
 for(let tic=report.nextCommand;tic<native.executedTics;tic++){
  const raw=commands.subarray(tic*4,tic*4+4);
  if(tic<native.executedTics){const r=await send(method('advance(bytes)')+word(32)+tail(raw),address,'gameplay');assert.equal(r.status,'0x1');assert.equal(r.logs.length,1);const o=Buffer.from(r.logs[0].data.slice(2),'hex');assert.equal(uint(o,0),tic+1);assert(!difference(states[tic+1],bytes(o,32)),'Original gameplay observation diverged');report.nativeGameplayComparisons++;report.gameplayTics=tic+1;await doFrame('capture(uint32)',word(tic+1));report.gameplayCaptures++;}
  else {report.phase='original-ui';await doFrame('presentationTick(bytes,bool)',word(64)+word(1)+tail(raw));}
  await drainWipe();report.demoTics=tic+1;report.nextCommand=tic+1;
  if((tic+1)%25===0)console.log(`E1M${map} original tic ${tic+1}/${tape.commands.length}; frames ${report.frames.length}`);
  if((tic+1)%checkpointEvery===0 || tic+1===native.executedTics || interrupted || stopAfter&&tic+1>=stopAfter)await saveCheckpoint();
  if(interrupted || stopAfter&&tic+1>=stopAfter)throw Error('Recoverable requested stop; resume the frozen checkpoint');
 }
 report.phase='appended-presentation';
 // original=true is the existing four-byte command transport, not a tape provenance claim.
 // WI_checkForAccelerate owns all edge detection and state transitions inside EVM.
 const recipe=[0,1,...Array(104).fill(0),1,0,1,...Array(9).fill(0)];
 report.postExitInputs??=[];
 if(map!==8){
  for(let i=report.continuationTics;i<recipe.length;i++){
   const raw=Buffer.from([0,0,0,recipe[i]]);
   const f=await doFrame('presentationTick(bytes,bool)',word(64)+word(1)+tail(raw));await drainWipe();
   report.postExitInputs.push({index:i+1,rawHex:raw.toString('hex'),buttons:recipe[i],frameId:f.frameId});report.continuationTics++;
   if(i===0 || interrupted){await saveCheckpoint();if(interrupted)throw Error('Recoverable requested stop');}
  }
  const held=report.postExitInputs.slice(1,106).map(x=>report.frames[x.frameId-1]);assert.equal(held.length,105);assert(held.every(f=>f.kind===3&&f.stage===10),'Exact final-statistics hold');
 }else{
  let held=report.continuationHeld??0;
  while(held<105){const f=await doFrame('presentationTick(bytes,bool)',word(64)+word(report.continuationTics===0?1:0)+tail(Buffer.alloc(4)));await drainWipe();report.continuationTics++;
   report.postExitInputs.push({index:report.continuationTics,rawHex:'00000000',buttons:0,advanceTransportSequence:report.continuationTics===1,frameId:f.frameId});if(f.kind===4&&f.stage===1)held++;report.continuationHeld=held;
   assert(report.continuationTics<5000,'Finale continuation bounded');
   if(report.continuationTics%checkpointEvery===0||interrupted){await saveCheckpoint();if(interrupted)throw Error('Recoverable requested stop');}
  }
 }
 report.originalTapeConsumedTics=native.executedTics;report.originalTapePreservedTotalTics=tape.commands.length;
 report.presentationPolicy={name:identity.presentationPolicy,finalStatisticsFrames:map===8?0:105,postExitCommandSHA256:sha(Buffer.concat(report.postExitInputs.map(x=>Buffer.from(x.rawHex,'hex')))),originalTrailerExecuted:false,ending:map===8?'original E1 finale art hold':'original WI Entering/NoState cnt=1 endpoint; final handoff unsupported; no next-map P_Ticker'};
 await snapshot(native.executedTics);const fs=fields(states.at(-1));assert.equal(fs.find(x=>x.field==='global.gameaction').value,6);
 report.pass=true;report.phase='complete';await saveCheckpoint();
} catch(e){report.error=String(e);console.error(e);process.exitCode=1;}
finally {
 report.endedUTC=new Date().toISOString();report.totalGas=report.transactions.reduce((n,t)=>n+t.gas,0);report.rpcSeconds=report.transactions.reduce((n,t)=>n+t.elapsedMs,0)/1000;report.totalVideoFrames=report.frames.length;report.videoSeconds=report.frames.length/35;
 if(child&&child.exitCode===null&&child.signalCode===null){await new Promise(done=>{const timer=setTimeout(()=>{child.kill('SIGKILL');done();},2000);child.once('exit',()=>{clearTimeout(timer);done();});child.kill('SIGTERM');});}
 report.ownedRuntimeStopped=!!child&&(child.exitCode!==null||child.signalCode!==null);await writeFile(out+'/recording.json',JSON.stringify(report,null,2)+'\n');await writeFile(out+'/anvil-stderr.log',stderr);console.log(JSON.stringify({pass:report.pass,map,frames:report.frames.length,gameplayTics:report.gameplayTics,error:report.error}));
}
