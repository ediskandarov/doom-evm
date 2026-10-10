// SPDX-License-Identifier: GPL-2.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import {InputTransactions,INITIALIZE_EPISODE_SELECTOR,NEW_EPISODE_SELECTOR,RESTART_EPISODE_SELECTOR,PAUSE_EPISODE_SELECTOR,GAME_STARTED_SELECTOR,LAST_INPUT_SELECTOR} from './input-loop.mjs';
import {FRAME_TOPIC,FrameInbox} from './protocol.mjs';
const word=n=>BigInt(n).toString(16).padStart(64,'0');
function fixture() {
  let started=false,seq=7,revert=false,resolveWait;
  const sent=[],waits=[];
  const rpc=async(method,params)=>{
    if(method==='eth_call')return '0x'+word(params[0].data===GAME_STARTED_SELECTOR?Number(started):seq);
    assert.equal(method,'eth_sendTransaction');sent.push(params[0]);return '0x'+word(sent.length);
  };
  const inbox=new FrameInbox(()=>{});
  const waitReceipt=async(_rpc,hash)=>{
    if(waits.length)await waits.shift();
    const data=sent.at(-1).data;
    if(revert)return {status:'0x0',logs:[],transactionHash:hash};
    if(data.startsWith(INITIALIZE_EPISODE_SELECTOR)){started=true;return {status:'0x1',logs:[],transactionHash:hash};}
    seq=Number(BigInt('0x'+data.slice(-64)));
    return {status:'0x1',transactionHash:hash,logs:[{address:'0x1234',topics:[FRAME_TOPIC,'0x'+word(seq),'0x'+word(seq)],data:'0x'+word(2)+word(1)+word(96)+word(2)+'0102'+'0'.repeat(60),transactionHash:hash,logIndex:'0x0',blockNumber:'0x1'}]};
  };
  const client=new InputTransactions(rpc,{address:'0x1234',driver:'0xabcd',gameplay:true,rawKeyboard:true,productionUI:true,episodeMode:true,startMap:9,skill:4,gasLimit:10000000000},inbox,{waitReceipt});
  return {client,sent,setRevert:value=>revert=value,block:()=>{waits.push(new Promise(r=>resolveWait=r));return ()=>resolveWait();}};
}
test('episode startup confirms state without consuming sequence; resume reuses deployment',async()=>{
  const f=fixture();await f.client.load();await f.client.startGame();
  assert.equal(f.sent[0].data,INITIALIZE_EPISODE_SELECTOR+word(9)+word(4)+word(0));assert.equal(f.client.sequence,7);
  await f.client.startGame();assert.equal(f.sent.length,1);
});
test('new game, restart and pause share the exclusive sequenced Frame channel',async()=>{
  const f=fixture();await f.client.load();await f.client.startGame();
  await f.client.episodeControl('new',{map:3,skill:2});await f.client.episodeControl('restart');await f.client.episodeControl('pause',{paused:true});
  assert.deepEqual(f.sent.slice(1).map(t=>t.data),[NEW_EPISODE_SELECTOR+word(3)+word(2)+word(8),RESTART_EPISODE_SELECTOR+word(9),PAUSE_EPISODE_SELECTOR+word(1)+word(10)]);
  assert.equal(f.client.sequence,10);
});
test('reverted episode control keeps sequence; invalid selection sends nothing',async()=>{
  const f=fixture();await f.client.load();await f.client.startGame();f.setRevert(true);
  await assert.rejects(f.client.episodeControl('restart'),/reverted/);assert.equal(f.client.sequence,7);assert(f.client.canSend);
  const count=f.sent.length;await assert.rejects(f.client.episodeControl('new',{map:10}),/Invalid Episode/);assert.equal(f.sent.length,count);
});
test('pending control excludes keyboard input until its mined receipt settles',async()=>{
  const f=fixture();await f.client.load();await f.client.startGame();const release=f.block();const pending=f.client.episodeControl('restart');
  await assert.rejects(f.client.nextEvents([]),/pending/);release();await pending;assert.equal(f.client.sequence,8);
});
