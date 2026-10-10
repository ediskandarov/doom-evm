#!/usr/bin/env node
// Dedicated ordinary-EVM raw-key and storage proof; never changes production adapters.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {spawn,execFileSync} from 'node:child_process';
import {connect} from 'node:net';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
import {loadGasBudget} from '../../execution-budget.mjs';
const port=Number(process.env.CHEATS_PORT??18695);
assert(port>1024&&port<65536&&![18579,18690,18694].includes(port));
const output=process.env.CHEATS_REPORT??'artifacts/phase4/cheats-evm.json';
const {gasHex,gasLimit}=loadGasBudget();
const hash=b=>createHash('sha256').update(b).digest('hex');
const artifact=JSON.parse(await readFile('out/CheatProbe.sol/CheatProbe.json','utf8'));
const cases=JSON.parse(await readFile('test/fixtures/phase4_cheats/cases.json','utf8'));
const cast=(...args)=>execFileSync(resolve('.toolchain/bin/cast'),args,{encoding:'utf8'}).trim();
const calldata=(sig,...args)=>cast('calldata',sig,...args);
let child,stderr='',id=0;
const url=`http://127.0.0.1:${port}`;
async function rpc(method,params=[]){
 const r=await fetch(url,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(120000)});
 const data=await r.json();if(data.error)throw Error(JSON.stringify(data.error));return data.result;
}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function send(from,to,data){
 const tx=await rpc('eth_sendTransaction',[{from,...(to?{to}:{}),data,gas:gasHex}]);
 const deadline=Date.now()+120000;while(Date.now()<deadline){const r=await rpc('eth_getTransactionReceipt',[tx]);if(r)return r;await sleep(25);}throw Error('receipt deadline');
}
const chosen=['iddqd','idkfa','idfa','idspispopd','idclip','idbeholdv','idbeholds','idbeholdi','idbeholdr','idbeholda','idbeholdl','idchoppers','idmypos','warp-0-3139','warp-2-3131','iddt','dt-gated-interleave','netgame','st-high-key-bits','music-excluded'];
try{
 const occupied=await new Promise(resolve=>{const s=connect({host:'127.0.0.1',port});s.once('connect',()=>{s.destroy();resolve(true);});s.once('error',()=>resolve(false));s.setTimeout(1000,()=>{s.destroy();resolve(true);});});assert(!occupied,'port occupied; refusing existing node');
 child=spawn(resolve('.toolchain/bin/anvil'),['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--gas-limit',String(gasLimit),'--memory-limit','1073741824','--silent'],{stdio:['ignore','ignore','pipe']});
 child.stderr.on('data',b=>{stderr+=b;});
 const ready=Date.now()+15000;while(true){try{await rpc('eth_chainId');break;}catch(e){if(Date.now()>ready)throw Error('Anvil start failed: '+stderr);await sleep(50);}}
 const [from]=await rpc('eth_accounts');const deploy=await send(from,null,artifact.bytecode.object);assert.equal(deploy.status,'0x1');const address=deploy.contractAddress;
 const runtime=await rpc('eth_getCode',[address,'latest']);const rows=[];let snapshots=0;
 const observe=()=>rpc('eth_call',[{to:address,data:calldata('observe()')},'latest']);
 const sequence=async()=>Number(BigInt(await rpc('eth_call',[{to:address,data:calldata('inputSeq()')},'latest'])));
 for(const name of chosen){
  const native=cases.find(c=>c.name===name);assert(native,name);
  const reset=await send(from,address,calldata('reset(int32[8])','['+native.initial.join(',')+']'));assert.equal(reset.status,'0x1');
  let seq=0,at=0;const transactions=[];
  // Irregular chunks split all prefixes; warp chunks split both raw parameter slots.
  while(at<native.events.length){
   const n=Math.min([2,1,3,1,1,4][seq%6],native.events.length-at);const events=native.events.slice(at,at+n);
   const data=calldata('rawEvents(uint32,int32[4][],bool)',String(++seq),'['+events.map(e=>'['+e.join(',')+']').join(',')+']','false');
   const r=await send(from,address,data);assert.equal(r.status,'0x1');assert.equal(r.logs.length,n);
   for(let i=0;i<n;i++){
    assert.equal(BigInt(r.logs[i].topics[1]),BigInt(seq));assert.equal(BigInt(r.logs[i].topics[2]),BigInt(i));
    assert.equal(r.logs[i].data,'0x'+native.snapshotSha256[at+i],name+' event '+(at+i));snapshots++;
   }
   assert.equal(await observe(),'0x'+native.snapshotSha256[at+n-1]);assert.equal(await sequence(),seq);
   transactions.push({transaction:r.transactionHash,gasUsed:Number(BigInt(r.gasUsed)),events:n});at+=n;
  }
  rows.push({nativeCase:name,events:native.events.length,resetTransaction:reset.transactionHash,transactions});
 }
 // Mined downstream failure rolls back both partially recognized input and mutations.
 const fresh=cases.find(c=>c.name==='iddqd');await send(from,address,calldata('reset(int32[8])','['+fresh.initial.join(',')+']'));
 const prefix=fresh.events.slice(0,4);const first=await send(from,address,calldata('rawEvents(uint32,int32[4][],bool)','1','['+prefix.map(e=>'['+e.join(',')+']').join(',')+']','false'));assert.equal(first.status,'0x1');
 const before=await observe();const finish='[[0,100,1,0]]';
 const reverted=await send(from,address,calldata('rawEvents(uint32,int32[4][],bool)','2',finish,'true'));assert.equal(reverted.status,'0x0');assert.equal(reverted.logs.length,0);assert.equal(await observe(),before);assert.equal(await sequence(),1);
 const success=await send(from,address,calldata('rawEvents(uint32,int32[4][],bool)','2',finish,'false'));assert.equal(success.status,'0x1');assert.equal(await observe(),'0x'+fresh.snapshotSha256[4]);
 const duplicate=await send(from,address,calldata('rawEvents(uint32,int32[4][],bool)','2',finish,'false'));assert.equal(duplicate.status,'0x0');assert.equal(duplicate.logs.length,0);assert.equal(await observe(),'0x'+fresh.snapshotSha256[4]);assert.equal(await sequence(),2);
 const sources={};for(const p of ['src/doom/m_cheat.sol','src/doom/st_cheats.sol','src/support/CheatFixture.sol','src/support/CheatProbe.sol','tools/reference/cheats/evm.mjs','test/fixtures/phase4_cheats/cases.json','test/fixtures/phase4_cheats/manifest.json','foundry.toml','execution-budget.json'])sources[p]=hash(await readFile(p));
 const report={schemaVersion:1,goal:'4.4',pass:true,scope:'Dedicated raw-key support probe, actual Solidity cheat modules and original-C event hashes across ordinary transactions. Production adapters/browser, AM pixels and actual map load are not integrated.',rpcPort:port,gasBudget:gasLimit,compiler:artifact.metadata.compiler,settings:artifact.metadata.settings,contract:address,creationTransaction:deploy.transactionHash,deploymentGas:Number(BigInt(deploy.gasUsed)),runtimeBytes:(runtime.length-2)/2,runtimeSha256:hash(Buffer.from(runtime.slice(2),'hex')),cases:rows.length,snapshots,rows,rollback:{transaction:reverted.transactionHash,status:reverted.status,gasUsed:Number(BigInt(reverted.gasUsed)),logs:0,parserAndPlayerUnchanged:true,inputSeqUnchanged:true,retryTransaction:success.transactionHash,retryOriginalCMatch:true,duplicateTransaction:duplicate.transactionHash,duplicateStatus:duplicate.status},sourceSha256:sources};
 await mkdir(resolve(output,'..'),{recursive:true});await writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({pass:true,cases:rows.length,snapshots,transactions:rows.reduce((n,r)=>n+r.transactions.length,0),deploymentGas:report.deploymentGas,report:output}));
}finally{if(child?.exitCode===null)await new Promise(resolve=>{child.once('exit',resolve);child.kill('SIGTERM');});}
