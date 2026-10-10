// SPDX-License-Identifier: GPL-2.0-only
// Actual production CREATE and original keyboard/trigger execution, no state injection.
import {readFile,writeFile,mkdir,open} from 'node:fs/promises';
import {spawn,execFileSync} from 'node:child_process';
import {connect} from 'node:net';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {decodeFrame,FRAME_TOPIC} from '../../../web/protocol.mjs';
import {decodeFramePalette,FRAME_PALETTE_TOPIC} from '../../../web/ui-palette.mjs';
import {loadGasBudget} from '../../execution-budget.mjs';
import {serve} from '../../transport/serve.mjs';
const args=process.argv.slice(2),opt=(n,d)=>args.includes(n)?args[args.indexOf(n)+1]:d;
const port=Number(opt('--port','18761')),prefix=opt('--output-prefix','artifacts/phase4/episode-completion/evm');
assert(Number.isInteger(port)&&port>1024&&port<65536&&![18880,8088].includes(port));
const budget=loadGasBudget(),gas=budget.gasHex,url=`http://127.0.0.1:${port}`;
const sha=b=>createHash('sha256').update(b).digest('hex'),word=n=>BigInt.asUintN(256,BigInt(n)).toString(16).padStart(64,'0');
const tail=b=>word(b.length)+b.toString('hex').padEnd(Math.ceil(b.length/32)*64,'0');
const json=async p=>JSON.parse(await readFile(p));
const artifact=await json('out/Doom.sol/Doom.json'),store=await json('out/ResourceStore.sol/ResourceStore.json');
const method=n=>{assert(artifact.methodIdentifiers[n],n);return '0x'+artifact.methodIdentifiers[n];};
const metadata=typeof artifact.metadata==='string'?JSON.parse(artifact.metadata):artifact.metadata;
const blob=await readFile('artifacts/local/wad/resources.bin'),bundle=await json('artifacts/local/wad/bundle.json');
assert.equal(sha(blob),bundle.blobSha256);
const directory=await readFile('test/fixtures/phase2_data/directory.bin');
const report={kind:'episode-one-functional-production-evm',pass:false,startedUtc:new Date().toISOString(),executionBudget:budget,
    compiler:{version:metadata.compiler.version,settings:metadata.settings},resourceIdentity:bundle.resourceIdentity,sourceHashes:{},frames:[],operations:[],rollbacks:[],routes:[],inputs:[]};
await mkdir(resolve(prefix,'..'),{recursive:true});
let child,log,httpServer,priorConfig,priorPalette,id=0,driver,other;
async function rpc(method,params=[]){const r=await fetch(url,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(300000)});assert(r.ok);const d=await r.json();if(d.error)throw Object.assign(Error(method+JSON.stringify(d.error)),{rpcError:d.error});return d.result;}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function until(f,label){const end=Date.now()+300000;while(Date.now()<end){const r=await f();if(r)return r;await sleep(20);}throw Error('Timeout '+label);}
async function tx(data,to,status='0x1',from=driver){const start=performance.now(),hash=await rpc('eth_sendTransaction',[{from,data,gas,...(to?{to}:{})}]);const r=await until(()=>rpc('eth_getTransactionReceipt',[hash]),'receipt');if(r.status!==status){try{await rpc('eth_call',[{from,to,data,gas},'latest']);}catch(e){console.error('FAILED TRANSACTION REVERT',JSON.stringify(e.rpcError));report.failedTransaction={hash,data,error:e.rpcError};}}assert.equal(r.status,status,`${hash} gas ${BigInt(r.gasUsed)}`);return {receipt:r,gas:Number(BigInt(r.gasUsed)),ms:performance.now()-start};}
const call=(to,data)=>rpc('eth_call',[{from:driver,to,data,gas},'latest']);
const words=hex=>hex.slice(2).match(/.{64}/g).map(n=>Number(BigInt.asIntN(256,BigInt('0x'+n))));
const status=async address=>words(await call(address,method('episodeStatus()')));
const view=async address=>words(await call(address,method('playerView()')));
const gs=async address=>words(await call(address,method('gameStatus()')));
async function frame(r,label,expected){const f=decodeFrame(r.receipt.logs.find(l=>l.topics[0]===FRAME_TOPIC)),p=decodeFramePalette(r.receipt.logs.find(l=>l.topics[0]===FRAME_PALETTE_TOPIC),f);
    assert.equal(f.pixels.length,64000);if(expected)assert.equal(Buffer.compare(Buffer.from(f.pixels),expected),0,label+' native pixels');
    const path=`${prefix}-${report.frames.length}.pixels`;await writeFile(path,f.pixels);
    report.frames.push({label,inputSeq:f.inputSeq,frameId:String(f.frameId),transaction:r.receipt.transactionHash,pixelSha256:sha(f.pixels),palette:p.palette,paletteSha256:sha(p.rgb),gas:r.gas,ms:r.ms,nativeExact:!!expected,pixelsPath:path});await writeFile(prefix+'.json',JSON.stringify(report,null,2)+'\n');return f;}
async function rollback(address,data,error,from=driver){const before=await rpc('eth_getProof',[address,[],'latest']);let failed=false;
    try{await rpc('eth_call',[{from,to:address,data,gas},'latest']);}catch(e){const actual=typeof e.rpcError?.data==='string'?e.rpcError.data:e.rpcError?.data?.data;assert.equal(actual?.slice(0,10),execFileSync(resolve('.toolchain/bin/cast'),['sig',error],{encoding:'utf8'}).trim());failed=true;}
    assert(failed,error);const r=await tx(data,address,'0x0',from),after=await rpc('eth_getProof',[address,[],'latest']);assert.equal(before.storageHash,after.storageHash);assert.equal(r.receipt.logs.length,0);report.rollbacks.push({error,transaction:r.receipt.transactionHash,gas:r.gas,allStorageRollback:true});}
async function init(address,map=1,skill=2){const r=await tx(method('initializeEpisode(int32,int32,bool)')+word(map)+word(skill)+word(0),address);assert.equal(r.receipt.logs.length,0);const s=await status(address);assert.deepEqual(s.slice(0,5),[map,skill,0,0,0]);report.operations.push({operation:'initializeEpisode',map,skill,transaction:r.receipt.transactionHash,gas:r.gas,ms:r.ms});}
const counters=new Map();
async function events(address,packet=[],draw=false,label='keyboard'){const sequence=(counters.get(address)??Number(BigInt(await call(address,method('inputSeq()')))))+1;
    const b=Buffer.from(packet.flat()),r=await tx(method(draw?'stepEventsAndRender(bytes,uint32)':'stepEvents(bytes,uint32)')+word(64)+word(sequence)+tail(b),address);
    counters.set(address,sequence);report.inputs.push({address,sequence,events:packet,draw,transaction:r.receipt.transactionHash,gas:r.gas,ms:r.ms});if(draw)await frame(r,label);else assert.equal(r.receipt.logs.length,0);return r;}
async function control(address,name,params=[]){const sequence=(counters.get(address)??Number(BigInt(await call(address,method('inputSeq()')))))+1;
    const r=await tx(method(name)+params.map(word).join('')+word(sequence),address);counters.set(address,sequence);report.operations.push({operation:name,params,sequence,transaction:r.receipt.transactionHash,gas:r.gas,ms:r.ms});await frame(r,name);return r;}
const codeEvents=text=>[...text].flatMap(c=>[[0,c.charCodeAt(0)],[1,c.charCodeAt(0)]]);
const configuration=address=>({rpcUrl:url,wsUrl:url.replace('http','ws'),address,driver,rendererKind:'doom-world-view',gameplay:true,productionUI:true,rawKeyboard:true,episodeMode:true,uiFullscreen:false,startMap:1,skill:2,deploymentBlock:'0x0',paletteUrl:'/palette.local.json',paletteKind:'wad',resourceIdentity:bundle.resourceIdentity,gasLimit:budget.gasLimit});
async function browserCheck(address,label,displayOnly=false) {
    const configPath=prefix+'.config.json';await writeFile(configPath,JSON.stringify(configuration(address),null,2)+'\n');
    const browser=spawn(process.execPath,['tools/transport/episode-browser-check.mjs','--config',configPath,'--output-prefix',prefix+'-browser-'+label,...(displayOnly?['--display-only']:[])],{stdio:'inherit'});
    const code=await new Promise((done,fail)=>{browser.once('error',fail);browser.once('exit',done);});assert.equal(code,0,'Chrome '+label);
}
// Build bounded original keyboard commands using live EVM coordinates. Cheating
// is explicit in route records; it only bypasses walls, never the authentic exit trigger.
let held=new Set();
async function keys(address,next,draw=false,label){const wanted=new Set(next),packet=[];for(const k of held)if(!wanted.has(k))packet.push([1,k]);for(const k of wanted)if(!held.has(k))packet.push([0,k]);held=wanted;return events(address,packet,draw,label);}
async function moveTo(address,x,y,{radius=12,max=350}={}) {
  for(let i=0;i<max;++i) {
    const p=await view(address),px=p[0]/65536,py=p[1]/65536;
    const distance=Math.hypot(x-px,y-py),speed=Math.hypot(p[4],p[5])/65536;
    // Original friction's stopping displacement guides only the test inputs.
    // Every movement result and exit decision still comes from the production EVM.
    const dx=x-px-p[4]/65536*(29/3),dy=y-py-p[5]/65536*(29/3);
    if(distance<radius&&speed<0.1){await keys(address,[]);return;}
    if(Math.hypot(dx,dy)<radius){await keys(address,[]);continue;}
    let desired=(Math.atan2(dy,dx)/(2*Math.PI)*4294967296+4294967296)%4294967296;
    const delta=((desired-(p[3]>>>0)+2147483648+4294967296)%4294967296)-2147483648;
    if(Math.abs(delta)>24000000) await keys(address,[delta>0?172:174]);
    else await keys(address,distance>160?[119,182]:distance<60&&held.has(119)?[]:[119]);
    if(i%50===0)console.log('Moving toward exit',x,y,'from',px,py);
    if((await status(address))[2]!==0)return;
  }
  throw Error('Input route did not reach '+x+','+y);
}
async function face(address,degrees) {
  for(let i=0;i<240;++i) {
    const p=await view(address),delta=((degrees/360*4294967296-(p[3]>>>0)+2147483648+4294967296)%4294967296)-2147483648;
    if(Math.abs(delta)<24000000){await keys(address,[]);return;}
    await keys(address,[delta>0?172:174]);
  }
  throw Error('turn route');
}
async function continueWI(address,next){assert.equal((await status(address))[2],1);held=new Set();
    for(const b of [[157],[],[157],[],[32]])await keys(address,b,true,'WI original fire/use');
    await keys(address,[]);
    for(let i=0;i<155&&(await status(address))[2]===1;++i)await events(address,[],i===0,'WI next-location');
    const s=await status(address);assert.equal(s[0],next);assert.equal(s[2],0);await events(address,[],true,'Next E1M'+next);return s;}
try{
    for(const path of ['tools/reference/episode_completion/evm.mjs','web/app.mjs','web/input-loop.mjs','tools/transport/episode-browser-check.mjs','foundry.toml','execution-budget.json'])report.sourceHashes[path]=sha(await readFile(path));
    for(const [path,identity]of Object.entries(metadata.sources)){const b=await readFile(path);assert.equal(execFileSync(resolve('.toolchain/bin/cast'),['keccak'],{input:'0x'+b.toString('hex'),encoding:'utf8',maxBuffer:1048576}).trim(),identity.keccak256,'source drift '+path);report.sourceHashes[path]=sha(b);}
    await new Promise((done,fail)=>{const s=connect({host:'127.0.0.1',port});s.once('connect',()=>{s.destroy();fail(Error('Occupied port'));});s.once('error',e=>e.code==='ECONNREFUSED'?done():fail(e));});
    log=await open(prefix+'.anvil.log','w');const nodeArgs=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--disable-block-gas-limit','--memory-limit','1073741824','--prune-history','64','--silent'];
    child=spawn(resolve('.toolchain/bin/anvil'),nodeArgs,{stdio:['ignore','ignore',log.fd]});let err;child.on('error',e=>err=e);
    await until(async()=>{if(err)throw err;if(child.exitCode!==null)throw Error('Owned Anvil exited');try{return await rpc('web3_clientVersion');}catch{return false;}},'Anvil');
    await rpc('anvil_setBlockGasLimit',[gas]);await rpc('evm_mine');[driver,other]=await rpc('eth_accounts');report.runtime={port,args:nodeArgs,client:await rpc('web3_clientVersion')};
    const addresses=[],receipts=[];
    for(let p=0;p<blob.length;p+=16384){const b=blob.subarray(p,p+16384),r=await tx(store.bytecode.object+word(32)+tail(b));assert.equal(await rpc('eth_getCode',[r.receipt.contractAddress,'latest']),'0x00'+b.toString('hex'));addresses.push(r.receipt.contractAddress);receipts.push({transaction:r.receipt.transactionHash,gas:r.gas});if(addresses.length%300===0)console.log('Verified CREATE',addresses.length);}
    report.resources={chunks:addresses.length,allRuntimeBytesExact:true,cumulativeGas:receipts.reduce((s,r)=>s+r.gas,0),receiptHash:sha(JSON.stringify(receipts))};
    const array=word(addresses.length)+addresses.map(a=>a.slice(2).padStart(64,'0')).join(''),constructor=word(64)+word(64+array.length/2)+array+tail(directory);
    async function deploy(){const r=await tx(artifact.bytecode.object+constructor),a=r.receipt.contractAddress,runtime=Buffer.from(artifact.deployedBytecode.object.slice(2),'hex');for(const spans of Object.values(artifact.deployedBytecode.immutableReferences))for(const s of spans)Buffer.from(word(driver),'hex').copy(runtime,s.start);assert.equal(await rpc('eth_getCode',[a,'latest']),'0x'+runtime.toString('hex'));report.operations.push({operation:'CREATE Doom',address:a,transaction:r.receipt.transactionHash,gas:r.gas,runtimeBytes:runtime.length,runtimeSha256:sha(runtime)});return a;}
    const address=await deploy();
    if(args.includes('--play')) {
        report.kind='episode-one-browser-launch';
        priorConfig=await readFile('web/config.local.json').catch(()=>null);priorPalette=await readFile('web/palette.local.json').catch(()=>null);
        await writeFile('web/config.local.json',JSON.stringify(configuration(address),null,2)+'\n');
        await writeFile('web/palette.local.json',await readFile('artifacts/local/wad/palette.json'));
        const httpPort=Number(opt('--http-port','18762'));assert(![18880,8088,port].includes(httpPort));httpServer=await serve(httpPort);
        console.log(`Episode One ready: http://127.0.0.1:${httpPort}. Select a level and click New Game. Ctrl-C stops only this launcher’s runtimes.`);
        report.pass=true;await writeFile(prefix+'.json',JSON.stringify(report,null,2)+'\n');
        await new Promise(done=>{process.once('SIGINT',done);process.once('SIGTERM',done);});
    } else {
    await rollback(address,method('initializeEpisode(int32,int32,bool)')+word(1)+word(2)+word(0),'NotDriver()',other);
    await rollback(address,method('initializeEpisode(int32,int32,bool)')+word(10)+word(2)+word(0),'UnsupportedSelection(int32,int32,int32)');await init(address,args.includes('--finale-only')?8:1);
    await rollback(address,method('restartEpisode(uint32)')+word(5),'BadSequence()');
    if(!args.includes('--finale-only')) {
    // Preserve exact original E1M1 gameplay/UI/pickup trace through the new G_Ticker.
    const native=await json('artifacts/local/ui-native/manifest.json');for(const [name,digest]of Object.entries(native.files))assert.equal(sha(await readFile('artifacts/local/ui-native/'+name)),digest);
    const packets=await json('artifacts/local/ui-native/packets.json'),players=await json('artifacts/local/ui-native/players.json');held=new Set();
    const keyList=[119,115,97,100,172,174,32,157,182,184];let fullscreen=false;
    for(const p of args.includes('--quick')?[]:packets){if(fullscreen!==p.fullscreen){await tx(method('setUIFullscreen(bool)')+word(p.fullscreen?1:0),address);fullscreen=p.fullscreen;}
        const before=report.frames.length,r=await keys(address,keyList.filter((_,bit)=>p.mask&(1<<bit)),p.render,'E1M1 native tic'+p.tic);
        const actual=[...await gs(address),...await view(address)],names=['gametic','leveltime','playerHealth','armorpoints','readyweapon','x','y','z','angle','momx','momy','momz','viewz','prndindex'];
        actual.forEach((v,i)=>assert.equal(names[i]==='angle'?v>>>0:v,names[i]==='angle'?players[p.tic][names[i]]>>>0:players[p.tic][names[i]],p.tic+' '+names[i]));
        if(p.render){const expected=await readFile(`artifacts/local/ui-native/frame-${String(p.tic).padStart(6,'0')}.bin`);assert.equal(report.frames.length,before+1);assert.equal(report.frames.at(-1).pixelSha256,sha(expected),'native full UI frame '+p.tic);report.frames.at(-1).nativeExact=true;}
        if(p.tic%50===0)console.log('PASS native integrated gameplay tic',p.tic);
    }
    report.nativeGameplay={tics:args.includes('--quick')?0:packets.length,fieldsPerTic:14,frames:args.includes('--quick')?0:packets.filter(p=>p.render).length,movement:!args.includes('--quick'),shooting:!args.includes('--quick'),actualPickupTic:args.includes('--quick')?null:64,manifestSha256:sha(await readFile('artifacts/local/ui-native/manifest.json'))};
    await keys(address,[]);await events(address,codeEvents('iddqd'),true,'God cheat');
    await events(address,[[0,9]],true,'Automap');assert.equal(words(await call(address,method('automapStatus()')))[0],1);
    await events(address,codeEvents('iddt'),true,'IDDT automap');assert.equal(words(await call(address,method('automapStatus()')))[4],1);
    await events(address,[[1,9],[0,9],[1,9]],true,'Automap close');
    for(let map=1;map<=9;++map){await control(address,'newEpisodeGame(int32,int32,uint32)',[map,2]);held=new Set();const s=await status(address);assert.deepEqual(s.slice(0,5),[map,2,0,0,0]);console.log('PASS production map',map);await writeFile(prefix+'.json',JSON.stringify(report,null,2)+'\n');}
    await events(address,codeEvents('idclev12'),true,'IDCLEV E1M2');assert.deepEqual((await status(address)).slice(0,4),[2,2,0,0]);assert.equal(words(await call(address,method('cheatStatus()'))).at(-1),0);
    const seq=(counters.get(address)??0)+1;
    await rollback(address,method('stepEvents(bytes,uint32)')+word(64)+word(seq)+tail(Buffer.from(codeEvents('idclev21').flat())),'UnsupportedGameflowProfile()');
    await rollback(address,method('stepEvents(bytes,uint32)')+word(64)+word(seq)+tail(Buffer.from([2,119])),'InvalidKeyboardEvents()');
    await rollback(address,method('setEpisodePaused(bool,uint32)')+word(1)+word(seq+9),'BadSequence()');
    await rollback(address,method('newEpisodeGame(int32,int32,uint32)')+word(3)+word(2)+word(seq),'NotDriver()',other);
    await control(address,'setEpisodePaused(bool,uint32)',[1]);let time=(await gs(address))[1];await events(address,[],true,'Paused');assert.equal((await gs(address))[1],time);
    await control(address,'setEpisodePaused(bool,uint32)',[0]);assert.equal((await gs(address))[1],time+1);
    await control(address,'restartEpisode(uint32)');assert.equal((await gs(address))[1],1);assert.equal((await gs(address))[2],100);
    // Cheat-assisted short authentic switch exit; no teleport/state/storage writes.
    await control(address,'newEpisodeGame(int32,int32,uint32)',[1,2]);held=new Set();await events(address,codeEvents('iddqd') .concat(codeEvents('idclip')));
    await moveTo(address,-365,1296);await face(address,180);await keys(address,[32]);await keys(address,[],true,'Genuine E1M1 switch exit');assert.equal((await status(address))[2],1);
    if(args.includes('--browser'))await browserCheck(address,'intermission',true);
    const inventory=await call(address,method('playerInventory()'));await continueWI(address,2);assert.equal(await call(address,method('playerInventory()')),inventory);report.routes.push({from:1,next:2,trigger:'original P_UseLines -> special11 -> G_ExitLevel',cheatAssistedTraversal:true,inventoryRetained:true});
    // E1M3 authentic secret switch, then E1M9 authentic normal return switch.
    await control(address,'newEpisodeGame(int32,int32,uint32)',[3,2]);held=new Set();await events(address,codeEvents('iddqd').concat(codeEvents('idclip')));
    await moveTo(address,248,1483);await face(address,0);await keys(address,[32]);await keys(address,[],true,'Genuine E1M3 secret exit');assert.equal((await status(address))[2],1);await continueWI(address,9);console.log('PASS genuine secret route E1M3 -> E1M9');report.routes.push({from:3,next:9,trigger:'original special51 secret exit',cheatAssistedTraversal:true});
    held=new Set();await events(address,codeEvents('idclip')); // noclip flag survives normal completion: toggle off then on below only if needed
    await events(address,codeEvents('idclip'));await moveTo(address,1312,596);await face(address,270);await keys(address,[32]);await keys(address,[],true,'Genuine E1M9 return exit');assert.equal((await status(address))[2],1);await continueWI(address,4);console.log('PASS genuine secret return E1M9 -> E1M4');report.routes.push({from:9,next:4,trigger:'original special11 return exit',cheatAssistedTraversal:true});
    }
    await control(address,'newEpisodeGame(int32,int32,uint32)',[8,2]);held=new Set();await events(address,codeEvents('iddqd').concat(codeEvents('idclip')));
    await moveTo(address,992,352);await face(address,90);await events(address,codeEvents('idclip')); // crossing triggers require original collision path, not noclip
    await keys(address,[119]);for(let i=0;i<20&&(await status(address))[2]===0;++i)await events(address);
    await keys(address,[],true,'E1M8 original finale');assert.equal((await status(address))[2],2);assert.equal((await status(address))[0],8);report.routes.push({from:8,next:null,trigger:'original P_TryMove cross special52 -> G_ExitLevel -> F_StartFinale',cheatAssistedTraversal:true});
    const finale=await json('test/fixtures/phase4_finale/manifest.json');assert(finale.exactNativeAgreement);
    const retailText=await readFile('test/fixtures/phase4_finale/19.bin');assert((await status(address))[10]<=10);assert.equal(report.frames.at(-1).pixelSha256,sha(retailText.subarray(28)),'native initial finale tiled frame');report.frames.at(-1).nativeExact=true; // count1, exact initial text frame
    // Later live count frames use the same native port; focused Forge covers all timing boundaries.
    const legacy=await deploy();const static_=await tx(method('renderFrame()'),legacy);const sf=decodeFrame(static_.receipt.logs.find(l=>l.topics[0]===FRAME_TOPIC));assert.equal(sha(sf.pixels),sha(await readFile('test/fixtures/renderer/full-angle0/pixels.bin')));
    await tx(method('initializeGameInput(bool)')+word(0),legacy);await events(legacy,[],true,'Legacy raw mode');report.legacy={staticNativeExact:true,rawInput:true};
    const worldLegacy=await deploy();await tx(method('initializeGame()'),worldLegacy);
    const wr=await tx(method('stepAndRender(uint32,uint32)')+word(0)+word(1),worldLegacy);
    const wf=decodeFrame(wr.receipt.logs.find(l=>l.topics[0]===FRAME_TOPIC));
    assert.equal(sha(wf.pixels),sha(await readFile('test/fixtures/gameplay/idle/frame-000001.bin')));report.legacy.worldOnlyNativeExact=true;
    const uiLegacy=await deploy();await tx(method('initializeGameUI(bool)')+word(0),uiLegacy);const lr=await tx(method('stepAndRender(uint32,uint32)')+word(257)+word(1),uiLegacy);await frame(lr,'Legacy UI',await readFile('artifacts/local/ui-native/frame-000001.bin'));
    await writeFile(prefix+'.config.json',JSON.stringify(configuration(address),null,2)+'\n');
    if(args.includes('--browser'))await browserCheck(address,'finale-controls');
    report.pass=true;
    }
}catch(e){report.error=e.stack;process.exitCode=1;console.error(e.stack);}
finally{if(httpServer){await new Promise(done=>httpServer.close(done));if(priorConfig)await writeFile('web/config.local.json',priorConfig);else await (await import('node:fs/promises')).rm('web/config.local.json',{force:true});if(priorPalette)await writeFile('web/palette.local.json',priorPalette);else await (await import('node:fs/promises')).rm('web/palette.local.json',{force:true});}
if(child?.pid&&child.exitCode===null&&child.signalCode===null)await new Promise(done=>{child.once('exit',done);child.kill('SIGTERM');setTimeout(()=>{if(child.exitCode===null)child.kill('SIGKILL');},1500).unref();});await log?.close();report.runtimeTermination={exitCode:child?.exitCode,signalCode:child?.signalCode};report.endedUtc=new Date().toISOString();report.stoppedOwnedRuntime=true;await writeFile(prefix+'.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({pass:report.pass,frames:report.frames.length,routes:report.routes.length,evidence:prefix+'.json'}));}
