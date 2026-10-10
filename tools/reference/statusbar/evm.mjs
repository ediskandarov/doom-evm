#!/usr/bin/env node
// Dedicated Goal 4.2 consumer: ordinary immutable resources -> EVM status/palette -> Frame.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {spawn,execFileSync} from 'node:child_process';
import {connect} from 'node:net';
import assert from 'node:assert/strict';
import {resolve} from 'node:path';
import {loadGasBudget} from '../../execution-budget.mjs';
import {decodeFrame} from '../../../web/protocol.mjs';
const port=Number(process.env.STATUSBAR_PORT??18695);
assert(port>1024&&port<65536&&![18579,18690,18694].includes(port));
const output=process.env.STATUSBAR_REPORT??'artifacts/phase4/statusbar-evm.json';
const {gasHex,gasLimit}=loadGasBudget();
const hash=b=>createHash('sha256').update(b).digest('hex');
const read=async p=>JSON.parse(await readFile(p,'utf8'));
const artifact=await read('out/StatusBarFrame.sol/StatusBarFrame.json');
const store=await read('out/ResourceStore.sol/ResourceStore.json');
const cases=await read('test/fixtures/phase4_statusbar/cases.json');
const word=n=>BigInt(n).toString(16).padStart(64,'0');const zero='0x'+'0'.repeat(64);
let child,stderr='',id=0;const url=`http://127.0.0.1:${port}`;
async function rpc(method,params=[]){const r=await fetch(url,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(120000)});const data=await r.json();if(data.error)throw Error(JSON.stringify(data.error));return data.result;}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function send(from,to,data){const tx=await rpc('eth_sendTransaction',[{from,...(to?{to}:{}),data,gas:gasHex}]);const deadline=Date.now()+120000;while(Date.now()<deadline){const r=await rpc('eth_getTransactionReceipt',[tx]);if(r)return r;await sleep(25);}throw Error('receipt timeout');}
try {
 const occupied=await new Promise(resolve=>{const s=connect({host:'127.0.0.1',port});s.once('connect',()=>{s.destroy();resolve(true);});s.once('error',()=>resolve(false));s.setTimeout(1000,()=>{s.destroy();resolve(true);});});assert(!occupied,'refusing occupied port');
 child=spawn(resolve('.toolchain/bin/anvil'),['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--gas-limit',String(gasLimit),'--memory-limit','1073741824','--silent'],{stdio:['ignore','ignore','pipe']});child.stderr.on('data',b=>{stderr+=b;});
 const ready=Date.now()+15000;while(true){try{await rpc('eth_chainId');break;}catch(e){if(Date.now()>ready)throw Error('Anvil start failed: '+stderr);await sleep(50);}}
 const [from]=await rpc('eth_accounts');const deployed=await send(from,null,artifact.bytecode.object);assert.equal(deployed.status,'0x1');const contract=deployed.contractAddress;const runtime=await rpc('eth_getCode',[contract,'latest']);assert.equal(runtime.toLowerCase(),artifact.deployedBytecode.object.toLowerCase());
 const blob=await readFile('test/fixtures/phase4_statusbar/resources.bin');const dir=await readFile('test/fixtures/phase4_statusbar/directory.bin');const chunks=[];const deployments=[];
 for(let at=0;at<blob.length;at+=16384){const part=blob.subarray(at,at+16384);const args=word(32)+word(part.length)+part.toString('hex').padEnd(Math.ceil(part.length/32)*64,'0');const r=await send(from,null,store.bytecode.object+args);assert.equal(r.status,'0x1');assert.equal(await rpc('eth_getCode',[r.contractAddress,'latest']),'0x00'+part.toString('hex'));chunks.push(r.contractAddress);deployments.push({transaction:r.transactionHash,bytes:part.length,gasUsed:Number(BigInt(r.gasUsed))});}
 const lumps=[];for(let at=0;at<dir.length;at+=16)lumps.push([`0x${dir.subarray(at,at+8).toString('hex')}`,dir.readUInt32LE(at+8),dir.readUInt32LE(at+12)]);
 const source=ls=>`((0,${zero},${zero},${zero},0),[${chunks.join(',')}],${blob.length},[${ls.map(l=>'('+l.join(',')+')').join(',')}])`;
 const signature='render(((uint32,bytes32,bytes32,bytes32,uint8),address[],uint32,(bytes8,uint32,uint32)[]),bool,bool,uint32,int32)';
 const calldata=(ls,legacy,seq,damage)=>execFileSync(resolve('.toolchain/bin/cast'),['calldata',signature,source(ls),'false',String(legacy),String(seq),String(damage)],{encoding:'utf8'}).trim();
 const rows=[];let seq=0;
 for(const [suite,legacy,damage] of [['inventory',false,0],['receipt_damage',false,9],['palettes',true,0]]){
  const native=cases.suites[suite][0];const r=await send(from,contract,calldata(lumps,legacy,++seq,damage));assert.equal(r.status,'0x1');assert.equal(r.logs.length,2);
  const palette=r.logs[0];assert.equal(palette.address.toLowerCase(),contract.toLowerCase());assert.equal(palette.topics.length,2);assert.equal(palette.topics[0],execFileSync(resolve('.toolchain/bin/cast'),['keccak','StatusPalette(uint64,uint8,bytes)'],{encoding:'utf8'}).trim());const data=Buffer.from(palette.data.slice(2),'hex');const index=Number(BigInt('0x'+data.subarray(0,32).toString('hex')));const offset=Number(BigInt('0x'+data.subarray(32,64).toString('hex')));const len=Number(BigInt('0x'+data.subarray(offset,offset+32).toString('hex')));const rgb=data.subarray(offset+32,offset+32+len);
  assert.equal(len,768);assert.equal(index,native.state[6]);assert.equal(hash(rgb),native.sha256[2]);assert.equal(BigInt(palette.topics[1]),BigInt(seq));
  const frame=decodeFrame(r.logs[1]);assert.equal(frame.frameId,BigInt(seq));assert.equal(frame.inputSeq,seq);assert.equal(frame.width,320);assert.equal(frame.height,200);assert.equal(hash(Buffer.from(frame.pixels)),native.sha256[0]);
  rows.push({suite,legacy,damage,transaction:r.transactionHash,gasUsed:Number(BigInt(r.gasUsed)),frameSha256:native.sha256[0],paletteSha256:hash(rgb),paletteIndex:index,pixelCount:64000});
 }
 const corrupt=lumps.map(l=>[...l]);const bar=corrupt.find(l=>Buffer.from(l[0].slice(2),'hex').toString().replaceAll('\0','')==='STBAR');assert(bar);bar[2]=4;
 const before=await rpc('eth_getStorageAt',[contract,'0x0','latest']);const invalid=await send(from,contract,calldata(corrupt,false,seq+1,0));assert.equal(invalid.status,'0x0');assert.equal(invalid.logs.length,0);assert.equal(await rpc('eth_getStorageAt',[contract,'0x0','latest']),before);
 const paths=['src/doom/st_lib.sol','src/doom/st_stuff.sol','test/statusbar/StatusBarFrame.sol','tools/reference/statusbar/evm.mjs','test/fixtures/phase4_statusbar/resources.bin','test/fixtures/phase4_statusbar/cases.json','foundry.toml','execution-budget.json'];const sourceSha256={};for(const p of paths)sourceSha256[p]=hash(await readFile(p));
 const report={goal:'4.2',pass:true,kind:'ordinary isolated Anvil status-bar consumer',scope:'Authentic resource bytes loaded through ordinary ResourceStore CREATE; all status pixels, face selection and gamma palette produced in EVM. Seeded top168 background for these receipts; real native world composition verified separately in dedicated Foundry integration.',productionAdaptersModified:false,port,gasBudget:gasLimit,compiler:artifact.metadata.compiler,compilerSettings:artifact.metadata.settings,runtimeSha256:hash(Buffer.from(runtime.slice(2),'hex')),artifactSha256:hash(await readFile('out/StatusBarFrame.sol/StatusBarFrame.json')),creation:{transaction:deployed.transactionHash,gasUsed:Number(BigInt(deployed.gasUsed))},resourceDeployments:deployments,rows,rollback:{transaction:invalid.transactionHash,status:invalid.status,logs:0,counterUnchanged:true},sourceSha256};
 await mkdir(resolve(output,'..'),{recursive:true});await writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({pass:true,frames:rows.length,gas:rows.map(r=>r.gasUsed),output}));
} finally {if(child?.exitCode===null)await new Promise(resolve=>{child.once('exit',resolve);child.kill('SIGTERM');});}
