// SPDX-License-Identifier: GPL-2.0-only
// Ordinary CREATE/startup: native bytes are comparison outputs, never engine input.
import {readFile, writeFile, mkdir, open} from 'node:fs/promises';
import {spawn, execFileSync} from 'node:child_process';
import {connect} from 'node:net';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {loadGasBudget} from '../../execution-budget.mjs';
import {verifyEpisode} from '../../wad/episode.ts';

const args=process.argv.slice(2), option=(n,d)=>args.includes(n)?args[args.indexOf(n)+1]:d;
const port=Number(option('--port','18713')), output=option('--output','artifacts/phase4/episode-startup/evm.json');
assert(Number.isInteger(port)&&port>1024&&port<65536&&![18880,8088].includes(port));
const sha=b=>createHash('sha256').update(b).digest('hex');
const json=async p=>JSON.parse(await readFile(p,'utf8'));
const word=n=>BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');
const tail=b=>word(b.length)+b.toString('hex').padEnd(Math.ceil(b.length/32)*64,'0');
const budget=loadGasBudget(), gas=budget.gasHex;
const bundle=await json('artifacts/local/wad/bundle.json'), catalog=await json('artifacts/local/wad/episode.json');
const blob=await readFile('artifacts/local/wad/resources.bin'), directory=await readFile('test/fixtures/phase2_data/directory.bin');
verifyEpisode(await readFile('artifacts/local/freedoom/freedoom1.wad'),catalog,bundle,blob);
const native=await json('test/fixtures/phase4_episode_startup/manifest.json');
assert.equal(native.status,'O0/O2/ASan+UBSan exact');
assert.deepEqual(native.resourceIdentity,bundle.resourceIdentity);
for(const [name,digest] of Object.entries(native.files))assert.equal(sha(await readFile('test/fixtures/phase4_episode_startup/'+name)),digest);
const artifact=await json('out/EpisodeStartupProbe.sol/EpisodeStartupProbe.json'), store=await json('out/ResourceStore.sol/ResourceStore.json');
const metadata=typeof artifact.metadata==='string'?JSON.parse(artifact.metadata):artifact.metadata;
const method=n=>{assert(artifact.methodIdentifiers[n],n);return '0x'+artifact.methodIdentifiers[n];};
const url=`http://127.0.0.1:${port}`;
const report={goal:'4.13a',kind:'episode-startup-ordinary-evm',pass:false,startedUtc:new Date().toISOString(),
  resourceIdentity:bundle.resourceIdentity,catalogSha256:catalog.catalogSha256,
  nativeManifestSha256:sha(await readFile('test/fixtures/phase4_episode_startup/manifest.json')),
  compiler:{version:metadata.compiler.version,settings:metadata.settings},executionBudget:budget,
  sourceHashes:{},cases:[],rejections:[],
  notes:['Shared original blob deployed once by1755 ordinary ResourceStore CREATEs; every runtime byte is checked.',
    'Each case creates a fresh authenticated support host, runs synchronous original source-driven startup, and persists typed GameState/GameflowState. No EVM state, allocations or native expected data are injected.',
    'Five digests compare full DSG1 world, collision/grouping/start/scroller state, complete normalized live zone/owner state, flow globals and mutable difficulty. Persisted-state recomputation must match.',
    'World-only startup; no tic, Frame, UI, transition, browser, intermission or finale acceptance.',
    'Receipt gas includes identity validation, setup, comparison serialization, typed state storage and proof event. It is support-host startup cost, not production adapter/frame cost. No EVM-memory measurement is claimed.']};
await mkdir(resolve(output,'..'),{recursive:true});
let child, log, id=0;
async function rpc(method,params=[]){
  const r=await fetch(url,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(300000)});
  assert(r.ok);const d=await r.json();if(d.error)throw Object.assign(Error(method+': '+JSON.stringify(d.error)),{rpcError:d.error});return d.result;
}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function receipt(hash){const end=Date.now()+300000;while(Date.now()<end){const r=await rpc('eth_getTransactionReceipt',[hash]);if(r)return r;await sleep(20);}throw Error('receipt timeout '+hash);}
async function tx(from,data,to,status='0x1'){
  const start=performance.now(), hash=await rpc('eth_sendTransaction',[{from,data,gas,...(to?{to}:{})}]);
  const r=await receipt(hash);assert.equal(r.status,status,`transaction ${hash} consumed ${BigInt(r.gasUsed)} gas`);
  return {receipt:r,gas:Number(BigInt(r.gasUsed)),ms:performance.now()-start};
}
const call=(from,to,data)=>rpc('eth_call',[{from,to,data,gas},'latest']);
async function rejection(from,address,data,error){
  const before=await rpc('eth_getProof',[address,[],'latest']);
  let rejected=false;try{await call(from,address,data);}catch(e){
    const actual=typeof e.rpcError?.data==='string'?e.rpcError.data:e.rpcError?.data?.data;
    const expected=execFileSync(resolve('.toolchain/bin/cast'),['sig',error],{encoding:'utf8'}).trim();
    assert.equal(actual?.slice(0,10),expected,error);rejected=true;
  }assert(rejected,error);
  const r=await tx(from,data,address,'0x0'),after=await rpc('eth_getProof',[address,[],'latest']);
  assert.equal(after.storageHash,before.storageHash);assert.equal(r.receipt.logs.length,0);
  report.rejections.push({error,transaction:r.receipt.transactionHash,gas:r.gas,allStorageRollback:true,logs:0});
  console.log('PASS rollback',error);
}
try{
  for(const [path,identity] of Object.entries(metadata.sources)){
    const bytes=await readFile(path);
    const digest=execFileSync(resolve('.toolchain/bin/cast'),['keccak'],{input:'0x'+bytes.toString('hex'),encoding:'utf8',maxBuffer:1024*1024}).trim();
    assert.equal(digest,identity.keccak256,'artifact source drift '+path);report.sourceHashes[path]=sha(bytes);
  }
  for(const path of ['tools/reference/episode_startup/reference.py','tools/reference/episode_startup/observe.inc','tools/reference/episode_startup/evm.mjs','foundry.toml','execution-budget.json'])report.sourceHashes[path]=sha(await readFile(path));
  await new Promise((done,fail)=>{const s=connect({host:'127.0.0.1',port});s.once('connect',()=>{s.destroy();fail(Error('Refusing occupied runtime port'));});s.once('error',e=>e.code==='ECONNREFUSED'?done():fail(e));});
  log=await open('artifacts/local/episode-startup/anvil.log','w');
  const nodeArgs=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--disable-block-gas-limit','--memory-limit','1073741824','--silent'];
  child=spawn(resolve('.toolchain/bin/anvil'),nodeArgs,{stdio:['ignore','ignore',log.fd]});
  let spawnError;child.on('error',e=>spawnError=e);
  const deadline=Date.now()+15000;
  for(;;){if(spawnError)throw spawnError;if(child.exitCode!==null)throw Error('Owned Anvil exited');try{await rpc('web3_clientVersion');break;}catch(e){if(Date.now()>deadline)throw e;await sleep(50);}}
  await rpc('anvil_setBlockGasLimit',[gas]);await rpc('evm_mine');
  assert.equal(BigInt((await rpc('eth_getBlockByNumber',['latest',false])).gasLimit),BigInt(budget.gasLimit));
  report.runtime={port,args:nodeArgs,client:await rpc('web3_clientVersion')};
  const [driver,other]=await rpc('eth_accounts'),addresses=[],deployments=[];
  const uploadStart=performance.now();
  for(let p=0;p<blob.length;p+=16384){
    const b=blob.subarray(p,p+16384),r=await tx(driver,store.bytecode.object+word(32)+tail(b));
    assert.equal(await rpc('eth_getCode',[r.receipt.contractAddress,'latest']),'0x00'+b.toString('hex'));
    addresses.push(r.receipt.contractAddress);deployments.push({index:deployments.length,transaction:r.receipt.transactionHash,gas:r.gas,runtimeSha256:sha(Buffer.concat([Buffer.from([0]),b]))});
    if(addresses.length%300===0)console.log('Verified resource CREATE',addresses.length,'/1755');
  }
  report.resources={chunks:addresses.length,allRuntimeBytesVerified:true,blobBytes:blob.length,
    cumulativeDeploymentGas:deployments.reduce((n,r)=>n+r.gas,0),uploadMs:performance.now()-uploadStart,receiptsSha256:sha(JSON.stringify(deployments))};
  await writeFile('artifacts/local/episode-startup/resource-receipts.json',JSON.stringify(deployments,null,2)+'\n');
  const array=word(addresses.length)+addresses.map(a=>a.slice(2).padStart(64,'0')).join('');
  const constructor=word(64)+word(64+array.length/2)+array+tail(directory);
  async function deploy(){
    const r=await tx(driver,artifact.bytecode.object+constructor),address=r.receipt.contractAddress;
    const expected=Buffer.from(artifact.deployedBytecode.object.slice(2),'hex');
    for(const spans of Object.values(artifact.deployedBytecode.immutableReferences))for(const s of spans)Buffer.from(word(driver),'hex').copy(expected,s.start);
    assert.equal(await rpc('eth_getCode',[address,'latest']),'0x'+expected.toString('hex'));
    return {address,transaction:r.receipt.transactionHash,gas:r.gas,ms:r.ms,runtimeBytes:expected.length,runtimeSha256:sha(expected)};
  }
  const guard=await deploy();report.rollbackHost=guard;
  const init=(episode,map,skill,nomonsters=false,deterministic=true)=>method('initialize(int32,int32,int32,bool,bool)')+word(episode)+word(map)+word(skill)+word(nomonsters?1:0)+word(deterministic?1:0);
  await rejection(other,guard.address,init(1,2,2),'NotDriver()');
  for(const [episode,map,skill] of [[2,1,2],[1,0,2],[1,10,2],[1,2,-1],[1,2,5]])await rejection(driver,guard.address,init(episode,map,skill),'UnsupportedSelection(int32,int32,int32)');
  for(const [fault,error] of [[1,'ResourceIdentityMismatch()'],[2,'ResourceDirectoryMismatch()'],[3,'ResourceChunksMismatch()'],[4,'ResourceChunksMismatch()'],[5,'InjectedPostSetupFailure()']])
    await rejection(driver,guard.address,method('initializeFault(uint32)')+word(fault),error);
  for(const expected of native.cases){
    const deployment=await deploy(),r=await tx(driver,init(1,expected.map,expected.skill,expected.nomonsters),deployment.address);
    assert.equal(r.receipt.logs.length,1);const log_=r.receipt.logs[0];
    assert.equal(log_.address,deployment.address);assert.equal(log_.topics[1],'0x'+word(expected.map));
    const names=['world','collision','zone','flow','difficulty'];
    const digests=names.map(n=>expected.files[n+'.bin'].sha256);
    assert.equal(log_.data,'0x'+digests.join(''),expected.name+' all native startup observations');
    assert.equal(await call(driver,deployment.address,method('persistedDigests()')),'0x'+digests.join(''),expected.name+' actual persisted world');
    const status=(await call(driver,deployment.address,method('status()'))).slice(2).match(/.{64}/g).map(x=>Number(BigInt('0x'+x)));
    assert.deepEqual(status.slice(0,5),[1,expected.map,expected.skill,0,0]);assert.equal(status[7],expected.summary.sectors);assert.equal(status[8],1);assert.equal(status[9],1);
    report.cases.push({name:expected.name,map:expected.map,skill:expected.skill,nomonsters:expected.nomonsters,deployment,
      transaction:r.receipt.transactionHash,gas:r.gas,ms:r.ms,digests:Object.fromEntries(names.map((n,i)=>[n,digests[i]])),
      startupStatus:status,persistedWorldExact:true,emittedFrames:0});
    await writeFile(output,JSON.stringify(report,null,2)+'\n');
    console.log('PASS ordinary EVM',expected.name,': native startup exact;',r.gas,'gas');
    if(expected.map===2&&expected.skill===2&&!expected.nomonsters)await rejection(driver,deployment.address,init(1,3,2),'AlreadyInitialized()');
  }
  report.pass=true;
}catch(e){report.error=e.stack;process.exitCode=1;console.error(e.stack);}
finally{
  if(child?.pid&&child.exitCode===null)await new Promise(done=>{child.once('exit',done);child.kill('SIGTERM');setTimeout(()=>{if(child.exitCode===null)child.kill('SIGKILL');},1500).unref();});
  await log?.close();report.endedUtc=new Date().toISOString();report.stoppedOwnedRuntime=true;
  await writeFile(output,JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({pass:report.pass,cases:report.cases.length,rejections:report.rejections.length,output}));
}
