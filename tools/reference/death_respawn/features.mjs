// SPDX-License-Identifier: GPL-2.0-only
// Acceptance through real DOM keys and production methods; no state injection.
import {writeFile,mkdir,readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const words=v=>v.slice(2).match(/.{64}/g).map(x=>Number(BigInt.asIntN(256,BigInt('0x'+x))));
const word=n=>BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');
const sha=b=>createHash('sha256').update(b).digest('hex');
export async function verifyFeatures(game,{keys,evaluate,readGame,rpc,report,canvas,install,until}) {
 const read=async sig=>words(await readGame(game,sig)),life=()=>read('playerLifecycle()'),gs=()=>read('gameStatus()');
 const menu=()=>evaluate('window.fixtureClient.transactions.menuStatus()');
 await evaluate('window.fixtureClient.startGame();true');
 if(!(await menu()).active)await keys(['Escape'],game+' death scenario menu');
 await keys(['KeyS','Enter'],game+' select death map');
 const map=game==='doom2'?7:1,skill=3;
 const current=(await menu()).item,count=game==='doom2'?32:9;
 await keys([...Array((map-1-current+count)%count).fill('ArrowDown'),'Enter'],game+' selected map');
 const skillMenu=await menu();await keys([...Array((skill-skillMenu.item+5)%5).fill('ArrowDown'),'Enter'],game+' Ultra-Violence');
 const start=await gs(),startView=await read('playerView()');
 assert.equal((await life())[0],0);assert.equal(start[0],1,'fresh production menu startup has one world tic');
 const output='artifacts/local/death-respawn/browser-traces/'+game;await mkdir(output,{recursive:true});
 const tape=[{forward:0,buttons:0,render:1,op:0,label:'selected-map first tic'}],observations=[await observe('selected-map first tic')];
 let held=[],turnheld=0;
 async function observe(label){const [status,lifecycle,view,ui,inv]=await Promise.all([gs(),life(),read('playerView()'),read('uiStatus()'),read('playerInventory()')]);
  return {label,status,lifecycle,view,face:ui[3],palette:ui[5],rndindex:ui[7],inventory:inv,episode:await evaluate('window.fixtureClient.transactions.episodeStatus()')};}
 async function tick(codes,label,{draw=false,op=0,record=true,buttons,forward}={}) {
  await evaluate(`(async()=>{for(const code of ${JSON.stringify(held)})if(!${JSON.stringify(codes)}.includes(code))window.dispatchEvent(new KeyboardEvent('keyup',{code,bubbles:true,cancelable:true}));for(const code of ${JSON.stringify(codes)})if(!${JSON.stringify(held)}.includes(code))window.dispatchEvent(new KeyboardEvent('keydown',{code,bubbles:true,cancelable:true}));const k=window.fixtureClient.keyboard,p=k.packet();await window.fixtureClient.transactions.nextEvents(p,{draw:${draw}});k.acknowledge(p.length);return true})()`);
  held=codes;turnheld=codes.includes('ArrowRight')?turnheld+1:0;
  const angle=codes.includes('ArrowRight')?-(turnheld<6?320:(codes.includes('ShiftLeft')?1280:640)):0;
  if(record){tape.push({angle,forward:forward??(codes.includes('ArrowUp')?25:0),buttons:buttons??((codes.includes('ControlLeft')?1:0)|(codes.includes('Space')?2:0)),render:draw?1:0,op,label});observations.push(await observe(label));}
  if(draw){await until(()=>evaluate('window.__transportProof.frames.at(-1)?.inputSeq===window.fixtureClient.transactions.sequence'),'matching rendered input');await canvas(game+' '+label);}
 }
 async function cheat(text,label,op){await evaluate(`for(const code of ${JSON.stringify([...text].map(c=>'Key'+c.toUpperCase()))}){window.dispatchEvent(new KeyboardEvent('keydown',{code,bubbles:true,cancelable:true}));window.dispatchEvent(new KeyboardEvent('keyup',{code,bubbles:true,cancelable:true}));}true`);await tick([],label,{op});}
 async function save(){await writeFile(output+'/commands.txt',tape.map(x=>`${x.forward} 0 ${x.angle??0} ${x.buttons} ${x.render} ${x.op}\n`).join(''));await writeFile(output+'/observations.json',JSON.stringify({game,map,skill,start,startView,tape,observations},null,2)+'\n');}
 report.deaths??=[];
 for(let cycle=0;cycle<2;cycle++){
  await cheat('idfa','original IDFA inventory cycle'+cycle,7);
  assert.notDeepEqual((await read('playerInventory()')).slice(0,4),[50,0,0,0]);
  await tick(['Digit5'],'select original rocket weapon',{buttons:36});
  await tick([],'release weapon selection');
  for(let i=0;i<29;i++)await tick(['ArrowRight','ShiftLeft'],'original turn/weapon raise '+cycle+'/'+i);
  for(let i=0;i<4;i++)await tick([],'finish original weapon raise '+cycle+'/'+i);
  let dead=false;
  // Original rockets against real level geometry and real monsters; no test-only endpoint.
  for(let i=0;i<180;i++){
   await tick(i%20===19?['ArrowUp']:['ArrowUp','ControlLeft'],'move/fire '+cycle+'/'+i,{draw:i===0});
   if((await life())[0]===1){dead=true;break;}
   if(i%20===0)console.log('Death route',game,cycle,i,(await gs()).slice(1,4));
  }
  assert(dead,'real gameplay must cause lethal damage');
  await tick([],'dead view first',{draw:true});const deadUI=await read('uiStatus()');assert.equal(deadUI[3],41);assert(deadUI[5]>0,'original damage palette');
  for(let i=0;i<35;i++)await tick([],'death view drop '+cycle+'/'+i);
  assert.equal((await life())[0],1);assert.equal((await life())[3],6*65536);
  await tick(['ControlLeft'],'attack alone remains dead',{draw:true});assert.equal((await life())[0],1);
  await tick([],'release attack');
  const frozen=await readGame(game,'gameStatus()');
  await keys(['Escape'],game+' menu while dead');await keys(['Space'],game+' menu owns use');
  assert.equal((await life())[0],1);assert.equal(await readGame(game,'gameStatus()'),frozen);
  await keys(['ArrowDown','ArrowUp','Escape'],game+' navigate/resume while dead');
  await tick(['Space'],'use queues original rebirth',{draw:true});assert.equal((await life())[0],2);
  const before=await read('inputSeq()');
  // First cycle proves normal reload; second proves original action ordering under menu ownership.
  if(cycle===0)await tick([],'same-map original rebirth',{draw:true});
  else {
   await evaluate("window.dispatchEvent(new KeyboardEvent('keyup',{code:'Space',bubbles:true,cancelable:true}));true");held=[];
   await keys(['Escape'],game+' queued rebirth serviced under menu');
   tape.push({forward:0,buttons:0,render:0,op:4,label:'queued menu rebirth'});observations.push(await observe('queued menu rebirth'));
   assert.equal((await gs())[1],0,'original menu freezes world after reset viewz=0');
   await keys(['ArrowDown','ArrowUp','Escape'],game+' menu navigation after rebirth');
   await tick([],'first world tic after menu rebirth',{draw:true,op:5});
  }
  assert.equal((await life())[0],0);const state=await evaluate('window.fixtureClient.transactions.episodeStatus()');assert.deepEqual([state.map,state.skill],[map,skill]);
  const after=await gs(),inv=await read('playerInventory()');assert.deepEqual(after.slice(1),[1,100,0,1]);
  assert.deepEqual(inv.slice(0,8),[50,0,0,0,200,50,300,50]);assert.deepEqual(inv.slice(8,14),Array(6).fill(0));assert.deepEqual(inv.slice(14),[1,1,0,0,0,0,0,0,0]);assert.equal((await life())[5],0);assert.equal((await read('uiStatus()'))[5],0,'rebirth restores original base palette');
  assert.deepEqual((await read('playerView()')).slice(0,2),startView.slice(0,2));
  report.deaths.push({game,cycle,map,skill,actualGameplayDamage:true,originalUse:true,attackDoesNotRebirth:true,deadViewheight:6*65536,inventoryReset:true,sameStart:true,profile:3,address:install.config.address,reloadInputBefore:before[0],reloadInputAfter:(await read('inputSeq()'))[0]});
  await save();
 }
 await tick(['ArrowUp','ControlLeft'],'successful gameplay after repeated rebirth',{draw:true,op:5});assert.equal((await life())[0],0);assert.notDeepEqual((await read('playerView()')).slice(0,2),startView.slice(0,2));
 await tick([],'release continued gameplay');
 const address=install.config.address,root=(await rpc('eth_getProof',[address,[],'latest'])).storageHash,sequence=(await read('inputSeq()'))[0];
 const invalid='0x'+install.methods['stepEventsAndRender(bytes,uint32)']+word(64)+word(sequence)+word(2)+'0020'.padEnd(64,'0');
 const hash=await rpc('eth_sendTransaction',[{from:install.config.driver,to:address,data:invalid,gas:'0x2540be400'}]);
 let receipt;for(let i=0;i<1000&&!receipt;i++){receipt=await rpc('eth_getTransactionReceipt',[hash]);if(!receipt)await new Promise(r=>setTimeout(r,50));}
 assert.equal(receipt.status,'0x0');assert.equal(receipt.logs.length,0);assert.equal((await rpc('eth_getProof',[address,[],'latest'])).storageHash,root);
 report.rollbacks??=[];report.rollbacks.push({game,label:'invalid rebirth input sequence after successful gameplay',transaction:hash,storageRoot:root,allStorageUnchanged:true,noLogs:true});
 await save();report.checks.push({label:game+' actual moving lethal gameplay, two deaths/use/rebirths, dead camera/bar, menu isolation, inventory/map/skill/start reset, continued gameplay and rollback',pass:true,trace:output,commandsSha256:sha(await readFile(output+'/commands.txt')),observationsSha256:sha(await readFile(output+'/observations.json'))});
}
