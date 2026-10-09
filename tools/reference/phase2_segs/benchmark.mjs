#!/usr/bin/env node
// Full pinned WAD ordinary deployment + actual opcode MSIZE telemetry in a separate probe.
import {readFile,writeFile,mkdir,readdir} from 'node:fs/promises';
import {spawn,execFileSync} from 'node:child_process';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {canonical} from '../../wad/wad.ts';
import {validateSchema} from '../../wad/schema.ts';
import {instrumentGasMarkers,traceMemory,sha} from '../phase2_data/instrument.mjs';
import {loadGasBudget, executionEnv} from '../../execution-budget.mjs';
const {gasLimit, gasHex, source: gasBudgetSource} = loadGasBudget();
const budgetEnv = executionEnv({...process.env, DOOM_GAS_LIMIT: String(gasLimit)});
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../../..');process.chdir(root);
const args=process.argv.slice(2),option=(name,fallback)=>{const i=args.indexOf(name);return i<0?fallback:args[i+1];};
const port=Number(option('--port','18563')),output=option('--output','artifacts/local/phase2-wall-measurements.json');
const bundle=JSON.parse(await readFile('artifacts/local/wad/bundle.json','utf8'));
validateSchema(bundle,JSON.parse(await readFile('schemas/resource-bundle-v0.schema.json','utf8')));
const blob=await readFile('artifacts/local/wad/resources.bin');assert.equal(sha(blob),bundle.blobSha256);assert.equal(blob.length,bundle.blobByteLength);
const manifest=Object.fromEntries(Object.entries(bundle).filter(([key])=>!['resourceIdentity','blobFile'].includes(key)));
assert.equal(sha(canonical(manifest)),bundle.resourceIdentity.bundleSha256);
const pinned=JSON.parse(await readFile('test/fixtures/wad/snapshot.json','utf8'));assert.deepEqual(bundle.resourceIdentity,pinned.resourceIdentity);
const directory=Buffer.alloc(bundle.lumps.length*16);let cursor=0;
for(const[i,l]of bundle.lumps.entries()){assert.equal(l.id,i);assert.equal(l.offset,cursor);cursor+=l.length;assert(cursor<=blob.length);Buffer.from(l.nameHex,'hex').copy(directory,i*16);directory.writeUInt32LE(l.offset,i*16+8);directory.writeUInt32LE(l.length,i*16+12);}
assert.equal(cursor,blob.length);assert.deepEqual(directory,await readFile('test/fixtures/phase2_data/directory.bin'));
execFileSync(resolve('.toolchain/bin/forge'),['build','tools/reference/phase2_segs/WallProbe.sol'],{env:budgetEnv,stdio:'pipe',timeout:120000});
const artifact=JSON.parse(await readFile('out/WallProbe.sol/WallProbe.json','utf8'));
const chunkArtifact=JSON.parse(await readFile('out/ResourceStore.sol/ResourceStore.json','utf8'));
const instrumented=instrumentGasMarkers(artifact,await readFile('tools/reference/phase2_segs/WallProbe.sol','utf8'));
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
  const native=JSON.parse(await readFile('test/fixtures/renderer/manifest.json','utf8'));
  const results=[];
  for(let angle=0;angle<8;angle++) {
    const name=`walls-angle${angle}`,ref=native.cases.find(c=>c.name===name);assert(ref&&ref.mode==='walls'&&ref.angle===angle*0x20000000);
    const data='0x'+artifact.methodIdentifiers['render(uint32)']+word(angle*0x20000000);
    const base={from,data,gas:gasHex};
    const decode=value=>{const w=value.slice(2).match(/.{64}/g);assert.equal(w.length,12);return {gas:w.slice(0,3).map(x=>Number(BigInt('0x'+x))),memory:w.slice(3,8).map(x=>Number(BigInt('0x'+x))),pixels:w[8],drawsegs:Number(BigInt('0x'+w[9])),planes:Number(BigInt('0x'+w[10])),openings:Number(BigInt('0x'+w[11]))};};
    const regular=decode(await rpc('eth_call',[{...base,to:normal.contractAddress},'latest']));
    const measured=decode(await rpc('eth_call',[{...base,to:telemetry.contractAddress},'latest']));
    assert.deepEqual(measured.gas,regular.gas,'instrumentation changed gas');assert.equal(measured.pixels,regular.pixels,'instrumentation changed pixels');assert.equal(measured.pixels,ref.frameSha256,'original C wall mismatch');
    assert.equal(measured.drawsegs,ref.scene.drawsegs);assert.equal(measured.planes,ref.scene.visplanes);assert.equal(measured.openings,regular.openings);
    for(const n of measured.memory)assert.equal(n%32,0);
    const mined=await send(data,normal.contractAddress),measuredMined=await send(data,telemetry.contractAddress);assert.equal(mined.gasUsed,measuredMined.gasUsed,'telemetry changed transaction gas');
    results.push({name,mode:'walls',angle:ref.angle,gasStages:['resource-storage-copy','resource-map-view-initialization','BSP-and-wall-rendering'],operationGas:measured.gas,memoryStages:['entry','resource-storage-copy','resource-map-view-initialization','BSP-and-wall-rendering','framebuffer-SHA'],actualMemoryBytes:measured.memory,pixelsSha256:measured.pixels,drawsegs:measured.drawsegs,visplanes:measured.planes,openingShorts:measured.openings,transactionGas:Number(BigInt(mined.gasUsed)),normalTransactionHash:mined.transactionHash,telemetryTransactionHash:measuredMined.transactionHash});
    console.log(`${name}: walls ${measured.gas[2]} gas; MSIZE ${measured.memory[2]} -> ${measured.memory[3]}; total ${Number(BigInt(mined.gasUsed))}`);
  }
  const calibrationRuntime='6000610123535960005260206000f3';
  const n=word(calibrationRuntime.length/2).slice(-2);const cal=await send('0x60'+n+'600c60003960'+n+'6000f3'+calibrationRuntime);
  const calCall={from,to:cal.contractAddress,gas:gasHex};const actual=Number(BigInt(await rpc('eth_call',[calCall,'latest'])));
  const trace=await rpc('debug_traceCall',[calCall,'latest',{disableStorage:true,disableStack:false,enableMemory:false}]);assert(!trace.failed);
  const calibration=traceMemory(trace.structLogs);assert.equal(actual,320);assert.equal(calibration.highWaterBytes,actual);
  const soliditySources=(await readdir('src',{recursive:true})).filter(file=>file.endsWith('.sol')).map(file=>'src/'+file).sort();
  const sourceHashes={};for(const file of [...soliditySources,'tools/tables/generate.py','tools/reference/phase2_segs/WallProbe.sol','tools/reference/phase2_segs/benchmark.mjs','tools/reference/phase2_data/instrument.mjs','foundry.toml','tools/execution-budget.mjs','execution-budget.json'])sourceHashes[file]=sha(await readFile(file));
  const report={gasLimit,gasBudgetSource,kind:'phase2-genuine-walls-ordinary-EVM',client:await rpc('web3_clientVersion'),resourceIdentity:bundle.resourceIdentity,sourceHashes,instrumentation:instrumented.report,calibration:{actualMsize:actual,decodedHighWater:calibration.highWaterBytes},scope:'All WAD chunks and both probes ordinarily CREATE-deployed; no etch/setCode. Telemetry changes source-mapped GAS helper only. Every call and mined transaction retains identical gas and original-C pixels. No full-plane/sprite performance claim.',upload:{chunkCount:chunks.length,chunkBytes:blob.length,chunkDeploymentMs,totalGas:chunks.reduce((s,c)=>s+c.gasUsed,0),chunks},probeDeployments:{normal,telemetry},results};
  await mkdir(dirname(resolve(output)),{recursive:true});await writeFile(output,JSON.stringify(report,null,2)+'\n');console.log('Saved '+output);
} finally {if(server){server.kill('SIGTERM');await new Promise(resolve=>{if(server.exitCode!==null)return resolve();server.once('exit',resolve);setTimeout(()=>{server.kill('SIGKILL');resolve();},1000);});}}
