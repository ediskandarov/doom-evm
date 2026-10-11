import {readFile,writeFile} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {connect} from 'node:net';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const out='artifacts/local/ultimate-main-integration',port=19021,url=`http://127.0.0.1:${port}`;
const a=JSON.parse(await readFile(`${out}/OwnerPersistence.json`));
const method=name=>'0x'+a.methodIdentifiers[name];
const sha=b=>createHash('sha256').update(b).digest('hex');
const gas='0x2540be400',report={kind:'focused-owner-provenance-component-evm',pass:false,startedUTC:new Date().toISOString(),port,transactions:[],scope:'Synthetic source-owned owner fixture, ordinary CREATE and storage round-trip/DrawBounds rollback; not a replay or new commercial-resource admission proof.'};
let child,id=0,from,stderr='';
const rpc=async(method,params=[])=>{const r=await fetch(url,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(30000)});assert(r.ok);const j=await r.json();if(j.error)throw Object.assign(Error(JSON.stringify(j.error)),{data:j.error.data});return j.result;};
const wait=ms=>new Promise(done=>setTimeout(done,ms));
const call=(to,data)=>rpc('eth_call',[{from,to,data,gas},'latest']);
const send=async(data,to,status='0x1')=>{const hash=await rpc('eth_sendTransaction',[{from,data,gas,...(to?{to}:{})}]);let receipt;for(let i=0;i<1500&&!receipt;i++){receipt=await rpc('eth_getTransactionReceipt',[hash]);if(!receipt)await wait(20);}assert(receipt);assert.equal(receipt.status,status);report.transactions.push(receipt);return receipt;};
try{
 await new Promise((done,fail)=>{const s=connect({host:'127.0.0.1',port});s.once('connect',()=>{s.destroy();fail(Error('Occupied owned test port'));});s.once('error',e=>e.code==='ECONNREFUSED'?done():fail(e));});
 const args=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--gas-limit','10000000000','--memory-limit','1073741824','--silent'];
 child=spawn(resolve('.toolchain/bin/anvil'),args,{stdio:['ignore','ignore','pipe']});child.stderr.on('data',b=>stderr+=b);
 await new Promise((done,fail)=>{child.once('spawn',done);child.once('error',fail);});
 let ready=false;for(let i=0;i<500&&!ready;i++){if(child.exitCode!==null)throw Error(stderr);try{await rpc('web3_clientVersion');ready=true;}catch{await wait(20);}}assert(ready);[from]=await rpc('eth_accounts');
 const deployment=await send(a.bytecode.object),address=deployment.contractAddress;
 assert.equal(await rpc('eth_getCode',[address,'latest']),a.deployedBytecode.object);
 report.runtime={args,address,runtimeBytes:(a.deployedBytecode.object.length-2)/2,runtimeSha256:sha(Buffer.from(a.deployedBytecode.object.slice(2),'hex'))};
 const before=await call(address,method('digest()')),storageBefore=await rpc('eth_getProof',[address,[],'latest']);
 const encoded=Buffer.from((await call(address,method('read()'))).slice(2),'hex');
 const num=(b,at)=>Number(BigInt('0x'+b.subarray(at,at+32).toString('hex')));
 const bytes=(at)=>{const off=num(encoded,at),n=num(encoded,off);return encoded.subarray(off+32,off+32+n);};
 const data=bytes(0),provenance=bytes(32);assert.equal(data.length,40);assert.equal(provenance.length,40);
 assert.equal(data.subarray(8,16).toString('hex'),'1000000020000000');assert(provenance.subarray(8,16).every(v=>v===5));
 let rejected=false;try{await call(address,method('rejectedTransaction()'));}catch(e){assert.equal(e.data,'0x5b9a48fe');rejected=true;}assert(rejected);
 const failed=await send(method('rejectedTransaction()'),address,'0x0');assert.equal(failed.logs.length,0);
 assert.equal(await call(address,method('digest()')),before);assert.equal((await rpc('eth_getProof',[address,[],'latest'])).storageHash,storageBefore.storageHash);
 assert.equal(await call(address,method('read()')),'0x'+encoded.toString('hex'));
 report.ownerAddress='0x0000002000000010';report.provenance=5;report.ownerBytesLE=data.subarray(8,16).toString('hex');report.allSavedFieldsAndProvenanceUnchanged=true;report.fullStorageRootRollback=true;report.noFailureLogs=true;report.pass=true;
}catch(e){report.error=e.stack;process.exitCode=1;}
finally{if(child?.pid&&child.exitCode===null&&child.signalCode===null)await new Promise(done=>{child.once('exit',done);child.kill('SIGTERM');setTimeout(()=>{if(child.exitCode===null)child.kill('SIGKILL');},1500).unref();});report.ownedRuntimeStopped=!!child&&(child.exitCode!==null||child.signalCode!==null);report.endedUTC=new Date().toISOString();report.stderr=stderr;await writeFile(`${out}/owner-evm.json`,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({pass:report.pass,ownerAddress:report.ownerAddress,provenance:report.provenance,rollback:report.fullStorageRootRollback,ownedRuntimeStopped:report.ownedRuntimeStopped,error:report.error}));}
