// SPDX-License-Identifier: GPL-2.0-only
// Integration harness only: wire the isolated adapter in an ignored website copy.
import {cp,readFile,writeFile,mkdir} from 'node:fs/promises';
import {resolve} from 'node:path';
const out=resolve('artifacts/local/doom2/browser-runtime/web');await mkdir(out,{recursive:true});await cp('web',out,{recursive:true,filter:source=>!['config.local.json','palette.local.json'].includes(source.split('/').at(-1))&&!source.endsWith('.wad')});
// This directory belongs solely to this goal; discard stale diagnostic overrides.
for(const name of ['config.local.json','palette.local.json']){const {unlink}=await import('node:fs/promises');await unlink(out+'/'+name).catch(e=>{if(e.code!=='ENOENT')throw e;});}
const original=await readFile('web/launcher.mjs','utf8');
let source=original.replace("import {BrowserInstaller,localEndpoint} from './install-engine.mjs';","import {localEndpoint} from './install-engine.mjs';\nimport {Doom2BrowserInstaller as BrowserInstaller} from './doom2-install.mjs';");
source=source.replace("import {PROFILES,prepareResources,authenticateIWAD} from './install-resources.mjs';","import {authenticateIWAD} from './install-resources.mjs';\nimport {DOOM2_PROFILE,prepareDoom2Resources} from './doom2-profile.mjs';\nconst PROFILES=[DOOM2_PROFILE];\nconst prepareResources=bytes=>prepareDoom2Resources(bytes);");
source=source.replace('Episode One · original EVM menu and gameplay','MAP01–MAP32 · original commercial EVM menu and gameplay · experimental virtual pointers');
source=source.replace("status.textContent='Preparing authenticated Freedoom resources…';", "throw Error('Select the exact local DOOM2.WAD first');");
if(source===original)throw Error('Adapter wiring failed');await writeFile(out+'/launcher.mjs',source);
console.log(out);
