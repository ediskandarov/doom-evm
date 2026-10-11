// SPDX-License-Identifier: GPL-2.0-only
// Audit the existing original-C initial-zero-zone profile without changing failed gates.
import {readFile,writeFile} from 'node:fs/promises';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {resolve} from 'node:path';
import {fields} from '../speedrun/dsg1.mjs';
const base=resolve(process.argv[2]);const json=async p=>JSON.parse(await readFile(p,'utf8'));
const sha=b=>createHash('sha256').update(b).digest('hex');const n=await json(base+'/native-result.json');
const profileBytes=async p=>gunzipSync(await readFile(base+'/native-'+p+'/states.bin.gz'));
const reference=await profileBytes('O2');assert.equal(sha(reference),n.statesSha256);
const profiles=[];
for(const name of ['O2','O0','sanitize','sanitize-fill']) {
 const p=n.profiles.find(p=>p.profile===name);assert(p&&p.returncode===0);
 const stdout=await readFile(base+'/native-'+name+'/stdout.log','utf8');const stderr=await readFile(base+'/native-'+name+'/stderr.log');assert.equal(stderr.length,0);
 const exits=[...stdout.matchAll(/SPEEDRUN_EXIT (\d+) (\d+) (\d+) (\d+) (-?\d+)/g)].map(m=>m.slice(1).map(Number));
 assert.equal(exits.length,1);assert.equal(exits[0][0],n.executedTics);assert.equal(exits[0][2],6);
 const bytes=await profileBytes(name);const digest=sha(bytes);
 if(name!=='sanitize-fill')assert.equal(digest,sha(reference));
 profiles.push({name,statesSha256:digest,exit:exits[0],allStateBytesEqual:digest===sha(reference)});
}
const filled=await profileBytes('sanitize-fill');let at=0,bt=0,tic=0;const differingFields=new Map();let firstDifference;
while(at<reference.length&&bt<filled.length){
 const al=reference.readUInt32BE(at),bl=filled.readUInt32BE(bt);assert.equal(al,bl);
 const a=reference.subarray(at+4,at+4+al),b=filled.subarray(bt+4,bt+4+bl);
 if(!a.equals(b)) {
  const fa=fields(a),fb=fields(b);assert.equal(fa.length,fb.length);
  for(let i=0;i<fa.length;i++)if(fa[i].value!==fb[i].value){
   assert.equal(fa[i].field,fb[i].field);const field=fa[i].field;
   assert(/^thinker\[\d+\]\.special\.(type|crush|low)$/.test(field),'Unclassified native divergence: '+field);
   assert.equal(fa[i].value,0);assert.equal(fb[i].value,-1515870811);
   firstDifference??={tic,field,initialZero:fa[i].value,freshFill:fb[i].value};
   differingFields.set(field,(differingFields.get(field)??0)+1);
  }
 }
 at+=4+al;bt+=4+bl;tic++;
}
assert.equal(at,reference.length);assert.equal(bt,filled.length);assert.equal(tic,n.executedTics+1);
const sources={};for(const file of ['original/DOOM/linuxdoom-1.10/p_floor.c','original/DOOM/linuxdoom-1.10/p_plats.c','tools/reference/gameplay/host.c','tools/reference/episode_startup/reference.py','tools/reference/ultimate_speedruns/native-domain.mjs'])sources[file]=sha(await readFile(file));
const result={pass:true,profile:'initial-zero-zone',scope:'Pinned original C with existing64MiB calloc zone, no fresh-allocation fill; full O2/O0/ASan-UBSan DSG1 equality. Alternate fresh0xa5 allocation diagnostic is preserved separately and remains failed where original stair/platform fields are uninitialized.',demoSha256:n.demoSha256,wadSha256:n.wadSha256,nativeStatesSha256:n.statesSha256,nativeResultSha256:sha(await readFile(base+'/native-result.json')),gameplayObservations:tic,profiles,firstDifference,differingFields:[...differingFields].map(([field,observations])=>({field,observations})),originalSources:[{function:'EV_BuildStairs',file:'p_floor.c',span:[453,554],cause:'Original stairs never initialize type or crush; T_MoveFloor and the observer read them.'},{function:'EV_DoPlat',file:'p_plats.c',span:[139,277],cause:'raiseAndChange and raiseToNearestAndChange never initialize low; the observer serializes it. The field is irrelevant while the raising platform completes normally.'}],sourceHashes:sources,allAllocationProfilesExact:n.allProfilesExact,limitations:'Finite equality to the declared existing native profile; no universal native allocation equivalence. No field is masked in EVM comparison; no source, tape, fixture, state or provenance check is changed.'};
await writeFile(base+'/native-domain.json',JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({pass:true,profile:result.profile,observations:tic,firstDifference,fields:differingFields.size}));
