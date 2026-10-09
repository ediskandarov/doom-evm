#!/usr/bin/env python3
"""Separate observed P_GroupLines boundary; unchanged native setup and allocation arithmetic."""
import argparse,gzip,importlib.util,json,os,pathlib,re,struct,subprocess,sys,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[3];HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('zone_lifecycle_reference',ROOT/'tools/reference/phase3_zone_lifecycle/reference.py');native=importlib.util.module_from_spec(spec);spec.loader.exec_module(native)
from build import ref,renderer,PUNITS
from verify import delta_decode
FIXTURES=ROOT/'test/fixtures/phase3_zone_setup';BASE=ROOT/'artifacts/local/gameplay-browser-native';WAD=ROOT/'artifacts/local/freedoom/freedoom1.wad'

def main():
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args();baseline=None;metadata=None
 with tempfile.TemporaryDirectory(prefix='doom-zone-setup-') as t:
  temp=pathlib.Path(t);bins={}
  for profile,opt,san in [('O0','O0',False),('O2','O2',False),('asan','O2',True)]:
   out=temp/profile;binary,m=native.compile_trace(out,opt,san)
   path=out/'p_setup.c';source=path.read_text();match=re.search(r'\nvoid\s+P_GroupLines\s*\([^;{}]*\)\s*\{',source);assert match
   pos=match.end();depth=1
   while depth:
    if source[pos]=='{':depth+=1
    elif source[pos]=='}':depth-=1
    pos+=1
   source=source[:pos-1]+'\n    ZoneStage("after_P_GroupLines");\n'+source[pos-1:];path.write_text(source)
   flags=[f.replace('<BUILD>',str(out)) for f in m['flags']]
   cmd=['clang',*flags,'-I'+str(out),*[str(out/name) for name in renderer.UNITS+PUNITS],str(out/'game_functions.c'),str(ROOT/'tools/reference/phase3_zone_lifecycle/host.c'),'-Wl,-dead_strip','-o',str(out/'setup-observed')]
   r=subprocess.run(cmd,text=True,capture_output=True);assert r.returncode==0,r.stderr;bins[profile]=out/'setup-observed'
   if profile=='O2':metadata=m;metadata['setupStageAdaptedSha256']=ref.sha(source.encode())
  for profile,fill in [('O0','0'),('O2','0'),('asan','0'),('asan','0xa5')]:
   dest=temp/(profile+'-'+fill);dest.mkdir()
   r=subprocess.run([str(bins[profile]),str(WAD),str(dest),str(BASE/'commands.txt'),'ordinary'],text=True,capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0','DOOM_ORACLE_ALLOCATION_FILL':fill});assert r.returncode==0 and not r.stderr,(profile,fill,r.stderr)
   assert (dest/'states.bin').read_bytes()==delta_decode(gzip.decompress((BASE/'states.delta.bin.gz').read_bytes()))
   for p in dest.iterdir():
    if p.name not in ['states.bin','zone-events.jsonl','zone-stages.jsonl','zone-sprites.jsonl'] and (BASE/p.name).exists():assert p.read_bytes()==(BASE/p.name).read_bytes(),('observer altered original',p.name)
   events=[json.loads(x) for x in (dest/'zone-events.jsonl').read_bytes().splitlines()];stages=[json.loads(x) for x in (dest/'zone-stages.jsonl').read_bytes().splitlines()]
   start=next(s for s in stages if s['stage']=='after_R_InitSprites');group=next(s for s in stages if s['stage']=='after_P_GroupLines');setup=next(s for s in stages if s['stage']=='after_P_Setup')
   geometry_events=events[start['eventCount']:group['eventCount']]
   compact=native.startup_outputs(geometry_events,{**group,'eventCount':len(geometry_events)})
   final=native.startup_outputs([], {**setup,'eventCount':0})['startup-headers.bin']
   current={'geometry-operations.bin':compact['startup-operations.bin'],'geometry-summary.bin':compact['startup-summary.bin'],'geometry-headers.bin':compact['startup-headers.bin'],'setup-headers.bin':final,'geometry-events.json':(json.dumps(geometry_events,indent=2,sort_keys=True)+'\n').encode(),'geometry-stage.json':(json.dumps(group,sort_keys=True,separators=(',',':'))+'\n').encode(),'setup-stage.json':(json.dumps(setup,sort_keys=True,separators=(',',':'))+'\n').encode()}
   if baseline is None:baseline=current
   else:assert current==baseline,('four-profile setup observer disagreement',profile,fill)
   print(f'PASS native setup {profile}/{fill}: exact P_GroupLines/P_Setup headers, original six frames/world unchanged',flush=True)
 outputs={name if name.endswith('.bin') else name+'.gz':data if name.endswith('.bin') else gzip.compress(data,mtime=0) for name,data in baseline.items()}
 paths=[pathlib.Path(__file__),ROOT/'tools/reference/phase3_zone_lifecycle/reference.py',ROOT/'tools/reference/phase3_zone_lifecycle/observe.inc',ROOT/'tools/reference/phase3_zone_lifecycle/observe.h',ROOT/'tools/reference/phase3_zone_lifecycle/calls.h',ROOT/'tools/reference/phase3_zone_lifecycle/host.c',ROOT/'test/fixtures/phase3_zone_lifecycle/layout.json']
 outputs['manifest.json']=(json.dumps({'scope':'Native comparison-only original P_Setup physical geometry boundary before THINGS and complete setup boundary after actor/special spawns. No native operation tape as runtime input.','profiles':['O0','O2','ASan+UBSan','ASan+UBSan fill0xa5'],'geometryOperations':struct.unpack_from('>I',baseline['geometry-operations.bin'])[0],'native':metadata,'sourceHashes':{str(p.relative_to(ROOT)):ref.sha(p.read_bytes()) for p in paths},'files':{name:ref.sha(data) for name,data in outputs.items()}},indent=2,sort_keys=True)+'\n').encode()
 for name,data in outputs.items():
  path=FIXTURES/name
  if a.check:assert path.read_bytes()==data,'stale setup fixture '+name
  else:path.write_bytes(data)
 print('PASS original native setup boundaries four profiles exact')
if __name__=='__main__':main()
