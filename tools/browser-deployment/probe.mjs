// SPDX-License-Identifier: GPL-2.0-only
import {spawn} from 'node:child_process';
import {connect} from 'node:net';
const port=18991;
await new Promise((done,fail)=>{const s=connect({host:'127.0.0.1',port});s.once('connect',()=>{s.destroy();fail(Error('Occupied port'));});s.once('error',e=>e.code==='ECONNREFUSED'?done():fail(e));});
const child=spawn('.toolchain/bin/anvil',['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--no-request-size-limit','--memory-limit','1073741824','--gas-limit','10000000000','--allow-origin','http://127.0.0.1:18992','--silent'],{stdio:['ignore','ignore','inherit']});
try{for(let i=0;i<100;i++){try{const r=await fetch(`http://127.0.0.1:${port}`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:1,method:'anvil_nodeInfo',params:[]})});console.log(await r.text());break;}catch{if(child.exitCode!==null)throw Error('Anvil failed');await new Promise(r=>setTimeout(r,50));}}}finally{child.kill('SIGTERM');}
