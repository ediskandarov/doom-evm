// SPDX-License-Identifier: GPL-2.0-only
// Retain BrowserInstaller's transactions, recovery, locks, storage and verification.
import {BrowserInstaller,expectedRuntime} from './install-engine.mjs';
import {sha256,unhex,word} from './install-resources.mjs';
import {DOOM2_PROFILE} from './doom2-profile.mjs';
import pins from './doom2-pins.mjs';
export class Doom2BrowserInstaller extends BrowserInstaller {
 async artifact(name){
  const pin=pins.artifacts[name],bytes=await this.fetchArtifact(pin.url);
  if(await sha256(bytes)!==pin.sha256)throw Error(`Precompiled DOOM II ${name} artifact authentication failed`);
  return JSON.parse(new TextDecoder().decode(bytes));
 }
 fresh(){return {...super.fresh(),artifactSha256:pins.artifacts.Doom.sha256,profile:'doom2'};}
 async exclusive(task){
  // super.connect establishes endpoint/chain/driver before taking the lock. Select
  // the profile release key before its first journal read, and on all later locks.
  if(this.chain&&this.artifacts)this.key=[this.url,this.chain.chainId,this.chain.genesisHash,this.driver,pins.artifacts.Doom.sha256,'doom2|virtual'].join('|');
  return super.exclusive(task);
 }
 async discover(){
  const found=await super.discover();
  if(found.installed&&BigInt(await this.call(found.game.address,'selectedMemoryProfile()'))!==BigInt(DOOM2_PROFILE.memoryProfile))throw Error('Installed DOOM II memory profile differs from the explicitly selected browser profile');
  return found;
 }
 async send(operation){
  // This adapter explicitly chooses the supported virtual API for interactive DOOM II.
  // Base BrowserInstaller still owns nonce reservation, exact calldata journaling,
  // canonical receipts, rollback and all recovery. No default contract behavior changes.
  if(operation.kind==='initialize')operation={...operation,data:'0x'+this.artifacts.Doom.methods['initializeMenuWithMemoryProfile(bool,uint8)']+operation.data.slice(10)+word(DOOM2_PROFILE.memoryProfile)};
  return super.send(operation);
 }
 async install(resources,profile=DOOM2_PROFILE){
  if(profile.id!=='doom2'||resources.resourceIdentity.bundleSha256!==DOOM2_PROFILE.bundleSha256)throw Error('Exact DOOM II deployment profile required');
  return super.install(resources,DOOM2_PROFILE);
 }
 configuration(game=this.journal.game){return {...super.configuration(game),profile:'doom2',mapRange:[1,32],memoryProfile:'virtual',initializationAPI:'initializeMenuWithMemoryProfile(bool,uint8)'};}
 async discoverChain(){
  const latest=await this.rpc('eth_getBlockByNumber',['latest',false]);
  if(BigInt(latest.number)>10000n)throw Error('Local chain exceeds installation discovery window. Use a dedicated fresh Anvil or retain its installation journal.');
  const profile=DOOM2_PROFILE;
  for(let n=0n;n<=BigInt(latest.number);n++){
   const block=await this.rpc('eth_getBlockByNumber',['0x'+n.toString(16),true]);
   if(!block)throw Error('Chain history unavailable for installation discovery');
   for(const tx of block.transactions){
    if(tx.to||tx.from.toLowerCase()!==this.driver)continue;
    const store=this.artifacts.ResourceStore.bytecode,doom=this.artifacts.Doom.bytecode;
    if(!tx.input.startsWith(store)&&!tx.input.startsWith(doom))continue;
    const mined=await this.rpc('eth_getTransactionReceipt',[tx.hash]);
    if(!mined||mined.status!=='0x1'||mined.blockHash!==block.hash)continue;
    const code=await this.rpc('eth_getCode',[mined.contractAddress,'latest']);
    if(tx.input.startsWith(store)){
     // Decode this release's ordinary ResourceStore(bytes) constructor. Never
     // trust bytecode prefixes alone: prove every runtime byte as well.
     const data=tx.input.slice(store.length),offset=Number(BigInt('0x'+data.slice(0,64))),length=Number(BigInt('0x'+data.slice(64,128)));
     if(offset!==32||length>16384||data.length!==128+Math.ceil(length/32)*64)continue;
     const runtime='0x00'+data.slice(128,128+length*2);
     if(code.toLowerCase()!==runtime.toLowerCase())continue;
     const digest=await sha256(unhex(code.slice(2)));
     this.journal.resources[digest]={address:mined.contractAddress,transactionHash:tx.hash};
    }else if(code.toLowerCase()===expectedRuntime(this.artifacts.Doom,this.driver).toLowerCase()){
     const data=tx.input.slice(doom.length),value=byte=>Number(BigInt('0x'+data.slice(byte*2,(byte+32)*2)));
     const arrayOffset=value(0),directoryOffset=value(32),count=value(arrayOffset),directoryLength=value(directoryOffset);
     if(arrayOffset!==64||count!==profile.chunks||directoryOffset!==96+count*32||directoryLength!==profile.lumps*16)continue;
     const directory=unhex(data.slice((directoryOffset+32)*2,(directoryOffset+32+directoryLength)*2));
     if(await sha256(directory)!==profile.directorySha256)continue;
     const chunks=[];
     for(let i=0;i<count;i++){
      const address='0x'+data.slice((arrayOffset+32+i*32)*2+24,(arrayOffset+64+i*32)*2);
      const code=await this.rpc('eth_getCode',[address,'latest']);
      chunks.push({address,digest:await sha256(unhex(code.slice(2)))});
     }
     const paletteResponse=await fetch('/doom2-assets/palette.json');if(!paletteResponse.ok)throw Error('Release palette missing');
     const palette=await paletteResponse.json();
     const identity={schemaVersion:0,wadSha256:profile.wadSha256,bundleSha256:profile.bundleSha256,paletteSha256:'fd895921b5d0a394612bb29852ed003d44d69f76dec31c0dc6b5d5fc7d63f7bb',paletteVariant:0};
     if(await this.call(mined.contractAddress,'resourceIdentity()')!==this.identityData(identity))continue;
     this.journal.game={address:mined.contractAddress,transactionHash:tx.hash,deploymentBlock:mined.blockNumber,identity,chunks,palette};
    }
    if(!this.journal.anchor)this.journal.anchor={number:mined.blockNumber,hash:mined.blockHash};
   }
   if(n%100n===0n)this.progress('Discovering on-chain installation',Number(n),Number(BigInt(latest.number)));
  }
  await this.save();
 }
}
