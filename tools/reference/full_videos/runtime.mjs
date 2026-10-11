// Streaming checkpoint primitives preserved from the historical owner recorder.
import {createGzip} from 'node:zlib';
import {createWriteStream} from 'node:fs';
import {pipeline} from 'node:stream/promises';
import {once} from 'node:events';
import {rename} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
export async function gzipArray(file, rows, stateStream = false) {
  const compression = createGzip({level:1}); const dest=createWriteStream(file + '.tmp');
  const done=pipeline(compression,dest);
  const push = async bytes => {if(!compression.write(bytes)) await once(compression,'drain');};
  if (!stateStream) await push('[');
  for (let i=0;i<rows.length;i++) {
    if (stateStream) {const b=Buffer.alloc(4);b.writeUInt32BE(rows[i].length);await push(b);await push(rows[i]);}
    else await push((i?',':'')+JSON.stringify(rows[i]));
  }
  if (!stateStream) await push(']'); compression.end();await done;await rename(file+'.tmp',file);
}
export async function dumpChain(file,port) {
  const response=await fetch(`http://127.0.0.1:${port}`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:1,method:'anvil_dumpState',params:[]}),signal:AbortSignal.timeout(900000)});
  assert(response.ok);const out=createWriteStream(file+'.tmp');let prefix='',started=false,pending='',ended=false;
  const digest=createHash('sha256');let bytes=0;
  for await(const chunk of response.body) {
    let part=Buffer.from(chunk).toString('ascii');
    if (!started) {prefix+=part;const match=/"result"\s*:\s*"0x/.exec(prefix);if(!match){assert(prefix.length<4096,'State dump RPC error: '+prefix);continue;}part=prefix.slice(match.index+match[0].length);prefix='';started=true;}
    if (ended) continue;
    const quote=part.indexOf('"');if(quote>=0){part=part.slice(0,quote);ended=true;}
    pending+=part;assert(/^[0-9a-f]*$/i.test(pending));const n=pending.length-pending.length%2;
    const raw=Buffer.from(pending.slice(0,n),'hex');pending=pending.slice(n);digest.update(raw);bytes+=raw.length;
    if(!out.write(raw))await once(out,'drain');
  }
  assert(started&&ended&&pending.length===0);out.end();await once(out,'finish');await rename(file+'.tmp',file);
  return {file,sha256:digest.digest('hex'),bytes};
}
