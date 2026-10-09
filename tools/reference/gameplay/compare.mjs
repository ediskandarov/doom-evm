#!/usr/bin/env node
// SPDX-License-Identifier: GPL-2.0-only
// Actual original-gameplay state and live frame comparisons on ordinary local EVM.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {spawn,execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {gunzipSync,gzipSync} from 'node:zlib';
import {connect} from 'node:net';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {loadGasBudget,executionEnv} from '../../execution-budget.mjs';
const budget=loadGasBudget();
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../../..');process.chdir(root);
const args=process.argv.slice(2),option=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const cases=option('--cases','idle,movement,pistol,combat-arena,damage-arena,death-arena,door-use,door-obstructed,projectile-arena').split(',');
const limit=Number(option('--limit','Infinity')),batch=Number(option('--batch','5')),port=Number(option('--port','18577'));
const prefix=option('--output-prefix','artifacts/local/gameplay-evm');
assert(limit===Infinity||(Number.isInteger(limit)&&limit>=0),'invalid --limit');
assert(Number.isInteger(batch)&&batch>=1&&batch<=100);assert(Number.isInteger(port)&&port>1024&&port<65536);
await mkdir(dirname(prefix),{recursive:true});
const sha=data=>createHash('sha256').update(data).digest('hex');
const word=value=>BigInt.asUintN(256,BigInt(value)).toString(16).padStart(64,'0');
const tail=data=>word(data.length)+data.toString('hex').padEnd(Math.ceil(data.length/32)*64,'0');
const uint=(buf,pos)=>Number(BigInt('0x'+buf.subarray(pos,pos+32).toString('hex')));
const abiBytes=(buf,pos)=>{const off=uint(buf,pos),len=uint(buf,off);assert(off+32+len<=buf.length);return buf.subarray(off+32,off+32+len);};
function nativeStates(bytes){
  const data=gunzipSync(bytes),rows=[];let pos=0,previous=Buffer.alloc(0);
  while(pos<data.length){const size=data.readUInt32BE(pos);pos+=4;assert(size%4===0&&pos+size<=data.length);const state=Buffer.alloc(size);
    for(let i=0;i<size;i++)state[i]=data[pos+i]^(previous[i]??0);rows.push(state);previous=state;pos+=size;}
  return rows;
}
function nativePostStates(bytes){
  const data=gunzipSync(bytes),rows=new Map();let pos=0;
  while(pos<data.length){const tic=data.readUInt32BE(pos),size=data.readUInt32BE(pos+4);pos+=8;assert(size%4===0&&pos+size<=data.length);rows.set(tic,data.subarray(pos,pos+size));pos+=size;}
  return rows;
}
// Independent named DSG1 decoder: controls only comparison diagnostics, never simulation.
function fields(bytes){
  let pos=0;const rows=[];const one=name=>{assert(pos+4<=bytes.length,`truncated DSG1 at ${name}`);const value=bytes.readInt32BE(pos);rows.push({field:name,value,byte:pos});pos+=4;return value;};
  const group=(prefix,names)=>names.split(' ').forEach(name=>one(prefix+'.'+name));
  group('global','magic leveltime gametic prndindex rndindex gameaction secretexit totalkills totalitems totalsecret gameskill');
  group('player','mo playerstate viewz viewheight deltaviewheight bob health armorpoints armortype');
  for(let i=0;i<6;i++)one(`player.powers[${i}]`);for(let i=0;i<6;i++)one(`player.cards[${i}]`);one('player.backpack');
  for(let i=0;i<4;i++)one(`player.frags[${i}]`);group('player','readyweapon pendingweapon');
  for(let i=0;i<9;i++)one(`player.weaponowned[${i}]`);for(let i=0;i<4;i++){one(`player.ammo[${i}]`);one(`player.maxammo[${i}]`);}
  group('player','attackdown usedown cheats refire killcount itemcount secretcount damagecount bonuscount attacker extralight fixedcolormap colormap didsecret');
  for(let i=0;i<2;i++)group(`player.psprites[${i}]`,'state tics sx sy');
  const thinkers=one('thinkerCount');assert(thinkers>=0&&thinkers<65536);
  const special={2:'sector type topheight speed direction topwait topcountdown',3:'sector type crush direction newspecial texture floordestheight speed',4:'sector type bottomheight topheight speed crush direction tag olddirection',5:'sector speed low high wait count status oldstatus crush tag type',6:'sector count maxlight minlight maxtime mintime',7:'sector count minlight maxlight darktime brighttime',8:'sector minlight maxlight direction',9:'sector count maxlight minlight'};
  for(let i=0;i<thinkers;i++){
    const id=one(`thinkerOrder[${i}]`),base=`thinker[${id}]`,kind=one(base+'.kind');group(base,'callback prev next');
    if(kind===1)group(base+'.actor','x y z angle sprite frame floorz ceilingz radius height momx momy momz type tics state flags health movedir movecount target reactiontime threshold player lastlook tracer subsector snext sprev bnext bprev spawnpoint.x spawnpoint.y spawnpoint.angle spawnpoint.type spawnpoint.options');
    else {assert(special[kind],`unknown DSG1 thinker ${kind}`);group(base+'.special',special[kind]);}
  }
  const sectors=one('sectorCount');for(let i=0;i<sectors;i++)group(`sector[${i}]`,'floorheight ceilingheight floorpic ceilingpic lightlevel special tag soundtraversed soundtarget thinglist specialdata');
  const lines=one('lineCount');for(let i=0;i<lines;i++)group(`line[${i}]`,'flags special tag');
  const sides=one('sideCount');for(let i=0;i<sides;i++)group(`side[${i}]`,'textureoffset rowoffset toptexture bottomtexture midtexture');
  const blocks=one('blockCount');for(let i=0;i<blocks;i++)one(`block[${i}].head`);
  for(let i=0;i<16;i++)if(one(`button[${i}].btimer`))group(`button[${i}]`,'line where btexture');
  for(let i=0;i<30;i++)one(`activeplat[${i}]`);for(let i=0;i<30;i++)one(`activeceiling[${i}]`);
  const textures=one('textureCount');for(let i=0;i<textures;i++)one(`texturetranslation[${i}]`);
  const flats=one('flatCount');for(let i=0;i<flats;i++)one(`flattranslation[${i}]`);
  const head=one('iquehead'),tail=one('iquetail');for(let i=tail;i!==head;i=(i+1)&127)group(`itemqueue[${i}]`,'time x y angle type options');
  assert.equal(pos,bytes.length,'trailing DSG1 words');return rows;
}
function difference(expected,actual){
  if(expected.equals(actual))return null;
  const rows=fields(expected);let offset=0;while(offset<Math.min(expected.length,actual.length)&&expected[offset]===actual[offset])offset++;
  const at=Math.floor(offset/4)*4,record=rows.find(row=>row.byte===at);
  return {field:record?.field??'recordLength',byte:at,native:record?.value??null,evm:at+4<=actual.length?actual.readInt32BE(at):null,nativeBytes:expected.length,evmBytes:actual.length,nativeSha256:sha(expected),evmSha256:sha(actual)};
}
const bundle=JSON.parse(await readFile('artifacts/local/wad/bundle.json','utf8'));
const blob=await readFile('artifacts/local/wad/resources.bin'),directory=await readFile('test/fixtures/phase2_data/directory.bin');
assert.equal(sha(blob),bundle.blobSha256);
const native=JSON.parse(await readFile('test/fixtures/gameplay/manifest.json','utf8'));
const post=JSON.parse(await readFile('test/fixtures/gameplay_post/manifest.json','utf8'));assert.deepEqual(post.resourceIdentity,native.resourceIdentity);
assert.deepEqual(native.resourceIdentity,bundle.resourceIdentity);
const projectile=JSON.parse(await readFile('test/fixtures/gameplay_projectile/manifest.json','utf8'));
assert.deepEqual(projectile.resourceIdentity,bundle.resourceIdentity);
const fixtureDir=name=>name==='projectile-arena'?'test/fixtures/gameplay_projectile':`test/fixtures/gameplay/${name}`;
const fixtureHash=(name,leaf)=>name==='projectile-arena'?projectile.files[leaf]:native.files[name+'/'+leaf];
for(const name of cases){assert(name==='projectile-arena'||native.cases.some(row=>row.name===name),'unknown scenario '+name);
  assert.equal(sha(await readFile(fixtureDir(name)+'/states.delta.bin.gz')),fixtureHash(name,'states.delta.bin.gz'));}
if(args.includes('--decode-native-only')) {
  for(const name of cases){const rows=nativeStates(await readFile(fixtureDir(name)+'/states.delta.bin.gz'));for(const state of rows)fields(state);console.log(`PASS DSG1 schema ${name}: ${rows.length} records`);}
  process.exit(0);
}
if(!args.includes('--skip-build'))execFileSync(resolve('.toolchain/bin/forge'),['build','src/support/GameplayProbe.sol','src/evm/ResourceStore.sol'],{stdio:'inherit',timeout:600000,env:executionEnv()});
const artifact=JSON.parse(await readFile('out/GameplayProbe.sol/GameplayProbe.json','utf8')),chunk=JSON.parse(await readFile('out/ResourceStore.sol/ResourceStore.json','utf8'));
const method=name=>{const selector=artifact.methodIdentifiers[name];assert(selector,'missing probe method '+name);return '0x'+selector;};
const gas=budget.gasHex,url=`http://127.0.0.1:${port}`;let rpcId=0,server;
const report={kind:'original-gameplay-ordinary-evm-comparison',pass:false,scope:'Startup, authoritative logical world after every original tic, and only native-selected live frames. Direct ticcmds; test-only scenario setup.',resourceIdentity:bundle.resourceIdentity,gasLimit:budget.gasLimit,executionBudget:budget,notes:['Probe gas includes test-only DSG1 serialization and Observation events; this is not production Doom transaction cost.','The last source snapshot precedes selected rendering; renderer globals persist into subsequent real ticks.','No setCode, etch, alternate interpreter, or native-provided gameplay/pixels. Native bytes are comparison inputs only.'],cases:[],sourceHashes:{}};
async function rpc(method,params=[]){const response=await fetch(url,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++rpcId,method,params}),signal:AbortSignal.timeout(300000)});const result=await response.json();if(result.error)throw Object.assign(Error(`${method}: ${JSON.stringify(result.error)}`),{rpcError:result.error});return result.result;}
const sleep=ms=>new Promise(done=>setTimeout(done,ms));
async function waitFor(fn,label){for(let i=0;i<2400;i++){const value=await fn();if(value)return value;await sleep(50);}throw Error('Timeout '+label);}
async function transaction(from,data,to){const start=performance.now(),hash=await rpc('eth_sendTransaction',[{from,data,gas,...(to?{to}:{})}]);const r=await waitFor(()=>rpc('eth_getTransactionReceipt',[hash]),'receipt');assert.equal(r.status,'0x1',`EVM transaction reverted ${hash} gas ${BigInt(r.gasUsed)}`);return {receipt:r,ms:performance.now()-start};}
const scenarios={idle:0,movement:0,pistol:0,'combat-arena':1,'damage-arena':2,'death-arena':3,'door-use':4,'door-obstructed':5,'projectile-arena':6};
try{
  await new Promise((done,fail)=>{const socket=connect({host:'127.0.0.1',port});socket.once('connect',()=>{socket.destroy();fail(Error('Refusing occupied port'));});socket.once('error',error=>error.code==='ECONNREFUSED'?done():fail(error));});
  const nodeArgs=['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--disable-block-gas-limit','--memory-limit','1073741824','--silent'];
  server=spawn(resolve('.toolchain/bin/anvil'),nodeArgs,{stdio:['ignore','ignore','pipe']});let error='';server.stderr.on('data',data=>error+=data);server.on('error',e=>error+=e);
  await waitFor(async()=>{assert.equal(server.exitCode,null,error);try{return await rpc('web3_clientVersion');}catch{return false;}},'Anvil');
  await rpc('anvil_setBlockGasLimit',[gas]);const[from]=await rpc('eth_accounts');report.client=await rpc('web3_clientVersion');report.nodeArgs=nodeArgs;
  const addresses=[],uploadStart=performance.now();let chunkGas=0;
  for(let pos=0;pos<blob.length;pos+=16384){const bytes=blob.subarray(pos,pos+16384),r=(await transaction(from,chunk.bytecode.object+word(32)+tail(bytes))).receipt;chunkGas+=Number(BigInt(r.gasUsed));const code=await rpc('eth_getCode',[r.contractAddress,'latest']);assert.equal(code,'0x00'+bytes.toString('hex'));addresses.push(r.contractAddress);if(addresses.length%250===0)console.log(`Uploaded and exact verified ${addresses.length}/1755 chunks`);}
  assert.equal(addresses.length,1755);const uploadMs=performance.now()-uploadStart;
  const addr=word(addresses.length)+addresses.map(a=>a.slice(2).padStart(64,'0')).join('');
  const constructor=word(64)+word(64+addr.length/2)+addr+tail(directory);
  const deploy=(await transaction(from,artifact.bytecode.object+constructor)).receipt,address=deploy.contractAddress;
  assert.equal(await rpc('eth_getCode',[address,'latest']),artifact.deployedBytecode.object);
  report.deployment={address,transactionHash:deploy.transactionHash,gas:Number(BigInt(deploy.gasUsed)),runtimeBytes:(artifact.deployedBytecode.object.length-2)/2,all1755ResourceRuntimesVerified:true,uploadMs,totalChunkGas:chunkGas};
  report.compiler={version:artifact.metadata.compiler.version,settings:artifact.metadata.settings};
  for(const path of [...Object.keys(artifact.metadata.sources),'tools/reference/gameplay/compare.mjs','tools/reference/gameplay/observe.h','test/fixtures/gameplay/manifest.json','test/fixtures/gameplay_post/manifest.json','test/fixtures/gameplay_projectile/manifest.json','tools/reference/gameplay/post_render.py','tools/reference/gameplay/post_render_host.c','foundry.toml'])report.sourceHashes[path]=sha(await readFile(path));
  report.initialization={nativeZone:true,atomic:true,scope:'Each startup/reset runs original resource and level initialization in one call.'};
  for(const name of cases){
    const postBytes=await readFile(name==='projectile-arena'?fixtureDir(name)+'/post-render.bin.gz':`test/fixtures/gameplay_post/${name}.bin.gz`);assert.equal(sha(postBytes),name==='projectile-arena'?projectile.files['post-render.bin.gz']:post.files[name+'.bin.gz']);const postStates=nativePostStates(postBytes);
    const states=nativeStates(await readFile(fixtureDir(name)+'/states.delta.bin.gz'));fields(states[0]);
    const commandBytes=await readFile(fixtureDir(name)+'/commands.txt');assert.equal(sha(commandBytes),fixtureHash(name,'commands.txt'));
    const commands=commandBytes.toString('utf8').trim().split('\n').map(line=>line.split(' ').map(Number));
    const count=Math.min(limit,commands.length),caseReport={name,tics:0,frames:[],startup:false,batches:[]};report.cases.push(caseReport);
    const startupStart=performance.now();
    const initialHex=await rpc('eth_call',[{from,to:address,data:method('startup(uint8)')+word(scenarios[name]),gas},'latest']);
    const initial=abiBytes(Buffer.from(initialHex.slice(2),'hex'),0),diff=difference(states[0],initial);
    if(diff){report.firstDifference={case:name,tic:0,...diff};await writeFile(prefix+'.mismatch-native.bin',states[0]);await writeFile(prefix+'.mismatch-evm.bin',initial);throw Error(JSON.stringify(report.firstDifference));}
    caseReport.startup=true;caseReport.startupCallMs=performance.now()-startupStart;
    const startupTx=await transaction(from,method('startup(uint8)')+word(scenarios[name]),address);assert.equal(startupTx.receipt.logs.length,0);caseReport.startupGas=Number(BigInt(startupTx.receipt.gasUsed));
    console.log(`PASS ${name} startup DSG1: ${initial.length} bytes exact`);
    if(count===0)continue;
    const reset=await transaction(from,method('reset(uint8)')+word(scenarios[name]),address);caseReport.resetGas=Number(BigInt(reset.receipt.gasUsed));
    const observations=reset.receipt.logs.map(log=>decode(log));assert.equal(observations.length,1);assert.equal(observations[0].tic,0);assert.equal(difference(states[0],observations[0].state),null);
    const actual=[observations[0].state];
    for(let start=0;start<count;start+=batch){
      const rows=commands.slice(start,Math.min(start+batch,count)),packed=Buffer.alloc(rows.length*7);
      for(const[i,row]of rows.entries()){packed.writeInt8(row[0],i*7);packed.writeInt8(row[1],i*7+1);packed.writeInt16BE(row[2],i*7+2);packed[i*7+4]=row[3];packed[i*7+5]=row[4];}
      const result=await transaction(from,method('advance(bytes)')+word(32)+tail(packed),address);
      const obs=result.receipt.logs.map(log=>decode(log));assert.equal(obs.length,rows.length);
      for(const [i,row]of obs.entries()){
        const tic=start+i+1;assert.equal(row.tic,tic);const diff=difference(states[tic],row.state);actual.push(row.state);
        if(diff){report.firstDifference={case:name,tic,...diff};await writeFile(prefix+'.mismatch-native.bin',states[tic]);await writeFile(prefix+'.mismatch-evm.bin',row.state);throw Error(JSON.stringify(report.firstDifference));}
        if(commands[tic-1][4]){const expected=await readFile(fixtureDir(name)+`/frame-${String(tic).padStart(6,'0')}.bin`);assert.equal(sha(expected),fixtureHash(name,`frame-${String(tic).padStart(6,'0')}.bin`));assert.equal(row.pixels.length,64000);let differences=0,first=-1;for(let k=0;k<64000;k++)if(expected[k]!==row.pixels[k]){differences++;if(first<0)first=k;}
          if(differences){report.firstDifference={case:name,tic,field:'framebuffer',pixelDiffCount:differences,firstPixel:first,native:expected[first],evm:row.pixels[first]};await writeFile(prefix+'.mismatch-frame.bin',row.pixels);throw Error(JSON.stringify(report.firstDifference));}
          caseReport.frames.push({tic,pixelDiffCount:0,sha256:sha(row.pixels)});
        }else assert.equal(row.pixels.length,0);
        caseReport.tics=tic;
      }
      caseReport.batches.push({firstTic:start+1,tics:rows.length,transactionHash:result.receipt.transactionHash,gas:Number(BigInt(result.receipt.gasUsed)),ms:result.ms});
      if(caseReport.tics%25===0||caseReport.tics===count)console.log(`PASS ${name} ${caseReport.tics}/${count} authoritative tics, ${caseReport.frames.length} selected frames`);
    }
    const snapshot=abiBytes(Buffer.from((await rpc('eth_call',[{from,to:address,data:method('snapshot()'),gas},'latest'])).slice(2),'hex'),0);
    const expectedStored=commands[count-1][4]?postStates.get(count):states[count];assert(expectedStored,'missing exact native post-render observation');
    const storedDiff=difference(expectedStored,snapshot);
    if(storedDiff){report.firstDifference={case:name,tic:count,boundary:'stored after selected render',...storedDiff};await writeFile(prefix+'.mismatch-native.bin',expectedStored);await writeFile(prefix+'.mismatch-evm.bin',snapshot);throw Error(JSON.stringify(report.firstDifference));}
    caseReport.finalStoredState={boundary:commands[count-1][4]?'post-render':'post-tick',nativeSha256:sha(expectedStored),evmSha256:sha(snapshot),exact:true};
    const packed=Buffer.concat(actual.flatMap(state=>{const length=Buffer.alloc(4);length.writeUInt32BE(state.length);return [length,state];}));
    await writeFile(prefix+'.'+name+'.states.bin.gz',gzipSync(packed,{mtime:0}));caseReport.stateStreamSha256=sha(packed);
  }
  report.pass=true;report.completeNativeScenarioSet=cases.length===9&&new Set(cases).size===9&&report.cases.every(c=>c.tics===(c.name==='projectile-arena'?projectile.tics:native.cases.find(row=>row.name===c.name).tics))&&report.cases.reduce((n,c)=>n+c.tics,0)===2355&&report.cases.reduce((n,c)=>n+c.frames.length,0)===31;
  console.log(JSON.stringify({pass:true,completeNativeScenarioSet:report.completeNativeScenarioSet,cases:report.cases.map(({name,tics,frames})=>({name,tics,frames:frames.length}))}));
}catch(error){report.error=String(error);throw error;}finally{
  await writeFile(prefix+'.json',JSON.stringify(report,null,2)+'\n');
  if(server?.pid&&server.exitCode===null){await new Promise(done=>{server.once('exit',done);server.kill('SIGTERM');setTimeout(()=>{if(server.exitCode===null)server.kill('SIGKILL');},1500).unref();});}
}
function decode(log){assert.equal(log.address,report.deployment.address);const bytes=Buffer.from(log.data.slice(2),'hex');return {tic:uint(bytes,0),state:abiBytes(bytes,32),pixels:abiBytes(bytes,64)};}
