// SPDX-License-Identifier: GPL-2.0-only
// Ordinary production CREATE and captured commands on an isolated LOCAL node.
// Never sends writes to the user's live Anvil18579.
import {readFile,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {decodeFrame} from '../../../web/protocol.mjs';
import {loadGasBudget} from '../../execution-budget.mjs';
const args=process.argv.slice(2),arg=(k,d)=>args.includes(k)?args[args.indexOf(k)+1]:d;
const url=arg('--rpc','http://127.0.0.1:18690'), parsed=new URL(url);
assert.equal(parsed.hostname,'127.0.0.1');assert.notEqual(parsed.port,'18579','live node must remain read-only');
const prefix=arg('--capture','artifacts/local/drawbounds-crash'), strict=args.includes('--strict');
const out=arg('--report',prefix+(strict?'/replay-strict.json':'/replay-production.json'));
const fixture='test/fixtures/drawbounds_blood/',sha=b=>createHash('sha256').update(b).digest('hex');
const artifact=JSON.parse(await readFile(arg('--artifact','out/Doom.sol/Doom.json')));
const constructor=JSON.parse(await readFile(prefix+'/constructor.json'));
const tx=JSON.parse(await readFile(prefix+'/tx.json')).result,from=tx.from;
const packets=JSON.parse(await readFile(fixture+'commands.json'));
const players=JSON.parse(await readFile(fixture+'players.json'));
const native=JSON.parse(await readFile(fixture+'replay-native.json'));
assert.equal(sha(await readFile(fixture+'commands.json')),native.commandsSha256);
assert.equal(sha(await readFile(fixture+'players.json')),native.playersSha256);
const gas=loadGasBudget().gasHex,word=v=>BigInt(v).toString(16).padStart(64,'0');let id=0;
async function rpc(method,params=[]){
 const r=await fetch(url,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(300000)});
 assert(r.ok);const v=await r.json();if(v.error)throw Object.assign(Error(method+': '+v.error.message),{rpcError:v.error});return v.result;
}
async function send(data,to){
 const hash=await rpc('eth_sendTransaction',[{from,data,gas,...(to?{to}:{})}]);let r;const deadline=Date.now()+300000;
 while(!(r=await rpc('eth_getTransactionReceipt',[hash]))){assert(Date.now()<deadline,'receipt timeout '+hash);await new Promise(done=>setTimeout(done,25));}
 return r;
}
const method=name=>'0x'+artifact.methodIdentifiers[name];
const report={pass:false,strict,policy:strict?'Source-written-only diagnostic':'Explicit initial-zone zero profile; no unmodified-malloc pixel equivalence',executionBudget:loadGasBudget(),sourceRuntimeSha256:sha(Buffer.from(artifact.deployedBytecode.object.slice(2),'hex')),steps:[],nativeProfiles:native.profiles};
const keys=['gametic','leveltime','playerHealth','armorpoints','readyweapon','x','y','z','angle','momx','momy','momz','viewz','prndindex'];
async function observation(address){
 const v=await Promise.all([rpc('eth_call',[{to:address,data:method('gameStatus()')},'latest']),rpc('eth_call',[{to:address,data:method('playerView()')},'latest'])]);
 const words=v.flatMap(hex=>hex.slice(2).match(/.{64}/g));assert.equal(words.length,14);
 return Object.fromEntries(words.map((s,i)=>{const n=BigInt('0x'+s);return [keys[i],Number(BigInt.asIntN(256,n))];}));
}
try{
 await rpc('anvil_setBlockGasLimit',[gas]);
 const deployed=await send(artifact.bytecode.object+constructor.args.slice(2));assert.equal(deployed.status,'0x1');const address=deployed.contractAddress;report.address=address;report.deploymentGas=Number(BigInt(deployed.gasUsed));
 const init=await send(method(strict?'initializeGameStrict()':'initializeGame()'),address);assert.equal(init.status,'0x1');report.initializationGas=Number(BigInt(init.gasUsed));
 assert.deepEqual(await observation(address),players[0]);
 for(const row of packets){
  const data=method(row.render?'stepAndRender(uint32,uint32)':'step(uint32,uint32)')+word(row.buttons)+word(row.sequence);
  const r=await send(data,address);const entry={tic:row.sequence,hash:r.transactionHash,status:r.status,gas:Number(BigInt(r.gasUsed))};report.steps.push(entry);
  if(strict && row.sequence===445){
   assert.equal(r.status,'0x0');assert.equal(r.logs.length,0);assert.deepEqual(await observation(address),players[444]);
   try{await rpc('eth_call',[{from,to:address,data,gas},'latest']);assert.fail('strict must revert');}catch(e){assert.equal(e.rpcError?.data,'0x5b9a48fe');}
   report.pass=true;report.expectedDrawBoundsTic=445;break;
  }
  assert.equal(r.status,'0x1','reverted tic'+row.sequence);
  assert.deepEqual(await observation(address),players[row.sequence],'original gameplay fields tic'+row.sequence);
  entry.gameplayFieldDifferences=0;
  if(row.render){assert.equal(r.logs.length,1);const frame=decodeFrame(r.logs[0]);assert.equal(frame.inputSeq,row.sequence);entry.frameSha256=sha(frame.pixels);assert.equal(entry.frameSha256,native.frames[`frame-${String(row.sequence).padStart(6,'0')}.bin`],'initialized native frame tic'+row.sequence);entry.pixelDifferences=0;}
  if(row.sequence%25===0||row.sequence===445)console.log('PASS production replay',row.sequence,'gas',entry.gas);
 }
 if(!strict){report.pass=true;assert.equal(report.steps.length,445);}
}finally{await writeFile(out,JSON.stringify(report,null,2)+'\n');}
console.log('PASS',strict?'strict diagnostic':'initialized production','445-tic captured replay');
