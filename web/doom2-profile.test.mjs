// SPDX-License-Identifier: GPL-2.0-only
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {DOOM2_PROFILE,prepareDoom2Resources} from './doom2-profile.mjs';
import {Doom2BrowserInstaller} from './doom2-install.mjs';
import {word} from './install-resources.mjs';
import pins from './doom2-pins.mjs';
import {BrowserInstaller} from './install-engine.mjs';
test('DOOM II adapter authenticates exact packing and resource dimensions',async()=>{
 const path=process.env.DOOM2_WAD??process.env.HOME+'/Downloads/doom-steam/base/doom2/DOOM2.WAD';const bytes=new Uint8Array(await readFile(path));
 const r=await prepareDoom2Resources(bytes);assert.equal(r.resourceIdentity.bundleSha256,DOOM2_PROFILE.bundleSha256);assert.equal(r.chunks.length,889);assert.equal(r.directory.length,2919*16);
 assert.deepEqual(r.palette.resourceIdentity,r.resourceIdentity);const bad=bytes.slice();bad[bad.length-1]^=1;await assert.rejects(()=>prepareDoom2Resources(bad),/IWAD identity/);
});
test('DOOM II release profile explicitly requests virtual pointers without changing shared installer',async()=>{
 assert.equal(DOOM2_PROFILE.memoryProfile,3);assert.equal(DOOM2_PROFILE.initializationAPI,'initializeMenuWithMemoryProfile(bool,uint8)');
 const installer=new Doom2BrowserInstaller({fetchArtifact:async url=>new Uint8Array(await readFile('web'+url))});
 const a=await installer.artifact('Doom');assert(a.methods[DOOM2_PROFILE.initializationAPI]);assert(a.methods['initializeMenu(bool)']);
 assert.equal(pins.profile,'doom2');assert.equal(pins.memoryProfile,3);
 installer.chain={chainId:'0x7a69',genesisHash:'genesis'};installer.driver='driver';installer.artifacts={Doom:a};installer.url='http://127.0.0.1:19071';
 const previous=BrowserInstaller.prototype.send;BrowserInstaller.prototype.send=async operation=>operation;
 try{const actual=await installer.send({kind:'initialize',data:'0x'+a.methods['initializeMenu(bool)']+word(0)});assert.equal(actual.data,'0x'+a.methods[DOOM2_PROFILE.initializationAPI]+word(0)+word(3));const chunk={kind:'chunk',data:'0x1234'};assert.deepEqual(await installer.send(chunk),chunk);}finally{BrowserInstaller.prototype.send=previous;}

 await assert.rejects(()=>installer.install({resourceIdentity:{bundleSha256:'wrong'}},DOOM2_PROFILE),/Exact DOOM II/);
});

test('DOOM II discovery refuses a ready installation using a different memory policy',async()=>{
 const installer=new Doom2BrowserInstaller();const previous=BrowserInstaller.prototype.discover;
 BrowserInstaller.prototype.discover=async()=>({installed:true,game:{address:'0x1234'}});
 try{installer.call=async()=> '0x'+word(2);await assert.rejects(()=>installer.discover(),/memory profile differs/);installer.call=async()=> '0x'+word(3);assert.equal((await installer.discover()).installed,true);}finally{BrowserInstaller.prototype.discover=previous;}
});
