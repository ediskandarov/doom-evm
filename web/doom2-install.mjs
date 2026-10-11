// SPDX-License-Identifier: GPL-2.0-only
// Retain BrowserInstaller's transactions, recovery, locks, storage and verification.
import {BrowserInstaller} from './install-engine.mjs';
import {word} from './install-resources.mjs';
import {DOOM2_PROFILE} from './doom2-profile.mjs';
import pins from './doom2-pins.mjs';
export class Doom2BrowserInstaller extends BrowserInstaller {
 constructor(options={}){super({...options,release:pins,profiles:[DOOM2_PROFILE],paletteUrl:'/doom2-assets/palette.json'});}
 async discover(){
  const found=await super.discover();
  if(found.installed&&BigInt(await this.call(found.game.address,'selectedMemoryProfile()'))!==BigInt(DOOM2_PROFILE.memoryProfile))throw Error('Installed DOOM II memory profile differs from the explicitly selected browser profile');
  return found;
 }
 async send(operation){
  // This adapter explicitly chooses the supported virtual API for interactive DOOM II.
  // Base BrowserInstaller still owns nonce reservation, exact calldata journaling,
  // canonical receipts, rollback and all recovery. No default contract behavior changes.
  if(operation.kind==='initialize'&&operation.data.startsWith('0x'+this.artifacts.Doom.methods['initializeMenu(bool)']))operation={...operation,data:'0x'+this.artifacts.Doom.methods['initializeMenuWithMemoryProfile(bool,uint8)']+operation.data.slice(10)+word(DOOM2_PROFILE.memoryProfile)};
  return super.send(operation);
 }
 async install(resources,profile=DOOM2_PROFILE){
  if(profile.id!=='doom2'||resources.resourceIdentity.bundleSha256!==DOOM2_PROFILE.bundleSha256)throw Error('Exact DOOM II deployment profile required');
  return super.install(resources,DOOM2_PROFILE);
 }
 configuration(game=this.journal.game){return {...super.configuration(game),profile:'doom2',mapRange:[1,32],memoryProfile:'virtual',initializationAPI:'initializeMenuWithMemoryProfile(bool,uint8)'};}
}
