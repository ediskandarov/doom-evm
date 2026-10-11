// SPDX-License-Identifier: GPL-2.0-only
// Independent read-only verification of every authoritative gameplay receipt.
import {readFile,writeFile} from 'node:fs/promises';
import {createReadStream} from 'node:fs';
import {createGunzip,gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
const sha=b=>createHash('sha256').update(b).digest('hex');
const readJSON=async p=>JSON.parse(await readFile(p,'utf8'));
const word=(b,n)=>Number(BigInt('0x'+b.subarray(n*32,(n+1)*32).toString('hex')));
for(const arg of process.argv.slice(2)){
 const out=resolve(arg),r=await readJSON(out+'/recording.json'),m=r.identity.map;
 assert(r.pass);const base=resolve(`artifacts/local/ultimate-speedruns/E1M${m}`+(m===8?'/alternatives/sedlo-046':''));
 const native=await readJSON(base+'/native-result.json');const txs=r.transactions.filter(t=>['startup','gameplay'].includes(t.kind));
 assert.equal(txs.length,native.executedTics+1);let previous=Buffer.alloc(0),pending=Buffer.alloc(0),tic=0,checkedBytes=0;
 const original=base+'/native-states.delta.bin.gz';
 for await(const chunk of createReadStream(original).pipe(createGunzip())){
  pending=Buffer.concat([pending,chunk]);let at=0;
  while(pending.length-at>=4){const n=pending.readUInt32BE(at);if(pending.length-at<4+n)break;at+=4;
   const state=Buffer.alloc(n);for(let i=0;i<n;i++)state[i]=pending[at+i]^(previous[i]??0);at+=n;
   assert(tic<txs.length);const t=txs[tic],raw=await readFile(out+'/'+t.file);assert.equal(sha(raw),t.receiptSha256);
   const receipt=JSON.parse(gunzipSync(raw));assert.equal(receipt.status,'0x1');assert.equal(receipt.transactionHash,t.hash);
   assert.equal(receipt.logs.length,1,'Exactly one original Observation per advance/startup');assert.equal(receipt.logs[0].address.toLowerCase(),r.address.toLowerCase());assert.equal(receipt.logs[0].topics.length,1);assert.equal(receipt.logs[0].topics[0],'0x1bcd7c504ce65cb0e1ca0714b557a70e360ff70ac6a995bc163a19bcf5ebf370');
   const data=Buffer.from(receipt.logs[0].data.slice(2),'hex');assert.equal(word(data,0),tic);
   const offset=word(data,1),length=word(data,offset/32);assert.equal(length,state.length);
   assert(data.subarray(offset+32,offset+32+length).equals(state),`Full canonical snapshot diverges at E1M${m} tic${tic}`);
   checkedBytes+=state.length;previous=state;tic++;
  }
  pending=pending.subarray(at);
 }
 assert.equal(pending.length,0);assert.equal(tic,txs.length);assert.equal(tic,r.nativeGameplayComparisons);
 const report={pass:true,map:m,matchingGameplaySnapshots:tic,fullSnapshotBytesCompared:checkedBytes,noFieldsMasked:true,comparison:'Every startup/advance Observation decoded independently from authenticated successful receipts and compared byte-for-byte with preserved native XOR-delta tape.',nativeStateTape:original,nativeStateTapeSHA256:sha(await readFile(original)),recordingManifestSHA256:sha(await readFile(out+'/recording.json')),originalInputTapeSHA256:r.identity.demoSha256};
 await writeFile(out+'/state-verification.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
}
