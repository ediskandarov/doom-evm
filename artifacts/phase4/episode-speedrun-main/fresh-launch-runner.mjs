import {spawn} from 'node:child_process';
import {readFile,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const root='/Users/eduard/sandbox/doom-evm';
const cwd=root+'/artifacts/local/episode-speedrun-main/runtime';
const prefix=root+'/artifacts/phase4/episode-speedrun-main/fresh-launch-final';
const start=new Date().toISOString();
const child=spawn(process.execPath,['tools/reference/episode_completion/evm.mjs','--play','--port','18935','--http-port','18936','--output-prefix',prefix],{cwd,stdio:['ignore','inherit','inherit']});
let status;
child.once('exit',(code,signal)=>{status={code,signal};});
try {
 const end=Date.now()+300000;
 while(true) {
  if(status)throw Error('Launcher exited '+JSON.stringify(status));
  let ready=false;
  try{ready=JSON.parse(await readFile(prefix+'.json')).pass;}catch{}
  if(ready)break;
  assert(Date.now()<end,'Launcher startup timeout');
  await new Promise(r=>setTimeout(r,100));
 }
 const browser=spawn(process.execPath,['tools/transport/episode-browser-check.mjs','--fresh','--config',cwd+'/web/config.local.json','--output-prefix',prefix+'-browser'],{cwd,stdio:['ignore','inherit','inherit']});
 const code=await new Promise((done,fail)=>{browser.once('error',fail);browser.once('exit',done);});
 assert.equal(code,0,'Fresh launcher Canvas/DOM');
} finally {
 if(!status){child.kill('SIGTERM');await new Promise(done=>child.once('exit',done));}
 await writeFile(prefix+'-ownership.json',JSON.stringify({startedUtc:start,endedUtc:new Date().toISOString(),ownedLauncherPid:child.pid,exit:status,stoppedOwnedLauncher:true},null,2)+'\n');
}
