// SPDX-License-Identifier: GPL-2.0-only
// Sequential production browser / mined direct-RPC benchmark. No dependencies.
import {spawn,execFileSync,execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {readFile,writeFile,mkdir,mkdtemp,open,rm,unlink,readdir} from 'node:fs/promises';
import {resolve,join,basename} from 'node:path';
import {tmpdir} from 'node:os';
import {connect as socketConnect} from 'node:net';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import pins from '../../../web/doom2-pins.mjs';
import {DOOM2_PROFILE} from '../../../web/doom2-profile.mjs';
import {decodeFrame,expandPalette,FRAME_TOPIC,receipt as productionReceipt} from '../../../web/protocol.mjs';
import {decodeFramePalette,FRAME_PALETTE_TOPIC} from '../../../web/ui-palette.mjs';
import {eventStepData,nativeKey} from '../../../web/input.mjs';
import {serve} from '../../../tools/reference/doom2/serve.mjs';
import {installBrowserProbe} from '../doom2-map01-performance/browser-instrumentation.mjs';
const args=process.argv.slice(2),opt=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
if(args.includes('--abort-owned-profile')){
  const {abortOwned}=await import('../doom2-map01-performance/control.mjs');await abortOwned({profile:opt('--abort-owned-profile'),parentPid:Number(opt('--parent-pid')),anvilPid:Number(opt('--anvil-pid')),chromePid:Number(opt('--chrome-pid')),output:opt('--output')});process.exit(0);
}
const mode=opt('--mode','direct'),count=Number(opt('--frames','50')),reps=Number(opt('--repetitions','3')),warmup=Number(opt('--warmup','3'));
assert.equal(mode,'direct','Follow-up harness supports direct comparison only');assert(Number.isInteger(count)&&count>=50);assert(Number.isInteger(reps)&&reps>0);assert(warmup>=1);
assert(!args.includes('--headless-install')||mode==='direct','Headless installation is allowed only for direct mode');
const port=Number(opt('--port','19880')),httpPort=Number(opt('--http-port','18088'));
assert(![18880,8088].includes(port)&&![18880,8088,port].includes(httpPort));
const output=resolve(opt('--output','artifacts/local/doom2-map01-performance/run-'+Date.now()));
const local=resolve('artifacts/local/doom2-map01-performance');
const toolchain=resolve(opt('--toolchain-dir','.toolchain/bin'));
const wadPath=resolve(opt('--doom2-wad',process.env.HOME+'/Downloads/doom-steam/base/doom2/DOOM2.WAD'));
const chrome=opt('--chrome','/Applications/Google Chrome.app/Contents/MacOS/Google Chrome');
const compiled=opt('--compiler-artifact','');
const websiteRoot=resolve(opt('--web-root','web'));
const rpcUrl=`http://127.0.0.1:${port}`,origin=`http://127.0.0.1:${httpPort}`;
if(args.includes('--check-clean')){await free(port);await free(httpPort);console.log('PASS benchmark ports have no listeners:',port,httpPort);process.exit(0);}
const sha=b=>createHash('sha256').update(b).digest('hex'),now=()=>performance.now(),execAsync=promisify(execFile);
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const runCommand=(path,args=[])=>execFileSync(path,args,{encoding:'utf8',maxBuffer:10*1024*1024}).trim();
const report={schemaVersion:1,pass:false,startedUtc:new Date().toISOString(),sourceCommit:runCommand('git',['rev-parse','HEAD']),branch:runCommand('git',['branch','--show-current']),parameters:{mode,count,reps,warmup,port,httpPort},runs:[]};
report.harness={path:'artifacts/benchmarks/doom2-map01-melt-followup/run.mjs',sha256:sha(await readFile('artifacts/benchmarks/doom2-map01-melt-followup/run.mjs')),derivedFrom:'c4905b3e34d661be661e9adcb1dcd45611a8bd4d/artifacts/benchmarks/doom2-map01-performance/run.mjs'};
report.parameters.requireAC=args.includes('--require-ac');
report.parameters.meltEnabledInDirect=args.includes('--enable-wipe-in-direct');
assert(!report.parameters.meltEnabledInDirect || mode==='direct');
report.parameters.receiptPolicy=args.includes('--tight-poll')?'continuous unsuccessful receipt polling':'production receipt waiter: 20 ms after absent receipt';
report.parameters.browserNoticeGate=args.includes('--browser-notice-gate');
await mkdir(output,{recursive:true});assert.equal((await readdir(output)).length,0,'Refuse nonempty output directory; preserve earlier evidence and choose a fresh path');await mkdir(local,{recursive:true});console.log('Evidence directory:',output);
const save=async(name,value)=>writeFile(join(output,name),JSON.stringify(value,(key,v)=>key==='rgbHex'?undefined:v,2)+'\n');
const tap=code=>[['keydown',code],['keyup',code]];
const workload=[{phase:'setup',keys:tap('Enter')},{phase:'setup',keys:tap('Enter')},...Array.from({length:warmup},()=>({phase:'warmup',keys:[]}))];
// Repeated 50-tic route: forward, forward+right, right, forward+left,
// forward+fire, release. No cheats, menu freeze, or precomputed state.
let held=[];
for(let i=0;i<count;i++){
  const j=i%50;
  const target=i===count-1?[]:j<12?['ArrowUp']:j<24?['ArrowUp','ArrowRight']:j<32?['ArrowRight']:j<40?['ArrowUp','ArrowLeft']:['ArrowUp','ControlLeft'];
  const keys=[...held.filter(x=>!target.includes(x)).map(x=>['keyup',x]),...target.filter(x=>!held.includes(x)).map(x=>['keydown',x])];held=target;
  workload.push({phase:'measure',keys});
}
await save('workload.json',workload);
let node,browser,server,profile,ws,log,snapshot,config,methods,commandId=0,rpcId=0,cpuTimer,cpuBusy=false,currentCpu=null;
const pending=new Map();
const stopSignal=new AbortController();
for(const signal of ['SIGINT','SIGTERM'])process.once(signal,()=>{report.interrupted=signal;stopSignal.abort(Error('Benchmark interrupted: '+signal));for(const p of pending.values()){clearTimeout(p.timer);p.reject(Error('Benchmark interrupted: '+signal));}pending.clear();});
async function until(check,label,timeout=600000){const end=now()+timeout;while(now()<end){stopSignal.signal.throwIfAborted();const value=await check();if(value)return value;await sleep(100);}throw Error('Timeout '+label);}
async function free(p){await new Promise((done,fail)=>{const s=socketConnect({host:'127.0.0.1',port:p});s.once('connect',()=>{s.destroy();fail(Error('Occupied port '+p));});s.once('error',e=>e.code==='ECONNREFUSED'?done():fail(e));s.setTimeout(1000,()=>{s.destroy();fail(Error('Port check timeout'));});});}
async function stop(child){if(!child?.pid||child.exitCode!==null||child.signalCode!==null)return;await new Promise(done=>{child.once('exit',done);child.kill('SIGTERM');setTimeout(()=>{if(child.exitCode===null)child.kill('SIGKILL');},3000).unref();});}
async function rpc(method,params=[]){const r=await fetch(rpcUrl,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++rpcId,method,params}),signal:AbortSignal.any([AbortSignal.timeout(300000),stopSignal.signal])});const b=await r.json();if(b.error)throw Error(method+JSON.stringify(b.error));return b.result;}
const command=(method,params={})=>new Promise((resolve,reject)=>{const id=++commandId;pending.set(id,{resolve,reject,timer:setTimeout(()=>{pending.delete(id);reject(Error('CDP timeout '+method));},600000)});ws.send(JSON.stringify({id,method,params}));});
const evaluate=async expression=>{const r=await command('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(r.exceptionDetails.exception?.description??r.exceptionDetails.text);return r.result.value;};
const click=id=>evaluate(`document.querySelector(${JSON.stringify('#'+id)}).click();true`);
async function launcher(){await command('Page.navigate',{url:origin});await until(()=>evaluate('!!window.installationClient'),'launcher');
  await evaluate(`document.querySelector('#game-profile').value='doom2';document.querySelector('#game-profile').dispatchEvent(new Event('change'));document.querySelector('#rpc-endpoint').value=${JSON.stringify(rpcUrl)};true`);
  await click('connect');await until(async()=>{const p=await evaluate('window.__installationProof');if(p.errors.length)throw Error(p.errors.join('\n'));return p.connected&&!await evaluate('document.querySelector("#connect").disabled');},'connect');
}
function cpuSeconds(text){const fields=text.split(':').map(Number);return fields.reduce((a,n)=>a*60+n,0);}
async function cpuSample(){if(cpuBusy||!currentCpu)return;cpuBusy=true;const target=currentCpu;
    try{const {stdout}=await execAsync('/bin/ps',['-p',String(node.pid),'-o','time=,rss=,%cpu=']);const [time,rss,pct]=stdout.trim().split(/\s+/);target.push({monotonicMs:now(),cpuSeconds:cpuSeconds(time),rssKiB:Number(rss),psReportedCpuPercent:Number(pct)});}finally{cpuBusy=false;}}
async function beginCpu(){currentCpu=[];await cpuSample();cpuTimer=setInterval(()=>cpuSample().catch(e=>{report.cpuError=e.message;}),1000);return currentCpu;}
async function endCpu(){clearInterval(cpuTimer);while(cpuBusy)await sleep(10);await cpuSample();const data=currentCpu;currentCpu=null;return data;}
async function view(signature,block='latest'){return rpc('eth_call',[{to:config.address,data:'0x'+methods[signature]},block]);}
async function fingerprint(){const block=await rpc('eth_getBlockByNumber',['latest',false]);const game=await rpc('eth_getProof',[config.address,[],block.number]),beacon=await rpc('eth_getProof',['0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02',[],block.number]);return {stateRoot:block.stateRoot,blockHash:block.hash,block:block.number,timestamp:block.timestamp,gameStorageHash:game.storageHash,gameCodeHash:game.codeHash,beaconStorageHash:beacon.storageHash,driverBalance:await rpc('eth_getBalance',[config.driver,block.number]),inputSequence:await view('inputSeq()'),menu:await view('menuStatus()'),started:await view('gameStarted()'),memory:await view('selectedMemoryProfile()'),nonce:await rpc('eth_getTransactionCount',[config.driver,'latest'])};}
function busyProcesses(){return runCommand('/bin/ps',['-axo','pid,ppid,etime,%cpu,rss,command']).split('\n').slice(1).map(l=>l.trim().split(/\s+/)).filter(v=>Number(v[3])>=20&&![process.pid,node?.pid].includes(Number(v[0]))).map(v=>({pid:Number(v[0]),cpuPercent:Number(v[3]),rssKiB:Number(v[4]),executable:basename(v[5])}));}
async function quiet(){let previous='';await until(async()=>{const busy=busyProcesses().filter(p=>/^(solc|forge|clang|gcc|rustc|ffmpeg|anvil|node|bun|python|python3)$/.test(p.executable));if(busy.length){const label=JSON.stringify(busy);if(label!==previous){console.log('Waiting for competing CPU job:',label);previous=label;}await sleep(1000);return false;}return true;},'competing CPU jobs to finish',1800000);}
async function browserNotice(index){if(!report.parameters.browserNoticeGate)return;const path=join(local,`browser-${process.pid}-${index}.grant`);console.log(`READY browser ${index}: notify user, then create ${path}`);await until(async()=>{try{const value=await readFile(path,'utf8');return value.trim()==='notice-issued';}catch(e){if(e.code!=='ENOENT')throw e;return false;}},'browser-control notice',1800000);await unlink(path);}
async function restore(){await command('Page.navigate',{url:'about:blank'});await sleep(200);assert.equal(await rpc('evm_revert',[snapshot]),true);assert.deepEqual(await fingerprint(),report.baseline);snapshot=await rpc('evm_snapshot');}
async function inspectTransactions(records){
  const out=[];
  for(const r of records){const receipt=r.receipt??await rpc('eth_getTransactionReceipt',[r.hash]);assert.equal(receipt.status,'0x1');
    const frames=receipt.logs.filter(l=>l.address.toLowerCase()===config.address.toLowerCase()&&l.topics[0]===FRAME_TOPIC);assert.equal(frames.length,1);
    const f=decodeFrame(frames[0]),palette=decodeFramePalette(receipt.logs.find(l=>l.topics[0]===FRAME_PALETTE_TOPIC),f);
    const state=await view('gameStarted()',receipt.blockNumber)==='0x'+'1'.padStart(64,'0')?{gameStatus:await view('gameStatus()',receipt.blockNumber),playerView:await view('playerView()',receipt.blockNumber),episode:await view('episodeStatus()',receipt.blockNumber)}:null;
    const {receipt:discard,...rest}=r;out.push({...rest,gasUsed:Number(BigInt(receipt.gasUsed)),status:receipt.status,block:receipt.blockNumber,frameId:String(f.frameId),inputSeq:f.inputSeq,pixelSha256:sha(f.pixels),worldSha256:sha(f.pixels.subarray(0,320*168)),statusBarSha256:sha(f.pixels.subarray(320*168)),paletteSha256:sha(palette.rgb),rgbaSha256:sha(expandPalette(f,palette.rgb)),state});
  }return out;
}
async function browserRun(index){
  await launcher();assert.equal(await evaluate('window.__installationProof.installed'),true);
  await evaluate(`(${installBrowserProbe.toString()})(${JSON.stringify(workload)})`);
  await command('Page.bringToFront');console.log('Waiting for visible, focused Chrome before gameplay');await until(()=>evaluate('document.hasFocus()&&!document.hidden'),'visible focused Chrome',300000);
  const cpu=await beginCpu();await click('play');let progress=0;
  try{await until(async()=>{const b=await evaluate('window.__bench&&({done:window.__bench.done,error:window.__bench.error,index:window.__bench.index,hidden:document.hidden,running:window.fixtureClient?.loop.running,starting:window.fixtureClient?.loop.starting})');if(b?.error)throw Error(b.error);if(b?.hidden)throw Error('Browser became hidden; invalidate run');if(b?.index>0&&!b.done&&!b.running&&!b.starting)throw Error('Browser loop stopped before workload completion');if(b?.index>=progress+10){progress=b.index;console.log(`browser ${index}: ${Math.max(0,progress-2-warmup)}/${count}`);}return b?.done;},'browser workload',1800000);}
  catch(error){const partial=await evaluate('({probe:window.__bench,errors:window.__transportProof?.errors,running:window.fixtureClient?.loop.running,focused:document.hasFocus(),hidden:document.hidden})').catch(()=>({probeUnavailable:true}));
    for(const r of partial.probe?.rpc??[]){if(r.receipt){const receipt=r.receipt,f=receipt.logs.find(l=>l.topics[0]===FRAME_TOPIC);r.receiptSummary={status:receipt.status,hash:receipt.transactionHash,gasUsed:receipt.gasUsed,frame:f?{frameId:String(decodeFrame(f).frameId),inputSeq:decodeFrame(f).inputSeq,pixelSha256:sha(decodeFrame(f).pixels)}:null};delete r.receipt;}}
    await save(`browser-${index}-interrupted.json`,{excluded:true,error:error.message,partial,cpu:await endCpu()});throw error;}
  await sleep(50);const raw=await evaluate('window.__bench');await endCpu();
  assert.equal(await evaluate('window.fixtureClient.loop.running'),false);assert.equal(await evaluate('window.fixtureClient.keyboard.events.length'),0);
  assert.equal(await evaluate('document.hidden'),false);
  const sends=raw.rpc.filter(x=>x.method==='eth_sendTransaction');assert.equal(sends.length,workload.length+1);
  const transactions=await inspectTransactions(sends.map(s=>{const tick=raw.ticks.find(t=>t.sequence===Number(BigInt('0x'+s.params[0].data.slice(74,138))));const receipts=raw.rpc.filter(x=>x.method==='eth_getTransactionReceipt'&&x.hash===s.hash);const f=raw.frames.find(x=>x.hash===s.hash);
    assert(f?.canvasEndMs);assert(receipts.length>0);return {hash:s.hash,operation:s.params[0],phase:tick?.phase??'setup',index:tick?.index??-1,tick,submissionMs:s.startMs,sendResponseMs:s.endMs,receiptMs:Math.min(...receipts.map(x=>x.endMs)),receipt:receipts[0].receipt,frame:f,rpc:raw.rpc.filter(x=>x.hash===s.hash).map(({receipt,...rest})=>rest)};}));
  assert.equal(transactions.filter(t=>t.phase==='measure').length,count);
  const canvasSha=await evaluate("(async()=>{const b=document.querySelector('#frame').getContext('2d').getImageData(0,0,320,200).data;return [...new Uint8Array(await crypto.subtle.digest('SHA-256',b))].map(n=>n.toString(16).padStart(2,'0')).join('')})()");
  assert.equal(canvasSha,transactions.at(-1).rgbaSha256);
  const run={mode:'browser',index,clock:'browser performance.now milliseconds; CPU uses separate Node monotonic clock',transactions,cpu,finalCanvasSha256:canvasSha,errors:await evaluate('window.__transportProof.errors'),finalState:await fingerprint()};assert.equal(run.errors.length,0);
  await save(`browser-${index}.json`,run);return run;
}
async function directRun(index){
  // Keep Chrome on a blank page: no DOM/gameplay/Canvas or WS subscriptions.
  const cpu=await beginCpu(),records=[],presentation=[];
  const sendExcluded=async data=>{const start=now(),hash=await rpc('eth_sendTransaction',[{from:config.driver,to:config.address,data,gas:report.gas}]);const mined=await productionReceipt(rpc,hash);assert.equal(mined.status,'0x1');return {hash,gasUsed:Number(BigInt(mined.gasUsed)),milliseconds:now()-start,status:mined.status};};
  if(report.parameters.meltEnabledInDirect) await sendExcluded('0x'+methods['enableMeltWipe()']);
  const all=[{phase:'setup',keys:[]},...workload];
  for(let i=0;i<all.length;i++){
    const item=all[i],events=Uint8Array.from(item.keys.flatMap(([type,code])=>[type==='keydown'?0:1,nativeKey(code)]));
    const operation={from:config.driver,to:config.address,data:eventStepData(events,Number(BigInt(await view('inputSeq()')))+1),gas:report.gas};
    const submissionMs=now(),hash=await rpc('eth_sendTransaction',[operation]),sendResponseMs=now();let receipt,receiptPolls=0;
    const trackedRpc=async(method,params)=>{if(method==='eth_getTransactionReceipt')receiptPolls++;return rpc(method,params);};
    if(args.includes('--tight-poll')){while(!(receipt=await trackedRpc('eth_getTransactionReceipt',[hash]))){};}else receipt=await productionReceipt(trackedRpc,hash);
    const receiptMs=now();assert.equal(receipt.status,'0x1');
    // Production MenuTransactions performs this read after every gameplay packet;
    // preserve its ordinary RPC operation and ordering in the primary comparison.
    await view('gameStarted()');const completionMs=now();
    records.push({hash,operation,phase:item.phase,index:i-1,events:Array.from(events),submissionMs,sendResponseMs,receiptMs,completionMs,receiptPolls,receipt});
    if(report.parameters.meltEnabledInDirect && item.phase==='setup') {
      while(BigInt('0x'+(await view('wipeStatus()')).slice(130,194))===1n) {
        const next=Number(BigInt(await view('inputSeq()')))+1;
        presentation.push(await sendExcluded('0x'+methods['stepWipe(uint32)']+BigInt(next).toString(16).padStart(64,'0')));
      }
    }
    if(item.phase==='measure'&&(i-2-warmup)%10===0)console.log(`direct ${index}: ${i-2-warmup}/${count}`);
  }
  await endCpu();const transactions=await inspectTransactions(records);
  const run={mode:'direct',index,presentation,clock:'Node performance.now milliseconds',transactions,cpu,finalState:await fingerprint()};await save(`direct-${index}.json`,run);return run;
}
try{
  await free(port);await free(httpPort);
  try{await readFile(join(websiteRoot,'config.local.json'));throw Error('Refuse existing web/config.local.json; use a clean goal-owned website/worktree');}catch(e){if(e.code!=='ENOENT')throw e;}
  const wad=await readFile(wadPath);assert.equal(sha(wad),DOOM2_PROFILE.wadSha256);
  report.identity={iwad:{bytes:wad.length,sha256:sha(wad),md5:createHash('md5').update(wad).digest('hex')},profile:DOOM2_PROFILE,artifactPins:pins.artifacts,sourceHashes:{}};
  for(const [path,h]of Object.entries(pins.sources)){const actual=sha(await readFile(path));assert.equal(actual,h,path);report.identity.sourceHashes[path]=actual;}
  for(const a of Object.values(pins.artifacts))assert.equal(sha(await readFile('web'+a.url)),a.sha256);
  if(compiled){const a=JSON.parse(await readFile(compiled)),metadata=typeof a.metadata==='string'?JSON.parse(a.metadata):a.metadata;
    const payload=JSON.stringify({bytecode:a.bytecode.object,runtime:a.deployedBytecode.object,immutableReferences:a.deployedBytecode.immutableReferences,methods:a.methodIdentifiers})+'\n';assert.equal(sha(payload),pins.artifacts.Doom.sha256);
    assert(metadata.compiler.version.startsWith('0.8.37'));assert.equal(metadata.settings.viaIR,true);assert.equal(metadata.settings.optimizer.runs,200);assert.equal(metadata.settings.evmVersion,'cancun');
    for(const [path,v]of Object.entries(metadata.sources)){const digest=execFileSync(join(toolchain,'cast'),['keccak'],{input:'0x'+(await readFile(path)).toString('hex'),encoding:'utf8',maxBuffer:1048576}).trim();assert.equal(digest,v.keccak256,path);}
    report.identity.compiler={version:metadata.compiler.version,settings:metadata.settings,metadataSha256:sha(JSON.stringify(metadata)),verifiedSources:Object.keys(metadata.sources).length,compiledArtifactSha256:sha(await readFile(compiled))};
  }else throw Error('--compiler-artifact required to prove shipped bytecode/compiler/source identity');
  const hardware=JSON.parse(runCommand('/usr/sbin/system_profiler',['SPHardwareDataType','-json'])).SPHardwareDataType[0];
  report.environment={hardware:{model:hardware.machine_name,modelIdentifier:hardware.machine_model,chip:hardware.chip_type,cores:hardware.number_processors,memory:hardware.physical_memory},macOS:runCommand('/usr/bin/sw_vers'),node:process.version,anvil:runCommand(join(toolchain,'anvil'),['--version']),solc:runCommand(join(toolchain,'solc'),['--version']),power:runCommand('/usr/bin/pmset',['-g','custom']),powerSource:runCommand('/usr/bin/pmset',['-g','batt']),thermalStart:runCommand('/usr/bin/pmset',['-g','therm']),memoryStart:runCommand('/usr/bin/vm_stat'),memoryPressureStart:runCommand('/usr/bin/memory_pressure',['-Q'])};
  if(report.parameters.requireAC)assert(report.environment.powerSource.includes("drawing from 'AC Power'"),'AC power required');
  const processes=runCommand('/bin/ps',['-axo','pid,ppid,etime,%cpu,rss,command']);
  report.environment.busyProcessesStart=processes.split('\n').slice(1).map(l=>l.trim().split(/\s+/)).filter(v=>Number(v[3])>=20).map(v=>({pid:Number(v[0]),cpuPercent:Number(v[3]),rssKiB:Number(v[4]),executable:basename(v[5])}));
  const nodeArgs=['--host','127.0.0.1','--port',String(port),'--chain-id','31337','--hardfork','cancun','--disable-code-size-limit','--no-request-size-limit','--memory-limit','1073741824','--gas-limit','10000000000','--allow-origin',origin,'--silent'];
  log=await open(join(local,'anvil.log'),'w');node=spawn(join(toolchain,'anvil'),nodeArgs,{stdio:['ignore',log.fd,log.fd]});
  await until(async()=>{if(node.exitCode!==null)throw Error('Anvil exited');try{return await rpc('web3_clientVersion');}catch{return false;}},'Anvil',10000);
  report.runtime={anvilArguments:nodeArgs,nodeInfo:await rpc('anvil_nodeInfo'),pid:node.pid};
  server=await serve(httpPort,websiteRoot);profile=await mkdtemp(join(tmpdir(),'doom-map01-performance-'));
  // Headed, ordinary Chrome with a fresh goal-owned profile; no display claims.
  const browserArgs=[...(args.includes('--headless-install')?['--headless=new']:[]),'--no-first-run','--no-default-browser-check','--disable-background-networking','--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'];
  browser=spawn(chrome,browserArgs,{stdio:['ignore','ignore','pipe']});let stderr='';browser.stderr.on('data',b=>stderr+=b);
  const debug=await until(async()=>{if(browser.exitCode!==null)throw Error(stderr);try{return(await readFile(join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];}catch{return false;}},'Chrome',30000);
  const tabs=await(await fetch(`http://127.0.0.1:${debug}/json/list`)).json();ws=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);
  await new Promise((done,fail)=>{ws.addEventListener('open',done,{once:true});ws.addEventListener('error',fail,{once:true});});
  ws.addEventListener('message',e=>{const r=JSON.parse(e.data),p=pending.get(r.id);if(p){pending.delete(r.id);clearTimeout(p.timer);r.error?p.reject(Error(JSON.stringify(r.error))):p.resolve(r.result);}});
  await command('Page.enable');await command('Page.bringToFront');report.environment.browser=await command('Browser.getVersion');report.environment.browserArguments=browserArgs.map(x=>x.startsWith('--user-data-dir=')?'--user-data-dir=<temporary isolated profile>':x);
  await launcher();const doc=await command('DOM.getDocument'),input=await command('DOM.querySelector',{nodeId:doc.root.nodeId,selector:'#iwad'});
  await command('DOM.setFileInputFiles',{nodeId:input.nodeId,files:[wadPath]});
  await until(async()=>{const p=await evaluate('window.__installationProof');if(p.errors.length)throw Error(p.errors.join('\n'));return p.localIWAD?.authenticated&&!await evaluate('document.querySelector("#install").disabled');},'IWAD File API');
  const installStart=now();await click('install');let lastStage='';
  await until(async()=>{const p=await evaluate('window.__installationProof');if(p.errors.length)throw Error(p.errors.join('\n'));const e=p.events.at(-1);if(e?.stage!==lastStage){lastStage=e.stage;console.log('installation:',lastStage);}return p.installed&&!await evaluate('document.querySelector("#play").disabled');},'browser installation',1800000);
  report.installationMs=now()-installStart;
  ({config,methods}=await evaluate('({config:window.installationClient.installer.configuration(),methods:window.installationClient.installer.artifacts.Doom.methods})'));
  report.config=config;report.methods=methods;report.gas='0x'+BigInt(10000000000).toString(16);
  report.baseline=await fingerprint();assert.equal(BigInt(report.baseline.inputSequence),0n);assert.equal(BigInt(report.baseline.started),0n);assert.equal(BigInt(report.baseline.memory),3n);snapshot=await rpc('evm_snapshot');
  await save('preflight.json',report);console.log('Preflight verified; installed actual production DOOM II.');
  for(let index=1;index<=reps;index++){
    const order=mode==='all'?(index%2?['browser','direct']:['direct','browser']):[mode];
    for(const kind of order){await restore();await quiet();if(kind==='browser')await browserNotice(index);const powerBefore=runCommand('/usr/bin/pmset',['-g','batt']);if(report.parameters.requireAC)assert(powerBefore.includes("drawing from 'AC Power'"),'AC power required');console.log('START',kind,index,new Date().toISOString());const before=busyProcesses();const r=kind==='browser'?await browserRun(index):await directRun(index);r.busyProcessesBefore=before;r.busyProcessesAfter=busyProcesses();r.powerBefore=powerBefore;r.powerAfter=runCommand('/usr/bin/pmset',['-g','batt']);if(report.parameters.requireAC)assert(r.powerAfter.includes("drawing from 'AC Power'"),'AC power changed');await save(`${kind}-${index}.json`,r);report.runs.push({mode:kind,index,file:`${kind}-${index}.json`});console.log('DONE',kind,index,new Date().toISOString());if(kind==='browser')console.log('RELEASE browser control');await save('manifest.json',report);}
  }
  report.environment.thermalEnd=runCommand('/usr/bin/pmset',['-g','therm']);report.environment.memoryEnd=runCommand('/usr/bin/vm_stat');report.pass=true;
}catch(e){report.error=e.stack;console.error(e.stack);process.exitCode=1;}
finally{
  clearInterval(cpuTimer);currentCpu=null;report.endedUtc=new Date().toISOString();await save('manifest.json',report);
  for(const p of pending.values()){clearTimeout(p.timer);p.reject(Error('Benchmark cleanup'));}pending.clear();ws?.close();await stop(browser);await stop(node);if(server)await new Promise(done=>server.close(done));await log?.close();if(profile)await rm(profile,{recursive:true,force:true});
}
