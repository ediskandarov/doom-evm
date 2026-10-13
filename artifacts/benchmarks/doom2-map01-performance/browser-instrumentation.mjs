// SPDX-License-Identifier: GPL-2.0-only
// Observation and deterministic DOM input only; production scheduling stays intact.
export async function installBrowserProbe(workload) {
  const {GameplayLoop}=await import('/input-loop.mjs');
  const {FramePresentation}=await import('/ui-palette.mjs');
  const {FrameInbox}=await import('/protocol.mjs');
  const b=window.__bench={workload,frames:[],rpc:[],ticks:[],done:false,error:null,index:0};
  const now=()=>performance.now();
  const originalFetch=window.fetch;
  window.fetch=async function(url,options){
    let body;try{body=JSON.parse(options?.body);}catch{}
    if(!body?.method)return originalFetch.apply(this,arguments);
    const sample={method:body.method,startMs:now(),params:body.method==='eth_sendTransaction'?body.params:undefined};b.rpc.push(sample);
    try{
      const response=await originalFetch.apply(this,arguments);
      sample.headersMs=now();
      const originalJson=response.json.bind(response);
      response.json=async()=>{const value=await originalJson();sample.endMs=now();sample.error=value.error??null;
        if(body.method==='eth_sendTransaction')sample.hash=value.result;
        if(body.method==='eth_getTransactionReceipt'&&value.result){sample.hash=value.result.transactionHash;sample.receipt=value.result;}
        return value;};return response;
    }catch(e){sample.endMs=now();sample.error=e.message;throw e;}
  };
  const accept=FrameInbox.prototype.accept;
  FrameInbox.prototype.accept=function(log,source){const start=now();const result=accept.apply(this,arguments);
    if(result){const f=b.frames.find(f=>f.hash===log.transactionHash);if(f){f.inboxStartMs=start;f.inboxEndMs=now();}}return result;};
  const present=FramePresentation.prototype.present;
  FramePresentation.prototype.present=function(frame,source){
    const sample={hash:frame.log.transactionHash,frameId:String(frame.frameId),inputSeq:frame.inputSeq,source,eventProcessingMs:now()};b.frames.push(sample);
    if(!this.__benchWrapped){const callback=this.onFrame;this.onFrame=function(){
      const f=b.frames.find(f=>f.hash===arguments[0].log.transactionHash);b.paint=f;f.paletteReadyMs=now();
      try{return callback.apply(this,arguments);}finally{f.callbackEndMs=now();b.paint=null;}
    };this.__benchWrapped=true;}
    return present.apply(this,arguments);
  };
  const paint=CanvasRenderingContext2D.prototype.putImageData;
  CanvasRenderingContext2D.prototype.putImageData=function(){const f=b.paint;if(f)f.canvasStartMs=now();const result=paint.apply(this,arguments);
    if(f){f.canvasEndMs=now();requestAnimationFrame(()=>{f.nextAnimationFrameMs=now();});}return result;};
  const tick=GameplayLoop.prototype._tick;
  GameplayLoop.prototype._tick=async function(epoch){
    if(b.done)return;
    if(!this.running||epoch!==this.epoch)return tick.apply(this,arguments);
    const index=b.index, item=workload[index];if(!item){b.error='Unexpected benchmark tick';b.done=true;this.stop();return;}b.index++;
    const t={index,phase:item.phase,inputDispatchMs:now(),sequence:this.transactions.sequence+1};b.ticks.push(t);
    for(const [type,code] of item.keys)window.dispatchEvent(new KeyboardEvent(type,{code,bubbles:true,cancelable:true}));
    t.events=Array.from(this.keyboard.packet());t.tickStartMs=now();
    await tick.apply(this,arguments);t.tickEndMs=now();
    if(window.__transportProof.errors.length){b.error=window.__transportProof.errors.join('\n');this.stop();b.done=true;return;}
    if(index===workload.length-1){
      // Final workload packet releases all keys. Stop after the ordinary tick has
      // scheduled its successor; cancel that owned timer through production stop.
      b.done=true;this.start=async()=>false;this.stop();
    }
  };
}
