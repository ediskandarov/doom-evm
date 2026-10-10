// SPDX-License-Identifier: GPL-2.0-only
// Real Chrome DOM keyboard -> ordinary transactions -> Frame/Palette -> Canvas.
import {spawn} from 'node:child_process';
import {readFile,writeFile,mkdtemp,mkdir,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {serve} from './serve.mjs';
import {makeRpc,decodeFrame,expandPalette,FRAME_TOPIC} from '../../web/protocol.mjs';
import {decodeFramePalette,FRAME_PALETTE_TOPIC} from '../../web/ui-palette.mjs';
const args=process.argv.slice(2),option=(name,fallback)=>args.includes(name)?args[args.indexOf(name)+1]:fallback;
const prefix=option('--output-prefix','artifacts/phase4/menu/browser');
const config=JSON.parse(await readFile(option('--config','artifacts/phase4/menu/final.config.json')));
assert(config.episodeMode&&config.rawKeyboard&&config.productionUI&&config.menuMode);
const rpc=makeRpc(config.rpcUrl),sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const report={kind:'evm-menu-real-chrome-canvas',pass:false,startedUtc:new Date().toISOString(),config,frames:[],keyboard:[],sourceHashes:{}};
for(const path of ['web/app.mjs','web/menu-app.mjs','web/menu-input.mjs','web/index.html','web/input-loop.mjs','web/input.mjs','web/protocol.mjs','web/ui-palette.mjs','tools/transport/menu-browser-check.mjs'])report.sourceHashes[path]=sha(await readFile(path));
await mkdir(dirname(prefix),{recursive:true});
const priorConfig=await readFile('web/config.local.json').catch(()=>null),priorPalette=await readFile('web/palette.local.json').catch(()=>null);
await writeFile('web/config.local.json',JSON.stringify(config,null,2)+'\n');await writeFile('web/palette.local.json',await readFile('artifacts/local/wad/palette.json'));
let browser,server,profile,socket;
const sleep=ms=>new Promise(done=>setTimeout(done,ms));
async function until(check,label){const end=Date.now()+300000;while(Date.now()<end){const value=await check();if(value)return value;await sleep(20);}throw Error('Timeout '+label);}
async function stop(child){if(!child?.pid||child.exitCode!==null||child.signalCode!==null)return;await new Promise(done=>{child.once('exit',done);child.kill('SIGTERM');setTimeout(()=>{if(child.exitCode===null)child.kill('SIGKILL');},1500).unref();});}
try{
  server=await serve(0);profile=await mkdtemp(join(tmpdir(),'doom-menu-chrome-'));
  browser=spawn(process.env.CHROME_BIN??'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',['--headless=new','--no-first-run','--no-default-browser-check','--disable-background-networking','--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'],{stdio:['ignore','ignore','pipe']});
  let stderr='';browser.stderr.on('data',bytes=>stderr+=bytes);browser.on('error',error=>stderr+=error.message);
  const debug=await until(async()=>{if(browser.exitCode!==null)throw Error(stderr);try{return(await readFile(join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];}catch{return false;}},'Chrome');
  const tabs=await(await fetch(`http://127.0.0.1:${debug}/json/list`)).json();socket=new WebSocket(tabs.find(tab=>tab.type==='page').webSocketDebuggerUrl);
  await new Promise((done,fail)=>{socket.addEventListener('open',done,{once:true});socket.addEventListener('error',fail,{once:true});});
  let id=0;const pending=new Map();socket.addEventListener('message',event=>{const result=JSON.parse(event.data),task=pending.get(result.id);if(task){pending.delete(result.id);clearTimeout(task.timer);result.error?task.reject(Error(JSON.stringify(result.error))):task.resolve(result.result);}});
  const command=(method,params={})=>new Promise((resolve,reject)=>{const key=++id;pending.set(key,{resolve,reject,timer:setTimeout(()=>{pending.delete(key);reject(Error('CDP timeout '+method));},300000)});socket.send(JSON.stringify({id:key,method,params}));});
  const evaluate=async expression=>{const result=await command('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(result.exceptionDetails)throw Error(result.exceptionDetails.exception?.description??result.exceptionDetails.text);return result.result.value;};
  await command('Page.enable');await command('Emulation.setDeviceMetricsOverride',{width:1100,height:800,deviceScaleFactor:1,mobile:false});
  await command('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/`});
  await until(async()=>{const proof=await evaluate('window.__transportProof');if(proof?.errors?.length)throw Error(proof.errors.join('\n'));return proof?.ready&&proof.frames.length;},'automatic initial EVM menu');
  // Freeze scheduling only after actual automatic page startup and rendering.
  // Keep original DOM handlers, packet encoder, transaction queue and Canvas path.
  await evaluate('window.fixtureClient.stopGame();window.fixtureClient.loop.schedule=fn=>{window.__menuTick=fn;return 1};window.fixtureClient.loop.cancel=()=>{window.__menuTick=null};true');
  await until(()=>evaluate('!window.fixtureClient.transactions.pending&&!window.fixtureClient.loop.starting'),'settle auto loop');
  const visible=await evaluate(`({launcher:[...document.querySelectorAll('#step,#game-start,#game-stop,#episode-level,#episode-new,#episode-restart,#episode-pause')].filter(node=>node.getClientRects().length).map(node=>node.id),debugOpen:document.querySelector('#debug').open,started:window.fixtureClient.transactions.started})`);
  assert.deepEqual(visible.launcher,[]);assert.equal(visible.debugOpen,false);assert.equal(visible.started,false);report.noVisibleHTMLLauncher=true;
  async function check(label){
    const proof=await until(async()=>{const proof=await evaluate('window.__transportProof');if(proof.errors.length)throw Error(proof.errors.join('\n'));return proof.frames.length?proof:false;},'Canvas '+label);
    const latest=proof.frames.at(-1),receipt=await rpc('eth_getTransactionReceipt',[latest.transactionHash]);assert.equal(receipt.status,'0x1');
    const frame=decodeFrame(receipt.logs.find(log=>log.topics[0]===FRAME_TOPIC));
    const palette=decodeFramePalette(receipt.logs.find(log=>log.topics[0]===FRAME_PALETTE_TOPIC),frame);
    assert.equal(proof.latestPixelsHex,Buffer.from(frame.pixels).toString('hex'));assert.equal(proof.latestPalette.rgbHex,Buffer.from(palette.rgb).toString('hex'));
    const rgba=await evaluate(`(async()=>{const bytes=document.querySelector('#frame').getContext('2d').getImageData(0,0,320,200).data;return [...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(n=>n.toString(16).padStart(2,'0')).join('')})()`);
    assert.equal(rgba,sha(expandPalette(frame,palette.rgb)));
    const screenshot=await command('Page.captureScreenshot',{format:'png'}),path=prefix+'-'+report.frames.length+'.png';await writeFile(path,Buffer.from(screenshot.data,'base64'));
    const menu=await evaluate('window.fixtureClient.transactions.menuStatus()'),state=await evaluate('window.fixtureClient.transactions.episodeStatus()');
    report.frames.push({label,menu,state,transaction:latest.transactionHash,inputSeq:frame.inputSeq,pixelSha256:sha(frame.pixels),rgbaSha256:rgba,allCanvasPixelsExact:true,screenshot:path});console.log('PASS Chrome menu Canvas',label);return report.frames.at(-1);
  }
  await check('Page load main menu');
  await evaluate('window.fixtureClient.startGame();true');await until(()=>evaluate('!!window.__menuTick&&!window.fixtureClient.loop.starting'),'controlled loop');
  async function keys(codes,label,release=true){
    const before=await evaluate('window.__transportProof.frames.length');
    await evaluate(`(async()=>{for(const code of ${JSON.stringify(codes)}){window.dispatchEvent(new KeyboardEvent('keydown',{code,bubbles:true,cancelable:true}));if(${release})window.dispatchEvent(new KeyboardEvent('keyup',{code,bubbles:true,cancelable:true}));}await window.__menuTick();return true})()`);
    await until(()=>evaluate(`window.__transportProof.frames.length>${before}&&!window.fixtureClient.transactions.pending`),'keyboard '+label);
    report.keyboard.push({codes,label});return check(label);
  }
  assert.equal((await keys(['ArrowDown','Enter'],'Select Level')).menu.screen,3);
  assert.equal((await keys(['Digit9','Enter'],'E1M9 original skill screen')).menu.screen,2);
  const start=await keys(['Enter'],'Start E1M9');assert.equal(start.state.map,9);assert.equal(start.state.state,0);assert.equal(start.state.skill,2);
  assert.equal(await evaluate('window.fixtureClient.transactions.started'),true);
  const held=await keys(['ArrowUp'],'Held gameplay keyboard',false);assert.equal(held.state.state,0);
  await keys(['ArrowUp'],'Release gameplay key');
  const opened=await keys(['Escape'],'Reopen menu in gameplay');assert.equal(opened.menu.active,1);
  const address=config.address;
  // Read gameplay state via the existing browser RPC transport, no state injection.
  const gameSelector='0x'+JSON.parse(await readFile('out/Doom.sol/Doom.json')).methodIdentifiers['gameStatus()'];
  const game=()=>rpc('eth_call',[{to:address,data:gameSelector},'latest']);
  const frozen=await game();await keys(['KeyI','KeyD','KeyD','KeyQ','KeyD','ControlLeft','Digit1'],'Menu input isolation');
  await keys([],'Menu redraw remains paused');assert.equal(await game(),frozen);
  await keys(['Escape'],'Escape Resume');assert.equal(await game(),frozen);assert.equal(report.frames.at(-1).menu.active,0);
  await keys([],'Gameplay tic resumes');assert.notEqual(await game(),frozen);
  await keys(['Escape','KeyN','Enter','Enter'],'Original New Game skill selection');
  const original=await keys(['Enter'],'New Game E1M1');assert.equal(original.state.map,1);assert.equal(original.state.state,0);
  // Receipt fallback/backfill continues to decode EVM Frames in menu mode.
  await keys(['Escape'],'Menu before fallback');await evaluate('window.fixtureClient.stopGame();true');
  await until(()=>evaluate('!window.fixtureClient.transactions.pending'),'fallback settle');
  await evaluate('window.fixtureClient.nextFrame({disconnect:true})');await check('Receipt fallback and backfill');
  const fallback=await evaluate('window.__transportProof');assert.equal(fallback.fallbackVerified,true);assert(fallback.duplicates>0);report.receiptFallbackAndDedup=true;
  // Reload uses persisted menu/game state and still requires no HTML launcher.
  await evaluate('window.__menuReloadToken="old-document";true');
  await command('Page.reload');await until(async()=>{
    const state=await evaluate('({token:window.__menuReloadToken,proof:window.__transportProof,clientReady:!!window.fixtureClient?.transactions?.menuReady})');
    if(state.token==='old-document')return false;
    if(state.proof?.errors?.length)throw Error(state.proof.errors.join('\n'));
    return state.proof?.ready&&state.proof.menuProfile&&state.clientReady;
  },'new document reload persisted menu');
  await evaluate('window.fixtureClient.stopGame();true');await until(()=>evaluate('!window.fixtureClient.transactions.pending'),'reload settle');
  const reloaded=await check('Reload persisted EVM menu');assert.equal(reloaded.menu.active,1);assert.equal(reloaded.state.map,1);report.storageReload=true;
  report.browser=await command('Browser.getVersion');report.pass=true;
}catch(error){report.error=error.stack;process.exitCode=1;console.error(error.stack);}
finally{socket?.close();await stop(browser);if(server)await new Promise(done=>server.close(done));if(profile)await rm(profile,{recursive:true,force:true});
  if(priorConfig)await writeFile('web/config.local.json',priorConfig);else await rm('web/config.local.json',{force:true});
  if(priorPalette)await writeFile('web/palette.local.json',priorPalette);else await rm('web/palette.local.json',{force:true});
  report.endedUtc=new Date().toISOString();report.stoppedOwnedBrowser=true;await writeFile(prefix+'.json',JSON.stringify(report,null,2)+'\n');}
