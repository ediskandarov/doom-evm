// SPDX-License-Identifier: GPL-2.0-only
// Architecture gate: ordinary CREATE and actual authenticated EVM startup only.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {connect} from 'node:net';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {gzipSync} from 'node:zlib';
import assert from 'node:assert/strict';

const args=process.argv.slice(2),opt=(n,d)=>args.includes(n)?args[args.indexOf(n)+1]:d;
const port=Number(opt('--port','19391')),dir=opt('--output','artifacts/local/save-load/cost');
const source=opt('--resource-dir','/Users/eduard/sandbox/doom-evm/artifacts/local/wad');
assert(![18880,8088].includes(port));await mkdir(dir,{recursive:true});
const sha=b=>createHash('sha256').update(b).digest('hex');
const json=async p=>JSON.parse(await readFile(p));
const word=n=>BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');
const tail=b=>word(b.length)+b.toString('hex').padEnd(Math.ceil(b.length/32)*64,'0');
const probe=await json('out/SaveCostProbe.sol/SaveCostProbe.json');
const store=await json('out/ResourceStore.sol/ResourceStore.json');
const bundle=await json(source+'/bundle.json'),blob=await readFile(source+'/resources.bin');
assert.equal(sha(blob),bundle.blobSha256);
const directory=Buffer.alloc(bundle.lumps.length*16);
for(let i=0;i<bundle.lumps.length;i++){
 const l=bundle.lumps[i];Buffer.from(l.nameHex,'hex').copy(directory,i*16);
 directory.writeUInt32LE(l.offset,i*16+8);directory.writeUInt32LE(l.length,i*16+12);
}
let child,id=0,from;
const budget=Number(opt('--gas-limit','10000000000')),gas='0x'+BigInt(budget).toString(16);
const report={kind:'save-load-actual-state-architecture-cost-gate',pass:false,startedUtc:new Date().toISOString(),port,
 gasLimit:budget,resourceIdentity:bundle.resourceIdentity,measurements:[],transactions:[],sourceHashes:{},notes:[
 'Same initialized authentic Freedoom E1M1 world for every architecture. No Anvil state import or snapshot/revert.',
 'Typed root copies, ABI bytes, packed schema words and packed immutable16KiB code chunks compared.',
 'All resources and engines use ordinary CREATE; restore must retain the exact packed-root digest.',
 'Transaction wall time includes RPC/mining. This gate does not measure peak EVM MSIZE; final instrumentation is separate.']};
for(const p of Object.keys(probe.metadata.sources))report.sourceHashes[p]=sha(await readFile(p));
async function rpc(method,params=[]){const r=await fetch('http://127.0.0.1:'+port,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(300000)});const b=await r.json();if(b.error)throw Error(method+JSON.stringify(b.error));return b.result;}
async function send(data,to,label){const start=performance.now(),hash=await rpc('eth_sendTransaction',[{from,data,gas,...(to?{to}:{})}]);let r;while(!(r=await rpc('eth_getTransactionReceipt',[hash])))await new Promise(f=>setTimeout(f,20));
 const row={label,hash,status:r.status,gasUsed:Number(BigInt(r.gasUsed)),seconds:(performance.now()-start)/1000};report.transactions.push(row);
 await writeFile(dir+'/'+hash+'.receipt.json.gz',gzipSync(JSON.stringify(r)));return {r,row};}
try{
 await new Promise((done,fail)=>{const s=connect({host:'127.0.0.1',port});s.once('connect',()=>{s.destroy();fail(Error('Occupied dedicated port'));});s.once('error',e=>e.code==='ECONNREFUSED'?done():fail(e));});
 const argv=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--gas-limit',String(budget),'--memory-limit','1073741824','--no-request-size-limit','--prune-history','2','--transaction-block-keeper','2','--silent'];
 child=spawn(resolve('.toolchain/bin/anvil'),argv,{stdio:'ignore'});report.runtime={ownedPid:child.pid,args:argv};
 for(let i=0;;i++){try{[from]=await rpc('eth_accounts');break;}catch(e){if(i>100)throw e;await new Promise(f=>setTimeout(f,100));}}
 const chunks=[];
 for(let p=0;p<blob.length;p+=16384){const b=blob.subarray(p,p+16384),{r}=await send(store.bytecode.object+word(32)+tail(b),undefined,'resource');assert.equal(r.status,'0x1');assert.equal(await rpc('eth_getCode',[r.contractAddress,'latest']),'0x00'+b.toString('hex'));chunks.push(r.contractAddress);}
 const array=word(chunks.length)+chunks.map(a=>a.slice(2).padStart(64,'0')).join('');
 const {r:deployment}=await send(probe.bytecode.object+word(64)+word(64+array.length/2)+array+tail(directory),undefined,'probe CREATE');assert.equal(deployment.status,'0x1');const address=deployment.contractAddress;
 const data=(sig,body='')=>'0x'+probe.methodIdentifiers[sig]+body;
 const call=async sig=>rpc('eth_call',[{from,to:address,data:data(sig),gas},'latest']);
 assert.equal((await send(data('initialize(int32)',word(1)),address,'actual EVM initialization')).r.status,'0x1');
 const original=await call('digest()');
 for(const [kind,name] of ['typed storage roots','ABI bytes storage','packed schema storage','packed immutable code'].entries()){
  const {r,row}=await send(data('measure(uint8)',word(kind)),address,'save '+name);assert.equal(r.status,'0x1');
  const v=r.logs.at(-1).data.slice(2).match(/.{64}/g);const bytesLength=Number(BigInt('0x'+v[1]));
  const operationGas=Number(BigInt('0x'+v[2]));if(kind>=2)assert.equal('0x'+v[3],original);
  assert.equal((await send(data('corrupt()'),address,'diverge '+name)).r.status,'0x1');assert.notEqual(await call('digest()'),original);
  const restored=await send(data('restore(uint8)',word(kind)),address,'restore '+name);assert.equal(restored.r.status,'0x1');assert.equal(await call('digest()'),original);
  report.measurements.push({kind,name,bytesLength,saveGas:row.gasUsed,operationGas,saveSeconds:row.seconds,restoreGas:restored.row.gasUsed,restoreSeconds:restored.row.seconds,exactRestore:true,
    packedPayloadWords:kind===2?bytesLength/32:undefined,immutableChunks:kind===3?Math.ceil(bytesLength/16384):undefined});
  const overwrite=await send(data('measure(uint8)',word(kind)),address,'overwrite '+name);assert.equal(overwrite.r.status,'0x1');
  report.measurements.at(-1).overwriteGas=overwrite.row.gasUsed;
  report.measurements.at(-1).overwriteSeconds=overwrite.row.seconds;
  assert.equal(await call('digest()'),original);
  console.log('PASS architecture',report.measurements.at(-1));
 }
 report.pass=true;
}catch(error){report.error=String(error.stack??error);throw error;}
finally{
 if(child?.pid&&child.exitCode===null&&child.signalCode===null)await new Promise(done=>{child.once('exit',done);child.kill('SIGTERM');setTimeout(()=>{if(child.exitCode===null)child.kill('SIGKILL');},3000).unref();});
 report.endedUtc=new Date().toISOString();report.stoppedOwnedRuntime=!!child;
 await writeFile(dir+'/report.json',JSON.stringify(report,null,2)+'\n');
 await mkdir('artifacts/save-load',{recursive:true});
 await writeFile('artifacts/save-load/architecture-cost.json',JSON.stringify({...report,transactions:report.transactions.filter(x=>x.label!=='resource'),rawReportSha256:sha(await readFile(dir+'/report.json'))},null,2)+'\n');
}
