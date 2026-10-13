// SPDX-License-Identifier: GPL-2.0-only
// Remove resource payloads; preserve every numerical observation and outlier.
import {readFile,writeFile,readdir} from 'node:fs/promises';
import {join,resolve,relative} from 'node:path';
import {createHash} from 'node:crypto';
const root=resolve('artifacts/benchmarks/doom2-map01-performance/results'),sha=b=>createHash('sha256').update(b).digest('hex'),changes=[];
function sanitize(value){if(Array.isArray(value))return value.map(sanitize);if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).filter(([key])=>key!=='rgbHex').map(([key,v])=>[key==='psLifetimeCpuPercent'?'psReportedCpuPercent':key,sanitize(v)]));return value;}
async function visit(path){for(const e of await readdir(path,{withFileTypes:true})){const file=join(path,e.name);if(e.isDirectory())await visit(file);else if(e.name.endsWith('.json')&&e.name!=='sanitization.json'){const before=await readFile(file),after=Buffer.from(JSON.stringify(sanitize(JSON.parse(before)),null,2)+'\n');if(!before.equals(after)){await writeFile(file,after);changes.push({file:relative(root,file),beforeSha256:sha(before),afterSha256:sha(after)});}}}}
await visit(root);await writeFile(join(root,'sanitization.json'),JSON.stringify({operations:['Remove rgbHex resource palette payload fields','Correct the ps printed CPU field name; retain its number','JSON serialization only; no measurement values or samples discarded'],changes},null,2)+'\n');console.log('Sanitized',changes.length,'JSON files; numerical samples unchanged.');
