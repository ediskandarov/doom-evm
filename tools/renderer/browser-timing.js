// Injected only by the optional evidence hook, before application modules execute.
(() => {
  const proof=window.__rendererTiming={clock:'performance.now milliseconds since navigation',requests:[],notifications:[],canvas:[]};
  const fetchOriginal=window.fetch;
  window.fetch=async function(input,options){
    let request;try{request=JSON.parse(options?.body);}catch{}
    const record=request?.method?{method:request.method,id:request.id,start:performance.now(),params:request.method==='eth_sendTransaction'?request.params:undefined}:null;
    if(record)proof.requests.push(record);
    const response=await fetchOriginal.apply(this,arguments);
    if(record){record.headersAt=performance.now();const json=response.json.bind(response);response.json=async()=>{const value=await json();record.responseAt=performance.now();if(request.method==='eth_sendTransaction')record.transactionHash=value.result;if(request.method==='eth_getTransactionReceipt'&&value.result)record.receipt={transactionHash:value.result.transactionHash,status:value.result.status};return value;};}
    return response;
  };
  const Socket=window.WebSocket;
  window.WebSocket=class extends Socket {constructor(...args){super(...args);this.addEventListener('message',event=>{try{const message=JSON.parse(event.data);if(message.method==='eth_subscription')proof.notifications.push({at:performance.now(),transactionHash:message.params.result.transactionHash});}catch{}});}};
  const put=CanvasRenderingContext2D.prototype.putImageData;
  CanvasRenderingContext2D.prototype.putImageData=function(){const start=performance.now();const value=put.apply(this,arguments);proof.canvas.push({start,end:performance.now(),frameIndex:window.__transportProof.frames.length});return value;};
})();
