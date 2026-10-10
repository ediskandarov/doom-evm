// SPDX-License-Identifier: GPL-2.0-only
// Real Chrome, existing browser controls, mined EVM Frame/Palette -> Canvas.
import {spawn} from 'node:child_process';
import {readFile,writeFile,mkdtemp,mkdir,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {serve} from './serve.mjs';
import {makeRpc,decodeFrame,expandPalette,FRAME_TOPIC} from '../../web/protocol.mjs';
import {decodeFramePalette,FRAME_PALETTE_TOPIC} from '../../web/ui-palette.mjs';
const args=process.argv.slice(2),opt=(n,d)=>args.includes(n)?args[args.indexOf(n)+1]:d;
const prefix=opt('--output-prefix','artifacts/phase4/episode-completion/browser');
const config=JSON.parse(await readFile(opt('--config','artifacts/phase4/episode-completion/evm.config.json')));
// This inherited launcher-control gate deliberately selects the legacy browser profile.
config.menuMode=false;
assert(config.episodeMode&&config.rawKeyboard&&config.productionUI);
const rpc=makeRpc(config.rpcUrl),sha=b=>createHash('sha256').update(b).digest('hex');
const report={kind:'episode-one-real-chrome-canvas',pass:false,startedUtc:new Date().toISOString(),config,frames:[],controls:[],sourceHashes:{}};
for(const path of ['web/app.mjs','web/input-loop.mjs','web/input.mjs','web/protocol.mjs','web/ui-palette.mjs','tools/transport/episode-browser-check.mjs'])report.sourceHashes[path]=sha(await readFile(path));
await mkdir(dirname(prefix),{recursive:true});
const priorConfig=await readFile('web/config.local.json').catch(()=>null),priorPalette=await readFile('web/palette.local.json').catch(()=>null);
await writeFile('web/config.local.json',JSON.stringify(config,null,2)+'\n');
await writeFile('web/palette.local.json',await readFile('artifacts/local/wad/palette.json'));
let browser,server,profile,socket;
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function until(check,label){const end=Date.now()+300000;while(Date.now()<end){const r=await check();if(r)return r;await sleep(20);}throw Error('Timeout '+label);}
async function stop(child){if(!child?.pid||child.exitCode!==null||child.signalCode!==null)return;await new Promise(done=>{child.once('exit',done);child.kill('SIGTERM');setTimeout(()=>{if(child.exitCode===null)child.kill('SIGKILL');},1500).unref();});}
try {
  server=await serve(0);profile=await mkdtemp(join(tmpdir(),'doom-episode-chrome-'));
  browser=spawn(process.env.CHROME_BIN??'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',['--headless=new','--no-first-run','--no-default-browser-check','--disable-background-networking','--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'],{stdio:['ignore','ignore','pipe']});
  let err='';browser.stderr.on('data',b=>err+=b);browser.on('error',e=>err+=e.message);
  const debug=await until(async()=>{if(browser.exitCode!==null)throw Error(err);try{return(await readFile(join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];}catch{return false;}},'Chrome');
  const tabs=await(await fetch(`http://127.0.0.1:${debug}/json/list`)).json();socket=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);
  await new Promise((done,fail)=>{socket.addEventListener('open',done,{once:true});socket.addEventListener('error',fail,{once:true});});
  let id=0;const pending=new Map();socket.addEventListener('message',e=>{const r=JSON.parse(e.data),p=pending.get(r.id);if(p){pending.delete(r.id);clearTimeout(p.timer);r.error?p.reject(Error(JSON.stringify(r.error))):p.resolve(r.result);}});
  const command=(method,params={})=>new Promise((resolve,reject)=>{const key=++id;pending.set(key,{resolve,reject,timer:setTimeout(()=>{pending.delete(key);reject(Error('CDP timeout '+method));},300000)});socket.send(JSON.stringify({id:key,method,params}));});
  const evaluate=async expression=>{const r=await command('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(r.exceptionDetails.exception?.description??r.exceptionDetails.text);return r.result.value;};
  await command('Page.enable');await command('Emulation.setDeviceMetricsOverride',{width:1100,height:1000,deviceScaleFactor:1,mobile:false});
  await command('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/`});
  await until(async()=>{const p=await evaluate('window.__transportProof');if(p?.errors?.length)throw Error(p.errors.join('\n'));return p?.ready&&(args.includes('--fresh')||p.frames.length);},'Episode page');
  // Control the input timer, retaining actual DOM handlers and transaction code.
  await evaluate('window.fixtureClient.loop.schedule=fn=>{window.__episodeTick=fn;return 1};window.fixtureClient.loop.cancel=()=>{window.__episodeTick=null};true');
  async function check(label){const p=await until(async()=>{const p=await evaluate('window.__transportProof');if(p.errors.length)throw Error(p.errors.join('\n'));return p.frames.length?p:false;},'Canvas '+label);
    const latest=p.frames.at(-1),receipt=await rpc('eth_getTransactionReceipt',[latest.transactionHash]);assert.equal(receipt.status,'0x1');
    const f=decodeFrame(receipt.logs.find(l=>l.topics[0]===FRAME_TOPIC)),pal=decodeFramePalette(receipt.logs.find(l=>l.topics[0]===FRAME_PALETTE_TOPIC),f);
    assert.equal(p.latestPixelsHex,Buffer.from(f.pixels).toString('hex'));assert.equal(p.latestPalette.rgbHex,Buffer.from(pal.rgb).toString('hex'));
    const rgba=await evaluate(`(async()=>{const b=document.querySelector('#frame').getContext('2d').getImageData(0,0,320,200).data;return [...new Uint8Array(await crypto.subtle.digest('SHA-256',b))].map(n=>n.toString(16).padStart(2,'0')).join('')})()`);
    assert.equal(rgba,sha(expandPalette(f,pal.rgb)));
    const image=await command('Page.captureScreenshot',{format:'png'});const path=prefix+'-'+report.frames.length+'.png';await writeFile(path,Buffer.from(image.data,'base64'));
    const state=await evaluate('window.fixtureClient.transactions.episodeStatus()');
    report.frames.push({label,state,transaction:latest.transactionHash,inputSeq:f.inputSeq,pixelSha256:sha(f.pixels),palette:pal.palette,rgbaSha256:rgba,allCanvasPixelsExact:true,screenshot:path});console.log('PASS Chrome Canvas',label);
  }
  if(!args.includes('--fresh'))await check('Existing lifecycle Frame');
  if(!args.includes('--display-only')) {
    async function click(id,label){const before=await evaluate('window.__transportProof.frames.length');await evaluate(`document.querySelector(${JSON.stringify('#'+id)}).click();true`);
      await until(()=>evaluate(`window.__transportProof.frames.length>${before}&&!window.fixtureClient.transactions.pending&&!window.fixtureClient.loop.starting`),'control '+label);
      await evaluate('window.fixtureClient.stopGame();true');await until(()=>evaluate('!window.fixtureClient.transactions.pending'),'control settle');await check(label);report.controls.push(label);}
    await evaluate('document.querySelector("#episode-level").value="1";true');await click('episode-new','New Game E1M1');
    assert.equal(report.frames.at(-1).state.map,1);assert.equal(report.frames.at(-1).state.state,0);
    await click('episode-pause','Pause');assert.equal(report.frames.at(-1).state.paused,1);
    await click('episode-pause','Resume');assert.equal(report.frames.at(-1).state.paused,0);
    await click('episode-restart','Restart');assert.equal(report.frames.at(-1).state.map,1);
    await evaluate('document.querySelector("#episode-level").value="9";true');await click('episode-new','New Game E1M9');assert.equal(report.frames.at(-1).state.map,9);
    // Actual keyboard event binding with a controlled original loop tic.
    await evaluate('document.querySelector("#game-start").click();true');await until(()=>evaluate('!!window.__episodeTick&&!window.fixtureClient.loop.starting'),'input loop');
    await evaluate('(async()=>{window.dispatchEvent(new KeyboardEvent("keydown",{code:"Tab",key:"Tab",bubbles:true,cancelable:true}));await window.__episodeTick();window.fixtureClient.stopGame();return true})()');
    await until(()=>evaluate('!window.fixtureClient.transactions.pending'),'keyboard settle');await check('Tab Automap');
  }
  report.browser=await command('Browser.getVersion');report.pass=true;
}catch(e){report.error=e.stack;process.exitCode=1;console.error(e.stack);}
finally {socket?.close();await stop(browser);if(server)await new Promise(done=>server.close(done));if(profile)await rm(profile,{recursive:true,force:true});
  if(priorConfig)await writeFile('web/config.local.json',priorConfig);else await rm('web/config.local.json',{force:true});
  if(priorPalette)await writeFile('web/palette.local.json',priorPalette);else await rm('web/palette.local.json',{force:true});
  report.endedUtc=new Date().toISOString();report.stoppedOwnedBrowser=true;await writeFile(prefix+'.json',JSON.stringify(report,null,2)+'\n');}
