// SPDX-License-Identifier: GPL-2.0-only
import {BrowserInstaller,localEndpoint} from './install-engine.mjs';
import {PROFILES,prepareResources,authenticateIWAD} from './install-resources.mjs';
import {openMenu} from './menu-app.mjs';
export async function openLauncher(){
 const launcher=document.querySelector('#launcher'),status=document.querySelector('#install-status'),connection=document.querySelector('#connection'),profileSelect=document.querySelector('#game-profile'),file=document.querySelector('#iwad'),install=document.querySelector('#install'),play=document.querySelector('#play'),connect=document.querySelector('#connect'),pause=document.querySelector('#install-pause'),progress=document.querySelector('#install-progress'),endpoint=document.querySelector('#rpc-endpoint');
 launcher.hidden=false;document.querySelector('#frame').hidden=true;document.querySelector('#status').hidden=true;
 document.title='DOOM on EVM · Game launcher';
 const proof=window.__installationProof={connected:false,installed:false,events:[],errors:[]};
 let selected=PROFILES[0],resources,busy=false,connected=false,installed=false;
 const installer=new BrowserInstaller({onProgress:event=>{
  proof.events.push(event);if(proof.events.length>2500)proof.events.shift();
  status.textContent=event.stage+(event.total?` · ${event.completed} / ${event.total}`:'');
  progress.hidden=!event.total;if(event.total){progress.max=event.total;progress.value=event.completed;}
 }});
 window.installationClient={installer,get resources(){return resources;},prepare:prepareResources,profiles:PROFILES};
 const controls=()=>{
  connect.disabled=busy;endpoint.disabled=busy;profileSelect.disabled=busy;file.disabled=busy;
  file.hidden=!!selected.url;document.querySelector('#iwad-label').hidden=file.hidden;
  install.disabled=busy||!connected||!selected.available||installed||(!selected.url&&!resources);
  play.disabled=busy||!connected||!selected.available||!installed;
  pause.hidden=!busy;install.textContent=proof.errors.length?'Retry / resume installation':'Install / resume';
 };
 const fail=error=>{status.textContent=error.message;proof.errors.push(error.message);controls();};
 const task=async run=>{busy=true;controls();try{await run();}catch(error){fail(error);}finally{busy=false;controls();}};
 for(const p of PROFILES){const option=document.createElement('option');option.value=p.id;option.textContent=p.name+(p.available?'':' — unavailable');profileSelect.append(option);}
 const choose=()=>{
  selected=PROFILES.find(p=>p.id===profileSelect.value);resources=null;file.value='';
  installed=false;proof.installed=false;proof.localIWAD=null;
  document.querySelector('#profile-note').textContent=selected.available?'Episode One · original EVM menu and gameplay':selected.reason;
  status.textContent=selected.available?(installed?'Installation verified. Ready to play.':'Connect to your local Anvil, then install.'):'Profile unavailable. You can check a local IWAD identity.';
  controls();
 };
 profileSelect.addEventListener('change',()=>{choose();if(connected)task(async()=>{
  await installer.selectProfile(selected);
  const found=await installer.exclusive(()=>installer.discover());
  installed=found.installed;proof.installed=installed;proof.discovery=found;
  status.textContent=installed?'Installation verified. Ready to play.':`No complete installation.${found.partial?` ${found.partial} reusable resources found.`:''}`;
 });});choose();
 file.addEventListener('change',()=>task(async()=>{
  const local=file.files[0];if(!local)return;
  // File API bytes stay in browser memory and are never sent to a server.
  status.textContent='Verifying local IWAD…';
  const bytes=new Uint8Array(await local.arrayBuffer());
  const identity=await authenticateIWAD(bytes,selected);
  resources=selected.bundleSha256?await prepareResources(bytes,selected):null;
  proof.localIWAD={profile:selected.id,name:local.name,identity:resources?.resourceIdentity??identity,authenticated:true};
  status.textContent=`IWAD verified: ${selected.name}. ${selected.available?'Ready to install.':selected.reason}`;
 }));
 connect.addEventListener('click',()=>task(async()=>{
  connected=false;installed=false;proof.connected=false;proof.installed=false;
  localEndpoint(endpoint.value);await installer.connect(endpoint.value,selected);
  const found=await installer.exclusive(()=>installer.discover());
  connected=true;installed=found.installed;proof.connected=true;proof.installed=installed;proof.discovery=found;proof.chain=installer.chain;
  connection.textContent='Connected to local Anvil · 31337 · Cancun';
  status.textContent=installed?'Installation verified. Ready to play.':`No complete installation.${found.partial?` ${found.partial} resources found; resume to continue.`:''}`;
 }));
 install.addEventListener('click',()=>task(async()=>{
  await installer.exclusive(async()=>{
   if(!resources){
    if(!selected.url)throw Error('Choose and verify your local IWAD before installation.');
    status.textContent='Preparing authenticated Freedoom resources…';
    const response=await fetch(selected.url);if(!response.ok)throw Error('Freedoom resources unavailable. Ask the website maintainer to prepare the release package.');
    resources=await prepareResources(new Uint8Array(await response.arrayBuffer()),selected);
   }
   const config=await installer.install(resources,selected);
   installed=true;proof.installed=true;proof.config=config;status.textContent='Installation verified. Ready to play.';
  });
 }));
 pause.addEventListener('click',()=>installer.pause());
 play.addEventListener('click',()=>task(async()=>{
  await installer.exclusive(async()=>{
   const found=await installer.discover();if(!found.installed)throw Error('Installation changed; reconnect and resume.');
   const config=installer.configuration();
   // The original menu client exclusively owns gameplay inputs and presentation.
   launcher.hidden=true;document.querySelector('#frame').hidden=false;
   await openMenu(config);
  });
 }));
 controls();
 // Explicit connection is required. Never auto-connect to wallets or networks.
}
