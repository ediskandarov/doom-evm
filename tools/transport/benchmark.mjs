// SPDX-License-Identifier: GPL-2.0-only
// Node >=24, no npm dependencies. Local unlocked Anvil accounts only.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { spawn, execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
import { FRAME_TOPIC, stepData, decodeFrame, FrameInbox, FrameSubscription, makeRpc, receipt, backfill } from '../../web/protocol.mjs';
const root = fileURLToPath(new URL('../../', import.meta.url));
process.chdir(root);
const argv = process.argv.slice(2), option = (name, fallback) => { const i=argv.indexOf(name); return i<0?fallback:argv[i+1]; };
const port = Number(option('--port','18546')), external = option('--rpc',null);
const url = external ?? `http://127.0.0.1:${port}`, wsUrl = option('--ws',url.replace(/^http/,'ws'));
const count = Number(option('--frames','3'));
assert(Number.isInteger(count) && count>=2 && count<=100, '--frames must be 2..100');
const args = ['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--disable-block-gas-limit','--memory-limit','1073741824','--silent'];
let node, subscription, nodeOutput = '';
const memory = [process.memoryUsage()];
let peakAnvilRssBytes = 0;
const sample = () => {
  memory.push(process.memoryUsage());
  if (node?.pid) { try { const rss = Number(execFileSync('ps',['-o','rss=','-p',String(node.pid)],{encoding:'utf8'}).trim())*1024; peakAnvilRssBytes=Math.max(peakAnvilRssBytes,rss); } catch {} }
};
let sampler;
const sha = data => createHash('sha256').update(data).digest('hex');
const rpc = makeRpc(url);
async function waitFor(test, description) {
  const deadline = performance.now()+30000;
  while (performance.now()<deadline) { if (await test()) return; await new Promise(r=>setTimeout(r,25)); }
  throw Error(`Timeout: ${description}`);
}
try {
  execFileSync(resolve('.toolchain/bin/forge'),['build'],{stdio:'inherit',timeout:60000});
  if (!external) {
    // Refuse to accidentally attach to an existing process when claiming self-managed node settings.
    try { await rpc('web3_clientVersion'); throw Error('Port already has an RPC server; choose --port or explicit --rpc'); }
    catch (error) { if (error.message.includes('already')) throw error; }
    node=spawn(resolve('.toolchain/bin/anvil'),args,{stdio:['ignore','pipe','pipe']});
    node.stdout.on('data',x=>nodeOutput+=x); node.stderr.on('data',x=>nodeOutput+=x);
    let startError; node.on('error',error=>startError=error);
    await waitFor(async()=>{
      if(startError) throw startError;
      if(node.exitCode!==null) throw Error(`Anvil exited ${node.exitCode}: ${nodeOutput}`);
      try { await rpc('web3_clientVersion'); return true; } catch { return false; }
    },'Anvil readiness');
  }
  if (!external) await rpc('anvil_setBlockGasLimit',['0x3b9aca00']);
  sampler=setInterval(sample,100); sample();
  const accounts=await rpc('eth_accounts'); assert(accounts.length>=2,'needs local unlocked accounts');
  const artifact=JSON.parse(await readFile('out/FrameFixture.sol/FrameFixture.json','utf8'));
  const deployHash=await rpc('eth_sendTransaction',[{from:accounts[0],data:artifact.bytecode.object,gas:'0x3b9aca00'}]);
  const deployment=await receipt(rpc,deployHash); assert.equal(deployment.status,'0x1');
  const address=deployment.contractAddress;
  const wsLogs=new Map(), delivered=[];
  const inbox=new FrameInbox((frame,source)=>delivered.push({frameId:String(frame.frameId),source}));
  subscription=new FrameSubscription(wsUrl,address,log=>{
    wsLogs.set(log.transactionHash,{log,time:performance.now()}); inbox.accept(log,'ws');
  });
  await subscription.connect(); // ACK required before any frame transaction.
  const frames=[];
  for(let sequence=1;sequence<=count;sequence++) {
    const start=performance.now();
    const hash=await rpc('eth_sendTransaction',[{from:accounts[0],to:address,data:stepData(sequence),gas:'0x3b9aca00'}]);
    const submitted=performance.now();
    const mined=await receipt(rpc,hash), receiptAt=performance.now();
    assert.equal(mined.status,'0x1'); assert.equal(mined.logs.length,1);
    const log=mined.logs[0]; assert.equal(log.topics[0],FRAME_TOPIC);
    inbox.accept(log,'receipt');
    await waitFor(()=>wsLogs.has(hash),'complete WS log');
    const notification=wsLogs.get(hash);
    assert.equal(notification.log.data,log.data,'every ABI payload byte agrees between WS and receipt');
    assert.deepEqual(notification.log.topics,log.topics);
    const frame=decodeFrame(log); assert.equal(frame.pixels.length,64000);
    assert.equal(frame.frameId,BigInt(sequence)); assert.equal(frame.inputSeq,sequence);
    for(let i=0;i<frame.pixels.length;i++) assert.equal(frame.pixels[i],(i+sequence)%256,`pixel ${i}`);
    frames.push({sequence,transactionHash:hash,frameId:String(frame.frameId),pixelBytes:frame.pixels.length,abiDataBytes:(log.data.length-2)/2,pixelsSha256:sha(frame.pixels),gasUsed:Number(BigInt(mined.gasUsed)),gasLimit:1000000000,submitResponseMs:submitted-start,receiptMs:receiptAt-start,wsDeliveryMs:notification.time-start,wsEqualsReceipt:true});
  }
  // Deliberately lose the subscription for one transaction, then recover from its receipt.
  subscription.close();
  const fallbackSequence=count+1;
  const fallbackHash=await rpc('eth_sendTransaction',[{from:accounts[0],to:address,data:stepData(fallbackSequence),gas:'0x3b9aca00'}]);
  const fallbackReceipt=await receipt(rpc,fallbackHash); assert.equal(fallbackReceipt.status,'0x1');
  assert.equal(fallbackReceipt.logs.length,1); assert(inbox.accept(fallbackReceipt.logs[0],'receipt'));
  const shownBeforeBackfill=delivered.length;
  await subscription.connect();
  const recovered=await backfill(rpc,address,deployment.blockNumber,inbox);
  assert.equal(recovered,count+1); assert.equal(delivered.length,shownBeforeBackfill,'backfill is deduplicated');
  // Mine real failed transactions: wrong driver, replay, skipped input, out of gas, and revert AFTER LOG.
  const selector=execFileSync(resolve('.toolchain/bin/cast'),['sig','revertAfterFrame(uint32)'],{encoding:'utf8'}).trim();
  const next=fallbackSequence+1, stateSelector=execFileSync(resolve('.toolchain/bin/cast'),['sig','frameId()'],{encoding:'utf8'}).trim();
  const sequenceSelector=execFileSync(resolve('.toolchain/bin/cast'),['sig','inputSeq()'],{encoding:'utf8'}).trim();
  const failures=[];
  for(const [name,from,data,gas] of [
    ['wrong-driver',accounts[1],stepData(next),'0x3b9aca00'],
    ['replayed-sequence',accounts[0],stepData(fallbackSequence),'0x3b9aca00'],
    ['skipped-sequence',accounts[0],stepData(next+1),'0x3b9aca00'],
    ['out-of-gas',accounts[0],stepData(next),'0x186a0'],
    ['revert-after-log',accounts[0],selector+next.toString(16).padStart(64,'0'),'0x3b9aca00']]) {
    const hash=await rpc('eth_sendTransaction',[{from,to:address,data,gas}]); const failed=await receipt(rpc,hash);
    assert.equal(failed.status,'0x0',name); assert.equal(failed.logs.length,0,name);
    assert.equal(BigInt(await rpc('eth_call',[{to:address,data:stateSelector},'latest'])),BigInt(fallbackSequence));
    assert.equal(BigInt(await rpc('eth_call',[{to:address,data:sequenceSelector},'latest'])),BigInt(fallbackSequence));
    failures.push({name,transactionHash:hash,status:failed.status,logCount:failed.logs.length,gasUsed:Number(BigInt(failed.gasUsed))});
  }
  sample();
  const block=await rpc('eth_getBlockByNumber',[deployment.blockNumber,false]);
  const palette=JSON.parse(await readFile('web/palette.synthetic.json','utf8'));
  const config={rpcUrl:url,wsUrl,address,driver:accounts[0],deploymentBlock:deployment.blockNumber,paletteUrl:'/palette.synthetic.json',resourceIdentity:palette.resourceIdentity};
  const report={kind:'synthetic-transport-experiment',timestamp:new Date().toISOString(),nodeVersion:process.version,anvilVersion:await rpc('web3_clientVersion'),compilerVersion:execFileSync(resolve('.toolchain/bin/solc'),['--version'],{encoding:'utf8'}).trim(),nodeArgs:external?null:args,externalNodeSettingsUnverified:Boolean(external),postLaunchRpc:external?null:{method:'anvil_setBlockGasLimit',params:['0x3b9aca00']},blockGasLimit:Number(BigInt(block.gasLimit)),deployment:{transactionHash:deployHash,address,gasUsed:Number(BigInt(deployment.gasUsed)),runtimeBytes:(artifact.deployedBytecode.object.length-2)/2},frames,fallback:{sequence:fallbackSequence,source:'receipt',recoveredLogs:recovered,duplicates:inbox.duplicates,displayed:delivered},failedTransactions:failures,memory:{samplingIntervalMs:100,nodePeakSampledRssBytes:Math.max(...memory.map(x=>x.rss)),nodePeakSampledHeapUsedBytes:Math.max(...memory.map(x=>x.heapUsed)),nodePeakSampledExternalBytes:Math.max(...memory.map(x=>x.external)),anvilPeakSampledRssBytes:node?peakAnvilRssBytes:null,samples:memory.length},notes:['Timings are wall-clock client observations including JSON-RPC, execution and mining; no isolated EVM execution-time claim.','Memory peaks are sampled, not guaranteed exact maxima. External-node Anvil RSS is unavailable.','Synthetic fixture only: no WAD, original C equivalence or engine implementation.']};
  await mkdir('artifacts/local',{recursive:true});
  await writeFile(option('--output','artifacts/local/transport.json'),JSON.stringify(report,null,2)+'\n');
  await writeFile('web/config.local.json',JSON.stringify(config,null,2)+'\n');
  console.log(JSON.stringify(report,null,2));
} finally {
  clearInterval(sampler); subscription?.close();
  if(node&&node.exitCode===null) { node.kill('SIGTERM'); await Promise.race([new Promise(r=>node.once('exit',r)),new Promise(r=>setTimeout(()=>{node.kill('SIGKILL');r();},2000))]); }
}
