// SPDX-License-Identifier: GPL-2.0-only
// Assertions only. All selection/settings/gameplay remain real DOM→EVM inputs.
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const words=v=>v.slice(2).match(/.{64}/g).map(x=>Number(BigInt.asIntN(256,BigInt('0x'+x))));
const word=n=>BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');
const tail=b=>word(b.length)+Buffer.from(b).toString('hex').padEnd(Math.ceil(b.length/32)*64,'0');
function ui(data){const v=words(data),offset=v[10];const length=Number(BigInt('0x'+data.slice(2+offset*2,2+offset*2+64)));return {on:v[8],counter:v[9],fullscreen:v[1],text:Buffer.from(data.slice(2+offset*2+64,2+offset*2+64+length*2),'hex').toString().replace(/\0.*$/s,'')};}
export async function verifyFeatures(game,{keys,evaluate,until,readGame,rpc,report,install}){
 const bytes=await readFile('artifacts/local/options/startup-native/result.json'),native=JSON.parse(bytes);assert(native.pass_);
 report.nativeStartupSha256=createHash('sha256').update(bytes).digest('hex');report.selections??=[];report.rollbacks??=[];
 const read=async sig=>words(await readGame(game,sig)),menu=()=>evaluate('window.fixtureClient.transactions.menuStatus()');
 const state=()=>evaluate('window.fixtureClient.transactions.episodeStatus()'),hud=async()=>ui(await readGame(game,'uiStatus()'));
 const label=text=>game+' '+text;
 await evaluate('window.fixtureClient.startGame();true');await until(()=>evaluate('!!window.__tick&&!window.fixtureClient.loop.starting'),'feature key loop');
 async function main(){
  for(let i=0;i<3&&(await menu()).active&&(await menu()).screen!==0;i++)await keys(['Backspace'],label('Back'));
  if(!(await menu()).active)await keys(['Escape'],label('open main'));
  assert.equal((await menu()).screen,0);
 }
 async function select(map,skill){
  await main();await keys(['KeyS','Enter'],label('SELECT LEVEL'));assert.equal((await menu()).screen,3);
  const count=game==='doom2'?32:9,current=(await menu()).item;
  const down=(map-1-current+count)%count,up=(current-map+1+count)%count;
  await keys([...Array(Math.min(down,up)).fill(down<=up?'ArrowDown':'ArrowUp'),'Enter'],label('map '+map+' → original skills'));
  assert.equal((await menu()).screen,2);assert.equal((await menu()).map,map);
  await keys([...Array((skill-(await menu()).item+5)%5).fill('ArrowDown'),'Enter'],label('skill '+skill));
  if(skill===4){assert.equal((await menu()).confirmation,1);await keys(['KeyY'],label('Nightmare confirmed'));}
  const s=await state();assert.deepEqual([s.map,s.skill,s.state,s.action],[map,skill,0,0]);
  const gs=await read('gameStatus()'),view=await read('playerView()'),totals=await read('spawnStatus()'),inv=await read('playerInventory()');
  const expected=native.cases.find(c=>c.game===game&&c.map===map&&c.skill===skill);assert(expected);
  assert.deepEqual(totals.slice(0,3),[expected.totalKills,expected.totalItems,expected.totalSecrets]);
  assert.deepEqual([gs[1],gs[2],view[0],view[1],view[8]],[expected.leveltime,expected.health,expected.x,expected.y,expected.prndindex]);
  assert.deepEqual(inv.slice(0,4),expected.ammo);assert.deepEqual(inv.slice(8,14),Array(6).fill(0));assert.deepEqual(inv.slice(14),[1,1,0,0,0,0,0,0,0]);assert.equal(gs[3],0);
  report.selections.push({game,map,skill,totals,leveltime:gs[1],prndindex:view[8],nativeSpawnAndRNGExact:true,originalInventoryRestored:true,noIntermission:true});
  console.log('PASS native/EVM map skill',game,map,skill);
 }
 for(const skill of [2,4])await select(1,skill);
 await main();await keys(['KeyS','Enter','ArrowUp','Enter'],label('last-map skill selection'));
 const selected=(await menu()).map;await keys(['Backspace'],label('skill Back to list'));assert.equal((await menu()).screen,3);assert.equal((await menu()).map,selected);
 await keys(['Backspace'],label('list Back to main'));assert.equal((await menu()).screen,0);
 await keys(['KeyS','Enter','Enter','KeyN','Enter'],label('Nightmare cancellation prompt'));assert.equal((await menu()).confirmation,1);
 const frozen=await readGame(game,'gameStatus()');await keys(['KeyN'],label('Nightmare cancel'));assert.equal((await menu()).active,0);assert.equal(await readGame(game,'gameStatus()'),frozen);
 await keys(['KeyI','KeyD','KeyK','KeyF','KeyA'],label('original inventory cheat'));
 assert.notDeepEqual((await read('playerInventory()')).slice(0,4),[50,0,0,0]);
 for(const map of game==='doom2'?[32]:[9])await select(map,2);
 async function newGame(){await main();await keys(['KeyN','Enter'],label('original NEW GAME'));if(game!=='doom2')await keys(['Enter'],label('original E1 episode'));assert.equal((await menu()).screen,2);await keys(['Enter'],label('original first-map startup'));assert.equal((await state()).map,1);}
 await newGame();
 await main();await keys(['KeyO','Enter'],label('Options'));assert.equal((await menu()).screen,4);assert.deepEqual(await read('optionsStatus()'),[1,10,1]);
 await keys(['KeyM','Enter'],label('Messages OFF'));assert.deepEqual(await read('optionsStatus()'),[0,10,1]);
 await keys(['Escape'],label('close Options'));await keys([],label('forced Messages OFF HUD'));assert.equal((await hud()).text,'Messages OFF');assert.equal((await hud()).on,1);
 await select(1,2);await keys(['KeyI','KeyD','KeyD','KeyQ','KeyD'],label('OFF gameplay message'));assert.equal((await hud()).on,0);
 await main();await keys(['KeyO','Enter'],label('reopen persists OFF'));assert.deepEqual(await read('optionsStatus()'),[0,10,1]);
 await keys(['KeyS'],label('screen slider'));const before=await readGame(game,'gameStatus()');
 const frame10=report.frames.at(-1).pixelSha256;
 const statusPixels=Buffer.from(await evaluate('window.__transportProof.latestPixelsHex'),'hex').subarray(320*168);
 const statusHash=createHash('sha256').update(statusPixels).digest('hex');
 const nativePrior=await readFile('artifacts/local/options/status-resize-native/'+game+'/prior.pixels');assert.deepEqual(statusPixels,nativePrior,'cached native differential status bar');
 await keys(['ArrowRight'],label('full-screen viewport'));assert.deepEqual(await read('optionsStatus()'),[0,11,1]);assert.equal((await hud()).fullscreen,1);assert.equal(await readGame(game,'gameStatus()'),before);assert.notEqual(report.frames.at(-1).pixelSha256,frame10);
 const fullPixels=Buffer.from(await evaluate('window.__transportProof.latestPixelsHex'),'hex').subarray(320*168);assert.notDeepEqual(fullPixels,statusPixels);
 await keys(['ArrowRight','Enter'],label('upper size clamp'));assert.equal((await read('optionsStatus()'))[1],11);
 await keys(['ArrowLeft','ArrowLeft'],label('status bar and lower size clamp'));assert.equal((await read('optionsStatus()'))[1],10);assert.equal((await hud()).fullscreen,0);assert.equal(await readGame(game,'gameStatus()'),before);
 const restored=Buffer.from(await evaluate('window.__transportProof.latestPixelsHex'),'hex').subarray(320*168);const nativeRestored=await readFile('artifacts/local/options/status-resize-native/'+game+'/restored.pixels');assert.deepEqual(restored,nativeRestored,'all native refreshed status-bar pixels');
 const refreshChanges=[...restored].filter((b,i)=>b!==statusPixels[i]).length;
 report.checks.push({label:label('viewport overwrites status-bar region and matches all 10,240 original refreshed status-bar pixels'),pass:true,priorStatusBarSha256:statusHash,refreshedStatusBarSha256:createHash('sha256').update(restored).digest('hex'),originalRefreshChangedPixels:refreshChanges,worldFrozen:true});
 // A no-render size request must remain pending until the next menu Frame.
 await evaluate('window.fixtureClient.transactions.nextEvents(new Uint8Array([0,174,1,174]),{draw:false})');
 assert.equal((await read('optionsStatus()'))[1],11);await keys([],label('deferred no-render size applied'));assert.equal((await hud()).fullscreen,1);
 await keys(['ArrowLeft'],label('restore status-bar after deferred request'));
 // Preserve the inherited EVM setter: it must update the same authoritative menu value.
 async function setView(fullscreen){
  const data='0x'+install.methods['setUIFullscreen(bool)']+word(fullscreen?1:0);
  const sequence=(await read('inputSeq()'))[0];
  const hash=await rpc('eth_sendTransaction',[{from:install.config.driver,to:install.config.address,data,gas:'0x2540be400'}]);
  const receipt=await until(()=>rpc('eth_getTransactionReceipt',[hash]),'original view API');assert.equal(receipt.status,'0x1');assert.equal(receipt.logs.length,0);
  assert.equal((await read('optionsStatus()'))[1],fullscreen?11:10);assert.equal((await read('inputSeq()'))[0],sequence);
  (report.viewportAPI??=[]).push({game,fullscreen,transaction:hash,gasUsed:receipt.gasUsed,noLogs:true,sequenceUnchanged:true});
  await keys([],label('existing fullscreen API '+fullscreen));assert.equal((await hud()).fullscreen,fullscreen?1:0);assert.equal(await readGame(game,'gameStatus()'),before);
 }
 await setView(true);await setView(false);
 assert.deepEqual(Buffer.from(await evaluate('window.__transportProof.latestPixelsHex'),'hex').subarray(320*168),nativeRestored);
 report.checks.push({label:label('existing setUIFullscreen API and Options remain synchronized with exact native status restoration'),pass:true});
 await keys(['KeyM','Enter'],label('Messages ON'));await keys(['Escape'],label('resume ON'));await keys([],label('forced Messages ON HUD'));assert.equal((await hud()).text,'Messages ON');
 await select(1,2);await keys(['KeyI','KeyD','KeyD','KeyQ','KeyD'],label('ON gameplay message'));assert.equal((await hud()).on,1);assert.equal((await hud()).text,'Degreelessness Mode On');
 await main();await keys(['KeyO','Enter','KeyE','Enter'],label('End Game confirmation'));assert.equal((await menu()).confirmation,1);
 const beforeCancel=await readGame(game,'gameStatus()');await keys(['Escape'],label('End Game cancel'));assert.equal((await menu()).active,0);assert.equal(await readGame(game,'gameStatus()'),beforeCancel);
 await main();await keys(['KeyO','Enter','KeyS'],label('Options rollback boundary'));
 const seq=(await read('inputSeq()'))[0]+1;
 const packet=(b,n=seq)=>'0x'+install.methods['stepEventsAndRender(bytes,uint32)']+word(64)+word(n)+tail(b);
 async function rollback(data,text,from=install.config.driver,gas='0x2540be400'){
  const address=install.config.address,before=await rpc('eth_getProof',[address,[],'latest']);
  const hash=await rpc('eth_sendTransaction',[{from,to:address,data,gas}]);const receipt=await until(()=>rpc('eth_getTransactionReceipt',[hash]),'revert');assert.equal(receipt.status,'0x0');assert.equal(receipt.logs.length,0);
  assert.equal((await rpc('eth_getProof',[address,[],'latest'])).storageHash,before.storageHash);
  report.rollbacks.push({game,label:text,transaction:hash,storageRoot:before.storageHash,gasUsed:receipt.gasUsed,allStorageUnchanged:true,noLogs:true});
 }
 await rollback(packet([0,174]),'underfunded size-change and Frame',undefined,'0x5f5e100');
 await rollback(packet([0,109,0,13,2,0]),'invalid event after setting input');await rollback(packet([0]),'odd packet');await rollback(packet([0,174],seq-1),'stale sequence');await rollback(packet([0,174]),'non-driver',(await rpc('eth_accounts'))[1]);
 await keys(['ArrowRight'],label('same sequence size retry'));assert.equal((await read('optionsStatus()'))[1],11);
 await keys(['ArrowLeft','KeyE','Enter','KeyY'],label('End Game confirmed title'));assert.equal((await read('gameStarted()'))[0],0);assert.equal((await menu()).active,0);
 await keys(['Escape','KeyO','Enter','KeyE','Enter'],label('title End Game guarded'));assert.equal((await menu()).confirmation,0);assert.equal((await read('gameStarted()'))[0],0);
 await newGame();assert.equal((await read('gameStarted()'))[0],1);
 report.checks.push({label:label('Options actual effects/persistence; original NEW GAME; Back/Escape; End Game/cancel; rollback'),pass:true});
}
