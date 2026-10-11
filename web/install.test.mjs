// SPDX-License-Identifier: GPL-2.0-only
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {BrowserInstaller,localEndpoint,expectedRuntime} from './install-engine.mjs';
import {PROFILES,prepareResources,authenticateIWAD,word} from './install-resources.mjs';
const memory=()=>({data:null,async read(){return this.data;},async write(key,data){this.data=structuredClone(data);}});
test('localhost policy rejects remote origins, public RPC, credentials and misleading hostnames',()=>{
 for(const url of ['https://127.0.0.1:8545','http://127.0.0.1.evil.test','http://example.org','http://user@localhost','http://localhost/path','http://localhost/?x'])assert.throws(()=>localEndpoint(url,'http://localhost:8080'));
 assert.throws(()=>localEndpoint('http://localhost:8545','https://evil.test'));
 assert.equal(localEndpoint('http://127.0.0.1:18991','http://127.0.0.1:18992'),'http://127.0.0.1:18991');
});
test('authenticated precompiled artifact rejects any changed byte',async()=>{
 const installer=new BrowserInstaller({fetchArtifact:async()=>new TextEncoder().encode('{}')});
 await assert.rejects(()=>installer.artifact('Doom'),/authentication/);
});
test('pack existing Freedoom pipeline exactly; reject wrong and corrupted IWADs',async()=>{
 const bytes=new Uint8Array(await readFile('web/install-assets/freedoom1.wad'));
 const packed=await prepareResources(bytes,PROFILES[0]);
 assert.equal(packed.chunks.length,1755);assert.equal(packed.directory.length,3163*16);assert.equal(packed.resourceIdentity.bundleSha256,PROFILES[0].bundleSha256);
 await assert.rejects(()=>authenticateIWAD(bytes,PROFILES[1]),/identity mismatch/);
 bytes[13]^=1;await assert.rejects(()=>prepareResources(bytes,PROFILES[0]),/identity mismatch/);
});
test('immutable runtime binds driver and checks bounds',()=>{
 const a={runtime:'0x'+'00'.repeat(40),immutableReferences:{driver:[{start:8,length:32}]}};
 assert.equal(expectedRuntime(a,'0x1234'),'0x'+'00'.repeat(8)+word('0x1234'));
 assert.throws(()=>expectedRuntime({...a,immutableReferences:{x:[{start:10,length:32}]}},'0x1234'));
});
function pendingFixture(rpc){
 const storage=memory(),installer=new BrowserInstaller({storage});
 installer.key='test';installer.rpc=rpc;installer.driver='0x'+'11'.repeat(20);installer.journal={schemaVersion:1,pending:{nonce:'0x0',fromBlock:'0x0',kind:'initialize',to:'0x'+'22'.repeat(20),data:'0x1234',hash:null},receipts:[]};return {installer,storage};
}
test('uncertain nonce conflict cannot be blindly replayed',async()=>{
 let sent=false;const {installer}=pendingFixture(async(method)=>{
  if(method==='eth_getBlockByNumber')return {number:'0x0',transactions:[{from:'0x'+'11'.repeat(20),nonce:'0x0',input:'0xdead',to:null}]};
  if(method==='eth_sendTransaction')sent=true;
 });
 await assert.rejects(()=>installer.recoverPending(true),/different transaction/);assert.equal(sent,false);
});
test('consumed nonce with missing receipt refuses replay',async()=>{
 let sent=false;const {installer}=pendingFixture(async(method)=>{
  if(method==='eth_getBlockByNumber')return {number:'0x0',transactions:[]};
  if(method==='eth_getTransactionCount')return '0x1';
  if(method==='eth_sendTransaction')sent=true;
 });
 await assert.rejects(()=>installer.recoverPending(true),/do not replay/);assert.equal(sent,false);
});
test('reset with identical chain ID archives journal when anchor differs',async()=>{
 const storage=memory(),installer=new BrowserInstaller({storage});
 installer.key='same-chain';installer.chain={chainId:'0x7a69'};installer.driver='driver';
 installer.journal={anchor:{number:'0x1',hash:'old'},resetCount:0,pending:{},resources:{a:1},game:{address:'old'}};
 installer.rpc=async()=>({hash:'new'});await installer.reconcileChain();
 assert.equal(installer.journal.resetCount,1);assert.equal(installer.journal.game,null);assert.deepEqual(installer.journal.resources,{});
});
test('unused uncertain operation retries exact durable nonce and payload',async()=>{
 let sent;const {installer}=pendingFixture(async(method,params)=>{
  if(method==='eth_getBlockByNumber')return {number:'0x0',transactions:[]};
  if(method==='eth_getTransactionCount')return '0x0';
  if(method==='eth_sendTransaction'){sent=params[0];return '0xhash';}
 });
 installer.waitPending=async()=>null;
 await installer.recoverPending(true);
 assert.equal(sent.nonce,'0x0');assert.equal(sent.data,'0x1234');assert.equal(installer.journal.pending.hash,'0xhash');
});
test('known unmined operation is awaited and never resubmitted',async()=>{
 let sent=false;const {installer}=pendingFixture(async(method)=>{
  if(method==='eth_getTransactionReceipt')return null;
  if(method==='eth_getBlockByNumber')return {number:'0x0',transactions:[]};
  if(method==='eth_getTransactionCount')return '0x0';
  if(method==='eth_getTransactionByHash')return {hash:'known'};
  if(method==='eth_sendTransaction')sent=true;
 });
 installer.journal.pending.hash='known';installer.waitPending=async()=>null;
 await installer.recoverPending(true);assert.equal(sent,false);assert.equal(installer.journal.pending.hash,'known');
});
test('canonical receipt for initialization completes journal after reload',async()=>{
 const {installer,storage}=pendingFixture(async(method)=>{
  if(method==='eth_getTransactionReceipt')return {status:'0x1',blockNumber:'0x1',blockHash:'canonical',transactionHash:'known',gasUsed:'0x10'};
  if(method==='eth_getBlockByNumber')return {hash:'canonical'};
 });
 installer.journal.pending.hash='known';installer.call=async()=> '0x'+word(1);
 await installer.recoverPending(false);
 assert.equal(installer.journal.pending,null);assert.equal(storage.data.receipts.length,1);assert.equal(storage.data.anchor.hash,'canonical');
});
test('receipt from an orphaned block cannot complete an operation',async()=>{
 const {installer}=pendingFixture(async(method)=>{
  if(method==='eth_getTransactionReceipt')return {status:'0x1',blockNumber:'0x1',blockHash:'orphan'};
  if(method==='eth_getBlockByNumber')return {hash:'canonical'};
 });
 installer.journal.pending.hash='known';await assert.rejects(()=>installer.recoverPending(false),/no longer canonical/);assert(installer.journal.pending);
});
test('endpoint ownership refreshes a previously connected stale journal',async()=>{
 const oldLocks=Object.getOwnPropertyDescriptor(navigator,'locks');
 Object.defineProperty(navigator,'locks',{configurable:true,value:{request:async(name,options,task)=>task({name})}});
 try{
  const storage=memory();await storage.write('key',{resources:{completed:{address:'0x1234'}}});
  const installer=new BrowserInstaller({storage});installer.key='key';installer.url='http://localhost:8545';installer.journal={resources:{}};
  const count=await installer.exclusive(()=>Object.keys(installer.journal.resources).length);assert.equal(count,1);
 }finally{if(oldLocks)Object.defineProperty(navigator,'locks',oldLocks);else delete navigator.locks;}
});
test('profile journals isolate game identity and retain profile configuration',async()=>{
 const data=new Map(),storage={read:async key=>structuredClone(data.get(key)),write:async(key,value)=>data.set(key,structuredClone(value))};
 const oldLocks=Object.getOwnPropertyDescriptor(navigator,'locks');
 Object.defineProperty(navigator,'locks',{configurable:true,value:{request:async(name,options,task)=>task({name})}});
 try{
  const i=new BrowserInstaller({storage});i.url='http://localhost:8545';i.baseKey='release';i.chain={chainId:'0x7a69'};i.driver='driver';i.reconcileChain=async()=>{};i.discoverChain=async()=>{};
  await i.selectProfile(PROFILES[0]);i.journal.game={address:'freedoom',identity:{wadSha256:PROFILES[0].wadSha256}};await i.save();
  await i.selectProfile(PROFILES[1]);assert.equal(i.journal.game,null);assert.equal(i.journal.profile,'ultimate');
  i.journal.game={address:'ultimate',identity:{wadSha256:PROFILES[1].wadSha256}};await i.save();
  assert.equal(i.configuration().gameName,'Ultimate DOOM 1.9');assert.equal(i.configuration().memoryPolicy,3);
  await i.selectProfile(PROFILES[0]);assert.equal(i.journal.game.address,'freedoom');
  await i.selectProfile(PROFILES[1]);assert.equal(i.journal.game.address,'ultimate');
 }finally{if(oldLocks)Object.defineProperty(navigator,'locks',oldLocks);else delete navigator.locks;}
});
test('install refuses a mismatched active profile before submitting anything',async()=>{
 const i=new BrowserInstaller();let sent=false;i.send=async()=>{sent=true;};
 await assert.rejects(()=>i.install({resourceIdentity:{wadSha256:PROFILES[1].wadSha256}},PROFILES[1]),/Select the installation profile/);
 assert.equal(sent,false);
});
test('discovery refuses a game from another IWAD before reading its identity',async()=>{
 const i=new BrowserInstaller();i.journal={game:{address:'wrong',identity:{wadSha256:PROFILES[1].wadSha256}}};i.reconcileChain=async()=>{};i.codeMatches=async()=>true;i.artifacts={Doom:{runtime:'0x'}};
 await assert.rejects(()=>i.discover(),/profile mismatch/);
});
