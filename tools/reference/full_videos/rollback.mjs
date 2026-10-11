// SPDX-License-Identifier: GPL-2.0-only
// Restore a verified checkpoint into a separate owned runtime; never attach to recording Anvil.
import {readFile,writeFile,unlink} from 'node:fs/promises';import {createReadStream,createWriteStream} from 'node:fs';import {createGunzip} from 'node:zlib';import {pipeline} from 'node:stream/promises';import {spawn} from 'node:child_process';import {connect} from 'node:net';import {createHash} from 'node:crypto';import assert from 'node:assert/strict';import {resolve} from 'node:path';
const base=resolve(process.argv[2]),cp=JSON.parse(await readFile(base+'/checkpoint.json'));const port=18959;const sha=b=>createHash('sha256').update(b).digest('hex');assert.equal(sha(await readFile(cp.chain.file)),cp.chain.sha256);
const artifact=JSON.parse(await readFile('artifacts/local/full-videos/observer/out/FullSpeedrunProbe.sol/FullSpeedrunProbe.json'));assert.equal(sha(JSON.stringify(artifact.abi)),cp.identity.abiSha256);
const word=n=>BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');const method=n=>'0x'+artifact.methodIdentifiers[n];
const load=base+'/rollback-restore.json';await pipeline(createReadStream(cp.chain.file),createGunzip(),createWriteStream(load));let child,id=0;const address=cp.report.address,gas='0x'+BigInt(cp.identity.gasLimit).toString(16);let from;
async function rpc(method,params=[]){const r=await fetch('http://127.0.0.1:'+port,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params})});const x=await r.json();assert(!x.error,JSON.stringify(x.error));return x.result;}
async function call(name){return rpc('eth_call',[{from,to:address,data:method(name),gas},'latest']);}
const report={startedUTC:new Date().toISOString(),port,checkpointFrame:cp.report.frames.length,chainSHA256:cp.chain.sha256,checks:[],pass:false};
try {
 await new Promise((done,fail)=>{const s=connect({host:'127.0.0.1',port});s.on('connect',()=>{s.destroy();fail(Error('Occupied port'));});s.on('error',e=>e.code==='ECONNREFUSED'?done():fail(e));});
 child=spawn(resolve('.toolchain/bin/anvil'),['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--gas-limit',String(cp.identity.gasLimit),'--memory-limit',String(cp.identity.memory),'--no-request-size-limit','--load-state',load,'--silent'],{stdio:'ignore'});
 for(let i=0;;i++){try{[from]=await rpc('eth_accounts');break;}catch(e){if(i>100)throw e;await new Promise(r=>setTimeout(r,100));}}
 for(const [name,data] of [['capture(uint32)',word(0)],['capture(uint32)',word(cp.report.gameplayTics+1)],['stepWipe()',''],['presentationTick(bytes,bool)',word(64)+word(0)+word(4)+'00000000'.padEnd(64,'0')],['initializeMap(uint8,int32,int32,bool)',word(3)+word(1)+word(3)+word(0)]]){
  const before={};for(const n of ['savedDigest()','presentationDigest()','frameId()','snapshot()','presentationState()'])before[n]=await call(n);
  const hash=await rpc('eth_sendTransaction',[{from,to:address,data:method(name)+data,gas}]);let receipt;while(!(receipt=await rpc('eth_getTransactionReceipt',[hash])))await new Promise(r=>setTimeout(r,25));assert.equal(receipt.status,'0x0');assert.equal(receipt.logs.length,0);
  for(const n of Object.keys(before))assert.equal(await call(n),before[n]);report.checks.push({name,hash,gas:Number(BigInt(receipt.gasUsed)),allSavedAndPresentationFieldsUnchanged:true,noLogs:true});
 }
 report.pass=true;
}finally{if(child&&child.exitCode===null)await new Promise(done=>{child.on('exit',done);child.kill('SIGTERM');});report.ownedRuntimeStopped=true;report.endedUTC=new Date().toISOString();await unlink(load);await writeFile(base+'/rollback.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));}
