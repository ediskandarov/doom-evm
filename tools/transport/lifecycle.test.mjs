// SPDX-License-Identifier: GPL-2.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn,execFileSync } from 'node:child_process';
import { readdir } from 'node:fs/promises';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
const root=fileURLToPath(new URL('../../',import.meta.url));
const port=18551;
const profiles=async()=>new Set((await readdir(tmpdir())).filter(name=>name.startsWith('doom-evm-chrome-')));
async function assertPortFree(){
  const server=createServer();
  await new Promise((done,fail)=>{server.once('error',fail);server.listen(port,'127.0.0.1',done);});
  await new Promise(done=>server.close(done));
}
test('missing Chrome exits cleanly and removes its Anvil, server, and temporary profile', {timeout:60000}, async()=>{
  await assertPortFree();
  const before=await profiles();
  const child=spawn(process.execPath,['tools/transport/browser-check.mjs'],{cwd:root,env:{...process.env,CHROME_BIN:'/definitely/missing',BROWSER_ANVIL_PORT:String(port)},stdio:['ignore','pipe','pipe']});
  let output='';child.stdout.on('data',x=>output+=x);child.stderr.on('data',x=>output+=x);
  const code=await new Promise((done,fail)=>{child.once('error',fail);child.once('exit',done);});
  assert.equal(code,1,output);
  assert.match(output,/Browser check failed: spawn \/definitely\/missing ENOENT/);
  assert.doesNotMatch(output,/Unhandled 'error' event/);
  await assertPortFree();
  assert.deepEqual([...await profiles()].filter(name=>!before.has(name)),[],'no leaked profile');
  const processes=execFileSync('ps',['-axo','pid=,command='],{encoding:'utf8'});
  assert(!processes.split('\n').some(line=>line.includes('/anvil ')&&line.includes(`--port ${port}`)),'no owned Anvil process');
  // Exiting naturally also proves its ephemeral HTTP server did not keep the child alive.
});
