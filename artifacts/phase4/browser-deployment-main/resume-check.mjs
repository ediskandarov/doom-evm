// SPDX-License-Identifier: GPL-2.0-only
// Real browser File API, IndexedDB, RPC, ordinary CREATE and keyboard/Canvas.
// No predeployment, forged gameplay, state injection, or Computer Use.
import {spawn} from 'node:child_process';
import {readFile,writeFile,mkdir,mkdtemp,rm,open} from 'node:fs/promises';
import {connect as socketConnect} from 'node:net';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {serve} from '../transport/serve.mjs';
import {decodeFrame,expandPalette,FRAME_TOPIC} from '../../web/protocol.mjs';
import {decodeFramePalette,FRAME_PALETTE_TOPIC} from '../../web/ui-palette.mjs';
const args=process.argv.slice(2),lockOnly=args.includes('--lock-only'),opt=(name,fallback)=>args.includes(name)?args[args.indexOf(name)+1]:fallback;
const port=Number(opt('--port','18991')),httpPort=Number(opt('--http-port','18992')),prefix=opt('--output-prefix','artifacts/browser-deployment/real');
assert(![18880,8088].includes(port)&&![18880,8088,port].includes(httpPort));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex'),rpcUrl=`http://127.0.0.1:${port}`,origin=`http://127.0.0.1:${httpPort}`;
const report={kind:'browser-managed-installation-real-anvil-chrome',pass:false,startedUtc:new Date().toISOString(),port,httpPort,checks:[],frames:[],sourceHashes:{}};
for(const p of ['web/install-engine.mjs','web/install-resources.mjs','web/install-storage.mjs','web/install-pins.mjs','web/launcher.mjs','web/menu-app.mjs','web/app.mjs','web/index.html','tools/browser-deployment/check.mjs'])report.sourceHashes[p]=sha(await readFile(p));
report.integrationHarness='Copied source check with one additional reload Play/Escape/movement gate; all inherited assertions preserved';
report.sourceHashes['tools/browser-deployment/resume-check.mjs']=sha(await readFile('tools/browser-deployment/resume-check.mjs'));
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
async function connected(){await evaluate(`document.querySelector('#rpc-endpoint').value=${JSON.stringify(rpcUrl)};true`);await click('connect');await until(async()=>{const state=await evaluate('window.__installationProof');if(state?.errors.length)throw Error(state.errors.join('\n'));return state?.connected;},'connect/discover');}
async function settle(){await evaluate('window.fixtureClient.stopGame();window.fixtureClient.loop.schedule=fn=>{window.__tick=fn;return 1};window.fixtureClient.loop.cancel=()=>{};true');await until(()=>evaluate('!window.fixtureClient.transactions.pending&&!window.fixtureClient.loop.starting'),'settle game');}
async function canvas(label){
 const proof=await evaluate('window.__transportProof'),latest=proof.frames.at(-1),receipt=await rpc('eth_getTransactionReceipt',[latest.transactionHash]);assert.equal(receipt.status,'0x1');
 const frame=decodeFrame(receipt.logs.find(l=>l.topics[0]===FRAME_TOPIC)),palette=decodeFramePalette(receipt.logs.find(l=>l.topics[0]===FRAME_PALETTE_TOPIC),frame);
 assert.equal(proof.latestPixelsHex,Buffer.from(frame.pixels).toString('hex'));assert.equal(proof.latestPalette.rgbHex,Buffer.from(palette.rgb).toString('hex'));
 const rgba=await evaluate("(async()=>{const b=document.querySelector('#frame').getContext('2d').getImageData(0,0,320,200).data;return [...new Uint8Array(await crypto.subtle.digest('SHA-256',b))].map(n=>n.toString(16).padStart(2,'0')).join('')})()");
 assert.equal(rgba,sha(expandPalette(frame,palette.rgb)));
 const screenshot=await command('Page.captureScreenshot',{format:'png'}),path=prefix+'-'+report.frames.length+'.png';await writeFile(path,Buffer.from(screenshot.data,'base64'));
 const menu=await evaluate('window.fixtureClient.transactions.menuStatus()'),state=await evaluate('window.fixtureClient.transactions.episodeStatus()');
 report.frames.push({label,transaction:latest.transactionHash,gasUsed:receipt.gasUsed,pixelSha256:sha(frame.pixels),rgbaSha256:rgba,allCanvasPixelsExact:true,menu,state,screenshot:path});console.log('PASS Canvas',label);return report.frames.at(-1);
}
async function keys(codes,label){await evaluate(`(async()=>{for(const code of ${JSON.stringify(codes)}){window.dispatchEvent(new KeyboardEvent('keydown',{code,bubbles:true,cancelable:true}));window.dispatchEvent(new KeyboardEvent('keyup',{code,bubbles:true,cancelable:true}));}await window.__tick();return true})()`);return canvas(label);}
try{
 await free(port);await free(httpPort);log=await open(prefix+'.anvil.log','w');
 const nodeArgs=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--no-request-size-limit','--memory-limit','1073741824','--gas-limit','10000000000','--allow-origin',origin,'--silent'];
 node=spawn(resolve('.toolchain/bin/anvil'),nodeArgs,{stdio:['ignore',log.fd,log.fd]});
 await until(async()=>{if(node.exitCode!==null)throw Error('Anvil exited');try{return await rpc('web3_clientVersion');}catch{return false;}},'Anvil',10000);
 report.runtime={args:nodeArgs,info:await rpc('anvil_nodeInfo'),client:await rpc('web3_clientVersion')};
 server=await serve(httpPort);profile=await mkdtemp(join(tmpdir(),'doom-browser-install-'));
 browser=spawn(process.env.CHROME_BIN??'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',['--headless=new','--no-first-run','--no-default-browser-check','--disable-background-networking','--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'],{stdio:['ignore','ignore','pipe']});
 let stderr='';browser.stderr.on('data',b=>stderr+=b);
 const debug=await until(async()=>{if(browser.exitCode!==null)throw Error(stderr);try{return(await readFile(join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];}catch{return false;}},'Chrome',30000);
 const tabs=await(await fetch(`http://127.0.0.1:${debug}/json/list`)).json();ws=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);
 await new Promise((done,fail)=>{ws.addEventListener('open',done,{once:true});ws.addEventListener('error',fail,{once:true});});
 ws.addEventListener('message',e=>{const r=JSON.parse(e.data),p=pending.get(r.id);if(p){pending.delete(r.id);clearTimeout(p.timer);r.error?p.reject(Error(JSON.stringify(r.error))):p.resolve(r.result);}});
 await command('Page.enable');await command('Emulation.setDeviceMetricsOverride',{width:1100,height:900,deviceScaleFactor:1,mobile:false});
 await command('Page.navigate',{url:origin});await until(()=>evaluate('!!window.installationClient'),'launcher');
 assert.equal(await evaluate('window.__installationProof.connected'),false);report.checks.push({label:'No automatic RPC connection or wallet request',pass:true});
 await connected();assert.equal(await evaluate('window.__installationProof.installed'),false);
 // Real resource CREATE, then pause at a durable partial checkpoint.
 if(lockOnly)await evaluate(`(async()=>{const {BrowserInstaller}=await import('/install-engine.mjs');window.__otherInstaller=new BrowserInstaller();await window.__otherInstaller.connect(${JSON.stringify(rpcUrl)});return true})()`);
 await evaluate("const i=window.installationClient.installer;const progress=i.onProgress;i.onProgress=e=>{progress(e);if(e.stage==='Uploading authenticated resources'&&e.completed===8)i.pause()};document.querySelector('#install').click();true");
 await until(()=>evaluate('window.__installationProof.errors.some(e=>e.includes("paused"))'),'paused partial installation');
 const partial=await evaluate('({resources:Object.keys(window.installationClient.installer.journal.resources).length,receipts:window.installationClient.installer.journal.receipts.length,pending:window.installationClient.installer.journal.pending})');assert.equal(partial.resources,8);assert.equal(partial.pending,null);
 report.checks.push({label:'Partial resource upload interrupted after 8 chunks',pass:true,...partial});console.log('PASS partial interruption',partial.resources);
 if(lockOnly){
  const reused=await evaluate(`(async()=>{const other=window.__otherInstaller;other.onProgress=e=>{if(e.stage==='Uploading authenticated resources'&&e.completed===8)other.pause()};try{await other.exclusive(()=>other.install(window.installationClient.resources,window.installationClient.profiles[0]))}catch(e){if(!e.message.includes('paused'))throw e;}return {resources:Object.keys(other.journal.resources).length,receipts:other.journal.receipts.length}})()`);
  assert.equal(reused.resources,8);assert.equal(reused.receipts,8);
  const from=(await rpc('eth_accounts'))[0];assert.equal(BigInt(await rpc('eth_getTransactionCount',[from,'latest'])),8n);
  report.checks.push({label:'Previously connected second installer refreshes journal under lock and reuses all 8 resources with zero additional transactions',pass:true,...reused});
  const excluded=await evaluate(`navigator.locks.request('doom-evm-install|'+${JSON.stringify(rpcUrl)},async()=>{try{await window.__otherInstaller.exclusive(()=>{throw Error('must not run')});return false}catch(e){return e.message.includes('Another tab')}})`);
  assert.equal(excluded,true);report.checks.push({label:'Active endpoint lock rejects concurrent installer',pass:true});
  const screenshot=await command('Page.captureScreenshot',{format:'png'});await writeFile(prefix+'-launcher.png',Buffer.from(screenshot.data,'base64'));
  report.browser=await command('Browser.getVersion');report.pass=true;
 }else{
 await reload();await connected();assert.equal(await evaluate('window.__installationProof.discovery.partial'),8);
 // Lost send response AFTER actual mining. Journal has no tx hash: recovery
 // must locate sender/nonce in canonical blocks without deploying a duplicate.
 await evaluate("const i=window.installationClient.installer,real=i.rpc;let sends=0;i.rpc=async(...args)=>{const result=await real(...args);if(args[0]==='eth_sendTransaction'&&++sends===4)throw Error('Injected disconnect after actual submission');return result};document.querySelector('#install').click();true");
 await until(()=>evaluate('window.__installationProof.errors.some(e=>e.includes("Injected disconnect"))'),'uncertain send disconnect');
 const uncertain=await evaluate('window.installationClient.installer.journal.pending');assert.equal(uncertain.hash,null);
 report.checks.push({label:'Real submitted transaction loses response',pass:true,nonce:uncertain.nonce,kind:uncertain.kind});
 await reload();await connected();assert.equal(await evaluate('window.__installationProof.discovery.partial'),12);
 const from=(await rpc('eth_accounts'))[0];assert.equal(BigInt(await rpc('eth_getTransactionCount',[from,'latest'])),12n);
 report.checks.push({label:'Reload reconciles mined unknown-hash operation without duplicate CREATE',pass:true,resources:12});console.log('PASS uncertain recovery');
 // Real browser network failure before submission, then restore connectivity.
 await command('Network.enable');await command('Network.setBlockedURLs',{urls:[rpcUrl+'*']});await click('install');
 await until(()=>evaluate('window.__installationProof.errors.length>0'),'actual RPC disconnect');
 assert.equal(BigInt(await rpc('eth_getTransactionCount',[from,'latest'])),12n);
 await command('Network.setBlockedURLs',{urls:[]});await reload();await connected();
 report.checks.push({label:'Real browser RPC disconnect and retry preserve completed resources',pass:true,resources:12});
 // An actually pending transaction survives reload and is reconciled after mining.
 await rpc('evm_setAutomine',[false]);await click('install');
 await until(()=>evaluate('!!window.installationClient.installer.journal.pending?.hash'),'unmined operation');
 const unmined=await evaluate('window.installationClient.installer.journal.pending.hash');
 assert.equal(await rpc('eth_getTransactionReceipt',[unmined]),null);
 await reload();await connected();assert.equal(await evaluate('!!window.installationClient.installer.journal.pending'),true);
 await rpc('evm_setAutomine',[true]);await rpc('evm_mine');
 report.checks.push({label:'Reload preserves actual unmined transaction; resume reconciles after mining',pass:true,transaction:unmined});
 await click('install');
 let last=-1;
 await until(async()=>{
  const state=await evaluate('({proof:window.__installationProof,status:document.querySelector("#install-status").textContent})');
  if(state.proof.errors.length)throw Error(state.proof.errors.join('\n'));
  const n=state.proof.events.at(-1)?.completed??0;if(n>last+199){console.log(state.status);last=n;}
  return state.proof.installed;
 },'complete browser install',1800000);
 const installed=await evaluate('window.installationClient.installer.journal'),address=installed.game.address;
 assert.equal(installed.game.chunks.length,1755);assert.equal(Object.keys(installed.resources).length<=1755,true);
 assert.equal(installed.receipts.filter(r=>r.kind==='game').length,1);assert.equal(installed.receipts.filter(r=>r.kind==='initialize').length,1);
 await writeFile(prefix+'.installation.json',JSON.stringify(installed,null,2)+'\n');
 report.installation={address,resourceChunks:1755,uniqueResourceCreates:installed.receipts.filter(r=>r.kind==='chunk').length,operations:installed.receipts.length,receiptManifest:prefix+'.installation.json',receiptManifestSha256:sha(JSON.stringify(installed,null,2)+'\n'),resourceIdentity:installed.game.identity,totalGas:installed.receipts.reduce((n,r)=>n+BigInt(r.gasUsed),0n).toString()};
 report.checks.push({label:'Browser-only fresh Freedoom resource/game deployment and initialization',pass:true});
 await click('play');await until(async()=>{const p=await evaluate('window.__transportProof');if(p?.errors.length)throw Error(p.errors.join('\n'));return p?.ready;},'EVM main menu');
 await settle();const menu=await canvas('Installed EVM main menu');assert.equal(menu.menu.active,1);assert.equal(menu.menu.screen,0);assert.equal(await evaluate('document.querySelector("#launcher").hidden'),true);
 await evaluate('window.fixtureClient.startGame();true');await until(()=>evaluate('!!window.__tick&&!window.fixtureClient.loop.starting'),'controlled actual input loop');
 assert.equal((await keys(['Enter'],'New Game episode selection')).menu.screen,1);assert.equal((await keys(['Enter'],'Original skill screen')).menu.screen,2);const started=await keys(['Enter'],'New Game actual E1M1 gameplay');assert.equal(started.state.map,1);assert.equal(started.state.state,0);assert.equal(await evaluate('window.fixtureClient.transactions.started'),true);
 const methods=JSON.parse(await readFile('web/install-assets/Doom.json')).methods;
 const playerView=()=>rpc('eth_call',[{to:address,data:'0x'+methods['playerView()']},'latest']);
 const before=await playerView();await evaluate("window.dispatchEvent(new KeyboardEvent('keydown',{code:'ArrowUp',bubbles:true,cancelable:true}));window.__tick()");await canvas('Held movement gameplay');const after=await playerView();assert.notEqual(before,after);
 await keys(['ArrowUp'],'Release movement');report.checks.push({label:'Original keyboard New Game and actual moving gameplay',pass:true,beforePlayerView:before,afterPlayerView:after});
 const nonceBefore=await rpc('eth_getTransactionCount',[from,'latest']);await reload();await connected();assert.equal(await evaluate('window.__installationProof.installed'),true);
 assert.equal(await evaluate('window.installationClient.installer.journal.game.address'),address);assert.equal(await rpc('eth_getTransactionCount',[from,'latest']),nonceBefore);
 report.checks.push({label:'Reload discovers installation without transactions or deployment',pass:true,address,nonce:nonceBefore});
 // Lose just this release's journal. Discover ordinary CREATEs on-chain instead
 // of assuming missing IndexedDB means resources must be deployed again.
 await evaluate('window.installationClient.installer.storage.write(window.installationClient.installer.key,null)');
 await reload();await connected();
 assert.equal(await evaluate('window.__installationProof.installed'),true);
 assert.equal(await evaluate('window.installationClient.installer.journal.game.address'),address);
 assert.equal(await rpc('eth_getTransactionCount',[from,'latest']),nonceBefore);
 report.checks.push({label:'Missing local journal discovers and verifies on-chain installation without transactions',pass:true,address});
 console.log('PASS chain discovery without journal');
 // Commercial bytes are selected through Chrome's actual DOM File API only.
 for(const [id,path] of [['ultimate',opt('--ultimate-wad',process.env.HOME+'/Downloads/doom-steam/base/DOOM.WAD')],['doom2',opt('--doom2-wad',process.env.HOME+'/Downloads/doom-steam/base/doom2/DOOM2.WAD')]]){
  const bytes=await readFile(path),md5=createHash('md5').update(bytes).digest('hex');assert.equal(md5,id==='ultimate'?'c4fe9fd920207691a9f493668e0a2083':'25e1459ca71d321525f84628f45ca8cd');
  await evaluate(`document.querySelector('#game-profile').value=${JSON.stringify(id)};document.querySelector('#game-profile').dispatchEvent(new Event('change'));true`);
  const root=await command('DOM.getDocument'),input=await command('DOM.querySelector',{nodeId:root.root.nodeId,selector:'#iwad'});
  await command('DOM.setFileInputFiles',{nodeId:input.nodeId,files:[path]});
  await until(async()=>{const p=await evaluate('window.__installationProof');if(p.errors.length)throw Error(p.errors.join('\n'));return p.localIWAD?.profile===id&&p.localIWAD.authenticated;},'local commercial '+id);
  assert.equal(await evaluate('document.querySelector("#install").disabled&&document.querySelector("#play").disabled'),true);
  assert.equal(await rpc('eth_getTransactionCount',[from,'latest']),nonceBefore);
  report.checks.push({label:'Local File API authentication '+id,pass:true,md5,sha256:sha(bytes),bytes:bytes.length,productionUnavailable:true,noTransactions:true});
 }
 // Integration-only additional boundary: real Play after browser reload.
 // All inherited assertions above/below remain unchanged.
 await reload();await connected();assert.equal(await rpc('eth_getTransactionCount',[from,'latest']),nonceBefore);
 const resumeView=await playerView(),resumeBlock=BigInt(await rpc('eth_blockNumber'));
 const resumeResources=await evaluate('JSON.stringify(window.installationClient.installer.journal.resources)');
 await click('play');await until(async()=>{const p=await evaluate('window.__transportProof');if(p?.errors.length)throw Error(p.errors.join('\n'));return p?.ready;},'reload Play');
 await settle();const reopened=await canvas('Reload Play preserves E1M1 and opens original menu');
 assert.equal(reopened.state.map,1);assert.equal(reopened.menu.active,1);
 assert.equal(await evaluate('window.fixtureClient.config.address'),address);
 assert.equal(await playerView(),resumeView);
 await evaluate('window.fixtureClient.startGame();true');await until(()=>evaluate('!!window.__tick&&!window.fixtureClient.loop.starting'),'resume input loop');
 assert.equal((await keys(['Escape'],'Escape resumes saved E1M1')).menu.active,0);
 const resumedBefore=await playerView();
 await evaluate("window.dispatchEvent(new KeyboardEvent('keydown',{code:'ArrowUp',bubbles:true,cancelable:true}));window.__tick()");
 await canvas('Player moves again after browser reload');const resumedAfter=await playerView();
 assert.notEqual(resumedBefore.slice(0,130),resumedAfter.slice(0,130));
 await keys(['ArrowUp'],'Release movement after reload');
 assert.equal(await evaluate('JSON.stringify(window.installationClient.installer.journal.resources)'),resumeResources);
 assert.equal(await evaluate('window.installationClient.installer.journal.game.address'),address);
 const resumedTxs=[];
 for(let n=resumeBlock+1n;n<=BigInt(await rpc('eth_blockNumber'));n++){
  const block=await rpc('eth_getBlockByNumber',['0x'+n.toString(16),true]);
  for(const tx of block.transactions){assert.equal(tx.to?.toLowerCase(),address.toLowerCase());resumedTxs.push({hash:tx.hash,to:tx.to});}
 }
 assert(resumedTxs.length>0);
 report.checks.push({label:'Reload Play/Escape resumes saved player and real movement without any CREATE or resource redeployment',pass:true,address,playerViewBeforeReopen:resumeView,resumedBefore,resumedAfter,allTransactionsTargetSameGame:resumedTxs,resourceJournalUnchanged:true});
 // Same chainId, same endpoint, actual reset: previous installation must vanish.
 const chainId=await rpc('eth_chainId');await rpc('anvil_reset');assert.equal(await rpc('eth_chainId'),chainId);
 await reload();await connected();assert.equal(await evaluate('window.__installationProof.installed'),false);assert.equal(await evaluate('window.installationClient.installer.journal.game'),null);
 assert.equal(await rpc('eth_getCode',[address,'latest']),'0x');
 report.checks.push({label:'Same-chainId Anvil reset rejects stale installation',pass:true,chainId});
 // Fresh restart is a new runtime at same endpoint. Preserve browser IndexedDB.
 await stop(node);await free(port);node=spawn(resolve('.toolchain/bin/anvil'),nodeArgs,{stdio:['ignore',log.fd,log.fd]});await until(async()=>{try{return await rpc('web3_clientVersion');}catch{return false;}},'owned Anvil restart',10000);
 await reload();await connected();assert.equal(await evaluate('window.__installationProof.installed'),false);
 report.checks.push({label:'Anvil restart preserves no false installation',pass:true});
 report.browser=await command('Browser.getVersion');report.pass=true;
 }
}catch(error){report.error=error.stack;process.exitCode=1;console.error(error.stack);try{report.lastBrowserState=await evaluate('({installation:window.__installationProof,status:document.querySelector("#install-status")?.textContent,transport:window.__transportProof})');}catch{}}
finally{
 ws?.close();await stop(browser);await stop(node);if(server)await new Promise(done=>server.close(done));await log?.close();if(profile)await rm(profile,{recursive:true,force:true});
 report.endedUtc=new Date().toISOString();report.stoppedOwnedRuntimes=true;await writeFile(prefix+'.json',JSON.stringify(report,null,2)+'\n');console.log('Report',prefix+'.json');
}
