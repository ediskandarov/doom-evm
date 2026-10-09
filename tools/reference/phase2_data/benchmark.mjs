#!/usr/bin/env node
// Full pinned WAD ordinary deployment + actual opcode MSIZE telemetry in a separate probe.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {spawn,execFileSync} from 'node:child_process';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {canonical} from '../../wad/wad.ts';
import {validateSchema} from '../../wad/schema.ts';
import {instrumentGasMarkers,traceMemory,sha} from './instrument.mjs';
import {loadGasBudget, executionEnv} from '../../execution-budget.mjs';
const {gasLimit, gasHex, source: gasBudgetSource} = loadGasBudget();
const budgetEnv = executionEnv({...process.env, DOOM_GAS_LIMIT: String(gasLimit)});
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../../..');process.chdir(root);
const args=process.argv.slice(2),option=(name,fallback)=>{const i=args.indexOf(name);return i<0?fallback:args[i+1];};
const port=Number(option('--port','18561')),output=option('--output','artifacts/local/phase2-resource-access.json');
const bundle=JSON.parse(await readFile('artifacts/local/wad/bundle.json','utf8'));
validateSchema(bundle,JSON.parse(await readFile('schemas/resource-bundle-v0.schema.json','utf8')));
const blob=await readFile('artifacts/local/wad/resources.bin');assert.equal(sha(blob),bundle.blobSha256);assert.equal(blob.length,bundle.blobByteLength);
const manifest=Object.fromEntries(Object.entries(bundle).filter(([key])=>!['resourceIdentity','blobFile'].includes(key)));
assert.equal(sha(canonical(manifest)),bundle.resourceIdentity.bundleSha256);
const pinned=JSON.parse(await readFile('test/fixtures/wad/snapshot.json','utf8'));assert.deepEqual(bundle.resourceIdentity,pinned.resourceIdentity);
const directory=Buffer.alloc(bundle.lumps.length*16);let cursor=0;
for(const[i,l]of bundle.lumps.entries()){assert.equal(l.id,i);assert.equal(l.offset,cursor);cursor+=l.length;assert(cursor<=blob.length);Buffer.from(l.nameHex,'hex').copy(directory,i*16);directory.writeUInt32LE(l.offset,i*16+8);directory.writeUInt32LE(l.length,i*16+12);}
assert.equal(cursor,blob.length);assert.deepEqual(directory,await readFile('test/fixtures/phase2_data/directory.bin'));
execFileSync(resolve('.toolchain/bin/forge'),['build'],{env:budgetEnv,stdio:'pipe',timeout:120000});
const artifact=JSON.parse(await readFile('out/ResourceAccessProbe.sol/ResourceAccessProbe.json','utf8'));
const chunkArtifact=JSON.parse(await readFile('out/ResourceStore.sol/ResourceStore.json','utf8'));
const instrumented=instrumentGasMarkers(artifact,await readFile('src/support/ResourceAccessProbe.sol','utf8'));
const word=x=>BigInt(x).toString(16).padStart(64,'0'),hex=b=>Buffer.from(b).toString('hex');
const bytesTail=b=>word(b.length)+hex(b).padEnd(Math.ceil(b.length/32)*64,'0');
let id=0;
async function rpc(method,params=[]){const r=await fetch(`http://127.0.0.1:${port}`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params})});const j=await r.json();if(j.error)throw Error(`${method}: ${JSON.stringify(j.error)}`);return j.result;}
async function receipt(tx){for(let i=0;i<200;i++){const r=await rpc('eth_getTransactionReceipt',[tx]);if(r){assert.equal(r.status,'0x1',`transaction reverted ${tx}`);return r;}await new Promise(r=>setTimeout(r,25));}throw Error('receipt timeout '+tx);}
const serverArgs=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--disable-block-gas-limit','--memory-limit','1073741824','--silent'];
let server;
try {
  let occupied=false;try{await rpc('web3_clientVersion');occupied=true;}catch{}assert(!occupied,'benchmark port already in use');
  server=spawn(resolve('.toolchain/bin/anvil'),serverArgs,{stdio:['ignore','ignore','pipe']});let error='';server.stderr.on('data',b=>error+=b);
  for(let n=0;;n++){assert.equal(server.exitCode,null,error);try{await rpc('web3_clientVersion');break;}catch{}assert(n<200,'Anvil readiness timeout');await new Promise(r=>setTimeout(r,25));}
  await rpc('anvil_setBlockGasLimit',[gasHex]);await rpc('evm_mine');const[from]=await rpc('eth_accounts');
  const send=async(data,to)=>receipt(await rpc('eth_sendTransaction',[{from,...(to?{to}:{}),data,gas:gasHex}]));
  const chunks=[];const began=performance.now();
  for(let off=0;off<blob.length;off+=16384){
    const payload=blob.subarray(off,Math.min(off+16384,blob.length));
    const deployed=await send(chunkArtifact.bytecode.object+word(32)+bytesTail(payload));
    const code=await rpc('eth_getCode',[deployed.contractAddress,'latest']);assert.equal(code,'0x00'+hex(payload));
    chunks.push({index:chunks.length,offset:off,dataBytes:payload.length,address:deployed.contractAddress,transactionHash:deployed.transactionHash,gasUsed:Number(BigInt(deployed.gasUsed)),runtimeSha256:sha(Buffer.concat([Buffer.from([0]),payload]))});
    if(chunks.length%250===0)console.log(`Ordinary CREATE and exact runtime verification: ${chunks.length}/1755 chunks`);
  }
  assert.equal(chunks.length,1755);const chunkDeploymentMs=performance.now()-began;console.log(`All chunks deployed and verified in ${Math.round(chunkDeploymentMs)}ms`);
  const addressTail=word(chunks.length)+chunks.map(c=>c.address.slice(2).padStart(64,'0')).join('');
  const constructorArgs=word(64)+word(64+addressTail.length/2)+addressTail+bytesTail(directory);
  const normal=await send(artifact.bytecode.object+constructorArgs);
  const telemetry=await send('0x'+hex(instrumented.creation)+constructorArgs);
  const normalCode=await rpc('eth_getCode',[normal.contractAddress,'latest']);const measuredCode=await rpc('eth_getCode',[telemetry.contractAddress,'latest']);
  assert.equal(normalCode,artifact.deployedBytecode.object);assert.equal(measuredCode,'0x'+hex(instrumented.runtime));
  const names=['cross-chunk-read','lazy-initialization','eager-initialization','lazy-init-and-map','uncached-and-cached-columns','uncached-and-cached-flats'];
  const expected=[];
  expected[0]=sha(blob.subarray(16380,16396));
  const colormap=bundle.lumps.findLast(l=>l.nameHex==='434f4c4f524d4150');
  expected[1]=expected[2]=sha(Buffer.from([963,2916,246,1006,853].map(word).join('')+sha(blob.subarray(colormap.offset,colormap.offset+colormap.length)),'hex'));
  expected[3]=sha(Buffer.from([1196,182,1829,1175,2057,682,681,292].map(word).join(''),'hex'));
  const gets=await readFile('test/fixtures/phase2_data/getcolumns.bin');
  const lump=gets.readInt32LE(2*24+8),patch=bundle.lumps[lump],offset0=gets.readUInt32LE(2*24+12),patchBytes=blob.subarray(patch.offset,patch.offset+patch.length);
  // Native texture 2 is direct. Column one pointer comes from the original LE patch directory.
  assert(lump>0);const offset1=(patchBytes.readUInt32LE(12)+3)&65535;
  expected[4]=sha(Buffer.from(sha(patchBytes)+word(offset0)+sha(patchBytes)+word(offset1),'hex'));
  const flat=bundle.lumps[2917],flatHash=sha(blob.subarray(flat.offset,flat.offset+flat.length));assert.equal(flat.length,4096);expected[5]=sha(Buffer.from(flatHash+flatHash,'hex'));
  const results=[];
  for(let mode=0;mode<6;mode++) {
    const signatures=['probeRead()','probeInit(bool)','probeInit(bool)','probeMap()','probeColumns()','probeFlats()'];
    const data='0x'+artifact.methodIdentifiers[signatures[mode]]+((mode===1||mode===2)?word(mode===2?1:0):''),base={from,data,gas:gasHex};
    const decode=result=>{const w=result.slice(2).match(/.{64}/g);assert.equal(w.length,12);return {operationGas:w.slice(0,5).map(x=>Number(BigInt('0x'+x))),memory:w.slice(5,11).map(x=>Number(BigInt('0x'+x))),digest:w[11]};};
    const regular=decode(await rpc('eth_call',[{...base,to:normal.contractAddress},'latest']));
    const measured=decode(await rpc('eth_call',[{...base,to:telemetry.contractAddress},'latest']));
    assert.deepEqual(measured.operationGas,regular.operationGas,'GAS→MSIZE changed operation gas');assert.equal(measured.digest,regular.digest,'instrumentation changed output');assert.equal(measured.digest,expected[mode],'output disagrees with pinned/native resource evidence');
    for(const n of measured.memory)assert.equal(n%32,0,'MSIZE must be a multiple of32');
    const mined=await send(data,normal.contractAddress);const measuredMined=await send(data,telemetry.contractAddress);assert.equal(mined.gasUsed,measuredMined.gasUsed,'instrumentation changed total transaction gas');
    results.push({mode,operation:names[mode],operationGas:measured.operationGas,actualMemoryBytes:measured.memory,outputSha256:measured.digest,transactionGas:Number(BigInt(mined.gasUsed)),normalTransactionHash:mined.transactionHash,instrumentedTransactionHash:measuredMined.transactionHash});
    console.log(`${names[mode]}: transaction ${Number(BigInt(mined.gasUsed))} gas; actual MSIZE ${measured.memory.join(' -> ')} bytes`);
  }
  // A tiny independent actual-MSIZE calibration exercises code-copy expansion and a literal return.
  const calibrationRuntime='6000610123535960005260206000f3'; // MSTORE8[0x123], MSIZE=0x140.
  const n=word(calibrationRuntime.length/2).slice(-2);const cal=await send('0x60'+n+'600c60003960'+n+'6000f3'+calibrationRuntime);
  const calCall={from,to:cal.contractAddress,gas:gasHex};const actual=Number(BigInt(await rpc('eth_call',[calCall,'latest'])));
  const trace=await rpc('debug_traceCall',[calCall,'latest',{disableStorage:true,disableStack:false,enableMemory:false}]);assert(!trace.failed);
  const calibration=traceMemory(trace.structLogs);assert.equal(actual,320);assert.equal(calibration.highWaterBytes,actual);
  const sourceFiles=['src/support/ResourceAccessProbe.sol','src/doom/r_data.sol','src/doom/r_data_types.sol','src/evm/ResourceStore.sol','tools/reference/phase2_data/benchmark.mjs','tools/reference/phase2_data/instrument.mjs','foundry.toml','tools/execution-budget.mjs','execution-budget.json'];
  const report={gasLimit,gasBudgetSource,kind:'phase2-resource-ordinary-evm-access',identity:bundle.resourceIdentity,blobSha256:sha(blob),directorySha256:sha(directory),client:await rpc('web3_clientVersion'),serverArgs,compiler:'solc0.8.37 viaIR optimizer200 Cancun',sources:Object.fromEntries(await Promise.all(sourceFiles.map(async p=>[p,sha(await readFile(p))]))),instrumentation:instrumented.report,calibration:{actualMsize:actual,derivedHighWater:calibration.highWaterBytes,runtime:calibrationRuntime},deployment:{all1755RuntimeBytesVerified:true,totalChunkGas:chunks.reduce((n,c)=>n+c.gasUsed,0),chunkDeploymentMs,normalProbe:{address:normal.contractAddress,transactionHash:normal.transactionHash,gas:Number(BigInt(normal.gasUsed))},instrumentedProbe:{address:telemetry.contractAddress,transactionHash:telemetry.transactionHash,gas:Number(BigInt(telemetry.gasUsed))},chunks},results,notes:['All code contracts deployed by ordinary eth_sendTransaction CREATE. No etch/setCode or custom VM opcodes.','Only a separate measurement probe has dedicated source-mapped GAS instructions replaced with ordinary MSIZE; unchanged operation/transaction gas and independently verified resource output hashes are asserted for all six operations.','ActualMemoryBytes slots: function entry, after storage ResourceView copy, after first operation/init, after second operation, after third operation, after output digest. Unused slots are zero.','OperationGas slots: storage ResourceView copy, first operation/init, second operation, third operation, unused. Transaction gas includes calldata/dispatcher/storage copy/checksums/ABI result encoding.','Uncached column/flat means first allocation within that frame; initialization may already warm code accounts. Two probe deployments contain identical resource pointers and metadata.','MSIZE is actual interpreter memory rounded to32bytes; allocator bounds are not used as substitutes. No full-renderer timing claim.']};
  await mkdir(dirname(output),{recursive:true});await writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(`Saved ${output}`);
} finally {if(server?.pid&&server.exitCode===null){server.kill('SIGTERM');await new Promise(done=>{const t=setTimeout(()=>{server.kill('SIGKILL');done();},2000);server.once('exit',()=>{clearTimeout(t);done();});});}}
