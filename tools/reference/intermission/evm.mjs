#!/usr/bin/env node
// Verification only: ordinary immutable resources and WI receipts; JS transports/compares bytes.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {spawn,execFileSync} from 'node:child_process';
import {connect} from 'node:net';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
import {decodeFrame} from '../../../web/protocol.mjs';
import {loadGasBudget} from '../../execution-budget.mjs';

const port=Number(process.env.INTERMISSION_PORT??18746);
assert(Number.isInteger(port)&&port>1024&&port<65536&&![18579,18880,8088].includes(port),'use isolated port');
const output=process.env.INTERMISSION_REPORT??'artifacts/phase4/intermission/evm.json';
const hash=b=>createHash('sha256').update(b).digest('hex');
const read=async p=>JSON.parse(await readFile(p,'utf8'));
const fixture=await read('test/fixtures/phase4_intermission/cases.json');
const native=await read('test/fixtures/phase4_intermission/native.json');
const artifact=await read('out/IntermissionProbe.sol/IntermissionProbe.json');
const store=await read('out/ResourceStore.sol/ResourceStore.json');
const {gasHex,gasLimit}=loadGasBudget();
const word=n=>BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');
const dynamic=b=>word(b.length)+b.toString('hex').padEnd(Math.ceil(b.length/32)*64,'0');
const calldata=(method,b,seq)=>'0x'+artifact.methodIdentifiers[method]+word(64)+word(seq)+dynamic(b);
const actionData=(a,seq,draw)=>'0x'+artifact.methodIdentifiers['act(int32[5],uint32,bool)']+a.map(word).join('')+word(seq)+word(Number(draw));
function decodeBytes(data,index=0){
 const b=Buffer.from(data.slice(2),'hex');const p=Number(BigInt('0x'+b.subarray(index*32,index*32+32).toString('hex')));
 const n=Number(BigInt('0x'+b.subarray(p,p+32).toString('hex')));assert(p+32+n<=b.length);return b.subarray(p+32,p+32+n);
}
function expectedSnapshots(expected){
 const output=[];assert.equal(expected.length%532,0);
 for(let p=0;p<expected.length;p+=532)output.push(Buffer.concat([
  Buffer.from(hash(expected.subarray(p,p+452)),'hex'),Buffer.from(hash(expected.subarray(p+452,p+468)),'hex'),expected.subarray(p+468,p+532)]));
 return output;
}
let child,stderr='',id=0;const url=`http://127.0.0.1:${port}`;
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function rpc(method,params=[]){
 const r=await fetch(url,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(120000)});
 const j=await r.json();if(j.error)throw Error(JSON.stringify(j.error));return j.result;
}
async function send(from,to,data){
 const timer=performance.now();const tx=await rpc('eth_sendTransaction',[{from,...(to?{to}:{}),data,gas:gasHex}]);
 const deadline=Date.now()+120000;
 while(Date.now()<deadline){const r=await rpc('eth_getTransactionReceipt',[tx]);if(r)return {...r,measuredMilliseconds:performance.now()-timer};await sleep(25);}
 throw Error('receipt timeout');
}
async function storageHash(address){return (await rpc('eth_getProof',[address,[],'latest'])).storageHash;}
async function status(address){
 const result=await rpc('eth_call',[{to:address,data:'0x'+artifact.methodIdentifiers['snapshot()']},'latest']);
 const b=Buffer.from(result.slice(2),'hex');return {state:decodeBytes(result),frameHash:b.subarray(32,64).toString('hex')};
}
function assertSnapshots(receipt,expected){
 assert.equal(receipt.status,'0x1');assert.deepEqual(decodeBytes(receipt.logs[0].data),Buffer.concat(expected),'native state/dirty/pixel/background snapshots');
}
const start=new Date().toISOString();const rows=[],deployments=[],resources=[],storageRows=[],rejections=[];let sequence=0;
try {
 const occupied=await new Promise((r,reject)=>{
  const socket=connect({host:'127.0.0.1',port});socket.once('connect',()=>{socket.destroy();r(true);});
  socket.once('error',e=>{if(e.code==='ECONNREFUSED')r(false);else reject(e);});socket.setTimeout(1000,()=>{socket.destroy();r(true);});
 });assert(!occupied,'refusing occupied port');
 child=spawn(resolve('.toolchain/bin/anvil'),['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--gas-limit',String(gasLimit),'--memory-limit','1073741824','--silent'],{stdio:['ignore','ignore','pipe']});
 child.stderr.on('data',b=>{stderr+=b;});child.on('error',e=>{stderr+=String(e);});
 const ready=Date.now()+15000;while(true){try{await rpc('eth_chainId');break;}catch(e){if(Date.now()>ready)throw Error('Anvil start failed: '+stderr);await sleep(50);}}
 const [from,other]=await rpc('eth_accounts');const probes=[];
 for(let profile=0;profile<4;++profile){
  const file=await readFile(`test/fixtures/phase4_intermission/assets-${profile}.bin`);
  assert.equal(hash(file),native.assetProfiles[profile].sha256);
  const count=file.readUInt32BE(0),base=4+count*16,blob=file.subarray(base);assert.equal(hash(blob),native.assetProfiles[profile].blobSha256);
  const chunks=[];
  for(let p=0;p<blob.length;p+=16384){
   const part=blob.subarray(p,p+16384),receipt=await send(from,null,store.bytecode.object+word(32)+dynamic(part));
   assert.equal(receipt.status,'0x1');const code=await rpc('eth_getCode',[receipt.contractAddress,'latest']);assert.equal(code,'0x00'+part.toString('hex'));
   chunks.push(receipt.contractAddress);resources.push({profile,offset:p,length:part.length,address:receipt.contractAddress,transaction:receipt.transactionHash,gasUsed:Number(BigInt(receipt.gasUsed)),runtimeSha256:hash(Buffer.from(code.slice(2),'hex'))});
  }
  const descriptors=[];
  for(let i=0;i<count;++i){const p=4+i*16;descriptors.push(`(0x${file.subarray(p,p+8).toString('hex')},${file.readUInt32BE(p+8)},${file.readUInt32BE(p+12)})`);}
  const zero='0x'+'0'.repeat(64);const view=`((0,${zero},${zero},${zero},0),[${chunks.join(',')}],${blob.length},[${descriptors.join(',')}])`;
  const args=execFileSync(resolve('.toolchain/bin/cast'),['abi-encode','f(((uint32,bytes32,bytes32,bytes32,uint8),address[],uint32,(bytes8,uint32,uint32)[]))',view],{encoding:'utf8'}).trim().slice(2);
  const receipt=await send(from,null,artifact.bytecode.object+args);assert.equal(receipt.status,'0x1');
  const address=receipt.contractAddress,code=Buffer.from((await rpc('eth_getCode',[address,'latest'])).slice(2),'hex');
  const compiled=Buffer.from(artifact.deployedBytecode.object.replace(/^0x/,''),'hex');
  for(const refs of Object.values(artifact.deployedBytecode.immutableReferences??{}))for(const ref of refs){assert.equal(ref.length,32);Buffer.from(word(BigInt(from)),'hex').copy(compiled,ref.start);}
  assert.deepEqual(code,compiled,'deployed WI runtime equals source-bound artifact with actual driver');
  probes.push(address);deployments.push({profile,address,transaction:receipt.transactionHash,gasUsed:Number(BigInt(receipt.gasUsed)),runtimeBytes:code.length,runtimeSha256:hash(code)});
 }
 const sequences=[0,0,0,0];
 for(let i=0;i<fixture.caseCount;++i){
  const row=fixture.cases[i],profile=row.header[15],address=probes[profile];
  const data=await readFile(`test/fixtures/phase4_intermission/${i}.bin`),expected=await readFile(`test/fixtures/phase4_intermission/${i}.expected.bin`);
  assert.equal(hash(data),row.inputSha256);assert.equal(hash(expected),row.expectedSha256);
  const receipt=await send(from,address,calldata('run(bytes,uint32)',data,++sequences[profile]));assertSnapshots(receipt,expectedSnapshots(expected));assert.equal(receipt.logs.length,2);
  const frame=decodeFrame(receipt.logs[1]),actual=Buffer.from(frame.pixels),original=await readFile(`test/fixtures/phase4_intermission/${i}.pixels`);
  assert.deepEqual(actual,original,'all 64000 native indexes');assert.equal(frame.width,320);assert.equal(frame.height,200);assert.equal(frame.inputSeq,sequences[profile]);
  const current=await status(address);assert.deepEqual(current.state,expected.subarray(expected.length-532,expected.length-80));assert.equal(current.frameHash,hash(original));
  await mkdir('artifacts/local/intermission/frames',{recursive:true});await writeFile(`artifacts/local/intermission/frames/${i}.pixels`,actual);
  rows.push({case:i,name:row.name,profile,transaction:receipt.transactionHash,gasUsed:Number(BigInt(receipt.gasUsed)),measuredMilliseconds:receipt.measuredMilliseconds,nativeSnapshots:row.snapshots,frameSha256:hash(actual),exactIndexedPixels:64000,inputSeq:frame.inputSeq,frameId:String(frame.frameId)});
 }
 // Separate calls persist/reload genuine WI globals/latches/RNG and source-generated framebuffer.
 for(const index of [4,7]){
  const row=fixture.cases[index],profile=row.header[15],address=probes[profile];
  const data=await readFile(`test/fixtures/phase4_intermission/${index}.bin`),expected=await readFile(`test/fixtures/phase4_intermission/${index}.expected.bin`);
  const snapshots=expectedSnapshots(expected);let receipt=await send(from,address,calldata('begin(bytes,uint32)',data.subarray(0,64),++sequences[profile]));assertSnapshots(receipt,[snapshots[0]]);
  storageRows.push({case:index,action:'begin',transaction:receipt.transactionHash,gasUsed:Number(BigInt(receipt.gasUsed)),nativeSnapshot:0});
  for(let j=0;j<row.actions.length;++j){
   const action=row.actions[j],draw=action[0]===1||action[3]!==0;
   receipt=await send(from,address,actionData(action,++sequences[profile],draw));assertSnapshots(receipt,[snapshots[j+1]]);
   if(draw){const frame=decodeFrame(receipt.logs[1]);assert.equal(hash(Buffer.from(frame.pixels)),row.hashes[j+1].frameSha256);}
   if(index===4&&j===0)await writeFile('artifacts/local/intermission/frames/statistics.pixels',Buffer.from(decodeFrame(receipt.logs[1]).pixels));
   storageRows.push({case:index,action:j,transaction:receipt.transactionHash,gasUsed:Number(BigInt(receipt.gasUsed)),nativeSnapshot:j+1,rendered:draw});
  }
 }
 const address=probes[0],seq=sequences[0],invalidFixture=Buffer.from([0]);
 const invalids=[
  ['stale sequence',from,calldata('run(bytes,uint32)',await readFile('test/fixtures/phase4_intermission/4.bin'),seq)],
  ['unauthorized driver',other,calldata('run(bytes,uint32)',await readFile('test/fixtures/phase4_intermission/4.bin'),seq+1)],
  ['malformed script',from,calldata('run(bytes,uint32)',invalidFixture,seq+1)],
  ['post-completion tick',from,actionData([0,1,0,0,0],seq+1,false)],
  ['post-free draw',from,actionData([1,0,0,0,0],seq+1,true)],
 ];
 const badHeader=Buffer.from(await readFile('test/fixtures/phase4_intermission/4.bin'));badHeader.writeInt32BE(2,0);
 invalids.push(['commercial mode',from,calldata('run(bytes,uint32)',badHeader,seq+1)]);
 for(const [name,sender,data] of invalids){const before=await storageHash(address);const receipt=await send(sender,address,data);assert.equal(receipt.status,'0x0');assert.equal(receipt.logs.length,0);assert.equal(await storageHash(address),before);rejections.push({name,transaction:receipt.transactionHash,gasUsed:Number(BigInt(receipt.gasUsed)),storageRootUnchanged:true,logs:0});}
 const sources={};for(const path of ['src/doom/wi_stuff.sol','src/doom/wi_stuff_types.sol','src/support/IntermissionFixture.sol','src/support/IntermissionProbe.sol','src/doom/v_video.sol','src/doom/m_random.sol','src/doom/r_data.sol','foundry.toml','execution-budget.json','tools/reference/intermission/evm.mjs','test/fixtures/phase4_intermission/native.json','test/fixtures/phase4_intermission/cases.bin','web/protocol.mjs'])sources[path]=hash(await readFile(path));
 const report={schemaVersion:1,goal:'4.14a',pass:true,start,end:new Date().toISOString(),rpcPort:port,gasBudget:gasLimit,
  scope:'Independent WI support host; compact named UI fixtures with original-WAD provenance, separately declared synthetic profiles; no production/full-WAD authentication, level progression or browser integration claim',
  compiler:{version:artifact.metadata.compiler.version,settings:artifact.metadata.settings},resources,deployments,rows,storageRows,rejections,
  snapshotsCompared:rows.reduce((n,r)=>n+r.nativeSnapshots,0),sourceSha256:sources};
 await mkdir(resolve(output,'..'),{recursive:true});await writeFile(output,JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({pass:true,frames:rows.length,snapshots:report.snapshotsCompared,storageCalls:storageRows.length,rejections:rejections.length,gasRange:[Math.min(...rows.map(r=>r.gasUsed)),Math.max(...rows.map(r=>r.gasUsed))],output}));
}finally{
 if(child?.exitCode===null)await new Promise(r=>{child.once('exit',r);child.kill('SIGTERM');});
}
