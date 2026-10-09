// SPDX-License-Identifier: GPL-2.0-only
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve, sep } from 'node:path';
const webRoot=fileURLToPath(new URL('../../web/',import.meta.url));
export async function serve(port=8080) {
  const server=createServer(async(req,res)=>{
    const path=resolve(webRoot,'.'+new URL(req.url,'http://localhost').pathname.replace(/\/$/,'/index.html'));
    if(!path.startsWith(webRoot.endsWith(sep)?webRoot:webRoot+sep)) {res.writeHead(403).end();return;}
    try {
      const body=await readFile(path);
      res.setHeader('Content-Type',path.endsWith('.html')?'text/html':path.endsWith('.mjs')?'text/javascript':'application/json');
      res.setHeader('Cache-Control','no-store');res.end(body);
    }catch{res.writeHead(404).end('Not found');}
  });
  await new Promise((done,fail)=>{server.once('error',fail);server.listen(port,'127.0.0.1',done);});
  return server;
}
if(process.argv[1]===fileURLToPath(import.meta.url)) {
  const server=await serve(Number(process.env.PORT??8080));
  console.log(`Synthetic transport browser: http://127.0.0.1:${server.address().port}`);
}
