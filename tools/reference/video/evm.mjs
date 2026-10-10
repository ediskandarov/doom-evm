#!/usr/bin/env node
// Goal 4.1: ordinary CREATE, immutable original patches, EVM pixels -> frozen Frame ABI.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {spawn,execFileSync} from 'node:child_process';
import {connect} from 'node:net';
import assert from 'node:assert/strict';
import {resolve} from 'node:path';
import {loadGasBudget} from '../../execution-budget.mjs';
import {decodeFrame} from '../../../web/protocol.mjs';
const port=Number(process.env.VIDEO_PORT??18694);
assert(port>1024&&port<65536&&![18579,18690].includes(port),'use a fresh isolated node');
const output=process.env.VIDEO_REPORT??'artifacts/phase4/video-evm.json';
const {gasHex,gasLimit}=loadGasBudget();
const hash=b=>createHash('sha256').update(b).digest('hex');
const read=async p=>JSON.parse(await readFile(p,'utf8'));
const patches=await read('test/fixtures/phase4_video/patches.json');
const cases=await read('test/fixtures/phase4_video/cases.json');
const artifact=await read('out/VideoProbe.sol/VideoProbe.json');
const store=await read('out/ResourceStore.sol/ResourceStore.json');
const word=n=>BigInt(n).toString(16).padStart(64,'0');
const zero='0x'+'0'.repeat(64);
let child,stderr='',id=0;
const url=`http://127.0.0.1:${port}`;
async function rpc(method,params=[]){
 const response=await fetch(url,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(120000)});
 const data=await response.json();if(data.error)throw Error(JSON.stringify(data.error));return data.result;
}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function receipt(tx){const deadline=Date.now()+120000;while(Date.now()<deadline){const r=await rpc('eth_getTransactionReceipt',[tx]);if(r)return r;await sleep(25);}throw Error('receipt deadline');}
async function send(from,to,data){const tx=await rpc('eth_sendTransaction',[{from,...(to?{to}:{}),data,gas:gasHex}]);return receipt(tx);}
try {
 const occupied=await new Promise(resolve=>{const socket=connect({host:'127.0.0.1',port});socket.once('connect',()=>{socket.destroy();resolve(true);});socket.once('error',()=>resolve(false));socket.setTimeout(1000,()=>{socket.destroy();resolve(true);});});assert(!occupied,'port is occupied; refusing to use existing node');
 child=spawn(resolve('.toolchain/bin/anvil'),['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--gas-limit',String(gasLimit),'--memory-limit','1073741824','--silent'],{stdio:['ignore','ignore','pipe']});
 child.stderr.on('data',b=>{stderr+=b;});
 const ready=Date.now()+15000;while(true){try{await rpc('eth_chainId');break;}catch(e){if(Date.now()>ready)throw Error('Anvil start failed: '+stderr);await sleep(50);}}
 const [from]=await rpc('eth_accounts');
 const deployed=await send(from,null,artifact.bytecode.object);assert.equal(deployed.status,'0x1');
 const contract=deployed.contractAddress;
 const runtime=await rpc('eth_getCode',[contract,'latest']);
 const rows=[],frames=new Map();
 const signature='render(((uint32,bytes32,bytes32,bytes32,uint8),address[],uint32,(bytes8,uint32,uint32)[]),uint32,int32,int32,uint32,bool)';
 let sequence=0;
 for(const patch of patches.patches.filter(p=>p.id<6)){
  const bytes=await readFile('test/fixtures/phase4_video/'+patch.path);assert.equal(hash(bytes),patch.sha256);
  const chunks=[];
  for(let at=0;at<bytes.length;at+=16384){const part=bytes.subarray(at,at+16384);const args=word(32)+word(part.length)+part.toString('hex').padEnd(Math.ceil(part.length/32)*64,'0');
   const r=await send(from,null,store.bytecode.object+args);assert.equal(r.status,'0x1');const code=await rpc('eth_getCode',[r.contractAddress,'latest']);assert.equal(code,'0x00'+part.toString('hex'));chunks.push(r.contractAddress);}
  const name='0x'+Buffer.from(patch.name).toString('hex').padEnd(16,'0');
  const source=`((0,${zero},${zero},${zero},0),[${chunks.join(',')}],${bytes.length},[(${name},0,${bytes.length})])`;
  const native=cases.cases.find(c=>c.name==='patch-'+patch.name);assert(native);
  const [,x,y]=native.inputs;
  async function render(world168){const data=execFileSync(resolve('.toolchain/bin/cast'),['calldata',signature,source,'0',String(x),String(y),String(++sequence),String(world168)],{encoding:'utf8'}).trim();return send(from,contract,data);}
  const r=await render(false);assert.equal(r.status,'0x1');assert.equal(r.logs.length,1);
  const frame=decodeFrame(r.logs[0]);assert.equal(frame.width,320);assert.equal(frame.height,200);assert.equal(frame.frameId,BigInt(sequence));assert.equal(frame.inputSeq,sequence);
  const pixels=Buffer.from(frame.pixels);assert.equal(hash(pixels),native.sha256[0],patch.name+' original C full pixels');frames.set(patch.id,pixels);
  rows.push({patch:patch.name,profile:'320x200',transaction:r.transactionHash,status:r.status,gasUsed:Number(BigInt(r.gasUsed)),frameSha256:hash(pixels),nativeCase:native.name,pixelCount:64000});
  if(patch.id===2){const reduced=await render(true);assert.equal(reduced.status,'0x1');assert.equal(reduced.logs.length,1);const event=decodeFrame(reduced.logs[0]);const actual=Buffer.from(event.pixels);const expected=Buffer.from(pixels);for(let y=0;y<168;++y)expected[y*320]=0x77;assert.deepEqual(actual,expected,'R_DrawColumn 168 rows with same V patch, bottom32 preserved');rows.push({patch:patch.name,profile:'320x168 world + untouched32 rows',transaction:reduced.transactionHash,status:reduced.status,gasUsed:Number(BigInt(reduced.gasUsed)),frameSha256:hash(actual),pixelCount:64000,scope:'Same authentic patch/native-equivalent base frame; original R_Draw column shares screen0 alias, only first168 column0 pixels changed.'});}
 }
 // Physical malformed reads must revert a mined transaction and cannot advance counters or emit frames.
 const bytes=Buffer.from('0100040000000000ffffffff','hex');
 const args=word(32)+word(bytes.length)+bytes.toString('hex').padEnd(64,'0');const badStore=await send(from,null,store.bytecode.object+args);
 const source=`((0,${zero},${zero},${zero},0),[${badStore.contractAddress}],${bytes.length},[(0x4241440000000000,0,${bytes.length})])`;
 const data=execFileSync(resolve('.toolchain/bin/cast'),['calldata',signature,source,'0','0','0',String(sequence+1),'false'],{encoding:'utf8'}).trim();
 const before=await rpc('eth_getStorageAt',[contract,'0x0','latest']);const invalid=await send(from,contract,data);assert.equal(invalid.status,'0x0');assert.equal(invalid.logs.length,0);assert.equal(await rpc('eth_getStorageAt',[contract,'0x0','latest']),before);
 const sources={};for(const p of ['src/doom/v_video.sol','src/doom/v_video_types.sol','src/support/VideoProbe.sol','foundry.toml','execution-budget.json','tools/reference/video/evm.mjs','test/fixtures/phase4_video/cases.bin','test/fixtures/phase4_video/patches.json','web/protocol.mjs'])sources[p]=hash(await readFile(p));
 const report={schemaVersion:1,goal:'4.1',pass:true,kind:'ordinary isolated Anvil video support integration',productionEngineModified:false,resourceScope:'Six authentic patches verified against fixture hashes, supplied through existing immutable ResourceStore/R_Data reader; this support probe does not authenticate a full WAD deployment.',rpcPort:port,compiler:{version:artifact.metadata.compiler.version,settings:artifact.metadata.settings},gasBudget:gasLimit,contract,creationTransaction:deployed.transactionHash,deploymentGas:Number(BigInt(deployed.gasUsed)),runtimeBytes:(runtime.length-2)/2,runtimeSha256:hash(Buffer.from(runtime.slice(2),'hex')),rows,rollback:{transaction:invalid.transactionHash,status:invalid.status,logs:0,gasUsed:Number(BigInt(invalid.gasUsed)),counterUnchanged:true},sourceSha256:sources};
 await mkdir(resolve(output,'..'),{recursive:true});await writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({pass:true,frames:rows.length,gas:rows.map(r=>r.gasUsed),report:output}));
} finally {if(child?.exitCode===null){await new Promise(resolve=>{child.once('exit',resolve);child.kill('SIGTERM');});}}
