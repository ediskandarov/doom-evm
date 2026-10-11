// SPDX-License-Identifier: GPL-2.0-only
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {GAME_PROFILES,createGameInstaller} from './browser-profiles.mjs';
import {word} from './install-resources.mjs';
import {BrowserInstaller} from './install-engine.mjs';
test('three production games select their authenticated release and explicit policy API',async()=>{
 assert.deepEqual(GAME_PROFILES.map(p=>p.id),['freedoom','ultimate','doom2']);
 const releases=[];
 for(const profile of GAME_PROFILES){
  assert.equal(profile.available,true);
  const i=createGameInstaller(profile,{fetchArtifact:async url=>new Uint8Array(await readFile('web'+url))});
  i.profile=profile;
  const a=await i.artifact('Doom');
  assert.equal(i.memoryPolicy(),3);assert(a.methods[profile.initializationAPI??'initializeMenuWithPolicy(bool,uint8)']);
  assert(a.methods[i.memoryPolicyAPI()]);assert(a.methods['initializeMenu(bool)']);
  releases.push(i.release.artifacts.Doom.sha256);
 }
 assert.equal(releases[0],releases[1]);assert.notEqual(releases[0],releases[2]);
 assert.throws(()=>createGameInstaller({id:'doom2'}),/Unknown game/);
});
test('shared explicit DOOM II initialization keeps exactly two arguments',async()=>{
 const i=createGameInstaller(GAME_PROFILES[2]);
 // Supply the authenticated release without a browser fetch dependency.
 i.artifacts={Doom:JSON.parse(await readFile('web/doom2-assets/Doom.json','utf8'))};
 const data='0x'+i.artifacts.Doom.methods['initializeMenuWithMemoryProfile(bool,uint8)']+word(0)+word(3);
 const previous=BrowserInstaller.prototype.send;BrowserInstaller.prototype.send=async op=>op;
 try{assert.equal((await i.send({kind:'initialize',memoryPolicy:3,data})).data,data);}finally{BrowserInstaller.prototype.send=previous;}
});
test('DOOM II profile key and explicit initializer survive shared deployment manager adaptation',async()=>{
 const profile=GAME_PROFILES[2],data=new Map(),i=createGameInstaller(profile,{storage:{read:async k=>structuredClone(data.get(k)),write:async(k,v)=>data.set(k,structuredClone(v))}});
 const old=Object.getOwnPropertyDescriptor(navigator,'locks');
 Object.defineProperty(navigator,'locks',{configurable:true,value:{request:async(name,options,task)=>task({name})}});
 try{
  i.url='http://localhost:8545';i.baseKey='release';i.chain={chainId:'0x7a69'};i.driver='driver';i.reconcileChain=async()=>{};i.discoverChain=async()=>{};
  await i.selectProfile(profile);assert.equal(i.key,'release|doom2|memory=3');assert.equal(i.journal.profile,'doom2');assert.equal(i.journal.memoryPolicy,3);
  i.journal.game={address:'doom2'};await i.save();await i.selectProfile(profile);assert.equal(i.journal.game.address,'doom2');
  assert.equal(i.configuration().memoryPolicy,3);assert.equal(i.configuration().mapRange[1],32);
  await assert.rejects(()=>i.selectProfile(GAME_PROFILES[0]),/Unknown IWAD/);
 }finally{if(old)Object.defineProperty(navigator,'locks',old);else delete navigator.locks;}
});
