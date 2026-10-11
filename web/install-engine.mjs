// SPDX-License-Identifier: GPL-2.0-only
import pins from './install-pins.mjs';
import {InstallStorage} from './install-storage.mjs';
import {sha256,hex,unhex,word,abiBytes,PROFILES} from './install-resources.mjs';
export const INSTALL_GAS=10000000000;
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
export function localEndpoint(value,origin=globalThis.location?.origin){
 const page=new URL(origin);
 if(!['http:','https:'].includes(page.protocol)||!['localhost','127.0.0.1','[::1]'].includes(page.hostname))throw Error('Installer must be served from localhost. Remote websites cannot control local Anvil.');
 const url=new URL(value);
 if(url.protocol!=='http:'||!['localhost','127.0.0.1','[::1]'].includes(url.hostname)||url.username||url.password||url.search||url.hash||url.pathname!=='/')throw Error('Use an HTTP localhost Anvil endpoint');
 return url.origin;
}
export function installerRpc(url){
 let id=0;
 return async(method,params=[])=>{
  const response=await fetch(url,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params}),signal:AbortSignal.timeout(300000)});
  if(!response.ok)throw Error(`RPC HTTP ${response.status}`);
  const body=await response.json();if(body.error)throw Error(`${method}: ${body.error.message}`);return body.result;
 };
}
export function expectedRuntime(artifact,driver){
 const runtime=unhex(artifact.runtime.slice(2));
 for(const spans of Object.values(artifact.immutableReferences??{}))for(const span of spans){
  if(span.length!==32||span.start+32>runtime.length)throw Error('Unexpected immutable artifact');
  runtime.set(unhex(word(driver)),span.start);
 }
 return '0x'+hex(runtime);
}
export class BrowserInstaller {
 constructor({storage=new InstallStorage(),onProgress=()=>{},rpcFactory=installerRpc,fetchArtifact=async url=>new Uint8Array(await(await fetch(url)).arrayBuffer()),release=pins,profiles=PROFILES,paletteUrl='/install-assets/palette.json'}={}){
  this.storage=storage;this.onProgress=onProgress;this.rpcFactory=rpcFactory;this.fetchArtifact=fetchArtifact;this.release=release;this.profiles=profiles;this.paletteUrl=paletteUrl;this.stopped=false;this.profile=profiles[0];
 }
 memoryPolicy(profile=this.profile){return profile.memoryProfile??profile.memoryPolicy;}
 memoryPolicyAPI(){return this.profile.memoryStatusAPI??'resourceMemoryPolicy()';}
 progress(stage,completed=0,total=0){this.onProgress({stage,completed,total,address:this.journal?.game?.address});}
 async save(){await this.storage.write(this.key,this.journal);}
 async artifact(name){
  const pin=this.release.artifacts[name],bytes=await this.fetchArtifact(pin.url);
  if(await sha256(bytes)!==pin.sha256)throw Error(`Precompiled ${name} artifact authentication failed`);
  return JSON.parse(new TextDecoder().decode(bytes));
 }
 async connect(endpoint,profile=this.profiles[0]){
  this.url=localEndpoint(endpoint);this.rpc=this.rpcFactory(this.url);
  this.progress('Checking local Anvil');
  const [client,chainId,genesis,accounts,block,info]=await Promise.all([
   this.rpc('web3_clientVersion'),this.rpc('eth_chainId'),this.rpc('eth_getBlockByNumber',['0x0',false]),this.rpc('eth_accounts'),this.rpc('eth_getBlockByNumber',['latest',false]),this.rpc('anvil_nodeInfo')
  ]);
  if(!/^anvil\//i.test(client)||chainId!=='0x7a69'||!info||String(info.hardFork).toLowerCase()!=='cancun'||info.forkConfig?.forkUrl)throw Error('A local Cancun Anvil with chain ID 31337 is required');
  if(!accounts?.length||!/^0x[\da-f]{40}$/i.test(accounts[0]))throw Error('Anvil unlocked development account unavailable');
  if(BigInt(block.gasLimit)<BigInt(INSTALL_GAS))throw Error('Anvil block gas budget must be at least 10 billion');
  if(BigInt(await this.rpc('eth_getBalance',[accounts[0],'latest']))<10n**18n)throw Error('Development account needs at least 1 ETH');
  this.driver=accounts[0].toLowerCase();this.chain={chainId,genesisHash:genesis.hash,client,info};
  this.artifacts={Doom:await this.artifact('Doom'),ResourceStore:await this.artifact('ResourceStore')};
  this.baseKey=[this.url,chainId,genesis.hash,this.driver,this.release.artifacts.Doom.sha256].join('|');
  await this.selectProfile(profile);
  this.progress('Connected');return this.chain;
 }
 async selectProfile(profile){
  if(!this.profiles.includes(profile))throw Error('Unknown IWAD profile');
  this.profile=profile;this.key=this.baseKey+'|'+profile.id+'|memory='+this.memoryPolicy();
  await this.exclusive(async()=>{
   this.journal=await this.storage.read(this.key)??this.fresh();
   if(this.journal.schemaVersion!==1)throw Error('Unsupported installation journal');
   if(this.journal.profile!==profile.id)throw Error('Installation journal profile mismatch');
   await this.reconcileChain();if(profile.available&&!this.journal.anchor&&!this.journal.pending)await this.discoverChain();
  });
 }
 fresh(){return {schemaVersion:1,profile:this.profile.id,memoryPolicy:this.memoryPolicy(),chain:this.chain,driver:this.driver,artifactSha256:this.release.artifacts.Doom.sha256,resources:{},game:null,pending:null,receipts:[],resetCount:0};}
 async reconcileChain(){
  if(this.journal.anchor){
   const block=await this.rpc('eth_getBlockByNumber',[this.journal.anchor.number,false]);
   if(block?.hash!==this.journal.anchor.hash){
    const count=this.journal.resetCount+1;
    // Preserve old evidence as a separate journal; never trust same-chainId state.
    await this.storage.write(this.key+'|orphan|'+this.journal.anchor.hash,this.journal);
    this.journal=this.fresh();this.journal.resetCount=count;await this.save();this.progress('Chain reset detected; installation must be rebuilt');
   }
  }
 }
 async discoverChain(){
  const latest=await this.rpc('eth_getBlockByNumber',['latest',false]);
  if(BigInt(latest.number)>10000n)throw Error('Local chain exceeds installation discovery window. Use a dedicated fresh Anvil or retain its installation journal.');
  const profile=this.profile;
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
     const paletteResponse=await fetch(this.paletteUrl);if(!paletteResponse.ok)throw Error('Release palette missing');
     const palette=await paletteResponse.json();
     const identity={schemaVersion:0,wadSha256:profile.wadSha256,bundleSha256:profile.bundleSha256,paletteSha256:'fd895921b5d0a394612bb29852ed003d44d69f76dec31c0dc6b5d5fc7d63f7bb',paletteVariant:0};
     if(await this.call(mined.contractAddress,'resourceIdentity()')!==this.identityData(identity))continue;
     const ready=BigInt(await this.call(mined.contractAddress,'menuMode()'))===1n;
     if(ready&&Number(BigInt(await this.call(mined.contractAddress,this.memoryPolicyAPI())))!==this.memoryPolicy())continue;
     if(!ready&&this.journal.game&&BigInt(await this.call(this.journal.game.address,'menuMode()'))===1n)continue;
     this.journal.game={address:mined.contractAddress,transactionHash:tx.hash,deploymentBlock:mined.blockNumber,identity,chunks,palette:{...palette,resourceIdentity:identity}};
    }
    if(!this.journal.anchor)this.journal.anchor={number:mined.blockNumber,hash:mined.blockHash};
   }
   if(n%100n===0n)this.progress('Discovering on-chain installation',Number(n),Number(BigInt(latest.number)));
  }
  await this.save();
 }
 async codeMatches(address,runtime){return !!address&&(await this.rpc('eth_getCode',[address,'latest'])).toLowerCase()===runtime.toLowerCase();}
 async discover(){
  await this.reconcileChain();
  if(this.journal.pending)await this.recoverPending(false);
  const game=this.journal.game;
  if(!game)return {installed:false,partial:Object.keys(this.journal.resources).length,pending:!!this.journal.pending};
  if(!await this.codeMatches(game.address,expectedRuntime(this.artifacts.Doom,this.driver)))throw Error('Installed game runtime differs from authenticated artifact');
  if(game.identity.wadSha256!==this.profile.wadSha256)throw Error('Installed game profile mismatch');
  const identity=await this.call(game.address,'resourceIdentity()');
  if(identity!==this.identityData(game.identity))throw Error('Installed game resource identity mismatch');
  const ready=BigInt(await this.call(game.address,'menuMode()'))===1n;
  if(ready&&Number(BigInt(await this.call(game.address,this.memoryPolicyAPI())))!==this.memoryPolicy())throw Error('Installed memory policy mismatch');
  const receipt=await this.rpc('eth_getTransactionReceipt',[game.transactionHash]);
  if(!receipt||receipt.status!=='0x1'||receipt.contractAddress?.toLowerCase()!==game.address.toLowerCase())throw Error('Game deployment receipt unavailable or invalid');
  // Recheck every resource before declaring an installation usable.
  for(let i=0;i<game.chunks.length;i++){
   const chunk=game.chunks[i],code=await this.rpc('eth_getCode',[chunk.address,'latest']);
   if(await sha256(unhex(code.slice(2)))!==chunk.digest)throw Error(`Installed resource ${i+1} is missing or corrupt`);
   if(i%100===0)this.progress('Verifying installed resources',i+1,game.chunks.length);
  }
  this.progress(ready?'Installation verified':'Game deployed; initialization pending',game.chunks.length,game.chunks.length);
  return {installed:ready,game,partial:game.chunks.length,pending:!!this.journal.pending};
 }
 identityData(identity){return '0x'+word(identity.schemaVersion)+identity.wadSha256+identity.bundleSha256+identity.paletteSha256+word(identity.paletteVariant);}
 call(address,signature){const selector=this.artifacts.Doom.methods[signature];if(!selector)throw Error('Missing method '+signature);return this.rpc('eth_call',[{from:this.driver,to:address,data:'0x'+selector,gas:'0x'+INSTALL_GAS.toString(16)},'latest']);}
 pause(){this.stopped=true;}
 async recoverPending(resubmit){
  const op=this.journal.pending;if(!op)return null;
  // First find the canonical mined operation by hash or exact sender/nonce/data.
  let receipt=op.hash?await this.rpc('eth_getTransactionReceipt',[op.hash]):null;
  if(!receipt){
   const latest=await this.rpc('eth_getBlockByNumber',['latest',false]);
   if(BigInt(latest.number)-BigInt(op.fromBlock)>10000n)throw Error('Uncertain transaction exceeds recovery scan window; inspect the local chain before retry');
   for(let n=BigInt(op.fromBlock);n<=BigInt(latest.number);n++){
    const block=await this.rpc('eth_getBlockByNumber',['0x'+n.toString(16),true]);
    const tx=block?.transactions.find(tx=>tx.from.toLowerCase()===this.driver&&BigInt(tx.nonce)===BigInt(op.nonce));
    if(tx){
     if(tx.input.toLowerCase()!==op.data.toLowerCase()||(tx.to??null)?.toLowerCase()!==(op.to??null)?.toLowerCase())throw Error('Uncertain nonce was used by a different transaction; installation requires inspection');
     op.hash=tx.hash;receipt=await this.rpc('eth_getTransactionReceipt',[tx.hash]);break;
    }
   }
  }
  if(receipt){
   const block=await this.rpc('eth_getBlockByNumber',[receipt.blockNumber,false]);
   if(block?.hash!==receipt.blockHash)throw Error('Transaction receipt is no longer canonical');
   if(receipt.status!=='0x1'){this.journal.pending=null;await this.save();throw Error('Installation transaction reverted; retry with compatible Anvil limits');}
   if(!this.journal.anchor)this.journal.anchor={number:receipt.blockNumber,hash:receipt.blockHash};
   // Persist completion before clearing uncertainty. The exact operation is
   // applied here, including after reload between mining and journal commit.
   if(op.kind==='chunk'){
    const code=await this.rpc('eth_getCode',[receipt.contractAddress,'latest']);
    if(await sha256(unhex(code.slice(2)))!==op.digest)throw Error('Resource CREATE verification failed');
    this.journal.resources[op.digest]={address:receipt.contractAddress,transactionHash:receipt.transactionHash};
   }else if(op.kind==='game'){
    if(!await this.codeMatches(receipt.contractAddress,expectedRuntime(this.artifacts.Doom,this.driver)))throw Error('Game CREATE verification failed');
    this.journal.game={address:receipt.contractAddress,transactionHash:receipt.transactionHash,deploymentBlock:receipt.blockNumber,identity:op.identity,chunks:op.chunks,palette:op.palette};
   }else if(op.kind==='initialize'){
    if(BigInt(await this.call(op.to,'menuMode()'))!==1n)throw Error('Menu initialization verification failed');
    if(op.memoryPolicy!==undefined&&Number(BigInt(await this.call(op.to,this.memoryPolicyAPI())))!==op.memoryPolicy)throw Error('Memory profile initialization verification failed');
   }
   this.journal.receipts.push({kind:op.kind,hash:receipt.transactionHash,blockNumber:receipt.blockNumber,blockHash:receipt.blockHash,gasUsed:receipt.gasUsed});
   this.journal.pending=null;await this.save();return receipt;
  }
  const mined=BigInt(await this.rpc('eth_getTransactionCount',[this.driver,'latest']));
  if(mined>BigInt(op.nonce))throw Error('Uncertain operation nonce consumed without a recoverable receipt; do not replay');
  if(op.hash){
   const tx=await this.rpc('eth_getTransactionByHash',[op.hash]);
   if(tx){if(!resubmit)return null;return this.waitPending();}
  }
  const pending=BigInt(await this.rpc('eth_getTransactionCount',[this.driver,'pending']));
  if(pending!==mined)throw Error('Anvil has pending transactions; mine or resolve them before retrying');
  if(!resubmit)return null;
  // Reuse the exact reserved nonce. Even if a timed-out submission arrives late,
  // at most one transaction with this sender/nonce can be mined.
  op.hash=await this.rpc('eth_sendTransaction',[{from:this.driver,nonce:op.nonce,data:op.data,gas:'0x'+INSTALL_GAS.toString(16),...(op.to?{to:op.to}:{})}]);
  await this.save();return this.waitPending();
 }
 async waitPending(){
  const end=Date.now()+300000;
  while(Date.now()<end){
   const op=this.journal.pending;
   if(!op)return null;
   if(op.hash&&await this.rpc('eth_getTransactionReceipt',[op.hash]))return this.recoverPending(false);
   if(this.stopped)throw Error('Installation paused. Retry will reconcile the pending transaction.');
   await delay(100);
  }
  throw Error('Receipt timeout. Retry will reconcile this transaction before continuing.');
 }
 async send(operation){
  if(this.stopped)throw Error('Installation paused. Resume when ready.');
  if(this.journal.pending)await this.recoverPending(true);
  const nonce=await this.rpc('eth_getTransactionCount',[this.driver,'latest']);
  if(nonce!==await this.rpc('eth_getTransactionCount',[this.driver,'pending']))throw Error('Resolve pending Anvil transactions before installing');
  const block=await this.rpc('eth_getBlockByNumber',['latest',false]);
  this.journal.pending={...operation,nonce,fromBlock:block.number,hash:null};
  await this.save();return this.recoverPending(true);
 }
 async install(resources,profile){
  if(!profile.available)throw Error(profile.reason);
  if(resources.resourceIdentity.wadSha256!==profile.wadSha256)throw Error('Selected profile identity mismatch');
  if(profile.id!==this.profile.id)throw Error('Select the installation profile before installing');
  this.stopped=false;await this.reconcileChain();
  if(this.journal.pending)await this.recoverPending(true);
  const existing=await this.discover();
  if(existing.installed)return this.configuration(existing.game);
  const addresses=[];
  for(let i=0;i<resources.chunks.length;i++){
   if(this.stopped)throw Error('Installation paused. Resume when ready.');
   const chunk=resources.chunks[i];this.progress('Uploading authenticated resources',i,resources.chunks.length);
   let cached=this.journal.resources[chunk.digest];
   if(cached&&!await this.codeMatches(cached.address,'0x'+hex(chunk.runtime))){delete this.journal.resources[chunk.digest];cached=null;}
   if(!cached){await this.send({kind:'chunk',digest:chunk.digest,data:this.artifacts.ResourceStore.bytecode+word(32)+abiBytes(chunk.payload)});cached=this.journal.resources[chunk.digest];}
   addresses.push({address:cached.address,digest:chunk.digest});
  }
  if(!this.journal.game){
   this.progress('Deploying authenticated DOOM contract',resources.chunks.length,resources.chunks.length);
   const array=word(addresses.length)+addresses.map(c=>word(c.address)).join('');
   await this.send({kind:'game',identity:resources.resourceIdentity,chunks:addresses,palette:resources.palette,data:this.artifacts.Doom.bytecode+word(64)+word(64+array.length/2)+array+abiBytes(resources.directory)});
  }
  const game=this.journal.game;
  if(BigInt(await this.call(game.address,'menuMode()'))!==1n){
   this.progress('Initializing EVM menu');
   const signature=profile.initializationAPI??'initializeMenuWithPolicy(bool,uint8)';
   await this.send({kind:'initialize',memoryPolicy:this.memoryPolicy(),to:game.address,data:'0x'+this.artifacts.Doom.methods[signature]+word(0)+word(this.memoryPolicy())});
  }
  const verified=await this.discover();if(!verified.installed)throw Error('Installation verification failed');
  return this.configuration(game);
 }
 configuration(game=this.journal.game){
  if(!game)throw Error('Install a game first');
  return {profile:this.profile.id,gameName:this.profile.name,memoryPolicy:this.memoryPolicy(),rpcUrl:this.url,wsUrl:this.url.replace('http:','ws:'),address:game.address,driver:this.driver,deploymentBlock:game.deploymentBlock,resourceIdentity:game.identity,palette:game.palette,paletteKind:'wad',gasLimit:INSTALL_GAS,rendererKind:'doom-world-view',gameplay:true,productionUI:true,rawKeyboard:true,episodeMode:true,menuMode:true,uiFullscreen:false};
 }
 async exclusive(task){
  if(!globalThis.navigator?.locks)throw Error('Browser Web Locks support is required to prevent concurrent installers');
  return navigator.locks.request('doom-evm-install|'+this.url,{ifAvailable:true},async lock=>{
   if(!lock)throw Error('Another tab is installing on this Anvil. Wait for it to finish.');
   // A different tab may have completed operations since this tab connected.
   // Re-read durable state only after acquiring endpoint ownership.
   if(this.key){const latest=await this.storage.read(this.key);if(latest)this.journal=latest;}
   return task();
  });
 }
}
