// SPDX-License-Identifier: GPL-2.0-only
// Ordinary CREATE uploads and byte-for-byte sample reads from a real packed WAD.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {spawn,execFileSync} from 'node:child_process';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {makeRpc,receipt} from '../../web/protocol.mjs';
import {canonical} from '../wad/wad.ts';
import {validateSchema} from '../wad/schema.ts';
import {loadGasBudget, executionEnv} from '../execution-budget.mjs';
const {gasLimit, gasHex, source: gasBudgetSource} = loadGasBudget();
const budgetEnv = executionEnv({...process.env, DOOM_GAS_LIMIT: String(gasLimit)});
process.chdir(fileURLToPath(new URL('../../',import.meta.url)));
const args=process.argv.slice(2),option=(name,fallback)=>{const i=args.indexOf(name);return i<0?fallback:args[i+1];};
const bundlePath=option('--bundle',null);
assert(bundlePath,'Usage: node tools/resources/benchmark.mjs --bundle path/to/bundle.json');
const bundle=JSON.parse(await readFile(bundlePath,'utf8'));
validateSchema(bundle,JSON.parse(await readFile('schemas/resource-bundle-v0.schema.json','utf8')));
assert.equal(bundle.provenance.kind,'wad');
const blob=await readFile(resolve(dirname(bundlePath),bundle.blobFile));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
assert.equal(sha(blob),bundle.blobSha256);
assert.equal(blob.length,bundle.blobByteLength);
const manifest=Object.fromEntries(Object.entries(bundle).filter(([key])=>!['resourceIdentity','blobFile'].includes(key)));
assert.equal(sha(canonical(manifest)),bundle.resourceIdentity.bundleSha256,'bundle manifest identity');
const snapshot=JSON.parse(await readFile('test/fixtures/wad/snapshot.json','utf8'));
assert.deepEqual(bundle.resourceIdentity,snapshot.resourceIdentity,'pinned WAD package identity');
let cursor=0;
for(const [index,lump] of bundle.lumps.entries()){assert.equal(lump.id,index);assert.equal(lump.offset,cursor);cursor+=lump.length;assert(cursor<=blob.length&&cursor<=0xffffffff);}
assert.equal(cursor,blob.length);
assert.equal(bundle.resourceIdentity.wadSha256,bundle.provenance.wadSha256);
const name=lump=>Buffer.from(lump.nameHex,'hex').toString('ascii').replace(/\0.*$/,'');
const selected=[];
for(const [lumpName,limit] of [['PLAYPAL',768],['COLORMAP',4096],['NODES',16384]]) {
  const lump=lumpName==='NODES'?bundle.lumps.find(x=>name(x)===lumpName):bundle.lumps.findLast(x=>name(x)===lumpName);
  assert(lump&&lump.length>0,`missing ${lumpName}`);
  const payload=blob.subarray(lump.offset,lump.offset+Math.min(lump.length,limit));
  selected.push({lump,payload});
}
const port=Number(option('--port','18553')),rpc=makeRpc(`http://127.0.0.1:${port}`);
const word=x=>BigInt(x).toString(16).padStart(64,'0');
const bytesAbi=bytes=>word(32)+word(bytes.length)+bytes.toString('hex').padEnd(Math.ceil(bytes.length/32)*64,'0');
const sig=s=>execFileSync(resolve('.toolchain/bin/cast'),['sig',s],{encoding:'utf8'}).trim();
const readSig=sig('read(uint256,uint256)'),sampleSig=sig('sample(uint256,uint256)'),sourceSig=sig('source()');
const nodeArgs=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--disable-block-gas-limit','--memory-limit','1073741824','--silent'];
let node;
const results=[];
try {
  try {await rpc('web3_clientVersion');throw Error('Port in use');}catch(e){if(e.message==='Port in use')throw e;}
  execFileSync(resolve('.toolchain/bin/forge'),['build'],{env:budgetEnv,stdio:'pipe',timeout:120000});
  node=spawn(resolve('.toolchain/bin/anvil'),nodeArgs,{stdio:['ignore','ignore','pipe']});
  let startError,output='';node.on('error',e=>startError=e);node.stderr.on('data',x=>output+=x);
  const deadline=Date.now()+30000;
  for(;;){
    if(startError)throw startError;if(node.exitCode!==null)throw Error(output);
    try{await rpc('web3_clientVersion');break;}catch{}
    if(Date.now()>deadline)throw Error('Anvil readiness timeout');
    await new Promise(r=>setTimeout(r,50));
  }
  await rpc('anvil_setBlockGasLimit',[gasHex]);
  const [from]=await rpc('eth_accounts');
  for(const {lump,payload} of selected) {
    const strategies=[];
    for(const contract of ['StorageResourceFixture','CodeResourceFixture']) {
      const artifact=JSON.parse(await readFile(`out/ResourcePlacement.sol/${contract}.json`,'utf8'));
      const data=artifact.bytecode.object+bytesAbi(payload);
      const start=performance.now();
      const deployment=await receipt(rpc,await rpc('eth_sendTransaction',[{from,data,gas:gasHex}]));
      assert.equal(deployment.status,'0x1');
      const uploadMs=performance.now()-start,to=deployment.contractAddress,reads=[];
      for(const [offset,length] of [[0,Math.min(32,payload.length)],[Math.min(17,payload.length),Math.min(768,Math.max(0,payload.length-17))],[0,payload.length],[payload.length,0]]) {
        const argumentsAbi=word(offset)+word(length);
        const response=await rpc('eth_call',[{from,to,data:readSig+argumentsAbi,gas:gasHex},'latest']);
        assert.equal(BigInt('0x'+response.slice(2,66)),32n);
        assert.equal(Number(BigInt('0x'+response.slice(66,130))),length);
        const bytes=Buffer.from(response.slice(130,130+length*2),'hex');
        assert.deepEqual(bytes,payload.subarray(offset,offset+length));
        const began=performance.now();
        const mined=await receipt(rpc,await rpc('eth_sendTransaction',[{from,to,data:sampleSig+argumentsAbi,gas:gasHex}]));
        assert.equal(mined.status,'0x1');assert.equal(mined.logs.length,1);
        assert.equal(mined.logs[0].data,'0x'+sha(bytes));
        reads.push({offset,length,sha256:sha(bytes),gasUsed:Number(BigInt(mined.gasUsed)),receiptMs:performance.now()-began,transactionHash:mined.transactionHash});
      }
      let auxiliaryRuntimeBytes=0;
      if(contract==='CodeResourceFixture') {
        const target='0x'+(await rpc('eth_call',[{to,data:sourceSig},'latest'])).slice(-40);
        const code=await rpc('eth_getCode',[target,'latest']);
        assert.equal(code,'0x00'+payload.toString('hex'));
        auxiliaryRuntimeBytes=(code.length-2)/2;
      }
      strategies.push({contract,uploadGas:Number(BigInt(deployment.gasUsed)),uploadReceiptMs:uploadMs,initcodeBytes:(data.length-2)/2,runtimeBytes:(artifact.deployedBytecode.object.length-2)/2,auxiliaryRuntimeBytes,address:to,deploymentTransactionHash:deployment.transactionHash,reads});
    }
    results.push({lumpId:lump.id,lumpName:name(lump),sourceLength:lump.length,measuredBytes:payload.length,payloadSha256:sha(payload),strategies});
  }
  const report={gasLimit,gasBudgetSource,scope:'Phase 1 static WAD resource placement; no renderer/frame-access measurement',wadSha256:bundle.resourceIdentity.wadSha256,bundleSha256:bundle.resourceIdentity.bundleSha256,anvilVersion:await rpc('web3_clientVersion'),nodeArgs,timestamp:new Date().toISOString(),results,notes:['Each read transaction has cold storage/account access; read() output is checked against actual WAD bytes before measuring sample().','sample() includes SHA-256 and one event; upload includes ordinary constructor deployment and initialization.','Code strategy includes deployment of both reader and STOP-prefixed payload contract.','Timings include client/RPC/mining overhead; these are not isolated EVM execution times.','No anvil_setCode, custom opcode or frame/view precomputation. Full renderer access patterns remain a Phase 2+ measurement.']};
  const out=option('--output','artifacts/local/resource-placement.json');await mkdir(dirname(out),{recursive:true});
  await writeFile(out,JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report,null,2));
}finally {
  if(node?.pid&&node.exitCode===null&&node.signalCode===null) {
    await new Promise(done=>{const timer=setTimeout(()=>{node.kill('SIGKILL');done();},2000);node.once('exit',()=>{clearTimeout(timer);done();});node.kill('SIGTERM');});
  }
}
