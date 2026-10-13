// SPDX-License-Identifier: GPL-2.0-only
// Recompute publication metrics from retained sanitized samples; no runtime needed.
import {readFile,writeFile} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const dir=resolve(process.argv[2]??'artifacts/benchmarks/doom2-map01-performance/results/run1');
const load=async name=>JSON.parse(await readFile(join(dir,name),'utf8'));
const manifest=await load('manifest.json');assert.equal(manifest.pass,true,manifest.error);
const diagnostic=process.argv.includes('--diagnostic'),strictGlobal=process.argv.includes('--require-global-root-equality');
export const quantile=(values,q)=>{const sorted=[...values].sort((a,b)=>a-b);assert(sorted.length);const index=(sorted.length-1)*q,lo=Math.floor(index),hi=Math.ceil(index);return sorted[lo]+(sorted[hi]-sorted[lo])*(index-lo);};
const distribution=values=>({count:values.length,mean:values.reduce((a,b)=>a+b,0)/values.length,median:quantile(values,.5),p95:quantile(values,.95),min:Math.min(...values),max:Math.max(...values)});
const sha=x=>createHash('sha256').update(x).digest('hex');
const runs=[];
for(const entry of manifest.runs){const run=await load(entry.file),tx=run.transactions.filter(t=>t.phase==='measure');assert.equal(tx.length,manifest.parameters.count);
  assert.equal(new Set(tx.map(t=>t.hash)).size,tx.length);assert.equal(new Set(tx.map(t=>t.frameId)).size,tx.length);
  for(let i=0;i<tx.length;i++){
    const t=tx[i];assert.equal(t.status,'0x1');assert(t.state);assert.equal(Number(BigInt('0x'+t.state.episode.slice(2,66))),1);assert.equal(Number(BigInt('0x'+t.state.episode.slice(66,130))),2);assert.equal(BigInt('0x'+t.state.episode.slice(130,194)),0n);
    if(i){assert.equal(t.inputSeq,tx[i-1].inputSeq+1);assert.equal(BigInt(t.frameId),BigInt(tx[i-1].frameId)+1n);assert.equal(BigInt('0x'+t.state.gameStatus.slice(2,66)),BigInt('0x'+tx[i-1].state.gameStatus.slice(2,66))+1n);assert.equal(BigInt('0x'+t.state.gameStatus.slice(66,130)),BigInt('0x'+tx[i-1].state.gameStatus.slice(66,130))+1n);}
    if(run.mode==='browser')assert(t.frame.canvasEndMs>=t.tick.inputDispatchMs);
  }
  assert(new Set(tx.map(t=>t.pixelSha256)).size>1,'Static scene');
  assert(new Set(tx.map(t=>t.state.playerView.slice(2,130))).size>1,'No movement');assert(new Set(tx.map(t=>t.state.playerView.slice(194,258))).size>1,'No turning');
  const start=run.mode==='browser'?tx[0].tick.inputDispatchMs:tx[0].submissionMs;
  const end=run.mode==='browser'?Math.max(tx.at(-1).frame.canvasEndMs,tx.at(-1).tick.tickEndMs):tx.at(-1).completionMs;
  const frameTimes=tx.map(t=>run.mode==='browser'?t.frame.canvasEndMs:t.receiptMs);
  const intervals=frameTimes.slice(1).map((v,i)=>v-frameTimes[i]);
  const cpu=run.cpu,first=cpu[0],last=cpu.at(-1),deltas=cpu.slice(1).map((v,i)=>100*(v.cpuSeconds-cpu[i].cpuSeconds)/((v.monotonicMs-cpu[i].monotonicMs)/1000));
  const metrics={mode:run.mode,index:run.index,frames:tx.length,transactions:tx.length,elapsedMs:end-start,windowStartMs:start,windowEndMs:end,gameplayFPS:tx.length/((end-start)/1000),transactionsPerSecond:tx.length/((end-start)/1000),ticsPerSecond:tx.length/((end-start)/1000),slowdownFrom35Hz:35/(tx.length/((end-start)/1000)),frameIntervalsMs:distribution(intervals),transactionReceiptLatencyMs:distribution(tx.map(t=>t.receiptMs-t.submissionMs)),gasPerFrame:distribution(tx.map(t=>t.gasUsed)),uniquePixelHashes:new Set(tx.map(t=>t.pixelSha256)).size,cpu:{scope:'entire mode workload including menu setup and warmup; cumulative process CPU time / monotonic elapsed time',samples:cpu.length,elapsedMs:last.monotonicMs-first.monotonicMs,meanPercent:100*(last.cpuSeconds-first.cpuSeconds)/((last.monotonicMs-first.monotonicMs)/1000),peakIntervalPercent:Math.max(...deltas),peakRssKiB:Math.max(...cpu.map(s=>s.rssKiB))},componentsMs:{sendRpc:distribution(tx.map(t=>t.sendResponseMs-t.submissionMs)),sendResponseToReceipt:distribution(tx.map(t=>t.receiptMs-t.sendResponseMs))}};
  if(run.mode==='browser'){
    metrics.inputToCanvasMs=distribution(tx.map(t=>t.frame.canvasEndMs-t.tick.inputDispatchMs));
    metrics.componentsMs.inputToSubmit=distribution(tx.map(t=>t.submissionMs-t.tick.inputDispatchMs));
    metrics.componentsMs.frameDecodeAndInbox=distribution(tx.map(t=>t.frame.inboxEndMs-t.frame.inboxStartMs));
    metrics.componentsMs.frameToPaletteReady=distribution(tx.map(t=>t.frame.paletteReadyMs-t.frame.eventProcessingMs));
    metrics.componentsMs.paletteExpansionAndCanvasReset=distribution(tx.map(t=>t.frame.canvasStartMs-t.frame.paletteReadyMs));
    metrics.componentsMs.putImageData=distribution(tx.map(t=>t.frame.canvasEndMs-t.frame.canvasStartMs));
    metrics.componentsMs.productionCallbackAfterPaint=distribution(tx.map(t=>t.frame.callbackEndMs-t.frame.canvasEndMs));
    metrics.componentsMs.betweenTicks=distribution(tx.slice(1).map((t,i)=>t.tick.tickStartMs-tx[i].tick.tickEndMs));
    metrics.componentsMs.canvasToNextAnimationFrame=distribution(tx.filter(t=>t.frame.nextAnimationFrameMs!==undefined).map(t=>t.frame.nextAnimationFrameMs-t.frame.canvasEndMs));
  }
  runs.push({entry,run,tx,metrics});
}
const reference=runs[0];
let storageAnchor;
if(manifest.storageProofAnchor){storageAnchor=await load(manifest.storageProofAnchor.file);assert.equal(storageAnchor.mode,'browser');assert.equal(storageAnchor.transactions.filter(t=>t.phase==='measure').length,manifest.parameters.count);
  assert.equal(storageAnchor.transactions.length,reference.run.transactions.length);assert.deepEqual(storageAnchor.errors,[]);assert.equal(storageAnchor.finalCanvasSha256,reference.run.transactions.at(-1).rgbaSha256);
  for(let i=0;i<reference.run.transactions.length;i++){const a=storageAnchor.transactions[i],b=reference.run.transactions[i];for(const key of ['operation','gasUsed','frameId','inputSeq','pixelSha256','paletteSha256','state'])assert.deepEqual(a[key],b[key],`storage anchor ${i} ${key}`);}
  assert(storageAnchor.finalState.gameStorageHash);}
const storageReference=storageAnchor?.finalState??reference.run.finalState;
for(const r of runs){
  assert.equal(r.run.transactions.length,reference.run.transactions.length);
  for(let i=0;i<r.run.transactions.length;i++){
    const a=r.run.transactions[i],b=reference.run.transactions[i];for(const key of ['operation','gasUsed','frameId','inputSeq','pixelSha256','paletteSha256','state'])assert.deepEqual(a[key],b[key],`${r.entry.file} ${i} ${key}`);
  }
  if(strictGlobal)assert.equal(r.run.finalState.stateRoot,reference.run.finalState.stateRoot,'Final full chain state root differs');
  if(!diagnostic){if(!r.run.finalState.gameStorageHash){assert(storageAnchor&&r.entry.mode==='browser','Missing full DOOM contract storage proof');continue;}assert.equal(r.run.finalState.gameStorageHash,storageReference.gameStorageHash,'Final DOOM contract storage root differs');assert.equal(r.run.finalState.gameCodeHash,storageReference.gameCodeHash,'DOOM code differs');assert.equal(r.run.finalState.driverBalance,storageReference.driverBalance,'Driver balance differs');}
}
const summary={sourceCommit:manifest.sourceCommit,pass:true,diagnostic,comparisonProof:{transactionsPerRun:reference.run.transactions.length,allOperationsGasFramePaletteStateEqual:true,finalDoomContractStorageProof:{capturedPrimaryRuns:runs.filter(r=>r.run.finalState.gameStorageHash).length,capturedSupplementalBrowserRuns:storageAnchor?1:0,allCapturedRootsEqual:diagnostic?null:true,root:storageReference.gameStorageHash??null,primaryRunsWithoutCapturedStorageRoot:runs.filter(r=>!r.run.finalState.gameStorageHash).map(r=>({mode:r.entry.mode,index:r.entry.index}))},finalFullChainStateRootEqual:runs.every(r=>r.run.finalState.stateRoot===reference.run.finalState.stateRoot),beaconContractStorageRootsDiffer:new Set(runs.map(r=>r.run.finalState.beaconStorageHash).filter(Boolean)).size>1,transactionContentIdenticalAcrossModes:true,transactionHashesIdenticalAcrossModes:runs.every(r=>r.run.transactions.every((t,i)=>t.hash===reference.run.transactions[i].hash)),finalFingerprints:runs.map(r=>({mode:r.entry.mode,index:r.entry.index,...r.run.finalState}))},runs:runs.map(r=>r.metrics),aggregate:{}};
for(const mode of ['browser','direct']){const set=runs.filter(r=>r.entry.mode===mode);if(!set.length)continue;
  const frames=set.reduce((n,r)=>n+r.metrics.frames,0),elapsedMs=set.reduce((n,r)=>n+r.metrics.elapsedMs,0);
  const tx=set.flatMap(r=>r.tx),intervals=set.flatMap(r=>{const f=r.tx.map(t=>mode==='browser'?t.frame.canvasEndMs:t.receiptMs);return f.slice(1).map((v,i)=>v-f[i]);});
  const cpuTime=set.reduce((n,r)=>n+r.run.cpu.at(-1).cpuSeconds-r.run.cpu[0].cpuSeconds,0),cpuElapsed=set.reduce((n,r)=>n+r.metrics.cpu.elapsedMs,0);
  summary.aggregate[mode]={repetitions:set.length,frames,transactions:frames,elapsedMs,gameplayFPS:frames/(elapsedMs/1000),transactionsPerSecond:frames/(elapsedMs/1000),ticsPerSecond:frames/(elapsedMs/1000),slowdownFrom35Hz:35/(frames/(elapsedMs/1000)),frameIntervalsMs:distribution(intervals),transactionReceiptLatencyMs:distribution(tx.map(t=>t.receiptMs-t.submissionMs)),gasPerFrame:distribution(tx.map(t=>t.gasUsed)),anvilMeanCpuPercent:100*cpuTime/(cpuElapsed/1000),anvilPeakIntervalCpuPercent:Math.max(...set.map(r=>r.metrics.cpu.peakIntervalPercent)),peakRssKiB:Math.max(...set.map(r=>r.metrics.cpu.peakRssKiB)),componentsMs:Object.fromEntries(Object.keys(set[0].metrics.componentsMs).map(key=>[key,{mean:set.reduce((n,r)=>n+r.metrics.componentsMs[key].mean,0)/set.length,medianOfRunMedians:quantile(set.map(r=>r.metrics.componentsMs[key].median),.5)}]))};
  if(mode==='browser')summary.aggregate[mode].inputToCanvasMs=distribution(tx.map(t=>t.frame.canvasEndMs-t.tick.inputDispatchMs));
}
if(summary.aggregate.browser&&summary.aggregate.direct){const b=summary.aggregate.browser,d=summary.aggregate.direct;summary.observedDifference={directThroughputGainPercent:100*(d.gameplayFPS/b.gameplayFPS-1),browserExtraCycleTimeMs:b.elapsedMs/b.frames-d.elapsedMs/d.frames,pairedRuns:runs.filter(r=>r.entry.mode==='browser').map(r=>{const d=runs.find(x=>x.entry.mode==='direct'&&x.entry.index===r.entry.index);return {index:r.entry.index,browserFPS:r.metrics.gameplayFPS,directFPS:d.metrics.gameplayFPS,directGainPercent:100*(d.metrics.gameplayFPS/r.metrics.gameplayFPS-1)};})};}
await writeFile(join(dir,'summary.json'),JSON.stringify(summary,null,2)+'\n');
const csv=rows=>rows.map(row=>row.map(value=>value===undefined||value===null?'':String(value).includes(',')||String(value).includes('"')?'"'+String(value).replaceAll('"','""')+'"':String(value)).join(',')).join('\n')+'\n';
const signedWord=(data,offset)=>data?String(BigInt.asIntN(256,BigInt('0x'+data.slice(2+64*offset,66+64*offset)))):null;
const frameRows=[['mode','repetition','phase','input_seq','frame_id','gametic','leveltime','health','gas_used','status','submission_ms','send_response_ms','receipt_ms','cycle_complete_ms','input_dispatch_ms','event_processing_ms','canvas_start_ms','canvas_complete_ms','next_animation_frame_ms','direct_receipt_polls','pixel_sha256','palette_sha256','rgba_sha256']];
const cpuRows=[['mode','repetition','sample','node_monotonic_ms','elapsed_since_cpu_start_ms','cumulative_cpu_seconds','rss_kib','interval_cpu_percent','ps_reported_cpu_percent']];
for(const r of runs){for(const t of r.run.transactions)frameRows.push([r.entry.mode,r.entry.index,t.phase,t.inputSeq,t.frameId,signedWord(t.state?.gameStatus,0),signedWord(t.state?.gameStatus,1),signedWord(t.state?.gameStatus,2),t.gasUsed,t.status,t.submissionMs,t.sendResponseMs,t.receiptMs,t.tick?.tickEndMs??t.completionMs,t.tick?.inputDispatchMs,t.frame?.eventProcessingMs,t.frame?.canvasStartMs,t.frame?.canvasEndMs,t.frame?.nextAnimationFrameMs,t.receiptPolls,t.pixelSha256,t.paletteSha256,t.rgbaSha256]);
  for(let i=0;i<r.run.cpu.length;i++){const c=r.run.cpu[i],prev=r.run.cpu[i-1];cpuRows.push([r.entry.mode,r.entry.index,i,c.monotonicMs,c.monotonicMs-r.run.cpu[0].monotonicMs,c.cpuSeconds,c.rssKiB,prev?100*(c.cpuSeconds-prev.cpuSeconds)/((c.monotonicMs-prev.monotonicMs)/1000):null,c.psReportedCpuPercent??c.psLifetimeCpuPercent]);}}
await writeFile(join(dir,'frames.csv'),csv(frameRows));await writeFile(join(dir,'cpu.csv'),csv(cpuRows));
const files=['manifest.json','preflight.json','workload.json',...manifest.runs.map(r=>r.file),'summary.json','frames.csv','cpu.csv'];
if(storageAnchor)files.push(manifest.storageProofAnchor.file,manifest.storageProofAnchor.sourceManifest);
await writeFile(join(dir,'SHA256SUMS'),(await Promise.all(files.map(async f=>sha(await readFile(join(dir,f)))+'  '+f))).join('\n')+'\n');
console.log(JSON.stringify(summary.aggregate,null,2));console.log('PASS exact workload/Frame/palette/gas/exposed-state comparisons'+(diagnostic?'; diagnostic only':'; all captured DOOM storage roots equal (capture coverage recorded)'));
