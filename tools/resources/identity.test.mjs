// SPDX-License-Identifier: GPL-2.0-only
// Requires the real package produced by the preceding verifier gate.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,mkdtemp,writeFile,symlink,rm} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {canonical,sha256} from '../wad/wad.ts';
const original=JSON.parse(await readFile('artifacts/local/wad/bundle.json','utf8'));
for(const [name,mutate,pattern] of [
  ['unknown manifest field',b=>{b.extra=true;},/extra extra/],
  ['forged manifest with stale identity',b=>{b.lumps[0].nameHex='0000000000000000';},/bundle manifest identity/],
  ['self-consistent unpinned resource identity',b=>{
    b.provenance.wadSha256='1'.repeat(64);b.resourceIdentity.wadSha256='1'.repeat(64);
    const manifest=Object.fromEntries(Object.entries(b).filter(([k])=>!['resourceIdentity','blobFile'].includes(k)));
    b.resourceIdentity.bundleSha256=sha256(canonical(manifest));
  },/pinned WAD package identity/]
])test(`placement benchmark rejects ${name} before starting Anvil`,async()=>{
  const folder=await mkdtemp(join(tmpdir(),'doom-resource-identity-'));
  try{
    const bundle=structuredClone(original);mutate(bundle);
    await symlink(resolve('artifacts/local/wad/resources.bin'),join(folder,'resources.bin'));
    const file=join(folder,'bundle.json');await writeFile(file,JSON.stringify(bundle));
    const result=spawnSync(process.execPath,['tools/resources/benchmark.mjs','--bundle',file],{encoding:'utf8',timeout:10000});
    assert.equal(result.status,1,result.stderr);assert.match(result.stderr,pattern);
  }finally{await rm(folder,{recursive:true,force:true});}
});
