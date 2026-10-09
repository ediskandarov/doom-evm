#!/usr/bin/env node
// Ordinary deployment and adversarial constructor checks for the authenticated production base.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {spawn,execFileSync} from 'node:child_process';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {canonical} from '../../wad/wad.ts';
import {validateSchema} from '../../wad/schema.ts';
import {instrumentGasMarkers,sha,traceMemory} from '../phase2_data/instrument.mjs';
import {loadGasBudget, executionEnv} from '../../execution-budget.mjs';
const {gasLimit, gasHex, source: gasBudgetSource} = loadGasBudget();
const budgetEnv = executionEnv({...process.env, DOOM_GAS_LIMIT: String(gasLimit)});
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../../..');process.chdir(root);
const args=process.argv.slice(2),option=(name,fallback)=>{const i=args.indexOf(name);return i<0?fallback:args[i+1];};
const port=Number(option('--port','18563')),output=option('--output','artifacts/local/phase2-source.json');
assert(Number.isInteger(port)&&port>1024&&port<65536,'invalid port');
const bundle=JSON.parse(await readFile('artifacts/local/wad/bundle.json','utf8'));
validateSchema(bundle,JSON.parse(await readFile('schemas/resource-bundle-v0.schema.json','utf8')));
const pinned=JSON.parse(await readFile('test/fixtures/wad/snapshot.json','utf8'));assert.deepEqual(bundle.resourceIdentity,pinned.resourceIdentity);
const manifest=Object.fromEntries(Object.entries(bundle).filter(([k])=>!['resourceIdentity','blobFile'].includes(k)));
assert.equal(sha(canonical(manifest)),bundle.resourceIdentity.bundleSha256);
const blob=await readFile('artifacts/local/wad/resources.bin');assert.equal(blob.length,bundle.blobByteLength);assert.equal(sha(blob),bundle.blobSha256);
const directory=Buffer.alloc(bundle.lumps.length*16);let cursor=0;
for(const[i,l]of bundle.lumps.entries()){assert.equal(l.id,i);assert.equal(l.offset,cursor);cursor+=l.length;assert(cursor<=blob.length);Buffer.from(l.nameHex,'hex').copy(directory,i*16);directory.writeUInt32LE(l.offset,i*16+8);directory.writeUInt32LE(l.length,i*16+12);}
assert.equal(cursor,blob.length);assert.deepEqual(directory,await readFile('test/fixtures/phase2_data/directory.bin'));
execFileSync(process.execPath,['tools/wad/check-source-identity.mjs'],{stdio:'inherit',timeout:30000});
execFileSync(resolve('.toolchain/bin/forge'),['build','src/support/WadResourcesProbe.sol','src/evm/ResourceStore.sol'],{env:budgetEnv,stdio:'pipe',timeout:120000});
const artifact=JSON.parse(await readFile('out/WadResourcesProbe.sol/WadResourcesProbe.json','utf8'));
const chunkArtifact=JSON.parse(await readFile('out/ResourceStore.sol/ResourceStore.json','utf8'));
const telemetry=instrumentGasMarkers(artifact,await readFile('src/support/WadResourcesProbe.sol','utf8'));
const word=x=>BigInt(x).toString(16).padStart(64,'0'),bytesTail=b=>word(b.length)+b.toString('hex').padEnd(Math.ceil(b.length/32)*64,'0');
const constructorArgs=(addresses,dir)=>{const tail=word(addresses.length)+addresses.map(x=>x.slice(2).padStart(64,'0')).join('');return word(64)+word(64+tail.length/2)+tail+bytesTail(dir);};
let id=0;
async function rpc(method,params=[]){const r=await fetch(`http://127.0.0.1:${port}`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(30000)});assert(r.ok,`HTTP${r.status}`);const j=await r.json();if(j.error)throw Object.assign(Error(`${method}: ${JSON.stringify(j.error)}`),{rpcError:j.error});return j.result;}
async function receipt(hash){const end=Date.now()+30000;while(Date.now()<end){const r=await rpc('eth_getTransactionReceipt',[hash]);if(r)return r;await new Promise(r=>setTimeout(r,25));}throw Error('receipt timeout '+hash);}
const nodeArgs=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--disable-block-gas-limit','--memory-limit','1073741824','--silent'];
let server,serverError='',spawnError;
async function stop(child){
  if(!child?.pid||child.exitCode!==null||child.signalCode!==null)return;
  await new Promise(done=>{let timer;const finish=()=>{clearTimeout(timer);child.removeListener('exit',finish);done();};child.once('exit',finish);child.kill('SIGTERM');timer=setTimeout(()=>{child.kill('SIGKILL');timer=setTimeout(finish,1500);},1500);});
  assert(child.exitCode!==null||child.signalCode!==null,'owned Anvil did not terminate');
}
try {
  let occupied=false;try{await rpc('web3_clientVersion');occupied=true;}catch{}assert(!occupied,'port already has an RPC server');
  server=spawn(resolve('.toolchain/bin/anvil'),nodeArgs,{stdio:['ignore','ignore','pipe']});server.on('error',e=>spawnError=e);server.stderr.on('data',b=>serverError+=b);
  const end=Date.now()+30000;for(;;){if(spawnError)throw spawnError;assert.equal(server.exitCode,null,serverError);try{await rpc('web3_clientVersion');break;}catch{}assert(Date.now()<end,'Anvil readiness timeout');await new Promise(r=>setTimeout(r,25));}
  await rpc('anvil_setBlockGasLimit',[gasHex]);await rpc('evm_mine');const[from]=await rpc('eth_accounts');
  const transact=async(data,to)=>receipt(await rpc('eth_sendTransaction',[{from,...(to?{to}:{}),data,gas:gasHex}]));
  const deploy=async(data)=>{const r=await transact(data);assert.equal(r.status,'0x1','CREATE failed');return r;};
  const upload=async(payload)=>{const r=await deploy(chunkArtifact.bytecode.object+word(32)+bytesTail(payload));const runtime='0x00'+payload.toString('hex');assert.equal(await rpc('eth_getCode',[r.contractAddress,'latest']),runtime);return {address:r.contractAddress,transactionHash:r.transactionHash,gas:Number(BigInt(r.gasUsed)),runtimeSha256:sha(Buffer.from(runtime.slice(2),'hex')),runtimeBytes:payload.length+1};};
  const chunks=[],begin=performance.now();
  for(let offset=0;offset<blob.length;offset+=16384){chunks.push({index:chunks.length,offset,...await upload(blob.subarray(offset,offset+16384))});if(chunks.length%250===0)console.log(`Authenticated source inputs: ${chunks.length}/1755 ordinary chunks uploaded and verified`);}
  assert.equal(chunks.length,1755);const uploadMs=performance.now()-begin,addresses=chunks.map(c=>c.address),encoded=constructorArgs(addresses,directory);
  const normal=await deploy(artifact.bytecode.object+encoded);
  const measured=await deploy('0x'+telemetry.creation.toString('hex')+encoded);
  assert.equal(await rpc('eth_getCode',[normal.contractAddress,'latest']),artifact.deployedBytecode.object);
  assert.equal(await rpc('eth_getCode',[measured.contractAddress,'latest']),'0x'+telemetry.runtime.toString('hex'));
  assert.equal(normal.gasUsed,measured.gasUsed,'runtime telemetry changed authenticated constructor cost');
  const call=(to,data)=>rpc('eth_call',[{from,to,data,gas:gasHex},'latest']);
  const signature=n=>'0x'+artifact.methodIdentifiers[n];
  const identity=bundle.resourceIdentity,identityWords=word(identity.schemaVersion)+identity.wadSha256+identity.bundleSha256+identity.paletteSha256+word(identity.paletteVariant);
  assert.equal(await call(normal.contractAddress,signature('resourceIdentity()')),'0x'+identityWords);
  const addressDigest=sha(Buffer.from(word(32)+word(addresses.length)+addresses.map(a=>a.slice(2).padStart(64,'0')).join(''),'hex'));
  const metadataExpected=sha(Buffer.from(identityWords+word(blob.length)+word(chunks.length)+word(bundle.lumps.length)+sha(directory)+addressDigest,'hex'));
  const metadataData=signature('metadataDigest()');assert.equal(await call(normal.contractAddress,metadataData),'0x'+metadataExpected);assert.equal(await call(measured.contractAddress,metadataData),'0x'+metadataExpected);
  const metadataReceipt=await transact(metadataData,normal.contractAddress);assert.equal(metadataReceipt.status,'0x1');
  const reads=[];
  for(const[offset,length]of [[0,32],[16380,16],[blob.length-32,32],[blob.length,0]]) {
    const calldata=signature('readRange(uint32,uint32)')+word(offset)+word(length);const result=await call(normal.contractAddress,calldata);
    assert.equal(BigInt('0x'+result.slice(2,66)),32n);assert.equal(Number(BigInt('0x'+result.slice(66,130))),length);
    assert.equal(result.slice(130,130+length*2),blob.subarray(offset,offset+length).toString('hex'));
    const data=signature('probeRead(uint32,uint32)')+word(offset)+word(length);
    const parse=x=>{const w=x.slice(2).match(/.{64}/g);assert.equal(w.length,7);return {gas:w.slice(0,2).map(x=>Number(BigInt('0x'+x))),memory:w.slice(2,6).map(x=>Number(BigInt('0x'+x))),digest:w[6]};};
    const a=parse(await call(normal.contractAddress,data)),b=parse(await call(measured.contractAddress,data));assert.deepEqual(a.gas,b.gas);assert.equal(a.digest,b.digest);assert.equal(b.digest,sha(blob.subarray(offset,offset+length)));for(const n of b.memory)assert.equal(n%32,0);
    const tx=await transact(data,normal.contractAddress),instrumentedTx=await transact(data,measured.contractAddress);assert.equal(tx.status,'0x1');assert.equal(instrumentedTx.status,'0x1');assert.equal(tx.gasUsed,instrumentedTx.gasUsed);
    reads.push({offset,length,outputSha256:b.digest,viewGas:b.gas[0],readGas:b.gas[1],actualMemoryBytes:b.memory,transactionGas:Number(BigInt(tx.gasUsed)),transactionHash:tx.transactionHash,instrumentedTransactionHash:instrumentedTx.transactionHash});
  }
  const errors=Object.fromEntries(['DirectoryIdentity()','ChunkIdentity()','ResourceDimensions()'].map(s=>[s,execFileSync(resolve('.toolchain/bin/cast'),['sig',s],{encoding:'utf8'}).trim()]));
  const corruptDirectory=Buffer.from(directory);corruptDirectory[0]^=1;
  const alteredPayload=Buffer.from(blob.subarray(1754*16384));alteredPayload[alteredPayload.length-1]^=1;const alteredChunk=await upload(alteredPayload);const alteredAddresses=[...addresses];alteredAddresses[1754]=alteredChunk.address;
  const rejections=[];
  for(const[name,chunkAddresses,dir,error]of [['modified-directory',addresses,corruptDirectory,'DirectoryIdentity()'],['modified-final-payload',alteredAddresses,directory,'ChunkIdentity()'],['missing-chunks',[],directory,'ResourceDimensions()']]) {
    const data=artifact.bytecode.object+constructorArgs(chunkAddresses,dir);let reverted;
    try{await rpc('eth_call',[{from,data,gas:gasHex},'latest']);}catch(e){reverted=e;}
    assert(reverted?.rpcError,'constructor eth_call unexpectedly succeeded');assert.equal(reverted.rpcError.data,errors[error],'wrong constructor rejection');
    const tx=await transact(data);assert.equal(tx.status,'0x0','tampered constructor mined successfully');assert.equal(tx.logs.length,0);
    assert.equal(await rpc('eth_getCode',[tx.contractAddress,'latest']),'0x','failed CREATE left runtime code');
    rejections.push({name,error,errorSelector:errors[error],transactionHash:tx.transactionHash,contractAddress:tx.contractAddress,status:tx.status,logs:tx.logs.length,gas:Number(BigInt(tx.gasUsed))});
  }
  // Independently calibrate the telemetry decoder against literal MSIZE at an awkward byte boundary.
  const calRuntime='6000610123535960005260206000f3',calLength=(calRuntime.length/2).toString(16).padStart(2,'0');
  const cal=await deploy('0x60'+calLength+'600c60003960'+calLength+'6000f3'+calRuntime);const calCall={from,to:cal.contractAddress,gas:gasHex};
  const actual=Number(BigInt(await rpc('eth_call',[calCall,'latest']))),trace=await rpc('debug_traceCall',[calCall,'latest',{disableStorage:true,disableStack:false,enableMemory:false}]);assert(!trace.failed);const derived=traceMemory(trace.structLogs);assert.equal(actual,320);assert.equal(derived.highWaterBytes,actual);
  const sourcePaths=[...new Set([...Object.keys(artifact.metadata.sources),'src/evm/ResourceStore.sol','tools/wad/check-source-identity.mjs','tools/reference/phase2_source/verify.mjs','tools/reference/phase2_data/instrument.mjs','foundry.toml','tools/execution-budget.mjs','execution-budget.json'])].sort();
  const report={gasLimit,gasBudgetSource,kind:'authenticated-wad-ordinary-deployment',identity,blobSha256:sha(blob),directorySha256:sha(directory),chunkCommitment:sha(Buffer.concat(chunks.map(c=>Buffer.from(c.runtimeSha256,'hex')))),client:await rpc('web3_clientVersion'),nodeArgs,sources:Object.fromEntries(await Promise.all(sourcePaths.map(async p=>[p,sha(await readFile(p))]))),instrumentation:telemetry.report,calibration:{actualMsize:actual,derivedHighWater:derived.highWaterBytes,runtime:calRuntime},deployment:{all1755RuntimeBytesVerified:true,uploadMs,totalChunkGas:chunks.reduce((n,c)=>n+c.gas,0),normalProbe:{address:normal.contractAddress,transactionHash:normal.transactionHash,gas:Number(BigInt(normal.gasUsed))},instrumentedProbe:{address:measured.contractAddress,transactionHash:measured.transactionHash,gas:Number(BigInt(measured.gasUsed))},chunks},metadata:{expectedSha256:metadataExpected,transactionHash:metadataReceipt.transactionHash,transactionGas:Number(BigInt(metadataReceipt.gasUsed)),binds:'all identity fields, blob length, chunk/lump counts, every stored directory descriptor, every ordered stored chunk address'},reads,rejections,tamperedChunk:alteredChunk,notes:['The unchanged production WadResources constructor authenticates the complete ordered STOP-prefixed code and packed directory before storage. Ordinary CREATE only; no etch/setCode or authentication bypass.','Metadata digest is independently reconstructed from verified inputs and exact ABI encoding. Every requested read matches original pinned bytes.','Only source-mapped GAS markers in separate probe runtime become ordinary MSIZE. Constructor code and authentication remain unchanged. All output hashes, operation gas and whole read transaction gas match normal deployment.','Read memory boundaries are entry, after ResourceView copy, after range read, after digest. ABI return encoding follows the final marker; this is not a claimed whole-call peak.','Both eth_call revert selectors and mined status0/logs0/absent runtime prove tampered source rejection.','Upload elapsed time includes client/RPC/mining/runtime verification; it is not isolated interpreter execution time.']};
  await mkdir(dirname(output),{recursive:true});await writeFile(output,JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({constructorGas:report.deployment.normalProbe.gas,metadata:report.metadata,reads,rejections,output},null,2));
}finally{await stop(server);}
