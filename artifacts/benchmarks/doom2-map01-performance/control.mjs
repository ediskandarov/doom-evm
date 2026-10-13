// SPDX-License-Identifier: GPL-2.0-only
// Recover sanitized partial observations and stop only verified owned children.
import {readFile,writeFile,mkdir,rm} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {decodeFrame,FRAME_TOPIC} from '../../../web/protocol.mjs';
export async function abortOwned({profile,parentPid,anvilPid,chromePid,output}){
  assert(/\/doom-map01-performance-[^/]+$/.test(profile));
  const processInfo=pid=>execFileSync('/bin/ps',['-p',String(pid),'-o','pid=,ppid=,command='],{encoding:'utf8'}).trim();
  const parent=processInfo(parentPid),anvil=processInfo(anvilPid),chrome=processInfo(chromePid);
  assert(parent.includes('node artifacts/benchmarks/doom2-map01-performance/run.mjs'));
  assert.equal(Number(anvil.split(/\s+/)[1]),parentPid);assert(anvil.includes('--port 19880'));
  assert.equal(Number(chrome.split(/\s+/)[1]),parentPid);assert(chrome.includes('--user-data-dir='+profile));
  const port=(await readFile(join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];
  const tabs=await(await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const ws=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);await new Promise((done,fail)=>{ws.addEventListener('open',done,{once:true});ws.addEventListener('error',fail,{once:true});});
  let id=0;const pending=new Map();ws.addEventListener('message',e=>{const r=JSON.parse(e.data);if(pending.has(r.id)){const p=pending.get(r.id);pending.delete(r.id);r.error?p.reject(Error(JSON.stringify(r.error))):p.resolve(r.result);}});
  const command=(method,params)=>new Promise((resolve,reject)=>{const key=++id;pending.set(key,{resolve,reject});ws.send(JSON.stringify({id:key,method,params}));});
  const response=await command('Runtime.evaluate',{expression:'({probe:window.__bench,errors:window.__transportProof?.errors,running:window.fixtureClient?.loop.running,hidden:document.hidden,powerConditionChanged:true})',returnByValue:true});
  const partial=response.result.value;
  if(partial?.probe){for(const r of partial.probe.rpc){if(r.receipt){const receipt=r.receipt;const f=receipt.logs.find(l=>l.topics[0]===FRAME_TOPIC);r.receiptSummary={status:receipt.status,hash:receipt.transactionHash,gasUsed:receipt.gasUsed,frame:f?{frameId:String(decodeFrame(f).frameId),inputSeq:decodeFrame(f).inputSeq,pixelSha256:createHash('sha256').update(decodeFrame(f).pixels).digest('hex')}:null};delete r.receipt;}}}
  await mkdir(output,{recursive:true});await writeFile(join(output,'interrupted.json'),JSON.stringify({excluded:true,reason:'User plugged laptop into AC and requested full restart; partial run also lost browser focus.',stoppedUtc:new Date().toISOString(),...partial},null,2)+'\n');
  console.log(JSON.stringify({frames:partial?.probe?.frames.length,ticks:partial?.probe?.ticks.length,errors:partial?.errors,running:partial?.running,hidden:partial?.hidden}));ws.close();
  process.kill(chromePid,'SIGTERM');process.kill(anvilPid,'SIGTERM');process.kill(parentPid,'SIGTERM');
  await new Promise(r=>setTimeout(r,2000));await rm(profile,{recursive:true,force:true});
}
