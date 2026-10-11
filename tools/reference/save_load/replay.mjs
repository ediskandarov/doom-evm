// SPDX-License-Identifier: GPL-2.0-only
// Real EVM archive/replay and original-C comparisons; never import native state.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {connect} from 'node:net';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {gzipSync} from 'node:zlib';
import assert from 'node:assert/strict';
import {instrumentGasMarkers} from '../phase2_data/instrument.mjs';
const args=process.argv.slice(2),opt=(n,d)=>args.includes(n)?args[args.indexOf(n)+1]:d;
const port=Number(opt('--port','19393')),dir=opt('--output','artifacts/local/save-load/replay');
const nativeDir=opt('--native','artifacts/local/save-load/replay-native');
const resources=opt('--resources','/Users/eduard/sandbox/doom-evm/artifacts/local/wad');
assert(![18880,8088].includes(port));await mkdir(dir,{recursive:true});
const sha=b=>createHash('sha256').update(b).digest('hex'),json=async p=>JSON.parse(await readFile(p));
const word=n=>BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');
const tail=b=>word(b.length)+b.toString('hex').padEnd(Math.ceil(b.length/32)*64,'0');
const bytes=(b,p)=>{const at=Number(BigInt('0x'+b.subarray(p,p+32).toString('hex'))),n=Number(BigInt('0x'+b.subarray(at,at+32).toString('hex')));assert(at+32+n<=b.length);return b.subarray(at+32,at+32+n);};
const artifact=await json('out/SaveReplayProbe.sol/SaveReplayProbe.json'),store=await json('out/ResourceStore.sol/ResourceStore.json');
const patched=instrumentGasMarkers(artifact,await readFile('src/support/SaveReplayProbe.sol','utf8'));
const bundle=await json(resources+'/bundle.json'),blob=await readFile(resources+'/resources.bin');assert.equal(sha(blob),bundle.blobSha256);
const directory=Buffer.alloc(bundle.lumps.length*16);for(let i=0;i<bundle.lumps.length;i++){const l=bundle.lumps[i];Buffer.from(l.nameHex,'hex').copy(directory,i*16);directory.writeUInt32LE(l.offset,i*16+8);directory.writeUInt32LE(l.length,i*16+12);}
const native=await json(nativeDir+'/report.json');assert(native.pass);
const report={kind:'exact save-load original-C/EVM continuation with source-mapped memory probe',pass:false,startedUtc:new Date().toISOString(),port,gasLimit:10000000000,
 resourceIdentity:bundle.resourceIdentity,nativeReferenceSha256:sha(await readFile(nativeDir+'/report.json')),instrumentation:patched.report,cases:[],transactions:[],sourceHashes:{},notes:[
 'Ordinary and GAS→MSIZE deployments differ only by bounded source-mapped marker opcodes. No setCode/etch or native state/pixel injection.',
 'Every original command/native world compared. Loaded state preserves exact rooted values including historical allocator metadata and rendering globals.',
 'MSIZE is this comparison adapter call-frame boundary; production wrapper high-water is measured separately.']};
for(const p of Object.keys(artifact.metadata.sources))report.sourceHashes[p]=sha(await readFile(p));
let child,id=0,from,observationTopic,archiveTopic;
const gas='0x2540be400';
async function rpc(method,params=[]){const r=await fetch('http://127.0.0.1:'+port,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(300000)});const b=await r.json();if(b.error)throw Error(method+JSON.stringify(b.error));return b.result;}
async function send(data,to,label){const start=performance.now(),hash=await rpc('eth_sendTransaction',[{from,data,gas,...(to?{to}:{})}]);let r;while(!(r=await rpc('eth_getTransactionReceipt',[hash])))await new Promise(f=>setTimeout(f,20));assert.equal(r.status,'0x1',label+' reverted '+hash);const row={label,hash,gas:Number(BigInt(r.gasUsed)),seconds:(performance.now()-start)/1000};if(label!=='resource'){report.transactions.push(row);await writeFile(dir+'/'+hash+'.receipt.json.gz',gzipSync(JSON.stringify(r)));}return {r,row};}
const data=(sig,body='')=>'0x'+artifact.methodIdentifiers[sig]+body;
const call=async(address,sig)=>Buffer.from((await rpc('eth_call',[{from,to:address,data:data(sig),gas},'latest'])).slice(2),'hex');
function records(b){let p=0;const result=[];while(p<b.length){const n=b.readUInt32BE(p);p+=4;result.push(b.subarray(p,p+n));p+=n;}assert.equal(p,b.length);return result;}
function observation(r){const log=r.logs.find(l=>l.topics[0]===observationTopic);assert(log);const b=Buffer.from(log.data.slice(2),'hex');return {state:bytes(b,0),pixels:bytes(b,32)};}
async function pair(addresses,sig,body,label){const a=await send(data(sig,body),addresses[0],label+' ordinary'),b=await send(data(sig,body),addresses[1],label+' MSIZE');assert.equal(a.r.gasUsed,b.r.gasUsed,'marker gas inequality');return [a,b];}
async function sameRoots(addresses){const d=await Promise.all(addresses.map(a=>call(a,'digest()')));assert.deepEqual(d[0],d[1],'complete roots differ between marker deployments');return d[0];}
try{
 await new Promise((done,fail)=>{const s=connect({host:'127.0.0.1',port});s.once('connect',()=>{s.destroy();fail(Error('Occupied dedicated port'));});s.once('error',e=>e.code==='ECONNREFUSED'?done():fail(e));});
 const argv=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--gas-limit','10000000000','--memory-limit','1073741824','--no-request-size-limit','--prune-history','2','--transaction-block-keeper','2','--silent'];child=spawn(resolve('.toolchain/bin/anvil'),argv,{stdio:'ignore'});report.runtime={ownedPid:child.pid,args:argv};
 for(let n=0;;n++){try{[from]=await rpc('eth_accounts');break;}catch(e){if(n>100)throw e;await new Promise(f=>setTimeout(f,100));}}
 const topic=async s=>rpc('web3_sha3',['0x'+Buffer.from(s).toString('hex')]);observationTopic=await topic('Observation(bytes,bytes)');archiveTopic=await topic('Archive(uint8,uint256,bytes32,uint256)');
 const chunks=[];for(let p=0;p<blob.length;p+=16384){const b=blob.subarray(p,p+16384),{r}=await send(store.bytecode.object+word(32)+tail(b),undefined,'resource');assert.equal(await rpc('eth_getCode',[r.contractAddress,'latest']),'0x00'+b.toString('hex'));chunks.push(r.contractAddress);}
 const array=word(chunks.length)+chunks.map(a=>a.slice(2).padStart(64,'0')).join(''),constructor=word(64)+word(64+array.length/2)+array+tail(directory);
 for(const test of native.cases){
  const addresses=[];for(const creation of [artifact.bytecode.object,'0x'+patched.creation.toString('hex')])addresses.push((await send(creation+constructor,undefined,'CREATE '+test.name)).r.contractAddress);
  const rows=records(await readFile(nativeDir+'/O2/'+test.name+'/states.bin'));
  const commands=(await readFile(nativeDir+'/'+test.name+'.commands','utf8')).trim().split('\n').map(s=>s.split(' ').map(Number));
  const row={name:test.name,tics:test.tics,checkpoint:test.checkpoint,nativeExactRows:0,nativeFrames:[],replayExactRows:0,archives:[],repeatCycles:0};report.cases.push(row);
  const initialized=await pair(addresses,'initialize(uint8)',word(test.scenario),test.name+' startup');
  for(const r of initialized)assert.deepEqual(observation(r.r).state,rows[0]);row.nativeExactRows++;
  const outputs=[];let checkpointDigest,checkpointSnapshot;
  async function advance(tic,replay=false){const cmd=commands[tic-1];const body=[cmd[0],cmd[1],cmd[2],0,0,cmd[3],cmd[4]].map(word).join('');
   const r=await pair(addresses,'advance((int8,int8,int16,int16,uint8,uint8),bool)',body,test.name+(replay?' replay ':' tic ')+tic);
   const a=observation(r[0].r),b=observation(r[1].r);assert.deepEqual(a.state,rows[tic],test.name+' native tic '+tic);assert.deepEqual(a,b,'observer outputs differ');
   if(replay){assert.deepEqual(a,outputs[tic-1],'restore continuation differs');row.replayExactRows++;}else{outputs.push(a);row.nativeExactRows++;}
   if(cmd[4]){const path=nativeDir+'/O2/'+test.name+'/frame-'+String(tic).padStart(6,'0')+'.bin';const frame=await readFile(path);assert.deepEqual(a.pixels,frame,'native framebuffer '+test.name+' '+tic);
    if(!replay)row.nativeFrames.push({tic,sha256:sha(frame),all64000PixelsExact:true});}
  }
  async function archive(operation){const before=await sameRoots(addresses),r=await pair(addresses,operation==='save'?'save(uint8)':'load(uint8)',word(0),test.name+' '+operation);
   const after=await sameRoots(addresses);if(operation==='save')assert.deepEqual(after,before,'save changed roots');else assert.deepEqual(after,checkpointDigest,'load did not restore complete roots');
   const b=Buffer.from(r[1].r.logs.find(l=>l.topics[0]===archiveTopic).data.slice(2),'hex');const w=Array.from({length:4},(_,i)=>b.subarray(i*32,(i+1)*32));
   row.archives.push({operation,bytes:Number(BigInt('0x'+w[1].toString('hex'))),digest:w[2].toString('hex'),highWaterBytes:Number(BigInt('0x'+w[3].toString('hex'))),gas:r[0].row.gas,seconds:r[0].row.seconds});return after;
  }
  for(let tic=1;tic<=test.tics;tic++){await advance(tic);if(tic===test.checkpoint){checkpointDigest=await archive('save');checkpointSnapshot=bytes(await call(addresses[0],'snapshot()'),0);}}
  const terminalDigest=await sameRoots(addresses);row.terminalRootDigest=terminalDigest.toString('hex');
  for(let cycle=0;cycle<2;cycle++){await archive('load');assert.deepEqual(bytes(await call(addresses[0],'snapshot()'),0),checkpointSnapshot);
   for(let tic=test.checkpoint+1;tic<=test.tics;tic++)await advance(tic,true);
   assert.deepEqual(await sameRoots(addresses),terminalDigest,'complete roots after replay differ, including allocator chronology');row.repeatCycles++;}
  row.fullRootReplayExact=true;
  console.log('PASS exact native restore/replay',test.name,row.nativeExactRows,row.replayExactRows,row.nativeFrames.length,'frames');
 }
 report.pass=true;
}catch(error){report.error=String(error.stack??error);throw error;}
finally{
 if(child?.pid&&child.exitCode===null&&child.signalCode===null)await new Promise(done=>{child.once('exit',done);child.kill('SIGTERM');setTimeout(()=>{if(child.exitCode===null)child.kill('SIGKILL');},3000).unref();});
 report.endedUtc=new Date().toISOString();report.stoppedOwnedRuntime=!!child;
 await writeFile(dir+'/report.json',JSON.stringify(report,null,2)+'\n');await mkdir('artifacts/save-load',{recursive:true});
 await writeFile('artifacts/save-load/evm-continuation.json',JSON.stringify({...report,rawReportSha256:sha(await readFile(dir+'/report.json'))},null,2)+'\n');
}
