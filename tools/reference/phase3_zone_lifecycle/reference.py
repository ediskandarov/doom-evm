#!/usr/bin/env python3
"""Observe original zone lifecycle, never feed allocation tape or pixels into an engine."""
import argparse,gzip,importlib.util,json,os,pathlib,re,struct,subprocess,sys,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[3];HERE=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools/reference/gameplay'))
from build import build,ref,renderer,PUNITS
from verify import delta_decode
GAME=ROOT/'tools/reference/gameplay';BASE=ROOT/'test/fixtures/gameplay';BROWSER=ROOT/'artifacts/local/gameplay-browser-native';FIXTURES=ROOT/'test/fixtures/phase3_zone_lifecycle';WAD=ROOT/'artifacts/local/freedoom/freedoom1.wad'

def compile_trace(out,opt,san):
 build(out,opt,san);native=json.loads((out/'gameplay-build-manifest.json').read_text());flags=[f.replace('<HARNESS>',str(GAME.parent)) for f in native['flags']]
 (out/'zone-observe.h').write_bytes((HERE/'observe.h').read_bytes());(out/'zone-calls.h').write_bytes((HERE/'calls.h').read_bytes())
 adaptations=[]
 for name in renderer.UNITS+PUNITS:
  p=out/name;s=p.read_text()
  if name=='z_zone.c':
   s=s.replace('newblock->tag = 0;','newblock->tag = 0;\n        ZoneFragmentObserved(newblock);',1)
   assert s.count('block->id = 0;')==1;s=s.replace('block->id = 0;','block->id = 0;\n    ZoneFreedObserved(block);',1)
   matches=list(re.finditer(r'\bZ_Free\s*\(([^;{}]*)\)\s*;',s));assert len(matches)==2,len(matches)
   for m in reversed(matches):s=s[:m.start()]+'ZoneFreeObserved("z_zone.c",__func__,__LINE__,'+m.group(1)+');'+s[m.end():]
   s+='\n'+(HERE/'observe.inc').read_text()
  else:
   matches=list(re.finditer(r'^#include[^\n]*\n',s,re.M))
   if not matches:
    assert not re.search(r'\bZ_(?:Malloc|Free|FreeTags|ChangeTag)\s*\(',s),name
    continue
   at=matches[-1].end();line=s[:at].count('\n')+1
   s=s[:at]+'#define ZONE_FILE "'+name+'"\n#include "zone-calls.h"\n#line '+str(line)+' "'+name+'"\n'+s[at:]
  p.write_text(s);adaptations.append({'file':name,'adaptedSourceSha256':ref.sha(s.encode())})
 host=(GAME/'host.c').read_text()
 host=host.replace('Z_Init();','Z_Init();ZoneStage("after_Z_Init");',1)
 host=host.replace('R_Init();R_InitSprites(sprite_names);','R_Init();ZoneStage("after_R_Init");R_InitSprites(sprite_names);ZoneStage("after_R_InitSprites");',1)
 host=host.replace('P_SetupLevel(1,1,1,sk_medium);','P_SetupLevel(1,1,1,sk_medium);ZoneStage("after_P_Setup");',1)
 host=host.replace('    char path[4096];snprintf(path,sizeof(path),"%s/ticks.bin"','    ZoneStage("after_scenario_setup");\n    char path[4096];snprintf(path,sizeof(path),"%s/ticks.bin"',1)
 host=host.replace('R_RenderPlayerView(players);char name[80];','R_RenderPlayerView(players);ZoneStage("after_render");char name[80];',1)
 (out/'original-host.c').write_text(host);(out/'observe.h').write_bytes((GAME/'observe.h').read_bytes());(out/'diagnostics.h').write_bytes((GAME/'diagnostics.h').read_bytes())
 flags+=['-include',str(out/'zone-observe.h')]
 command=['clang',*flags,'-I'+str(out),*[str(out/name) for name in renderer.UNITS+PUNITS],str(out/'game_functions.c'),str(HERE/'host.c'),'-Wl,-dead_strip','-o',str(out/'zone-lifecycle')]
 process=subprocess.run(command,text=True,capture_output=True);(out/'zone-build.log').write_text(process.stdout+process.stderr);assert process.returncode==0,process.stderr
 native['flags']=[f.replace(str(out),'<BUILD>') for f in flags];native['zoneObservationSources']=adaptations;native['zoneHostSha256']=ref.sha((HERE/'host.c').read_bytes());native['generatedHostSha256']=ref.sha(host.encode())
 return out/'zone-lifecycle',native

def startup_outputs(events,stage):
 selected=[e for e in events[:stage['eventCount']] if e['outer'] and e['op'] in ['malloc','free','tag']]
 words=[];digest=bytes(32)
 for e in selected:
  record=[{'malloc':1,'free':2,'tag':3}[e['op']],e['request'],e['requestedTag'],e['owner'],e['header'],e['size'],e['rover']]
  encoded=struct.pack('>7I',*[x&0xffffffff for x in record]);words.append(encoded);digest=bytes.fromhex(ref.sha(digest+encoded))
 ops=struct.pack('>I',len(words))+b''.join(words);summary=struct.pack('>I',len(words))+digest
 blocks=stage['blocks'];free=sum(b['size'] for b in blocks if not b['allocated'] or b['tag']>=100)
 rows=[stage['byteLength'],stage['rover'],stage['capPrev'],stage['capNext'],free,len(blocks)]
 for b in blocks:rows += [b['offset'],b['size'],b['allocated'],b['owner'],b['tag'] if b['allocated'] else 0,b['idKnown'],b['id'] if b['idKnown'] else 0,b['prev'],b['next']]
 rows += [len(stage['owners']),*stage['owners']];headers=struct.pack('>'+str(len(rows))+'I',*[x&0xffffffff for x in rows])
 return {'startup-operations.bin':ops,'startup-summary.bin':summary,'startup-headers.bin':headers}

def main():
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');p.add_argument('--quick',action='store_true',help='publish browser O2 interim observations; not four-profile acceptance');a=p.parse_args()
 cases=[('browser',BROWSER,'ordinary')]+[(c['name'],BASE/c['name'],json.loads((BASE/c['name']/'setup.json').read_text())['kind']) for c in json.loads((BASE/'manifest.json').read_text())['cases']]
 if a.quick:cases=cases[:1]
 outputs={};metrics=[];startup=None
 with tempfile.TemporaryDirectory(prefix='doom-zone-lifecycle-') as t:
  temp=pathlib.Path(t);bins={};metadata=None
  profiles=[('O2','O2',False)] if a.quick else [('O0','O0',False),('O2','O2',False),('asan','O2',True)]
  for name,opt,san in profiles:
   bins[name],m=compile_trace(temp/name,opt,san)
   if name=='O2':metadata=m
  for name,base,setup in cases:
   baseline=None;runprofiles=[('O2','0')] if a.quick else [('O0','0'),('O2','0'),('asan','0'),('asan','0xa5')]
   for profile,fill in runprofiles:
    dest=temp/(name+'-'+profile+'-'+fill);dest.mkdir()
    result=subprocess.run([str(bins[profile]),str(WAD),str(dest),str(base/'commands.txt'),setup],text=True,capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0','DOOM_ORACLE_ALLOCATION_FILL':fill});assert result.returncode==0 and not result.stderr,(name,profile,fill,result.stderr)
    assert (dest/'states.bin').read_bytes()==delta_decode(gzip.decompress((base/'states.delta.bin.gz').read_bytes()))
    for path in dest.iterdir():
     if path.name not in ['states.bin','zone-events.jsonl','zone-stages.jsonl','zone-sprites.jsonl'] and (base/path.name).exists():assert path.read_bytes()==(base/path.name).read_bytes(),('observer changed existing output',name,profile,path.name)
    current={path.name:path.read_bytes() for path in dest.iterdir() if path.name.startswith('zone-')}
    if baseline is None:baseline=current
    else:
     for key,data in baseline.items():assert current[key]==data,('normalized trace profile mismatch',name,profile,fill,key)
   events=[json.loads(line) for line in baseline['zone-events.jsonl'].splitlines()];stages=[json.loads(line) for line in baseline['zone-stages.jsonl'].splitlines()];sprites=[json.loads(line) for line in baseline['zone-sprites.jsonl'].splitlines()]
   start=next(s for s in stages if s['stage']=='after_R_InitSprites');derived=startup_outputs(events,start)
   if startup is None:startup=derived;outputs.update(derived)
   else:assert derived==startup,'startup differs across scenarios'
   for key,data in baseline.items():outputs[name+'/'+key+'.gz']=gzip.compress(data,mtime=0)
   final=stages[-1];metrics.append({'case':name,'events':len(events),'stageSnapshots':len(stages),'spriteSnapshots':len(sprites),'mallocs':final['mallocs'],'frees':final['frees'],'changeTags':final['tags'],'purges':final['purges'],'peakLiveBytes':final['peakLiveBytes'],'liveBytes':final['liveBytes'],'cachedSpriteCountAtStartup':len(next(s for s in sprites if s['stage']=='after_R_InitSprites')['sprites'])})
   print('PASS '+name+': '+str(len(events))+' normalized events; '+str(final['peakLiveBytes'])+' peak bytes; '+str(final['purges'])+' purges; existing outputs unchanged'+(' (O2 interim)' if a.quick else ' (four profiles)'),flush=True)
 outputs['manifest.json']=(json.dumps({'scope':'Comparison-only original native allocation/cache/layout lifecycle evidence; not a runtime allocation tape or pixel source.','status':'O2 interim' if a.quick else 'four-profile exact','upstreamCommit':ref.UPSTREAM,'profiles':[x[0]+':'+x[1] for x in runprofiles],'numericProfile':metadata,'events':'JSONL completed operations, source caller labels, requested size/tag/owner and normalized returned/pre-free header metadata; nested Free/freeTags marked outer=false.','ownerNamespace':'NULL/unowned=-1; cachedlump=lumpID; textureComposite=numlumps+textureID. Pointer fields are normalized offsets, not raw native addresses.','knownness':'Initial/free fragment id never read until written; newfragment resets idKnown=false, malloc sets true ZONEID, Free sets true0. Initial tag unknown; fragment/tag writes tracked. No raw unknown bytes portable claim.','startupBinary':'startup-operations.bin BE32 count+7words per completed outer malloc/free/tag; summary=count+rollingSHA256(zero32 then prior32+record28); headers byteLength/rover/capPrev/capNext/freeMemory/count +9wordblocks +ownerCount/payloadOffsets. All comparison-only.','cases':metrics,'sourceHashes':{str(p.relative_to(ROOT)):ref.sha(p.read_bytes()) for p in [pathlib.Path(__file__),HERE/'observe.h',HERE/'calls.h',HERE/'observe.inc',HERE/'host.c',GAME/'build.py',GAME/'host.c',GAME/'observe.h',GAME/'diagnostics.h']},'files':{name:ref.sha(data) for name,data in sorted(outputs.items())}},indent=2,sort_keys=True)+'\n').encode()
 for name,data in outputs.items():
  path=FIXTURES/name
  if a.check:assert path.read_bytes()==data,'stale zone lifecycle fixture '+name
  else:path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
 print('PASS native zone lifecycle'+(' INTERIM O2 only' if a.quick else ' four-profile evidence'))
if __name__=='__main__':main()
