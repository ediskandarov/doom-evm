// SPDX-License-Identifier: GPL-2.0-only
// Focused real transactions; comparison-only native pixels never enter EVM.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {connect} from 'node:net';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {gunzipSync,gzipSync} from 'node:zlib';
import assert from 'node:assert/strict';
import {decodeFrame,FRAME_TOPIC} from '../../../web/protocol.mjs';
const dir='artifacts/local/full-options-main/e1m2-evm',port=19374,gas='0x2540be400';
await mkdir(dir,{recursive:true});
const sha=b=>createHash('sha256').update(b).digest('hex');
const json=async p=>JSON.parse(await readFile(p));
const word=n=>BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');
const tail=b=>word(b.length)+b.toString('hex').padEnd(Math.ceil(b.length/32)*64,'0');
const uint=(b,at)=>Number(BigInt('0x'+b.subarray(at,at+32).toString('hex')));
const signed=(b,at)=>Number(BigInt.asIntN(256,BigInt('0x'+b.subarray(at,at+32).toString('hex'))));
const bytes=(b,at)=>{const offset=uint(b,at),n=uint(b,offset);assert(offset+32+n<=b.length);return b.subarray(offset+32,offset+32+n);};
const baseline=await json('out/FullSpeedrunProbe.sol/FullSpeedrunProbe.json');
const composed=await json('artifacts/local/full-options-main/observer/out/FullSpeedrunProbe.sol/FullSpeedrunProbe.json');
const store=await json('out/ResourceStore.sol/ResourceStore.json');
const bundle=await json('artifacts/local/ultimate-speedruns/wad/bundle.json');
const blob=await readFile('artifacts/local/ultimate-speedruns/wad/resources.bin');
const directory=await readFile('artifacts/local/ultimate-speedruns/wad/directory.bin');assert.equal(sha(blob),bundle.blobSha256);
const native=await json('artifacts/local/full-options-main/e1m2-native/result.json');assert(native.pass_);
const tape=await json('artifacts/local/ultimate-speedruns/E1M2/tape.json');
const info=await json('artifacts/local/ultimate-speedruns/E1M2/native-result.json');
const demo=await readFile('artifacts/local/ultimate-speedruns/E1M2/source-download');assert.equal(sha(demo),info.demoSha256);
assert.equal(Buffer.concat(tape.commands.map(c=>Buffer.from(c.rawHex,'hex'))).toString('hex'),demo.subarray(13,13+tape.commands.length*4).toString('hex'));
const delta=gunzipSync(await readFile('artifacts/local/ultimate-speedruns/E1M2/native-states.delta.bin.gz'));let position=0,previous=Buffer.alloc(0);const states=[];
while(position<delta.length){const n=delta.readUInt32BE(position);position+=4;const row=Buffer.alloc(n);for(let i=0;i<n;i++)row[i]=delta[position+i]^(previous[i]??0);position+=n;states.push(row);previous=row;}
let child,from,id=0,presentationTopic,paletteTopic;
const report={kind:'focused combined-main native/EVM display boundaries',startedUtc:new Date().toISOString(),pass:false,port,transactions:[],frames:[],rollbacks:[],checks:[],sourceHashes:{},nativeReferenceSha256:sha(await readFile('artifacts/local/full-options-main/e1m2-native/result.json')),demoSha256:sha(demo),resourceIdentity:bundle.resourceIdentity};
for(const a of [baseline,composed])for(const p of Object.keys(a.metadata.sources))report.sourceHashes[p]=sha(await readFile(p));
async function rpc(method,params=[]){const r=await fetch('http://127.0.0.1:'+port,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(300000)});const b=await r.json();if(b.error)throw Error(method+JSON.stringify(b.error));return b.result;}
async function send(data,to,kind,limit=gas,sender=from){const began=performance.now(),hash=await rpc('eth_sendTransaction',[{from:sender,data,gas:limit,...(to?{to}:{})}]);let r;while(!(r=await rpc('eth_getTransactionReceipt',[hash])))await new Promise(f=>setTimeout(f,20));const file=dir+'/'+hash+'.json.gz';await writeFile(file,gzipSync(JSON.stringify(r)));report.transactions.push({kind,hash,status:r.status,gasUsed:Number(BigInt(r.gasUsed)),seconds:(performance.now()-began)/1000,receipt:file,receiptSha256:sha(await readFile(file))});return r;}
function consumer(artifact,address,name){
 const method=sig=>'0x'+artifact.methodIdentifiers[sig];
 const call=async(sig,data='')=>Buffer.from((await rpc('eth_call',[{from,to:address,data:method(sig)+data,gas},'latest'])).slice(2),'hex');
 return {artifact,address,name,method,call};
}
async function nativeCompare(frame,folder,file){
 for(const profile of ['O2','O0','sanitize']){
  const path='artifacts/local/full-options-main/e1m2-native/'+profile+'/'+folder+'/'+file;
  const pixels=await readFile(path);assert.deepEqual(frame.pixels,pixels,name(frame)+' first native indexed divergence '+profile+'/'+folder+'/'+file);
  const palette=file.startsWith('gameplay-')?path.replace('.indexed8','.palette'):path.replace(file,'palette-'+file.split('-')[0]+'.bin');
  assert.deepEqual(frame.rgb,await readFile(palette),'native FramePalette '+path);
 }
 frame.row.nativePixelsAndPaletteExact=true;frame.row.nativeReference={folder,file,profiles:['O2','O0','sanitize']};
}
const name=f=>f.row.consumer+' frame'+f.row.frameId;
async function receiptFrame(c,r,label){
 assert.equal(r.status,'0x1',label+' reverted');const log=r.logs.find(l=>l.topics[0]===FRAME_TOPIC);assert(log,label+' lacks Frame');
 const f=decodeFrame(log),pal=r.logs.find(l=>l.topics[0]===paletteTopic);assert(pal);assert.equal(pal.topics.length,2);assert.equal(BigInt(pal.topics[1]),f.frameId);assert.equal(pal.address.toLowerCase(),c.address.toLowerCase());assert.equal(pal.transactionHash,log.transactionHash);assert.equal(pal.blockHash,log.blockHash);
 const paletteData=Buffer.from(pal.data.slice(2),'hex'),rgb=bytes(paletteData,32),pixels=Buffer.from(f.pixels);assert.equal(pixels.length,64000);assert.equal(rgb.length,768);
 const data=Buffer.from(r.logs.find(l=>l.topics[0]===presentationTopic).data.slice(2),'hex');
 const row={consumer:c.name,label,frameId:Number(f.frameId),kind:uint(data,0),demoTic:uint(data,32),gameplayTic:uint(data,64),rng:uint(data,96),state:signed(data,128),stage:signed(data,160),count:signed(data,192),statsHex:bytes(data,224).toString('hex'),pixelSha256:sha(pixels),paletteSha256:sha(rgb),paletteBank:signed(paletteData,0),transaction:r.transactionHash};
 assert.equal(row.frameId,report.frames.filter(x=>x.consumer===c.name).length+1);
 const stem=dir+'/'+c.name+'-'+row.frameId;await writeFile(stem+'.indexed8',pixels);await writeFile(stem+'.palette',rgb);row.localPixels=stem+'.indexed8';row.localPalette=stem+'.palette';report.frames.push(row);return {row,pixels,rgb};
}
async function display(c,sig,data='',label=sig){const before=await c.call('snapshot()'),digest=await c.call('savedDigest()');const r=await send(c.method(sig)+data,c.address,c.name+':'+sig);const f=await receiptFrame(c,r,label);assert.deepEqual(await c.call('snapshot()'),before,'display advanced canonical gameplay');assert.deepEqual(await c.call('savedDigest()'),digest);f.row.gameplayFrozen=true;return f;}
async function drain(c,reference){let index=0;while(uint(await c.call('wipeActive()'),0)){const f=await display(c,'stepWipe()');if(reference){assert(index<reference.length);await compareMetadata(f,reference[index++]);}}if(reference)assert.equal(index,reference.length);}
function rows(folder){const records=native.profiles.O2.rows[folder];return Object.keys(records).filter(x=>x.endsWith('.indexed8')&&!x.startsWith('gameplay-')).sort().map(file=>{const [seq,kind,demoTic,gameplayTic,rng,stage,count]=file.split('.')[0].split('-').map(Number);return {file,folder,seq,kind,demoTic,gameplayTic,rng,stage,count};});}
async function compareMetadata(f,r){for(const key of ['kind','demoTic','gameplayTic','rng','stage','count'])assert.equal(f.row[key],r[key],key+' '+name(f));await nativeCompare(f,r.folder,r.file);}
async function rollback(c,sig,data,label,limit=gas,sender=from){const before=await rpc('eth_getProof',[c.address,[],'latest']);const frame=await c.call('frameId()');const snapshot=await c.call('snapshot()');const r=await send(c.method(sig)+data,c.address,c.name+':rollback '+label,limit,sender);assert.equal(r.status,'0x0');assert.equal(r.logs.length,0);assert.equal((await rpc('eth_getProof',[c.address,[],'latest'])).storageHash,before.storageHash);assert.deepEqual(await c.call('frameId()'),frame);assert.deepEqual(await c.call('snapshot()'),snapshot);report.rollbacks.push({consumer:c.name,label,transaction:r.transactionHash,allStorageUnchanged:true,storageRoot:before.storageHash,noLogs:true});}
async function deploy(artifact,chunks,map,name){const array=word(chunks.length)+chunks.map(x=>x.slice(2).padStart(64,'0')).join('');const r=await send(artifact.bytecode.object+word(64)+word(64+array.length/2)+array+tail(directory),undefined,name+':deployment');assert.equal(r.status,'0x1');const c=consumer(artifact,r.contractAddress,name);const init=await send(c.method('initializeMap(uint8,int32,int32,bool)')+word(3)+word(map)+word(tape.header.skill)+word(tape.header.nomonsters),c.address,name+':startup');assert.equal(init.status,'0x1');return c;}
try{
 await new Promise((done,fail)=>{const s=connect({host:'127.0.0.1',port});s.once('connect',()=>{s.destroy();fail(Error('Occupied dedicated port'));});s.once('error',e=>e.code==='ECONNREFUSED'?done():fail(e));});
 const args=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--gas-limit','10000000000','--memory-limit','1073741824','--no-request-size-limit','--prune-history','2','--transaction-block-keeper','2','--silent'];child=spawn(resolve('.toolchain/bin/anvil'),args,{stdio:'ignore'});report.ownedPid=child.pid;report.anvilArgs=args;
 for(let i=0;;i++){try{[from]=await rpc('eth_accounts');break;}catch(e){if(i>100)throw e;await new Promise(f=>setTimeout(f,100));}}
 const event=baseline.abi.find(x=>x.name==='Presentation');presentationTopic=await rpc('web3_sha3',['0x'+Buffer.from('Presentation('+event.inputs.map(x=>x.type).join(',')+')').toString('hex')]);paletteTopic=await rpc('web3_sha3',['0x'+Buffer.from('FramePalette(uint64,int32,bytes)').toString('hex')]);
 const chunks=[];for(let offset=0;offset<blob.length;offset+=16384){const b=blob.subarray(offset,offset+16384),r=await send(store.bytecode.object+word(32)+tail(b),undefined,'authenticated resource');assert.equal(r.status,'0x1');assert.equal(await rpc('eth_getCode',[r.contractAddress,'latest']),'0x00'+b.toString('hex'));chunks.push(r.contractAddress);}
 for(const stress of [false]){
  const c=await deploy(stress?composed:baseline,chunks,2,stress?'options-stress':'unmodified-recorder');const initial=bytes(await c.call('snapshot()'),0);assert.deepEqual(initial,states[0]);let matched=1;
  const title=await display(c,'title()');

  for(let tic=1;tic<=84;tic++){
   const raw=Buffer.from(tape.commands[tic-1].rawHex,'hex');const r=await send(c.method('advance(bytes)')+word(32)+tail(raw),c.address,c.name+':authentic gameplay');assert.equal(r.status,'0x1');const obs=Buffer.from(r.logs[0].data.slice(2),'hex');assert.equal(uint(obs,0),tic);assert.deepEqual(bytes(obs,32),states[tic]);matched++;
   if([1,20,84].includes(tic)){
    const f=await display(c,'capture(uint32)',word(tic));
    if(tic===1){
     assert.equal(f.row.kind,2);let at=0;
     const compareEntry=async frame=>{const ref=native.entryWipe.frames[at++];assert(ref);assert.deepEqual(frame.pixels,await readFile('artifacts/local/full-options-main/e1m2-native/entry-wipe/'+ref.file));assert.equal(frame.row.rng,65);assert.deepEqual(frame.rgb,title.rgb);frame.row.nativePixelsAndPaletteExact=true;frame.row.nativeReference={entryWipeStep:at,seed:1,originalNativeMelt:true};};
     await compareEntry(f);await rollback(c,'advance(bytes)',word(32)+tail(raw),'gameplay rejected during blocking melt');
     while(uint(await c.call('wipeActive()'),0))await compareEntry(await display(c,'stepWipe()'));
     assert.equal(at,native.entryWipe.frames.length);
    }
    else await nativeCompare(f,tic===20?'tic20':'tic84','gameplay-'+String(tic).padStart(6,'0')+'.indexed8');
    if(stress&&tic===20){
     const settings=[[27],[111,13],[115],[174],[27],[27],[111,13],[115],[172],[27]];
     for(const keys of settings){const packet=Buffer.from(keys.flatMap(k=>[0,k]));const frame=await display(c,'optionEvents(bytes)',word(32)+tail(packet),'actual accepted Options packet '+keys.join(','));if(keys[0]===27&&uint(await c.call('testOptionsStatus()'),0)===0)await nativeCompare(frame,uint(await c.call('testOptionsStatus()'),32)===11?'tic20-full':'tic20-restored','gameplay-000020.indexed8');}
     assert.equal(uint(await c.call('testOptionsStatus()'),0),0);assert.equal(uint(await c.call('testOptionsStatus()'),32),10);
     await rollback(c,'optionEvents(bytes)',word(32)+tail(Buffer.from([0,27,2,0])),'invalid Options packet');
    }
   }
  }
  assert.equal(matched,85);assert.deepEqual(bytes(await c.call('snapshot()'),0),states[84]);
  const final=report.frames.at(-1);assert.equal((await readFile(final.localPixels))[106*320+290],8);
  report.checks.push({label:'Corrected borrowed UI E1M2 tic84: all framebuffer/palette bytes native-exact; sampled final pixel8',pass:true,canonicalSnapshots:85,gameplayTics:84,notFullE1M2Replay:true});

 }
 report.pass=true;
}catch(error){report.error=error.stack;console.error(error.stack);process.exitCode=1;}
finally{if(child&&child.exitCode===null)await new Promise(done=>{child.once('exit',done);child.kill('SIGTERM');});report.ownedRuntimeStopped=true;report.endedUtc=new Date().toISOString();await writeFile(dir+'/result.json',JSON.stringify(report,null,2)+'\n');console.log('Report',dir+'/result.json');}
