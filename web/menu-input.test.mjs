// SPDX-License-Identifier: GPL-2.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import {MenuTransactions,usesEVMMenu,INITIALIZE_MENU_SELECTOR,MENU_MODE_SELECTOR,MENU_STATUS_SELECTOR} from './menu-input.mjs';
import {GAME_STARTED_SELECTOR,LAST_INPUT_SELECTOR} from './input-loop.mjs';
import {EVENTS_STEP_SELECTOR,EVENTS_NO_RENDER_SELECTOR} from './input.mjs';
import {FrameInbox,FRAME_TOPIC} from './protocol.mjs';
const word=n=>BigInt(n).toString(16).padStart(64,'0');
function fixture(){
  const state={ready:false,started:false,sequence:0,sent:[],status:'0x1',wait:null,startOnNext:false,unknown:false};
  const rpc=async(method,params)=>{
    if(method==='eth_call'){
      const data=params[0].data;
      if(data===MENU_MODE_SELECTOR)return '0x'+word(state.ready);
      if(data===GAME_STARTED_SELECTOR)return '0x'+word(state.started);
      if(data===LAST_INPUT_SELECTOR)return '0x'+word(state.sequence);
      if(data===MENU_STATUS_SELECTOR)return '0x'+[1,1,3,8,0,8,9,2,0].map(word).join('');
      throw Error('Unexpected read '+data);
    }
    assert.equal(method,'eth_sendTransaction');state.sent.push(params[0].data);return '0x'+word(state.sent.length);
  };
  const waitReceipt=async(_rpc,hash)=>{
    if(state.wait)await state.wait;
    if(state.unknown)throw Error('Lost receipt');
    const data=state.sent[Number(BigInt(hash))-1];let logs=[];
    if(state.status==='0x1'){
      if(data.startsWith(INITIALIZE_MENU_SELECTOR))state.ready=true;
      else{
        state.sequence=Number(BigInt('0x'+data.slice(74,138)));if(state.startOnNext)state.started=true;
        if(data.startsWith(EVENTS_STEP_SELECTOR))logs=[{address:'0x1234',topics:[FRAME_TOPIC,'0x'+word(state.sequence),'0x'+word(state.sequence)],
          data:'0x'+word(2)+word(1)+word(96)+word(2)+'0102'.padEnd(64,'0'),transactionHash:hash,logIndex:'0x0',blockNumber:'0x1'}];
      }
    }
    return {status:state.status,logs,transactionHash:hash};
  };
  const client=new MenuTransactions(rpc,{gameplay:true,episodeMode:true,productionUI:true,rawKeyboard:true,
    address:'0x1234',driver:'0xabcd',gasLimit:10000000000},new FrameInbox(()=>{}),{waitReceipt});
  return {state,client};
}
test('every production player defaults to EVM menu with explicit legacy opt-out',()=>{
  assert.equal(usesEVMMenu({gameplay:true,rendererKind:'doom-world-view'}),true);
  assert.equal(usesEVMMenu({gameplay:true,rendererKind:'doom-world-view',menuMode:false}),false);
  assert.equal(usesEVMMenu({gameplay:false,rendererKind:'doom-world-view'}),false);
  assert.equal(usesEVMMenu({gameplay:true,rendererKind:'synthetic'}),false);
});
test('automatic menu startup consumes neither a game nor sequence and reuses persisted menu',async()=>{
  const {state,client}=fixture();await client.load();await client.startGame();
  assert.equal(client.menuReady,true);assert.equal(client.started,false);assert.equal(client.sequence,0);
  assert.equal(state.sent.length,1);await client.startGame();assert.equal(state.sent.length,1);
  await client.nextEvents(new Uint8Array());assert.equal(client.sequence,1);assert.equal(client.started,false);
  state.startOnNext=true;await client.nextEvents(Uint8Array.of(0,13));assert.equal(client.started,true);
  assert.equal((await client.menuStatus()).map,9);
});
test('title events retain exact shared raw ABI and malformed packets send nothing',async()=>{
  const {state,client}=fixture();await client.load();await client.startGame();
  for(const invalid of [[],Uint8Array.of(0),Uint8Array.of(2,119),new Uint8Array(130)])await assert.rejects(client.nextEvents(invalid));
  assert.equal(state.sent.length,1);assert.equal(client.sequence,0);
  await client.nextEvents(Uint8Array.of(1,119),{draw:false});assert(state.sent.at(-1).startsWith(EVENTS_NO_RENDER_SELECTOR));assert.equal(client.sequence,1);
});
test('pending menu navigation excludes overlapping input and mined revert keeps sequence',async()=>{
  const {state,client}=fixture();await client.load();await client.startGame();
  let resolve;state.wait=new Promise(done=>resolve=done);const pending=client.nextEvents(Uint8Array.of(0,175));
  await Promise.resolve();await assert.rejects(client.nextEvents(new Uint8Array()),/pending/);
  state.status='0x0';resolve();await assert.rejects(pending,/reverted/);assert.equal(client.sequence,0);assert.equal(client.canSend,true);
});
test('uncertain menu submission blocks subsequent mutation',async()=>{
  const {state,client}=fixture();await client.load();await client.startGame();state.unknown=true;
  await assert.rejects(client.nextEvents(Uint8Array.of(0,13)),/Lost receipt/);assert.equal(client.canSend,false);
  await assert.rejects(client.nextEvents(new Uint8Array()),/unknown/);assert.equal(client.sequence,0);
});
test('existing legacy game cannot silently switch startup profile',async()=>{
  const {state,client}=fixture();state.started=true;await client.load();await assert.rejects(client.startGame(),/legacy startup/);
  assert.equal(state.sent.length,0);
});
