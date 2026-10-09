// SPDX-License-Identifier: GPL-2.0-only
import { stepData, makeRpc, receipt, FrameInbox, FrameSubscription, backfill, expandPalette } from './protocol.mjs';
import { validatePalette } from './palette.mjs';
const status=document.querySelector('#status'), button=document.querySelector('#step'), canvas=document.querySelector('#frame');
const proof=window.__transportProof={ready:false,frames:[],errors:[],fallbackVerified:false};
const fail=error=>{status.textContent=error.message;proof.errors.push(error.message);};
const hex=bytes=>[...bytes].map(x=>x.toString(16).padStart(2,'0')).join('');
let subscription, reconnectTimer, stopped=false, busy=false;
try {
  const config=await (await fetch('/config.local.json')).json();
  const rpc=makeRpc(config.rpcUrl);
  const palette=await (await fetch(config.paletteUrl)).json();
  const rgb=await validatePalette(palette,config.resourceIdentity,config.paletteKind??'synthetic');
  proof.paletteKind=palette.kind;proof.paletteSha256=palette.resourceIdentity.paletteSha256;
  let latestBlock=config.deploymentBlock;
  const inbox=new FrameInbox((frame,source)=>{
    canvas.width=frame.width;canvas.height=frame.height;
    canvas.getContext('2d').putImageData(new ImageData(expandPalette(frame,rgb),frame.width,frame.height),0,0);
    latestBlock=frame.log.blockNumber;
    proof.frames.push({frameId:String(frame.frameId),inputSeq:frame.inputSeq,source,transactionHash:frame.log.transactionHash,pixelBytes:frame.pixels.length});
    proof.latestPixelsHex=hex(frame.pixels);
    status.textContent=`Frame ${frame.frameId} · input ${frame.inputSeq} · ${frame.width}×${frame.height}\n64,000 indexed8 bytes · via ${source}\n${frame.log.transactionHash}`;
  });
  const reconnect=async()=>{
    try { await subscription.connect(); await backfill(rpc,config.address,latestBlock,inbox); }
    catch(error){if(!stopped)reconnectTimer=setTimeout(reconnect,1000); status.textContent=error.message;}
  };
  subscription=new FrameSubscription(config.wsUrl,config.address,log=>inbox.accept(log,'ws'),error=>{
    status.textContent=error.message;
    if(error.message.startsWith('Removed Frame')){stopped=true;button.disabled=true;subscription.close();return;}
    if(!stopped){clearTimeout(reconnectTimer);reconnectTimer=setTimeout(reconnect,1000);}
  });
  // Subscription acknowledgement precedes the first enabled input.
  await subscription.connect();
  await backfill(rpc,config.address,config.deploymentBlock,inbox);
  // Read the contract counter so reloading a local page cannot accidentally replay input 1.
  let sequence=Number(BigInt(await rpc('eth_call',[{to:config.address,data:'0x3464285a'},'latest'])));
  const nextFrame=async({disconnect=false}={})=>{
    if(busy)throw Error('Previous transaction still pending');
    if(stopped)throw Error('Session invalidated; reload after checking the local chain');
    busy=true;button.disabled=true;
    let settled=false;
    try {
      if(disconnect)subscription.close();
      const hash=await rpc('eth_sendTransaction',[{from:config.driver,to:config.address,data:stepData(sequence+1),gas:'0x3b9aca00'}]);
      const mined=await receipt(rpc,hash);
      settled=true;
      if(mined.status!=='0x1'||mined.logs.length!==1)throw Error('Frame transaction failed');
      inbox.accept(mined.logs[0],'receipt');sequence++;
      if(disconnect){proof.fallbackVerified=proof.frames.at(-1).source==='receipt';await subscription.connect();proof.backfilled=await backfill(rpc,config.address,config.deploymentBlock,inbox);}
      proof.duplicates=inbox.duplicates;return mined;
    } finally {
      // An ambiguous send/receipt timeout must not permit another input transaction.
      busy=!settled;button.disabled=busy||stopped;
    }
  };
  window.fixtureClient={nextFrame,config,inbox};
  button.addEventListener('click',()=>nextFrame().catch(fail));button.disabled=false;proof.ready=true;
  status.textContent='Subscribed. Send a frame to run the synthetic fixture in the EVM.';
  if(new URLSearchParams(location.search).has('autotest')) {
    await nextFrame(); await nextFrame({disconnect:true});
    proof.rgbaSha256=hex(new Uint8Array(await crypto.subtle.digest('SHA-256',canvas.getContext('2d').getImageData(0,0,320,200).data)));
    proof.done=true;
  }
} catch(error){fail(error);}
window.addEventListener('beforeunload',()=>{stopped=true;clearTimeout(reconnectTimer);subscription?.close();});
