// SPDX-License-Identifier: GPL-2.0-only
// Exact EVM snapshots are intentionally noncanonical. Real DOM/ordinary EVM only.
import {verifyFeatures as saveChecks, decodeSlot} from '../save_load/browser-features.mjs';
import {mkdir, writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const word=n=>BigInt(n).toString(16).padStart(64,'0');
const words=x=>x.slice(2).match(/.{64}/g).map(v=>Number(BigInt.asIntN(256,BigInt('0x'+v))));

export async function verifyFeatures(game, api) {
 await saveChecks(game,api); // Fresh existing no-tic replay, Options, cross-map and rollback gates.
 const {keys,evaluate,readGame,rpc,report,canvas,until,install}=api;
 const read=async sig=>words(await readGame(game,sig)),life=()=>read('playerLifecycle()');
 const menu=()=>evaluate('window.fixtureClient.transactions.menuStatus()');
 const slotABI=n=>rpc('eth_call',[{to:install.config.address,data:'0x'+install.methods['readSaveSlot(uint8)']+word(n),gas:'0x2540be400'},'latest']);
 const slot=async n=>decodeSlot(await slotABI(n));
 async function save(n,name){
  const before=await slot(n);await keys(['F2'],game+' combined Save menu');
  assert.equal((await menu()).screen,6);const item=(await menu()).item;
  await keys([...Array((n-item+6)%6).fill('ArrowDown'),'Enter'],game+' combined select slot '+n);
  if(before.description.length)await keys(Array(before.description.length).fill('Backspace'),game+' combined description overwrite');
  const frame=await keys([...name].map(c=>c===' '?'Space':'Key'+c).concat('Enter'),game+' combined save '+name);
  const after=await slot(n);assert(after.occupied&&after.compatible);assert.equal(after.revision,before.revision+1);
  report.saveCosts.push({game,slot:n,operation:before.occupied?'overwrite':'save',gasUsed:frame.gasUsed,snapshotBytes:after.size,payloadStorageWords:after.size/32,revision:after.revision,digest:after.digest,transaction:frame.transaction,combined:true});
  return {slot:after,frame};
 }
 async function load(n,name){
  const before=await slot(n);await keys(['F3'],game+' combined Load menu');
  const frame=await keys(['Digit'+(n+1),'Enter'],game+' combined load '+name);
  assert.equal(frame.state.map,before.map);assert.equal(frame.state.skill,before.skill);
  report.saveCosts.push({game,slot:n,operation:'load',gasUsed:frame.gasUsed,snapshotBytes:before.size,digest:before.digest,transaction:frame.transaction,combined:true});return frame;
 }
 // Reset supported Options before the declared borrowed-UI native comparison.
 const settings=await read('optionsStatus()');
 if(!settings[0])await keys(['Escape','KeyO','Enter','KeyM','Enter','Escape'],game+' native messages enabled');
 if((await read('optionsStatus()'))[1]!==10)await keys(['Escape','KeyO','Enter','KeyS','ArrowLeft','Escape'],game+' native status-bar view');
 if(!(await menu()).active)await keys(['Escape'],game+' combined level selection');
 await keys(['KeyS','Enter'],game+' combined SELECT LEVEL');
 const map=game==='doom2'?7:1,count=game==='doom2'?32:9,current=(await menu()).item;
 await keys([...Array((map-1-current+count)%count).fill('ArrowDown'),'Enter'],game+' combined map');
 const skill=3;await keys([...Array((skill-(await menu()).item+5)%5).fill('ArrowDown'),'Enter'],game+' combined Ultra-Violence');
 assert.equal((await life())[0],0);
 let held=[],turnheld=0;
 const tape=[{forward:0,angle:0,buttons:0,render:1,op:0,label:'selected-map first tic'}];
 const observations=[await observe('selected-map first tic')];
 const firstFrame=report.frames.at(-1);firstFrame.nativeLabel=game+' selected-map first tic';
 async function observe(label){
  const [status,lifecycle,view,ui,inventory]=await Promise.all(['gameStatus()','playerLifecycle()','playerView()','uiStatus()','playerInventory()'].map(read));
  return {label,status,lifecycle,view,face:ui[3],palette:ui[5],rndindex:ui[7],inventory,episode:await evaluate('window.fixtureClient.transactions.episodeStatus()')};
 }
 async function tick(codes,label,{draw=false,op=0,buttons}={}){
  await evaluate(`(async()=>{for(const code of ${JSON.stringify(held)})if(!${JSON.stringify(codes)}.includes(code))window.dispatchEvent(new KeyboardEvent('keyup',{code,bubbles:true,cancelable:true}));for(const code of ${JSON.stringify(codes)})if(!${JSON.stringify(held)}.includes(code))window.dispatchEvent(new KeyboardEvent('keydown',{code,bubbles:true,cancelable:true}));const k=window.fixtureClient.keyboard,p=k.packet();await window.fixtureClient.transactions.nextEvents(p,{draw:${draw}});k.acknowledge(p.length);return true})()`);
  held=codes;turnheld=codes.includes('ArrowRight')?turnheld+1:0;
  const row={forward:codes.includes('ArrowUp')?25:0,angle:codes.includes('ArrowRight')?-(turnheld<6?320:1280):0,buttons:buttons??((codes.includes('ControlLeft')?1:0)|(codes.includes('Space')?2:0)),render:draw?1:0,op,label};
  const observation=await observe(label);tape.push(row);observations.push(observation);
  let frame;if(draw){await until(()=>evaluate('window.__transportProof.frames.at(-1)?.inputSeq===window.fixtureClient.transactions.sequence'),'combined frame');frame=await canvas(game+' '+label);frame.nativeLabel=game+' '+label;}
  return {codes,row,observation,frame};
 }
 async function trace(name){
  const dir='artifacts/local/death-save-main/traces/'+game+'/'+name;await mkdir(dir,{recursive:true});
  await writeFile(dir+'/commands.txt',tape.map(t=>`${t.forward} 0 ${t.angle} ${t.buttons} ${t.render} ${t.op}\n`).join(''));
  await writeFile(dir+'/observations.json',JSON.stringify({game,map,skill,tape,observations},null,2)+'\n');return dir;
 }
 await evaluate("for(const code of ['KeyI','KeyD','KeyF','KeyA']){window.dispatchEvent(new KeyboardEvent('keydown',{code,bubbles:true,cancelable:true}));window.dispatchEvent(new KeyboardEvent('keyup',{code,bubbles:true,cancelable:true}));}true");
 await tick([],'original IDFA inventory',{op:7});
 await tick(['Digit5'],'original rocket weapon',{buttons:36});await tick([],'release weapon selection');
 for(let n=0;n<29;n++)await tick(['ArrowRight','ShiftLeft'],'weapon raise turn '+n);
 for(let n=0;n<4;n++)await tick([],'weapon raised '+n);
 const alive=await save(0,'ALIVE'),aliveView=await readGame(game,'playerView()');
 const prefixTape=tape.slice(),prefixObservations=observations.slice(),continuation=[];
 async function die(){
  for(let n=0;n<180;n++){
   const row=await tick(n%20===19?['ArrowUp']:['ArrowUp','ControlLeft'],'genuine lethal route '+n,{draw:n===0});continuation.push(row);
   if((await life())[0]===1)return;
  }
  throw Error(game+' genuine lethal route did not die');
 }
 await die();continuation.push(await tick([],'dead first view',{draw:true}));
 assert.equal((await read('uiStatus()'))[3],41);
 for(let n=0;n<35;n++)continuation.push(await tick([],'death view drop '+n));
 assert.equal((await life())[3],6*65536);
 continuation.push(await tick(['ControlLeft'],'attack alone dead',{draw:true}));assert.equal((await life())[0],1);
 continuation.push(await tick([],'release attack'));
 const dead=await save(1,'DEAD');await trace('first');
 const loaded=await load(0,'ALIVE');assert.equal((await life())[0],0);assert.equal(loaded.pixelSha256,alive.frame.pixelSha256);assert.equal(await readGame(game,'playerView()'),aliveView);
 const roundtrip=await save(5,'ROOT CHECK');assert.equal(roundtrip.slot.digest,alive.slot.digest,'all saved roots restored after genuine death');
 // A replay is compared with both the first EVM execution and the original-C prefix.
 tape.splice(0,tape.length,...prefixTape);observations.splice(0,observations.length,...prefixObservations);held=[];turnheld=0;
 for(const original of continuation){
  const repeated=await tick(original.codes,'replay '+original.row.label,{draw:!!original.row.render,op:original.row.op,buttons:original.row.buttons});
  const expected=structuredClone(original.observation);expected.label=repeated.observation.label;
  assert.deepEqual(repeated.observation,expected,'all public lifecycle/world/RNG fields after load');
  if(original.frame){assert.equal(repeated.frame.pixelSha256,original.frame.pixelSha256);assert.equal(repeated.frame.rgbaSha256,original.frame.rgbaSha256);}
 }
 const deadReplay=await save(2,'DEAD REPLAY');assert.equal(deadReplay.slot.digest,dead.slot.digest,'entire dead world/thinker/allocator/UI root replay');
 await trace('loaded-replay');
 // B: original USE/rebirth/current-map restart, then restore the earlier living world.
 await tick(['Space'],'original use queues rebirth',{draw:true});assert.equal((await life())[0],2);
 await evaluate("window.dispatchEvent(new KeyboardEvent('keyup',{code:'Space',bubbles:true,cancelable:true}));true");held=[];
 await keys(['Escape'],game+' pending rebirth before menu freeze');assert.equal((await life())[0],0);
 tape.push({forward:0,angle:0,buttons:0,render:0,op:4,label:'menu rebirth'});observations.push(await observe('menu rebirth'));
 assert.equal((await read('gameStatus()'))[1],0);
 await keys(['Escape'],game+' resume original rebirth');
 await tick([],'first world tic after rebirth',{draw:true,op:5});
 assert.deepEqual((await read('gameStatus()')).slice(1),[1,100,0,1]);
 assert.equal((await read('uiStatus()'))[5],0);assert.deepEqual((await read('playerInventory()')).slice(0,8),[50,0,0,0,200,50,300,50]);
 const respawn=await save(3,'RESPAWN');await trace('rebirth');
 assert.equal((await slot(0)).digest,alive.slot.digest);assert.equal((await slot(1)).digest,dead.slot.digest);
 await load(0,'ALIVE AFTER RESPAWN');assert.equal((await life())[0],0);assert.equal(await readGame(game,'playerView()'),aliveView);
 const afterRespawn=await save(4,'AFTER RESPAWN');assert.equal(afterRespawn.slot.digest,alive.slot.digest);
 for(let n=0;n<6;n++){const s=await slot(n);assert(s.occupied&&s.compatible&&s.map===map&&s.skill===skill&&s.policy===3);}
 // A dead save remains usable even after world replacement. Loading restores corpse references.
 await load(1,'DEAD AFTER RESPAWN');assert.equal((await life())[0],1);
 assert.equal((await save(5,'DEAD CHECK')).slot.digest,dead.slot.digest);
 await load(0,'FINAL ALIVE');assert.equal((await save(5,'FINAL CHECK')).slot.digest,alive.slot.digest);
 report.combined??={};report.combined[game]={pass:true,map,skill,aliveDigest:alive.slot.digest,deadDigest:dead.slot.digest,respawnDigest:respawn.slot.digest,alivePixels:alive.frame.pixelSha256,aliveView,saveDieLoad:true,saveDieRespawnLoad:true,activeWorldReplayExact:true,completeRootsExact:true,deadSaveRestoresCorpse:true,allSixSlots:true,gameplayTics:observations.length,replayTics:continuation.length};
 report.saveSlots[game]={slot0ABI:await slotABI(0),slot0:alive.slot,fullRootReplayExact:true,completeFrameReplayExact:true,crossMapExact:true};
 report.checks.push({label:game+' Exact EVM save/death/load, deterministic active-world replay, original rebirth/load, dead snapshots, six isolated slots',pass:true});
}
