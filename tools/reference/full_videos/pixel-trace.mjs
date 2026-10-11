// SPDX-License-Identifier: GPL-2.0-only
// Restore a verified checkpoint into a separate owned runtime; never attach to recording Anvil.
import {readFile,writeFile,unlink} from 'node:fs/promises';import {createReadStream,createWriteStream} from 'node:fs';import {createGunzip} from 'node:zlib';import {pipeline} from 'node:stream/promises';import {spawn} from 'node:child_process';import {connect} from 'node:net';import {createHash} from 'node:crypto';import assert from 'node:assert/strict';import {resolve} from 'node:path';
const base=resolve(process.argv[2]),cp=JSON.parse(await readFile(base+'/checkpoint.json'));const port=18959;const sha=b=>createHash('sha256').update(b).digest('hex');assert.equal(sha(await readFile(cp.chain.file)),cp.chain.sha256);
const source=Object.keys(cp.identity.sourceHashes).find(x=>x.endsWith('/src/support/FullSpeedrunProbe.sol'));assert(source);const observer=source.slice(0,-'/src/support/FullSpeedrunProbe.sol'.length);const artifact=JSON.parse(await readFile(resolve('artifacts/local/full-videos/observer-pixel-trace/out/FullSpeedrunProbe.sol/FullSpeedrunProbe.json')));
const word=n=>BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');const method=n=>'0x'+artifact.methodIdentifiers[n];
const load=base+'/rollback-restore.json';await pipeline(createReadStream(cp.chain.file),createGunzip(),createWriteStream(load));let child,id=0;let address=cp.report.address;const gas='0x'+BigInt(cp.identity.gasLimit).toString(16);let from;
async function rpc(method,params=[]){const r=await fetch('http://127.0.0.1:'+port,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params})});const x=await r.json();assert(!x.error,JSON.stringify(x.error));return x.result;}
async function call(name){return rpc('eth_call',[{from,to:address,data:method(name),gas},'latest']);}
const report={startedUTC:new Date().toISOString(),port,checkpointFrame:cp.report.frames.length,chainSHA256:cp.chain.sha256,checks:[],pass:false};
try {
 await new Promise((done,fail)=>{const s=connect({host:'127.0.0.1',port});s.on('connect',()=>{s.destroy();fail(Error('Occupied port'));});s.on('error',e=>e.code==='ECONNREFUSED'?done():fail(e));});
 child=spawn(resolve('.toolchain/bin/anvil'),['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--gas-limit',String(cp.identity.gasLimit),'--memory-limit',String(cp.identity.memory),'--no-request-size-limit','--load-state',load,'--silent'],{stdio:'ignore'});
 for(let i=0;;i++){try{[from]=await rpc('eth_accounts');break;}catch(e){if(i>100)throw e;await new Promise(r=>setTimeout(r,100));}}
 const bytesTail=b=>word(b.length)+b.toString('hex').padEnd(Math.ceil(b.length/32)*64,'0');
 async function send(data,to){const hash=await rpc('eth_sendTransaction',[{from,data,gas,...(to?{to}:{})}]);let r;while(!(r=await rpc('eth_getTransactionReceipt',[hash])))await new Promise(f=>setTimeout(f,25));assert.equal(r.status,'0x1');report.checks.push({hash,gas:Number(BigInt(r.gasUsed))});
  for(const e of r.logs){const event=artifact.abi.find(x=>x.type==='event'&&['DiagnosticAlloc','DiagnosticZone'].includes(x.name)&&x.inputs.length===2);
   for(const name of ['DiagnosticAlloc','DiagnosticZone']){const t=await rpc('web3_sha3',['0x'+Buffer.from(name+'(uint32,bytes)').toString('hex')]);if(e.topics[0]!==t)continue;
    const b=Buffer.from(e.data.slice(2),'hex'),offset=Number(BigInt('0x'+b.subarray(0,32).toString('hex'))),n=Number(BigInt('0x'+b.subarray(offset,offset+32).toString('hex'))),tic=Number(BigInt(e.topics[1]));
    const file=name+'-'+String(tic).padStart(6,'0')+'.bin';await writeFile(base+'/'+file,b.subarray(offset+32,offset+32+n));report.journalFiles??=[];report.journalFiles.push({name,tic,file,sha256:sha(b.subarray(offset+32,offset+32+n))});
   }
  }return r;}
 const chunks=cp.report.chunks,addresses=word(chunks.length)+chunks.map(x=>x.slice(2).padStart(64,'0')).join(''),directory=await readFile('artifacts/local/ultimate-speedruns/wad/directory.bin');
 const deployed=await send(artifact.bytecode.object+word(64)+word(64+addresses.length/2)+addresses+bytesTail(directory));address=deployed.contractAddress;report.newDiagnosticContract=address;report.replayedOriginalGameplayTics=84;report.parentResourcesOnly=true;
 const tape=JSON.parse(await readFile('artifacts/local/ultimate-speedruns/E1M2/tape.json'));
 await send(method('initializeMap(uint8,int32,int32,bool)')+word(3)+word(2)+word(tape.header.skill)+word(tape.header.nomonsters),address);
 await send(method('title()'),address);
 for(let i=0;i<84;i++)await send(method('advance(bytes)')+word(32)+bytesTail(Buffer.from(tape.commands[i].rawHex,'hex')),address);
 const r=await send(method('capture(uint32)')+word(84),address);
 const topic=await rpc('web3_sha3',['0x'+Buffer.from('VirtualSamples(uint32,bytes)').toString('hex')]);
 const log=r.logs.find(x=>x.topics[0]===topic);assert(log);const raw=Buffer.from(log.data.slice(2),'hex');const read=(b,n)=>Number(BigInt.asIntN(256,BigInt('0x'+b.subarray(n*32,(n+1)*32).toString('hex'))));const at=read(raw,0),len=read(raw,at/32),data=raw.subarray(at+32,at+32+len);report.pixelTraces=[];report.pixelTracesWordHex=[];
 for(let i=0;i<data.length;i+=512){report.pixelTraces.push(Array.from({length:16},(_,n)=>read(data.subarray(i,i+512),n)));report.pixelTracesWordHex.push(Array.from({length:16},(_,n)=>data.subarray(i+n*32,i+(n+1)*32).toString('hex')));}
 console.log(JSON.stringify(report.pixelTraces));
 report.pass=true;
}finally{if(child&&child.exitCode===null)await new Promise(done=>{child.on('exit',done);child.kill('SIGTERM');});report.ownedRuntimeStopped=true;report.endedUTC=new Date().toISOString();await unlink(load);await writeFile(base+'/pixel-journal.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));}
