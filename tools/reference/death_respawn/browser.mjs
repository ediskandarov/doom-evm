// SPDX-License-Identifier: GPL-2.0-only
// Real browser File API, IndexedDB, RPC, ordinary CREATE and keyboard/Canvas.
// No predeployment, forged gameplay, state injection, or Computer Use.
import {verifyFeatures} from './features.mjs';
import {spawn} from 'node:child_process';
import {readFile,writeFile,mkdir,mkdtemp,rm,open,cp} from 'node:fs/promises';
import {connect as socketConnect} from 'node:net';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {serve} from '../../transport/serve.mjs';
import {decodeFrame,expandPalette,FRAME_TOPIC} from '../../../web/protocol.mjs';
import {decodeFramePalette,FRAME_PALETTE_TOPIC} from '../../../web/ui-palette.mjs';
const args=process.argv.slice(2),lockOnly=args.includes('--lock-only'),opt=(name,fallback)=>args.includes(name)?args[args.indexOf(name)+1]:fallback;
const port=Number(opt('--port','19421')),httpPort=Number(opt('--http-port','19422')),prefix=opt('--output-prefix','artifacts/local/death-respawn/browser');
assert(![18880,8088].includes(port)&&![18880,8088,port].includes(httpPort));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex'),rpcUrl=`http://127.0.0.1:${port}`,origin=`http://127.0.0.1:${httpPort}`;
const report={kind:'death-rebirth-real-anvil-chrome',pass:false,startedUtc:new Date().toISOString(),port,httpPort,checks:[],frames:[],sourceHashes:{}};
for(const p of ['web/install-engine.mjs','web/install-resources.mjs','web/install-storage.mjs','web/install-pins.mjs','web/launcher.mjs','web/menu-app.mjs','web/app.mjs','web/index.html','web/browser-profiles.mjs','web/doom2-profile.mjs','web/doom2-install.mjs','web/doom2-pins.mjs','tools/reference/death_respawn/browser.mjs','tools/reference/death_respawn/features.mjs','src/evm/Doom.sol','src/evm/Doom2.sol','src/evm/EpisodeRuntime.sol'])report.sourceHashes[p]=sha(await readFile(p));
await mkdir(resolve(prefix,'..'),{recursive:true});
let node,browser,server,profile,ws,log,id=0;
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function until(check,label,timeout=600000){const end=Date.now()+timeout;while(Date.now()<end){const value=await check();if(value)return value;await sleep(50);}throw Error('Timeout '+label);}
async function free(p){await new Promise((done,fail)=>{const socket=socketConnect({host:'127.0.0.1',port:p});socket.once('connect',()=>{socket.destroy();fail(Error('Occupied port '+p));});socket.once('error',e=>e.code==='ECONNREFUSED'?done():fail(e));});}
async function stop(child){if(!child?.pid||child.exitCode!==null||child.signalCode!==null)return;await new Promise(done=>{child.once('exit',done);child.kill('SIGTERM');setTimeout(()=>{if(child.exitCode===null)child.kill('SIGKILL');},3000).unref();});}
async function rpc(method,params=[]){const r=await fetch(rpcUrl,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(300000)});const body=await r.json();if(body.error)throw Error(method+JSON.stringify(body.error));return body.result;}
const pending=new Map();let commandId=0;
const command=(method,params={})=>new Promise((resolve,reject)=>{const id=++commandId;pending.set(id,{resolve,reject,timer:setTimeout(()=>{pending.delete(id);reject(Error('CDP timeout '+method));},600000)});ws.send(JSON.stringify({id,method,params}));});
const evaluate=async expression=>{const r=await command('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(r.exceptionDetails.exception?.description??r.exceptionDetails.text);return r.result.value;};
const click=id=>evaluate(`document.querySelector(${JSON.stringify('#'+id)}).click();true`);
async function reload(){await evaluate('window.__oldDocument=true');await command('Page.reload');await until(()=>evaluate('!window.__oldDocument&&!!window.installationClient'),'launcher reload');}
async function connected(){
 await evaluate(`document.querySelector('#rpc-endpoint').value=${JSON.stringify(rpcUrl)};true`);await click('connect');
 await until(async()=>{const s=await evaluate('window.__installationProof');if(s?.errors.length)throw Error(s.errors.join('\n'));return s?.connected&&!await evaluate('document.querySelector("#connect").disabled');},'connect/discover');
}
async function choose(game){
 await evaluate(`document.querySelector('#game-profile').value=${JSON.stringify(game)};document.querySelector('#game-profile').dispatchEvent(new Event('change'));true`);
 await until(async()=>{const s=await evaluate('window.__installationProof');if(s?.errors.length)throw Error(s.errors.join('\n'));return s?.profile===game&&!await evaluate('document.querySelector("#connect").disabled');},'select '+game);
 assert.equal(await evaluate('window.installationClient.installer.profile.id'),game);
}
async function localFile(game){
 const path=opt(game==='ultimate'?'--ultimate-wad':'--doom2-wad');if(!path)throw Error('Supply both commercial IWAD paths explicitly');
 const bytes=await readFile(path),md5=game==='ultimate'?'c4fe9fd920207691a9f493668e0a2083':'25e1459ca71d321525f84628f45ca8cd';
 assert.equal(createHash('md5').update(bytes).digest('hex'),md5);
 const root=await command('DOM.getDocument'),input=await command('DOM.querySelector',{nodeId:root.root.nodeId,selector:'#iwad'});
 await command('DOM.setFileInputFiles',{nodeId:input.nodeId,files:[resolve(path)]});
 await until(()=>evaluate('window.__installationProof.localIWAD?.authenticated&&!document.querySelector("#install").disabled'),'local IWAD authentication');
 report.checks.push({label:game+' browser File API exact IWAD',pass:true,md5,sha256:sha(bytes),bytes:bytes.length});
}
async function settle(){await evaluate('window.fixtureClient.stopGame();window.fixtureClient.loop.schedule=fn=>{window.__tick=fn;return 1};window.fixtureClient.loop.cancel=()=>{};true');await until(()=>evaluate('!window.fixtureClient.transactions.pending&&!window.fixtureClient.loop.starting'),'settle game');}
async function canvas(label){
 const proof=await evaluate('window.__transportProof'),latest=proof.frames.at(-1),receipt=await rpc('eth_getTransactionReceipt',[latest.transactionHash]);assert.equal(receipt.status,'0x1');
 const frame=decodeFrame(receipt.logs.find(l=>l.topics[0]===FRAME_TOPIC)),palette=decodeFramePalette(receipt.logs.find(l=>l.topics[0]===FRAME_PALETTE_TOPIC),frame);
 assert.equal(proof.latestPixelsHex,Buffer.from(frame.pixels).toString('hex'));assert.equal(proof.latestPalette.rgbHex,Buffer.from(palette.rgb).toString('hex'));
 const rgba=await evaluate("(async()=>{const b=document.querySelector('#frame').getContext('2d').getImageData(0,0,320,200).data;return [...new Uint8Array(await crypto.subtle.digest('SHA-256',b))].map(n=>n.toString(16).padStart(2,'0')).join('')})()");
 assert.equal(rgba,sha(expandPalette(frame,palette.rgb)));
 const screenshot=await command('Page.captureScreenshot',{format:'png'}),path=prefix+'-'+report.frames.length+'.png';await writeFile(path,Buffer.from(screenshot.data,'base64'));
 const indexed=prefix+'-'+report.frames.length+'.indexed.bin',rgb=prefix+'-'+report.frames.length+'.palette.bin';
 await writeFile(indexed,frame.pixels);await writeFile(rgb,palette.rgb);
 const menu=await evaluate('window.fixtureClient.transactions.menuStatus()'),state=await evaluate('window.fixtureClient.transactions.episodeStatus()');
 report.frames.push({label,transaction:latest.transactionHash,gasUsed:receipt.gasUsed,pixelSha256:sha(frame.pixels),paletteSha256:sha(palette.rgb),indexed,rgb,rgbaSha256:rgba,allCanvasPixelsExact:true,menu,state,screenshot:path,screenshotSha256:sha(Buffer.from(screenshot.data,'base64'))});console.log('PASS Canvas',label);return report.frames.at(-1);
}
async function keys(codes,label){await evaluate(`(async()=>{for(const code of ${JSON.stringify(codes)}){window.dispatchEvent(new KeyboardEvent('keydown',{code,bubbles:true,cancelable:true}));window.dispatchEvent(new KeyboardEvent('keyup',{code,bubbles:true,cancelable:true}));}await window.__tick();return true})()`);return canvas(label);}
const words=value=>value.slice(2).match(/.{64}/g).map(x=>BigInt('0x'+x).toString());
const installs={},players={};
async function readGame(game,signature){
 const config=installs[game].config,methods=installs[game].methods;
 return rpc('eth_call',[{to:config.address,data:'0x'+methods[signature],gas:'0x2540be400'},'latest']);
}
async function nonce(){return rpc('eth_getTransactionCount',[(await rpc('eth_accounts'))[0],'latest']);}
async function openGame(game){
 await click('play');await until(()=>evaluate('window.__transportProof?.ready&&!document.querySelector("#change-game").hidden'),'EVM menu '+game);await settle();
 const config=await evaluate('window.fixtureClient.config');assert.equal(config.profile,game);assert.equal(config.address,installs[game].config.address);assert.equal(config.resourceIdentity.wadSha256,installs[game].config.resourceIdentity.wadSha256);assert.equal(config.memoryPolicy,3);
 await canvas(game+' original EVM menu');
 await evaluate('window.fixtureClient.startGame();true');await until(()=>evaluate('!!window.__tick&&!window.fixtureClient.loop.starting'),'controlled DOM keys');
}
async function returnLauncher(){
 await evaluate('window.__oldDocument=true');await click('change-game');await until(()=>evaluate('!window.__oldDocument&&!!window.installationClient'),'Change game closes old document/client');
 assert.equal(await evaluate('window.__installationProof.connected'),false);await connected();
}
try{
 await free(port);await free(httpPort);log=await open(prefix+'.anvil.log','w');
 const nodeArgs=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--no-request-size-limit','--memory-limit','1073741824','--gas-limit','10000000000','--allow-origin',origin,'--silent'];
 node=spawn(resolve('.toolchain/bin/anvil'),nodeArgs,{stdio:['ignore',log.fd,log.fd]});
 await until(async()=>{if(node.exitCode!==null)throw Error('Anvil exited');try{return await rpc('web3_clientVersion');}catch{return false;}},'Anvil',10000);
 report.runtime={args:nodeArgs,info:await rpc('anvil_nodeInfo'),client:await rpc('web3_clientVersion')};
 const site=prefix+'.site';await cp('web',site,{recursive:true,filter:path=>!['config.local.json','palette.local.json'].includes(path.split('/').at(-1))});
 server=await serve(httpPort,{root:site});profile=await mkdtemp(join(tmpdir(),'doom-three-games-'));
 browser=spawn(process.env.CHROME_BIN??'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',['--headless=new','--no-first-run','--no-default-browser-check','--disable-background-networking','--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'],{stdio:['ignore','ignore','pipe']});
 let stderr='';browser.stderr.on('data',b=>stderr+=b);
 const debug=await until(async()=>{if(browser.exitCode!==null)throw Error(stderr);try{return(await readFile(join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];}catch{return false;}},'Chrome',30000);
 const tabs=await(await fetch(`http://127.0.0.1:${debug}/json/list`)).json();ws=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);
 await new Promise((done,fail)=>{ws.addEventListener('open',done,{once:true});ws.addEventListener('error',fail,{once:true});});
 ws.addEventListener('close',()=>{for(const p of pending.values()){clearTimeout(p.timer);p.reject(Error('Owned Chrome closed'));}pending.clear();});
 ws.addEventListener('message',e=>{const r=JSON.parse(e.data),p=pending.get(r.id);if(p){pending.delete(r.id);clearTimeout(p.timer);r.error?p.reject(Error(JSON.stringify(r.error))):p.resolve(r.result);}});
 await command('Page.enable');await command('Emulation.setDeviceMetricsOverride',{width:1100,height:900,deviceScaleFactor:1,mobile:false});
 await command('Page.navigate',{url:origin});await until(()=>evaluate('!!window.installationClient'),'launcher');
 assert.deepEqual(await evaluate('window.installationClient.profiles.map(p=>({id:p.id,available:p.available}))'),['freedoom','ultimate','doom2'].map(id=>({id,available:true})));
 assert.equal(await evaluate('window.__installationProof.connected'),false);
 report.checks.push({label:'All three profiles available; no automatic RPC or wallet connection',pass:true});
 await connected();
 for(const game of ['freedoom','ultimate','doom2']){
  await choose(game);assert.equal(await evaluate('window.__installationProof.installed'),false);
  if(game!=='freedoom')await localFile(game);
  const before=await nonce();
  // Observe the unchanged deployed Solidity default before the real explicit initializer.
  await evaluate("const i=window.installationClient.installer,send=i.send.bind(i);i.send=async op=>{if(op.kind==='initialize')window.__beforeInitializePolicy=Number(BigInt(await i.call(op.to,i.memoryPolicyAPI())));return send(op)};true");
  await click('install');await until(async()=>{const s=await evaluate('window.__installationProof');if(s?.errors.length)throw Error(s.errors.join('\n'));return s?.installed&&!await evaluate('document.querySelector("#play").disabled');},game+' browser installation');
  const installed=await evaluate('({config:window.installationClient.installer.configuration(),methods:window.installationClient.installer.artifacts.Doom.methods,key:window.installationClient.installer.key,journal:window.installationClient.installer.journal,beforePolicy:window.__beforeInitializePolicy})');
  assert.equal(installed.beforePolicy,2);assert.equal(installed.config.memoryPolicy,3);assert.equal(installed.journal.memoryPolicy,3);
  const init=installed.journal.receipts.find(x=>x.kind==='initialize'),tx=await rpc('eth_getTransactionByHash',[init.hash]);
  const signature=game==='doom2'?'initializeMenuWithMemoryProfile(bool,uint8)':'initializeMenuWithPolicy(bool,uint8)';
  assert.equal(tx.input,'0x'+installed.methods[signature]+'0'.repeat(64)+'3'.padStart(64,'0'));
  const journalPath=prefix+'.'+game+'.journal.json';await writeFile(journalPath,JSON.stringify(installed.journal,null,2)+'\n');
  installs[game]={config:installed.config,methods:installed.methods,journalKey:installed.key,resourceCount:installed.config.resourceIdentity.wadSha256=== '7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d'?1755:game==='ultimate'?756:889,
   receipts:installed.journal.receipts,journalPath,journalSha256:sha(await readFile(journalPath)),defaultPolicy:installed.beforePolicy,initializationAPI:signature};
  report.checks.push({label:game+' authenticated browser CREATE/install; Solidity default 2, explicit initializer 3',pass:true,address:installed.config.address,identity:installed.config.resourceIdentity,defaultPolicy:2,initializationTransaction:init.hash});
  await openGame(game);
  await verifyFeatures(game,{keys,evaluate,until,readGame,rpc,report,canvas,install:installs[game]});
  players[game]=await readGame(game,'playerView()');
  await returnLauncher();
 }
 assert.equal(new Set(Object.values(installs).map(i=>i.config.address)).size,3);
 assert.equal(new Set(Object.values(installs).map(i=>i.journalKey)).size,3);
 const switchingNonce=await nonce();
 for(const game of ['freedoom','ultimate','doom2']){
  await choose(game);assert.equal(await evaluate('window.__installationProof.installed'),true);
  assert.equal(await nonce(),switchingNonce);
  assert.equal(await readGame(game,'playerView()'),players[game]);
 }
 report.checks.push({label:'All three journals, addresses and identities isolated; selection/reload discovery makes zero transactions',pass:true,nonce:switchingNonce});
 for(const game of ['freedoom','ultimate','doom2']){
  const before=BigInt(await nonce());await choose(game);await openGame(game);
  // Opening the menu may publish Frames, but cannot tick the saved player world.
  assert.equal(await readGame(game,'playerView()'),players[game]);
  const after=BigInt(await nonce());
  for(let n=before;n<after;n++){
   const latest=await rpc('eth_getBlockByNumber',['latest',false]);let tx;
   for(let b=BigInt(latest.number);b>=0n&&!tx;b--){const block=await rpc('eth_getBlockByNumber',['0x'+b.toString(16),true]);tx=block.transactions.find(t=>BigInt(t.nonce)===n&&t.from.toLowerCase()===installs[game].config.driver);}
   assert(tx);assert.equal(tx.to?.toLowerCase(),installs[game].config.address.toLowerCase());
  }
  await keys(['Escape'],game+' resume saved gameplay');
  await settle();players[game]=await readGame(game,'playerView()');
  for(const other of Object.keys(players).filter(x=>x!==game))assert.equal(await readGame(other,'playerView()'),players[other]);
  report.checks.push({label:game+' Change game/reload/Play resumes same contract; all new transactions target it; other player states untouched',pass:true,newTransactions:Number(after-before),address:installs[game].config.address});
  await returnLauncher();
 }
 const beforeReload=await nonce();await reload();assert.equal(await evaluate('document.querySelector("#game-profile").value'),'doom2');await connected();assert.equal(await evaluate('window.__installationProof.installed'),true);assert.equal(await nonce(),beforeReload);
 report.checks.push({label:'Reload remembers selected DOOM II and detects existing installation without redeployment',pass:true});
 report.browser=await command('Browser.getVersion');report.installations=installs;report.pass=true;
}catch(error){report.error=error.stack;process.exitCode=1;console.error(error.stack);try{report.lastBrowserState=await evaluate('({installation:window.__installationProof,status:document.querySelector("#install-status")?.textContent,transport:window.__transportProof})');}catch{}}
finally{
 ws?.close();await stop(browser);await stop(node);if(server)await new Promise(done=>server.close(done));await log?.close();if(profile)await rm(profile,{recursive:true,force:true});
 report.endedUtc=new Date().toISOString();report.stoppedOwnedRuntimes=true;await writeFile(prefix+'.json',JSON.stringify(report,null,2)+'\n');console.log('Report',prefix+'.json');
}
