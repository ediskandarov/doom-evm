// SPDX-License-Identifier: GPL-2.0-only
// Retain whole valid cohorts; never select individual fast frames or runs.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import assert from 'node:assert/strict';
const root=resolve('artifacts/benchmarks/doom2-map01-performance/results');
const load=async p=>JSON.parse(await readFile(join(root,p),'utf8'));
const browser=await load('ac/manifest.json'),direct=await load('matched-direct-ac/manifest.json'),anchor=await load('production-poll-ac/manifest.json');
assert(browser.pass&&direct.pass);
for(const key of ['sourceCommit','identity','methods','gas'])assert.deepEqual(browser[key],direct[key],key);
assert.deepEqual(browser.runtime.anvilArguments,direct.runtime.anvilArguments);
for(const key of ['count','reps','warmup'])assert.equal(browser.parameters[key],direct.parameters[key]);
for(const key of ['inputSequence','menu','started','memory','nonce'])assert.equal(browser.baseline[key],direct.baseline[key]);
assert.equal(direct.baseline.gameStorageHash,anchor.baseline.gameStorageHash);
const manifest={schemaVersion:1,pass:true,sourceCommit:browser.sourceCommit,parameters:{mode:'all',count:50,reps:3,warmup:3,requireAC:true,receiptPolicy:direct.parameters.receiptPolicy},identity:browser.identity,gas:browser.gas,config:browser.config,methods:browser.methods,runtime:browser.runtime,environment:{browser:browser.environment,direct:direct.environment},
  sourceManifests:['../ac/manifest.json','../matched-direct-ac/manifest.json'],
  chronology:'All three successful browser repetitions from the initial AC cohort are retained. They always used production receipt polling. All three final direct-only repetitions use the same production receipt waiter. These cohorts ran sequentially in separately owned Anvil instances with identical startup arguments and authenticated resources. No within-mode runs or slow samples were selected out. The final direct cohort follows the browser cohort, so order/thermal/cache bias remains a limitation.',
  storageProofAnchor:{file:'../production-poll-ac/browser-1.json',sourceManifest:'../production-poll-ac/manifest.json',scope:'This complete browser run passed receipt, Canvas and state inspection before a later browser run in its cohort aborted. It supplies a supplemental full DOOM storage/code proof, and is excluded from primary throughput pooling.'},
  runs:[...Array.from({length:3},(_,i)=>({mode:'browser',index:i+1,file:`../ac/browser-${i+1}.json`})),...Array.from({length:3},(_,i)=>({mode:'direct',index:i+1,file:`../matched-direct-ac/direct-${i+1}.json`}))]};
await mkdir(join(root,'primary'),{recursive:true});await writeFile(join(root,'primary/manifest.json'),JSON.stringify(manifest,(key,v)=>key==='rgbHex'?undefined:v,2)+'\n');
await writeFile(join(root,'primary/preflight.json'),JSON.stringify({browser:'../ac/preflight.json',direct:'../matched-direct-ac/preflight.json',supplementalProof:'../production-poll-ac/preflight.json',allEngineResourceCompilerPinsEqual:true,allAnvilStartupArgumentsEqual:true,allExposedLogicalBaselineViewsEqual:true,initialDoomStorageProofEqualForDirectAndSupplementalBrowser:true},null,2)+'\n');
await writeFile(join(root,'primary/workload.json'),await readFile(join(root,'ac/workload.json')));
console.log('Assembled all 3 browser and 3 matched-poll direct repetitions without sample selection.');
