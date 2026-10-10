#!/usr/bin/env node
// Original geometry/actions -> Solidity automap -> frozen Frame. JS only transports and compares bytes.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {spawn} from 'node:child_process';
import {connect} from 'node:net';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
import {decodeFrame} from '../../../web/protocol.mjs';
import {loadGasBudget} from '../../execution-budget.mjs';
const port=Number(process.env.AUTOMAP_PORT??18745);
assert(port>1024&&port<65536&&![18545,18579,18690,18694].includes(port),'use isolated port');
const output=process.env.AUTOMAP_REPORT??'artifacts/phase4/automap-evm.json';
const hash=b=>createHash('sha256').update(b).digest('hex');
const read=async p=>JSON.parse(await readFile(p,'utf8'));
const fixture=await read('test/fixtures/phase4_automap/cases.json');
const native=await read('test/fixtures/phase4_automap/native.json');
const artifact=await read('out/AutomapProbe.sol/AutomapProbe.json');
const {gasHex,gasLimit}=loadGasBudget();
const word=n=>BigInt(n).toString(16).padStart(64,'0');
const dynamic=b=>word(b.length)+b.toString('hex').padEnd(Math.ceil(b.length/32)*64,'0');
const patches=await Promise.all(native.patches.map(async p=>{const b=await readFile('test/fixtures/phase4_automap/'+p.name+'.bin');assert.equal(hash(b),p.sha256);return b;}));
let position=320;const offsets=[],tails=[];
for(const p of patches){const encoded=dynamic(p);offsets.push(word(position));tails.push(encoded);position+=encoded.length/2;}
const array=offsets.join('')+tails.join('');
function calldata(input,sequence){const geometry=dynamic(input);return '0x'+artifact.methodIdentifiers['render(bytes,bytes[10],uint32)']+word(96)+word(96+geometry.length/2)+word(sequence)+geometry+array;}
function decodeBytes(data,index){const b=Buffer.from(data.slice(2),'hex');const p=Number(BigInt('0x'+b.subarray(index*32,index*32+32).toString('hex')));const n=Number(BigInt('0x'+b.subarray(p,p+32).toString('hex')));assert(p+32+n<=b.length);return b.subarray(p+32,p+32+n);}
let child,stderr='',id=0;const url=`http://127.0.0.1:${port}`;
async function rpc(method,params=[]){const r=await fetch(url,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(120000)});const j=await r.json();if(j.error)throw Error(JSON.stringify(j.error));return j.result;}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function send(from,to,data){const tx=await rpc('eth_sendTransaction',[{from,...(to?{to}:{}),data,gas:gasHex}]);const end=Date.now()+120000;while(Date.now()<end){const r=await rpc('eth_getTransactionReceipt',[tx]);if(r)return r;await sleep(25);}throw Error('receipt timeout');}
try {
    const occupied=await new Promise(r=>{const socket=connect({host:'127.0.0.1',port});socket.once('connect',()=>{socket.destroy();r(true);});socket.once('error',()=>r(false));socket.setTimeout(1000,()=>{socket.destroy();r(true);});});assert(!occupied,'refusing existing node');
    child=spawn(resolve('.toolchain/bin/anvil'),['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--gas-limit',String(gasLimit),'--memory-limit','1073741824','--silent'],{stdio:['ignore','ignore','pipe']});child.stderr.on('data',b=>{stderr+=b;});
    const ready=Date.now()+15000;while(true){try{await rpc('eth_chainId');break;}catch(e){if(Date.now()>ready)throw Error('Anvil start failed: '+stderr);await sleep(50);}}
    const [from]=await rpc('eth_accounts');const deployed=await send(from,null,artifact.bytecode.object);assert.equal(deployed.status,'0x1');const address=deployed.contractAddress;
    const runtime=await rpc('eth_getCode',[address,'latest']);const rows=[];let sequence=0;
    for(let i=0;i<fixture.cases.length;++i){
        const row=fixture.cases[i];const input=await readFile(`test/fixtures/phase4_automap/${i}.bin`);assert.equal(hash(input),row.inputSha256);
        const receipt=await send(from,address,calldata(input,++sequence));assert.equal(receipt.status,'0x1',row.name);assert.equal(receipt.logs.length,2);
        const states=decodeBytes(receipt.logs[0].data,0),frames=decodeBytes(receipt.logs[0].data,1);
        assert.equal(states.length,row.hashes.length*32);assert.equal(frames.length,states.length);
        for(let j=0;j<row.hashes.length;++j){assert.equal(states.subarray(j*32,j*32+32).toString('hex'),row.hashes[j].stateSha256,row.name+' state '+j);assert.equal(frames.subarray(j*32,j*32+32).toString('hex'),row.hashes[j].frameSha256,row.name+' pixels '+j);}
        const frame=decodeFrame(receipt.logs[1]);assert.equal(frame.width,320);assert.equal(frame.height,200);assert.equal(frame.frameId,BigInt(sequence));assert.equal(frame.inputSeq,sequence);
        const pixels=Buffer.from(frame.pixels);assert.equal(hash(pixels),row.hashes.at(-1).frameSha256);
        for(let p=53760;p<64000;++p)assert.equal(pixels[p],(p*13+Math.floor(p/320)*7+19)&255,'bottom32 preserved');
        rows.push({case:row.name,transaction:receipt.transactionHash,status:receipt.status,gasUsed:Number(BigInt(receipt.gasUsed)),statesCompared:row.hashes.length,frameSha256:hash(pixels),pixels:64000});
    }
    const before=await rpc('eth_getStorageAt',[address,'0x0','latest']);const invalid=await send(from,address,calldata(Buffer.from([0]),sequence+1));assert.equal(invalid.status,'0x0');assert.equal(invalid.logs.length,0);assert.equal(await rpc('eth_getStorageAt',[address,'0x0','latest']),before);
    const paths=['src/doom/am_map.sol','src/doom/am_map_types.sol','src/support/AutomapFixture.sol','src/support/AutomapProbe.sol','src/doom/v_video.sol','src/doom/tables.sol','foundry.toml','execution-budget.json','tools/reference/automap/evm.mjs','test/fixtures/phase4_automap/cases.bin','test/fixtures/phase4_automap/native.json','web/protocol.mjs'];const sources={};for(const p of paths)sources[p]=hash(await readFile(p));
    const report={schemaVersion:1,goal:'4.5',pass:true,kind:'ordinary isolated Anvil CREATE and automap Frame receipts',productionAdaptersModified:false,rpcPort:port,gasBudget:gasLimit,compiler:{version:artifact.metadata.compiler.version,settings:artifact.metadata.settings},contract:address,creationTransaction:deployed.transactionHash,deploymentGas:Number(BigInt(deployed.gasUsed)),runtimeBytes:(runtime.length-2)/2,runtimeSha256:hash(Buffer.from(runtime.slice(2),'hex')),nativeCases:fixture.caseCount,statesCompared:fixture.snapshots,rows,rollback:{transaction:invalid.transactionHash,status:invalid.status,logs:0,counterUnchanged:true,gasUsed:Number(BigInt(invalid.gasUsed))},sourceSha256:sources};
    await mkdir(resolve(output,'..'),{recursive:true});await writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({pass:true,frames:rows.length,states:fixture.snapshots,gasRange:[Math.min(...rows.map(r=>r.gasUsed)),Math.max(...rows.map(r=>r.gasUsed))],report:output}));
} finally {if(child?.exitCode===null)await new Promise(r=>{child.once('exit',r);child.kill('SIGTERM');});}
