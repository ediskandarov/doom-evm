// SPDX-License-Identifier: GPL-2.0-only
// Resource-only ordinary CREATE receipts; consumes a focused prebuilt harness.
import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {connect} from 'node:net';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
import {verifyEpisode} from '../../wad/episode.ts';
import {sha256} from '../../wad/wad.ts';
import {loadGasBudget} from '../../execution-budget.mjs';

const args=process.argv.slice(2), option=(key, fallback)=>{const i=args.indexOf(key);return i<0?fallback:args[i+1];};
const directory=option('--bundle','artifacts/local/wad'), wad=option('--wad','artifacts/local/freedoom/freedoom1.wad');
const output=option('--output','artifacts/phase4/episode-evm.json'), port=Number(option('--port','18747'));
assert(Number.isInteger(port)&&port>1024&&port<65536,'invalid isolated port');
const json=async file=>JSON.parse(await readFile(file,'utf8'));
const bundle=await json(resolve(directory,'bundle.json')), episode=await json(resolve(directory,'episode.json')), blob=await readFile(resolve(directory,'resources.bin'));
verifyEpisode(await readFile(wad),episode,bundle,blob);
const native=await json('artifacts/phase4/episode-native-comparison.json');
assert(native.pass&&native.catalogSha256===episode.catalogSha256,'native comparison must match this catalog');
const artifact=await json('out/EpisodeResourcesProbe.sol/EpisodeResourcesProbe.json'), store=await json('out/ResourceStore.sol/ResourceStore.json');
const {gasHex,gasLimit}=loadGasBudget();
const word=n=>BigInt(n).toString(16).padStart(64,'0'), bytesTail=b=>word(b.length)+b.toString('hex').padEnd(Math.ceil(b.length/32)*64,'0');
let id=0, child, stderr='';
async function rpc(method,params=[]){
 const response=await fetch(`http://127.0.0.1:${port}`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(120000)});
 const data=await response.json();if(data.error)throw Error(method+': '+JSON.stringify(data.error));return data.result;
}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function receipt(tx){const deadline=Date.now()+120000;while(Date.now()<deadline){const r=await rpc('eth_getTransactionReceipt',[tx]);if(r)return r;await sleep(25);}throw Error('receipt timeout '+tx);}
try {
 const occupied=await new Promise(done=>{const socket=connect({host:'127.0.0.1',port});socket.once('connect',()=>{socket.destroy();done(true);});socket.once('error',()=>done(false));socket.setTimeout(1000,()=>{socket.destroy();done(true);});});
 assert(!occupied,'port occupied; refusing to use existing node');
 const serverArgs=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--gas-limit',String(gasLimit),'--memory-limit','1073741824','--silent'];
 child=spawn(resolve('.toolchain/bin/anvil'),serverArgs,{stdio:['ignore','ignore','pipe']});
 let startError;child.on('error',e=>startError=e);child.stderr.on('data',b=>stderr+=b);
 const deadline=Date.now()+15000;
 for(;;){if(startError)throw startError;assert(child.exitCode===null,stderr);try{await rpc('eth_chainId');break;}catch(e){if(Date.now()>deadline)throw Error('Anvil start failed: '+stderr);await sleep(50);}}
 const[from]=await rpc('eth_accounts');
 const send=async(data,to)=>receipt(await rpc('eth_sendTransaction',[{from,...(to?{to}:{}),data,gas:gasHex}]));
 const chunks=[], deployments=[];const began=performance.now();
 for(let at=0;at<blob.length;at+=episode.chunkBytes){
  const b=blob.subarray(at,at+episode.chunkBytes), r=await send(store.bytecode.object+word(32)+bytesTail(b));assert.equal(r.status,'0x1');
  assert.equal(await rpc('eth_getCode',[r.contractAddress,'latest']),'0x00'+b.toString('hex'));
  chunks.push(r.contractAddress);deployments.push({index:deployments.length,transaction:r.transactionHash,gas:Number(BigInt(r.gasUsed)),runtimeSha256:sha256(Buffer.concat([Buffer.from([0]),b]))});
  if(chunks.length%300===0)console.log(`Verified ordinary CREATE resource chunks: ${chunks.length}/1755`);
 }
 const chunkDeploymentMs=performance.now()-began;
 const probe=await send(artifact.bytecode.object);assert.equal(probe.status,'0x1');
 assert.equal(await rpc('eth_getCode',[probe.contractAddress,'latest']),artifact.deployedBytecode.object);
 const addresses=word(chunks.length)+chunks.map(a=>a.slice(2).padStart(64,'0')).join('');
 const descriptors=word(bundle.lumps.length)+bundle.lumps.map(l=>l.nameHex.padEnd(64,'0')+word(l.offset)+word(l.length)).join('');
 const ri=bundle.resourceIdentity;
 const view=word(ri.schemaVersion)+ri.wadSha256+ri.bundleSha256+ri.paletteSha256+word(ri.paletteVariant)+word(256)+word(bundle.blobByteLength)+word(256+addresses.length/2)+addresses+descriptors;
 const signature='load(((uint32,bytes32,bytes32,bytes32,uint8),address[],uint32,(bytes8,uint32,uint32)[]),bytes8)';
 const calldata=map=>'0x'+artifact.methodIdentifiers[signature]+word(64)+Buffer.from(map).toString('hex').padEnd(64,'0')+view;
 const results=[];
 for(const expected of native.results){
  const data=calldata(expected.map), start=performance.now();
  const result=await rpc('eth_call',[{from,to:probe.contractAddress,data,gas:gasHex},'latest']);
  assert.equal(result.length,130);const initGas=Number(BigInt('0x'+result.slice(2,66))),mapGas=Number(BigInt('0x'+result.slice(66)));
  const r=await send(data,probe.contractAddress);assert.equal(r.status,'0x1');assert.equal(r.logs.length,1);
  const log=r.logs[0];assert.equal(log.address,probe.contractAddress);assert.equal(log.topics.length,2);assert.equal(log.topics[1],'0x'+Buffer.from(expected.map).toString('hex').padEnd(64,'0'));
  assert.equal(log.data,'0x'+expected.geometrySha256+expected.thingsSha256+expected.blockmapSha256+expected.rejectSha256,expected.map+' all native fields');
  results.push({...expected,transaction:r.transactionHash,transactionGas:Number(BigInt(r.gasUsed)),initGas,mapGas,callAndReceiptMs:performance.now()-start,calldataBytes:(data.length-2)/2});
  console.log(`${expected.map}: native resource digests exact; ${Number(BigInt(r.gasUsed))} transaction gas`);
 }
 const invalid=await send(calldata('E2M1'),probe.contractAddress);assert.equal(invalid.status,'0x0');assert.equal(invalid.logs.length,0);
 const sources={};for(const file of ['src/support/EpisodeResourcesProbe.sol','src/doom/r_data.sol','src/doom/r_data_types.sol','src/doom/r_defs.sol','src/evm/ResourceStore.sol','tools/reference/episode/evm.mjs','tools/wad/episode.ts','tools/wad/wad.ts','schemas/episode-resources-v1.schema.json','foundry.toml','execution-budget.json','test/fixtures/phase4_episode/native.json','artifacts/phase4/episode-native-comparison.json'])sources[file]=sha256(await readFile(file));
 const report={schemaVersion:1,goal:'4.7a',pass:true,scope:'Nine-map resources, no gameplay startup or frames',resourceIdentity:ri,catalogSha256:episode.catalogSha256,
  client:await rpc('web3_clientVersion'),serverArgs,compiler:{version:artifact.metadata.compiler.version,settings:artifact.metadata.settings},gasLimit,
  deployment:{chunks:chunks.length,allRuntimeBytesVerified:true,blobBytes:blob.length,totalChunkGas:deployments.reduce((n,r)=>n+r.gas,0),chunkDeploymentMs,
    receiptsSha256:sha256(JSON.stringify(deployments)),probe:{transaction:probe.transactionHash,gas:Number(BigInt(probe.gasUsed)),runtimeBytes:(artifact.deployedBytecode.object.length-2)/2,runtimeSha256:sha256(Buffer.from(artifact.deployedBytecode.object.slice(2),'hex'))}},
  results,otherEpisodeRejected:{transaction:invalid.transactionHash,status:invalid.status,logs:0},sourceSha256:sources,
  notes:['Full original shared blob deployed once by ordinary CREATE; all STOP-prefixed runtime bytes verified. No etch/setCode, production adapter modifications or compiler changes.',
   'Every map transaction invokes existing lazy resource initialization and R_LoadMap, then compares all geometry fields/THINGS and signed BLOCKMAP words/REJECT bytes with native hashes.',
   'ResourceView is supplied as calldata. Receipt gas includes calldata, decoding, lazy init, map loading, checksum serialization and event emission. It is not the production storage-backed startup cost.',
   'initGas and mapGas are gasleft deltas around existing resource operations. Wall timings include RPC/client/mining and a preceding eth_call.',
   'Resource validation and host identity checking precede deployment. This support probe is not an on-chain WAD authentication or level-loading integration.']};
 await mkdir(resolve(output,'..'),{recursive:true});await writeFile(output,JSON.stringify(report,null,2)+'\n');
 await writeFile(resolve(directory,'episode-deployment-receipts.json'),JSON.stringify(deployments,null,2)+'\n');
 console.log(JSON.stringify({pass:true,maps:9,output}));
} finally {
 if(child?.pid&&child.exitCode===null&&child.signalCode===null)await new Promise(done=>{const timer=setTimeout(()=>{child.kill('SIGKILL');done();},2000);child.once('exit',()=>{clearTimeout(timer);done();});child.kill('SIGTERM');});
}
