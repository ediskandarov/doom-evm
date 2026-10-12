// SPDX-License-Identifier: GPL-2.0-only
// Real DOM keys only for successful save/load. RPC reads and failed guards observe it.
import assert from 'node:assert/strict';
const word=n=>BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');
const tail=b=>word(b.length)+Buffer.from(b).toString('hex').padEnd(Math.ceil(b.length/32)*64,'0');
export function decodeSlot(hex){
 const b=Buffer.from(hex.slice(2),'hex'),at=p=>Number(BigInt('0x'+b.subarray(p,p+32).toString('hex')));
 const base=at(0),v=Array.from({length:16},(_,i)=>b.subarray(base+i*32,base+(i+1)*32));
 const n=i=>Number(BigInt('0x'+v[i].toString('hex'))),p=base+n(15),length=at(p);
 return {occupied:n(0)===1,compatible:n(1)===1,revision:n(2),gametic:n(3),leveltime:n(4),skill:n(5),episode:n(6),map:n(7),gamemode:n(8),policy:n(9),size:n(10),schema:v[11].toString('hex'),engine:v[12].toString('hex'),resource:v[13].toString('hex'),digest:v[14].toString('hex'),description:b.subarray(p+32,p+32+length).toString('ascii')};
}
export async function verifyFeatures(game,{keys,evaluate,until,readGame,rpc,report,install}){
 report.saveSlots??={};report.saveCosts??=[];report.rollbacks??=[];
 const c=install.config,methods=install.methods,label=s=>game+' '+s;
 const call=async(sig,body='')=>rpc('eth_call',[{from:c.driver,to:c.address,data:'0x'+methods[sig]+body,gas:'0x2540be400'},'latest']);
 const slotABI=slot=>call('readSaveSlot(uint8)',word(slot)),slot=async n=>decodeSlot(await slotABI(n));
 const menu=()=>evaluate('window.fixtureClient.transactions.menuStatus()');
 await evaluate('window.fixtureClient.startGame();true');await until(()=>evaluate('!!window.__tick&&!window.fixtureClient.loop.starting'),'save/load key loop');
 for(let n=0;n<6;n++)assert.equal((await slot(n)).occupied,false,'fresh IWAD slot namespace');
 // Keep Options and SELECT LEVEL on their existing routes.
 await keys(['Escape','KeyO','Enter','KeyM','Enter','KeyS','ArrowRight'],label('Options before save'));
 assert.equal((await menu()).screen,4);await keys(['Escape'],label('resume Options'));
 await keys(['KeyI','KeyD','KeyK','KeyF','KeyA'],label('real inventory change before snapshot'));
 const inv=await readGame(game,'playerInventory()');
 const savedView=await readGame(game,'playerView()'),savedState=await readGame(game,'gameStatus()');
 const savedPixel=report.frames.at(-1).pixelSha256;
 async function save(n,name){
  const before=await slot(n);await keys(['F2'],label('original Save Game menu'));
  assert.equal((await menu()).screen,6);const current=(await menu()).item;
  await keys([...Array((n-current+6)%6).fill('ArrowDown'),'Enter'],label('select save slot '+n));
  if(before.description.length)await keys(Array(before.description.length).fill('Backspace'),label('replace original description'));
  const codes=[...name].map(ch=>ch===' '?'Space':/[0-9]/.test(ch)?'Digit'+ch:'Key'+ch.toUpperCase());
  const f=await keys([...codes,'Enter'],label('save slot '+n));const after=await slot(n);
  assert(after.occupied&&after.compatible);assert.equal(after.description,name.toUpperCase());assert.equal(after.revision,before.revision+1);assert.equal(after.policy,3);
  report.saveCosts.push({game,slot:n,operation:before.occupied?'overwrite':'save',gasUsed:f.gasUsed,snapshotBytes:after.size,payloadStorageWords:after.size/32,revision:after.revision,digest:after.digest,transaction:f.transaction});return after;
 }
 async function load(n){
  const expected=await slot(n),clock=await readGame(game,'inputSeq()'),frame=await readGame(game,'frameId()');
  await keys(['F3'],label('original Load Game menu'));assert.equal((await menu()).screen,5);
  // Number hotkeys use original slot1..6, and empty selections stay disabled.
  const f=await keys(['Digit'+(n+1),'Enter'],label('load slot '+n));
  assert.equal((await menu()).active,0);assert.equal(f.state.map,expected.map);
  report.saveCosts.push({game,slot:n,operation:'load',gasUsed:f.gasUsed,snapshotBytes:expected.size,digest:expected.digest,transaction:f.transaction});
  assert(BigInt(await readGame(game,'inputSeq()'))>BigInt(clock));assert(BigInt(await readGame(game,'frameId()'))>BigInt(frame));return f;
 }
 const name=game.toUpperCase()+' MOVE';const original=await save(0,name);
 assert.equal(await readGame(game,'playerView()'),savedView);assert.equal(await readGame(game,'gameStatus()'),savedState);
 assert.equal(report.frames.at(-1).pixelSha256,savedPixel,'save advanced rendering');
 async function future(){
  const frames=[];
  for(const [code,down] of [['ArrowUp',true],['ControlLeft',true],['ControlLeft',false],['ArrowUp',false]]){
   await evaluate(`window.dispatchEvent(new KeyboardEvent(${JSON.stringify(down?'keydown':'keyup')},{code:${JSON.stringify(code)},bubbles:true,cancelable:true}));true`);
   frames.push((await keys([],label('real movement/combat continuation'))).pixelSha256);
  }
  return frames;
 }
 const firstFrames=await future();const futureView=await readGame(game,'playerView()');assert.notEqual(futureView,savedView);
 const futureSnapshot=await save(1,game.toUpperCase()+' FUTURE');
 const restored=await load(0);assert.equal(restored.pixelSha256,savedPixel,'saved EVM framebuffer');
 assert.equal(await readGame(game,'playerView()'),savedView);assert.equal(await readGame(game,'gameStatus()'),savedState);
 assert.equal(await readGame(game,'playerInventory()'),inv);
 // Resaving after load proves all four rooted values, including historical zone
 // records/render globals, rather than trusting a small public status projection.
 const roundtrip=await save(5,game.toUpperCase()+' CHECK');assert.equal(roundtrip.digest,original.digest);
 for(let cycle=0;cycle<2;cycle++){
  if(cycle)await load(0);
  assert.deepEqual(await future(),firstFrames,'same complete EVM framebuffers after load');
  assert.equal(await readGame(game,'playerView()'),futureView);
  const replay=await save(1,game.toUpperCase()+' FUTURE');assert.equal(replay.digest,futureSnapshot.digest,'complete roots after replay');
 }
 // Rejection consumes no sequence and rolls back both gameplay and save slots.
 const seq=Number(BigInt(await readGame(game,'inputSeq()')))+1;
 async function reject(sig,body,text,from=c.driver,gas='0x2540be400'){
  const before=await rpc('eth_getProof',[c.address,[],'latest']);
  const hash=await rpc('eth_sendTransaction',[{from,to:c.address,data:'0x'+methods[sig]+body,gas}]);
  const receipt=await until(()=>rpc('eth_getTransactionReceipt',[hash]),text);assert.equal(receipt.status,'0x0');assert.equal(receipt.logs.length,0);
  assert.equal((await rpc('eth_getProof',[c.address,[],'latest'])).storageHash,before.storageHash);
  report.rollbacks.push({game,label:text,transaction:hash,storageRoot:before.storageHash,allStorageUnchanged:true,noLogs:true});
 }
 await reject('loadGame(uint8,uint64,uint32)',word(2)+word(0)+word(seq),'empty slot');
 await reject('loadGame(uint8,uint64,uint32)',word(6)+word(1)+word(seq),'slot out of range');
 await reject('loadGame(uint8,uint64,uint32)',word(0)+word(0)+word(seq),'stale revision');
 await reject('loadGame(uint8,uint64,uint32)',word(0)+word(1)+word(seq),'non-driver',(await rpc('eth_accounts'))[1]);
 await reject('loadGame(uint8,uint64,uint32)',word(0)+word(1)+word(seq-1),'stale sequence');
 await reject('saveGame(uint8,bytes,uint64,uint32)',word(0)+word(128)+word(1)+word(seq)+tail(Buffer.from('UNDERFUNDED')),'underfunded overwrite',c.driver,'0x2faf080');
 await load(0);assert.equal(await readGame(game,'playerView()'),savedView);
 await save(5,game.toUpperCase()+' CHECK');assert.equal((await slot(5)).digest,original.digest);
 // SELECT LEVEL remains the existing extension, then restore across that map load.
 await keys(['Escape','KeyS','Enter'],label('preserved SELECT LEVEL'));assert.equal((await menu()).screen,3);
 await keys(['ArrowDown','Enter','Enter'],label('actual different level'));
 assert.equal((await evaluate('window.fixtureClient.transactions.episodeStatus()')).map,2);
 await load(0);assert.equal(await readGame(game,'playerView()'),savedView);
 await save(5,game.toUpperCase()+' CHECK');assert.equal((await slot(5)).digest,original.digest,'cross-map exact roots');
 report.saveSlots[game]={slot0ABI:await slotABI(0),slot0:original,fullRootReplayExact:true,completeFrameReplayExact:true,crossMapExact:true};
 report.checks.push({label:label('six EVM slots, exact no-tic restore/replay, overwrite, Options/SELECT LEVEL and cross-map load'),pass:true});
}
