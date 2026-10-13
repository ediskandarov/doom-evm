// SPDX-License-Identifier: GPL-2.0-only
// Canvas displays authenticated EVM Frame events; no host menu drawing or selection.
import { makeRpc, FrameInbox, FrameSubscription, backfill, expandPalette } from './protocol.mjs';
import { FramePresentation } from './ui-palette.mjs';
import { validatePalette } from './palette.mjs';
import { RawKeyboardInput, bindKeyboard } from './input.mjs';
import { GameplayLoop } from './input-loop.mjs';
import { MenuTransactions } from './menu-input.mjs';
import { heldKeyReleases, suspendWipeKeys } from './wipe-input.mjs';

export async function openMenu(config) {
  // The normal production player uses the menu/raw/Episode profile by default.
  // Explicit menuMode=false remains the legacy diagnostic/test opt-out.
  config.menuMode=true;config.episodeMode=true;config.productionUI=true;config.rawKeyboard=true;
  const canvas = document.querySelector('#frame'), status = document.querySelector('#status');
  const proof = window.__transportProof = { ready:false, rendererKind:'doom-world-view',gameplayAvailable:true,
    menuProfile:true, frames:[],inputs:[],errors:[],fallbackVerified:false };
  document.title = 'DOOM EVM · '+(config.gameName??'Freedoom');status.hidden=false;document.body.dataset.menu='true';
  for (const selector of ['.eyebrow','h1','.pill','body > p','#step']) document.querySelector(selector).hidden=true;
  canvas.setAttribute('aria-label','DOOM menu and gameplay rendered inside the EVM');canvas.tabIndex=0;
  const debug=document.createElement('details'), summary=document.createElement('summary');
  debug.id='debug';summary.textContent='Debug';debug.append(summary);status.before(debug);debug.append(status);
  const metrics=document.createElement('pre');metrics.id='debug-metrics';debug.append(metrics);
  const wipeNotice=document.createElement('div'), wipeText=document.createElement('span');
  wipeNotice.id='wipe-notice';wipeNotice.hidden=true;wipeNotice.setAttribute('aria-live','polite');
  const pauseWipe=document.createElement('button'), resumeWipe=document.createElement('button');
  pauseWipe.type=resumeWipe.type='button';pauseWipe.textContent='Pause transition';resumeWipe.textContent='Continue transition';
  wipeNotice.append(wipeText,pauseWipe,resumeWipe);canvas.after(wipeNotice);
  let subscription, reconnectTimer, stopped=false, loop, transactions, pendingPresentation=Promise.resolve(), wipePaused=false;
  const hex = bytes => [...bytes].map(n=>n.toString(16).padStart(2,'0')).join('');
  const fail = error => { status.textContent=error.message;proof.errors.push(error.message);debug.open=true; };
  const rpc=makeRpc(config.rpcUrl), palette=config.palette??await(await fetch(config.paletteUrl)).json();
  const rgb=await validatePalette(palette,config.resourceIdentity,config.paletteKind??'wad');
  proof.paletteKind=palette.kind;proof.paletteSha256=palette.resourceIdentity.paletteSha256;
  let latestBlock=config.deploymentBlock;
  const presentation=new FramePresentation(rpc,rgb,true,(frame,source,frameRGB,framePalette)=>{
    canvas.width=frame.width;canvas.height=frame.height;
    canvas.getContext('2d').putImageData(new ImageData(expandPalette(frame,frameRGB),frame.width,frame.height),0,0);
    latestBlock=frame.log.blockNumber;
    proof.frames.push({frameId:String(frame.frameId),inputSeq:frame.inputSeq,source,transactionHash:frame.log.transactionHash,pixelBytes:frame.pixels.length});
    proof.latestPixelsHex=hex(frame.pixels);proof.latestPalette={revision:framePalette.revision,palette:framePalette.palette,gamma:framePalette.gamma,rgbHex:hex(frameRGB)};
    status.textContent=`Frame ${frame.frameId} · input ${frame.inputSeq} · ${frame.width}×${frame.height}\n${frame.pixels.length} indexed8 bytes · via ${source}\n${frame.log.transactionHash}`;
  });
  const invalidate=()=>{stopped=true;presentation.invalidate();loop?.stop();transactions?.invalidate();subscription?.close();};
  const inbox=new FrameInbox((frame,source)=>{pendingPresentation=presentation.present(frame,source);pendingPresentation.catch(error=>{invalidate();fail(error);});});
  const reconnect=async()=>{try{await subscription.connect();await backfill(rpc,config.address,latestBlock,inbox);}catch(error){if(error.message.startsWith('Removed Frame')){invalidate();fail(error);return;}if(!stopped)reconnectTimer=setTimeout(reconnect,1000);}};
  subscription=new FrameSubscription(config.wsUrl,config.address,log=>inbox.accept(log,'ws'),error=>{
    status.textContent=error.message;if(error.message.startsWith('Removed Frame')){invalidate();fail(error);return;}
    if(!stopped){clearTimeout(reconnectTimer);reconnectTimer=setTimeout(reconnect,1000);}
  });
  await subscription.connect();await backfill(rpc,config.address,config.deploymentBlock,inbox);
  const update=()=>{proof.gameStarted=transactions?.started??false;proof.gameplayRunning=loop?.running??false;
    proof.wipe=transactions?.wipe??null;wipeNotice.hidden=!proof.wipe?.active;
    wipeText.textContent=`EVM melt · step ${proof.wipe?.progress??0}. Each frame requires a transaction; this can take minutes. Gameplay input is suspended. `;
    pauseWipe.disabled=!loop?.running;resumeWipe.disabled=!!loop?.running||!!transactions?.pending||!transactions?.canSend;
    metrics.textContent=`Gas budget: ${transactions?.gas??'loading'}\nInput sequence: ${transactions?.sequence??0}\nPending: ${transactions?.pending??false}`;};
  transactions=new MenuTransactions(rpc,config,inbox,{onState:update,onFrame:input=>{proof.inputs.push(input);proof.duplicates=inbox.duplicates;}});
  await transactions.load();proof.gasLimit=transactions.gas;proof.gasBudgetSource=transactions.gasSource;
  const keyboard=new RawKeyboardInput();
  loop=new GameplayLoop(transactions,keyboard,{onState:update,onError:fail});
  const binding=bindKeyboard(window,keyboard,document,{enabled:()=>loop.running&&!stopped&&!transactions.wipe?.active,onReset:()=>loop.stop()});
  pauseWipe.addEventListener('click',()=>{wipePaused=true;loop.stop();});
  resumeWipe.addEventListener('click',()=>{wipePaused=false;loop.start().catch(fail);});
  const resume=()=>{if(!wipePaused&&!document.hidden&&!stopped&&!loop.running&&!loop.starting&&!transactions.pending)loop.start().catch(fail);};
  window.addEventListener('focus',resume);document.addEventListener('visibilitychange',()=>{if(!document.hidden)resume();});
  canvas.addEventListener('pointerdown',()=>{canvas.focus();resume();});
  const startGame=async({run=true}={})=>{if(stopped)throw Error('Session invalidated');if(run)return loop.start();
    if(loop.running)throw Error('Stop continuous input before controlled startup');await transactions.startGame();update();return true;};
  const nextFrame=async({disconnect=false,buttons=0}={})=>{
    if(stopped)throw Error('Session invalidated');if(loop.running)throw Error('Stop continuous input before a manual frame');
    if(buttons!==0)throw Error('Use raw keyboard events for this deployment');
    if(disconnect&&transactions.wipe?.active)subscription.close();
    const packet=keyboard.packet();const active=transactions.wipe?.active;
    const result=active?await transactions.nextWipe():await transactions.nextEvents(packet,{beforeSend:disconnect?()=>subscription.close():undefined});
    if(!active)keyboard.acknowledge(packet.length);else suspendWipeKeys(keyboard);await pendingPresentation;
    if(disconnect){proof.fallbackVerified=proof.frames.at(-1).source==='receipt';await subscription.connect();proof.backfilled=await backfill(rpc,config.address,config.deploymentBlock,inbox);}
    proof.menu=await transactions.menuStatus();proof.duplicates=inbox.duplicates;return result;
  };
  const episodeControl=async(action,options={})=>{loop.stop();while(transactions.pending)await new Promise(done=>setTimeout(done,20));
    await transactions.load();const result=await transactions.episodeControl(action,options);await pendingPresentation;return result;};
  window.fixtureClient={nextFrame,config,inbox,startGame,episodeControl,stopGame:()=>loop.stop(),keyboard,transactions,loop};
  // Page load renders the EVM menu without an HTML launcher; reload reopens it.
  await transactions.startGame();const current=await transactions.menuStatus();
  if(transactions.wipe?.active)keyboard.events.push(...await heldKeyReleases(rpc,config.address));
  if(transactions.started&&!current.active&&!current.confirmation&&!transactions.wipe?.active)keyboard.events.push(0,27,1,27);
  await nextFrame();proof.ready=true;await loop.start();
  window.addEventListener('pagehide',()=>{binding.dispose();loop.stop();stopped=true;clearTimeout(reconnectTimer);subscription.close();},{once:true});
}
