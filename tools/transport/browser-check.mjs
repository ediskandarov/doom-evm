// SPDX-License-Identifier: GPL-2.0-only
// End-to-end check with local Chrome DevTools Protocol; no npm/browser-driver dependencies.
import { spawn, execFileSync } from 'node:child_process';
import { mkdtemp,readFile,writeFile,mkdir,rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join,resolve,dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import { serve } from './serve.mjs';
import { makeRpc,decodeFrame,expandPalette } from '../../web/protocol.mjs';
import {loadGasBudget, executionEnv} from '../execution-budget.mjs';
const {gasLimit, gasHex, source: gasBudgetSource} = loadGasBudget();
const budgetEnv = executionEnv({...process.env, DOOM_GAS_LIMIT: String(gasLimit)});
process.chdir(fileURLToPath(new URL('../../',import.meta.url)));
const argv=process.argv.slice(2),option=(name,fallback)=>{const i=argv.indexOf(name);return i<0?fallback:argv[i+1];};
const palettePath=option('--palette','web/palette.synthetic.json');
const outputPrefix=option('--output-prefix','artifacts/local/transport-browser');
// A renderer deployment supplies its live node/config; default remains the original mock gate.
const existingConfigPath=option('--existing-config',null);
const timingScriptPath=option('--timing-script',null);
const existingConfig=existingConfigPath?JSON.parse(await readFile(existingConfigPath,'utf8')):null;
const browserBudget=existingConfig?.gasLimit === undefined ? {gasLimit,source:gasBudgetSource}
  : {...loadGasBudget({env:{DOOM_GAS_LIMIT:String(existingConfig.gasLimit)}}),source:existingConfigPath};
const chromePath=process.env.CHROME_BIN??'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const port=Number(process.env.BROWSER_ANVIL_PORT??18549),rpcUrl=existingConfig?.rpcUrl??`http://127.0.0.1:${port}`,rpc=makeRpc(rpcUrl);
let anvil,chrome,server,cdp,profile;
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function waitFor(fn,label) { const end=Date.now()+30000;while(Date.now()<end){const value=await fn();if(value)return value;await sleep(50);}throw Error(`Timeout: ${label}`); }
async function stop(child) {
  // Failed spawn has no PID and never emits exit; do not wait on or signal it.
  if(!child?.pid||child.exitCode!==null||child.signalCode!==null)return;
  await new Promise(resolve=>{
    let timer;
    const done=()=>{clearTimeout(timer);child.removeListener('exit',done);resolve();};
    child.once('exit',done);
    child.kill('SIGTERM');
    timer=setTimeout(()=>{child.kill('SIGKILL');timer=setTimeout(done,1500);},1500);
  });
}
try {
  let expectedCase;
  if(existingConfig){
    assert.equal(existingConfig.rendererKind,'doom-world-view');
    const manifest=JSON.parse(await readFile('test/fixtures/renderer/manifest.json','utf8'));
    expectedCase=manifest.cases.find(row=>row.name===existingConfig.referenceCase);
    assert(expectedCase);assert.equal(expectedCase.mode,'full','browser M1 requires the complete world-view pass');
    assert.deepEqual(existingConfig.resourceIdentity,manifest.resourceIdentity);
    await rpc('web3_clientVersion');
    await writeFile('web/config.local.json',JSON.stringify({...existingConfig,gasLimit:browserBudget.gasLimit},null,2)+'\n');
  }else{
  try {await rpc('web3_clientVersion');throw Error('Anvil port in use');}catch(e){if(e.message.includes('port in use'))throw e;}
  anvil=spawn(resolve('.toolchain/bin/anvil'),['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--disable-block-gas-limit','--memory-limit','1073741824','--silent'],{stdio:['ignore','ignore','pipe']});
  let anvilError='',anvilStartError;anvil.on('error',error=>anvilStartError=error);
  anvil.stderr.on('data',x=>anvilError+=x);
  await waitFor(async()=>{if(anvilStartError)throw anvilStartError;if(anvil.exitCode!==null)throw Error(anvilError);try{return await rpc('web3_clientVersion');}catch{return false;}},'Anvil');
  await rpc('anvil_setBlockGasLimit',[gasHex]);
  execFileSync(process.execPath,['tools/transport/benchmark.mjs','--palette',palettePath,'--rpc',rpcUrl,'--output','artifacts/local/transport-browser-node.json'],{env:budgetEnv,timeout:60000,stdio:['ignore','pipe','inherit']});
  }
  server=await serve(0);
  profile=await mkdtemp(join(tmpdir(),'doom-evm-chrome-'));
  chrome=spawn(chromePath,['--headless=new','--no-first-run','--no-default-browser-check','--disable-background-networking','--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'],{stdio:['ignore','ignore','pipe']});
  let chromeError='',chromeStartError;chrome.on('error',error=>chromeStartError=error);
  chrome.stderr.on('data',x=>chromeError+=x);
  const debugPort=await waitFor(async()=>{if(chromeStartError)throw chromeStartError;if(chrome.exitCode!==null)throw Error(chromeError);try{return (await readFile(join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];}catch{return null;}},'Chrome DevTools');
  const targets=await(await fetch(`http://127.0.0.1:${debugPort}/json/list`)).json();
  cdp=new WebSocket(targets.find(x=>x.type==='page').webSocketDebuggerUrl);
  await new Promise((done,fail)=>{cdp.addEventListener('open',done,{once:true});cdp.addEventListener('error',fail,{once:true});});
  let id=0;const requests=new Map();
  cdp.addEventListener('message',event=>{const msg=JSON.parse(event.data);if(msg.id){const entry=requests.get(msg.id);if(entry){requests.delete(msg.id);clearTimeout(entry.timer);msg.error?entry.reject(Error(JSON.stringify(msg.error))):entry.resolve(msg.result);}}});
  const command=(method,params={})=>new Promise((resolve,reject)=>{const key=++id;requests.set(key,{resolve,reject,timer:setTimeout(()=>{requests.delete(key);reject(Error(`CDP timeout ${method}`));},10000)});cdp.send(JSON.stringify({id:key,method,params}));});
  await command('Page.enable');
  if(timingScriptPath)await command('Page.addScriptToEvaluateOnNewDocument',{source:await readFile(timingScriptPath,'utf8')});
  await command('Emulation.setDeviceMetricsOverride',{width:1100,height:900,deviceScaleFactor:1,mobile:false});
  await command('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/?autotest=1`});
  const proof=await waitFor(async()=>{
    const result=await command('Runtime.evaluate',{expression:'window.__transportProof',returnByValue:true});
    const value=result.result.value;if(value?.errors?.length)throw Error(value.errors.join('\n'));
    return value?.done?value:null;
  },'browser Canvas frame test');
  assert(proof.ready);assert(proof.fallbackVerified);assert(proof.duplicates>=2);
  const config=JSON.parse(await readFile('web/config.local.json','utf8'));
  const mined=await rpc('eth_getTransactionReceipt',[proof.frames.at(-1).transactionHash]);
  const frame=decodeFrame(mined.logs[0]);
  assert.equal(proof.latestPixelsHex,Buffer.from(frame.pixels).toString('hex'),'complete browser bytes equal mined receipt');
  const palette=JSON.parse(await readFile(palettePath,'utf8'));
  const expectedRgba=expandPalette(frame,Buffer.from(palette.rgbHex,'hex'));
  assert.equal(proof.rgbaSha256,createHash('sha256').update(expectedRgba).digest('hex'),'all Canvas pixels equal palette-expanded receipt');
  assert.equal(frame.pixels.length,64000);
  if(expectedCase){
    assert.equal(proof.rendererKind,'doom-world-view');
    assert.equal(createHash('sha256').update(frame.pixels).digest('hex'),expectedCase.frameSha256,'browser receipt must match the full original C golden');
  }
  assert.equal(proof.paletteKind,palette.kind);assert.equal(proof.paletteSha256,palette.resourceIdentity.paletteSha256);
  const screenshot=await command('Page.captureScreenshot',{format:'png'});
  await mkdir(dirname(outputPrefix),{recursive:true});await writeFile(outputPrefix+'.png',Buffer.from(screenshot.data,'base64'));
  delete proof.latestPixelsHex;
  const result={gasLimit:config.gasLimit,gasBudgetSource:browserBudget.source,timestamp:new Date().toISOString(),kind:expectedCase?'doom-world-view-browser':'synthetic-browser-transport',referenceCase:expectedCase?.name,browser:await command('Browser.getVersion'),config,proof,receiptPixelsSha256:createHash('sha256').update(frame.pixels).digest('hex'),allCanvasPixelsMatchReceipt:true,screenshot:outputPrefix+'.png'};
  if(timingScriptPath){const timing=await command('Runtime.evaluate',{expression:'window.__rendererTiming',returnByValue:true});result.timing=timing.result.value;assert(result.timing,'timing script did not produce evidence');}
  await writeFile(outputPrefix+'.json',JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
}catch(error){
  console.error(`Browser check failed: ${error.message}`);process.exitCode=1;
}finally{
  cdp?.close();await stop(chrome);await stop(anvil);
  if(server)await new Promise(r=>server.close(r));
  if(profile)await rm(profile,{recursive:true,force:true});
}
