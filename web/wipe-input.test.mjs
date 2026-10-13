// SPDX-License-Identifier: GPL-2.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import { readWipe, PendingPresentationSend, wipeWord, heldKeyReleases, suspendWipeKeys } from './wipe-input.mjs';
import { GameplayLoop } from './input-loop.mjs';
import { RawKeyboardInput } from './input.mjs';

test('capability probes old contracts without concealing malformed status or network failures', async () => {
  assert.equal(await readWipe(async () => '0x', '0x123'), null);
  assert.equal(await readWipe(async () => { throw Object.assign(Error(), {rpcError:{message:'execution reverted',data:'0x'}}); }, '0x123'), null);
  await assert.rejects(readWipe(async () => { throw Error('Network failure'); }, '0x123'), /Network/);
  await assert.rejects(readWipe(async () => '0x01', '0x123'), /Malformed/);
  assert.deepEqual(await readWipe(async () => '0x'+[1,1,1,4,3,0].map(wipeWord).join(''), '0x123'),
    {version:1,enabled:true,active:true,progress:4,from:3,to:0});
  await assert.rejects(readWipe(async () => '0x'+[2,1,1,4,3,0].map(wipeWord).join(''), '0x123'), /Unsupported/);
});

function journal() {
  const map=new Map(), storage={getItem:k=>map.get(k),setItem:(k,v)=>map.set(k,v),removeItem:k=>map.delete(k)};
  let occupied=false;
  const locks={request:async(_key,_options,fn)=>{
    if(occupied)return fn(null);occupied=true;try{return await fn({});}finally{occupied=false;}
  }};
  const state={hash:'0xabc',receipt:null,sent:0,scan:[]};
  const rpc=async(method,params)=>{
    if(method==='eth_getTransactionCount')return '0x7';
    if(method==='eth_blockNumber')return '0x2';
    if(method==='eth_getTransactionReceipt')return state.receipt;
    if(method==='eth_getBlockByNumber')return {hash:'0xblock',transactions:state.scan};
    if(method==='eth_getTransactionByHash')return {from:'0x123',nonce:'0x7'};
    throw Error(method);
  };
  const config={rpcUrl:'http://127.0.0.1:19121',address:'0xdef',driver:'0x123'};
  const make=()=>new PendingPresentationSend(rpc,config,storage,locks);
  return {state,make};
}

test('reload queues original releases and wipe suspension discards new presses without a transaction',async()=>{
  const held=(1n<<173n)|(1n<<32n);
  assert.deepEqual(await heldKeyReleases(async()=> '0x'+'0'.repeat(64*11)+wipeWord(held),'0x123'),[1,32,1,173]);
  const keyboard=new RawKeyboardInput();keyboard.update('ArrowUp',true);keyboard.update('KeyI',true);
  suspendWipeKeys(keyboard);assert.deepEqual(keyboard.events,[1,173,1,105]);assert.equal(keyboard.heldCodes.size,0);
});

test('unknown-hash send survives reload, blocks retries and finds exact sender/nonce after mining',async()=>{
  const {state,make}=journal();const first=make();
  await assert.rejects(first.send('0x01',async tx=>{assert.equal(tx.nonce,'0x7');state.sent++;throw Error('Lost send response');}),/Lost/);
  assert(first.pending);const reloaded=make();
  await assert.rejects(reloaded.recover(),/outcome unknown/);
  await assert.rejects(reloaded.send('0x01',()=>state.sent++),/outcome unknown/);assert.equal(state.sent,1);
  state.scan=[{from:'0x123',nonce:'0x7',hash:state.hash}];state.receipt={status:'0x1',blockHash:'0xblock',blockNumber:'0x2'};
  await reloaded.recover();assert.equal(reloaded.pending,null);assert.equal(state.sent,1);
});

test('known pending transaction is not resubmitted on reload; mined rollback releases journal',async()=>{
  const {state,make}=journal();const first=make();
  await assert.rejects(first.send('0x01',async(_tx,hash)=>{hash(state.hash);state.sent++;throw Error('Receipt timeout');}),/timeout/);
  const reloaded=make();await assert.rejects(reloaded.recover(),/outcome unknown/);assert.equal(state.sent,1);
  state.receipt={status:'0x0',blockHash:'0xblock',blockNumber:'0x2'};await reloaded.recover();assert.equal(reloaded.pending,null);
});

test('orphaned receipt cannot clear the durable pending transaction',async()=>{
  const {state,make}=journal();const first=make();
  await assert.rejects(first.send('0x01',async(_tx,hash)=>{hash(state.hash);throw Error('timeout');}));
  state.receipt={status:'0x1',blockHash:'0xorphan',blockNumber:'0x2'};
  await assert.rejects(make().recover(),/not canonical/);assert(first.pending);
});

test('exclusive endpoint ownership excludes a concurrent tab and settled receipt clears journal',async()=>{
  const {make}=journal();const a=make(),b=make();let done;
  const wait=new Promise(resolve=>done=resolve);
  const pending=a.send('0x01',async(_tx,_hash,settled)=>{await wait;settled();});
  await new Promise(resolve=>setImmediate(resolve));
  await assert.rejects(b.send('0x02',()=>{throw Error('must not send');}),/Another tab/);
  done();await pending;assert.equal(a.pending,null);
});

test('wipe loop sends presentation only, suspends ordinary keys, can stop and resume',async()=>{
  const keyboard=new RawKeyboardInput();keyboard.update('ArrowUp',true);
  const calls=[], transactions={wipe:{active:true},started:true,canSend:true,
    nextWipe:async()=>{calls.push('wipe');},nextEvents:async()=>{calls.push('world');},startGame:async()=>{}};
  let tick;const loop=new GameplayLoop(transactions,keyboard,{schedule:fn=>{tick=fn;return 1;},cancel:()=>{},onError:e=>{throw e;}});
  await loop.start();await tick();assert.deepEqual(calls,['wipe']);loop.stop();assert.equal(loop.running,false);
  await loop.start();await tick();assert.deepEqual(calls,['wipe','wipe']);loop.stop();
});
