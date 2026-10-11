#!/usr/bin/env python3
"""Actual original-C draws: prove owner-slot identity independently of address values."""
import argparse,gzip,hashlib,json,os,shutil,subprocess,time,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'tools/reference/speedrun'))
from replay import renderer,PUNITS
from verify_video import states
sha=lambda b:hashlib.sha256(b).hexdigest()
BASE=ROOT/'artifacts/local/ultimate-speedruns';OUT=BASE/'owner-native';OUT.mkdir(exist_ok=True)
hook=r'''
extern byte *screens[];
void OwnerSample(byte *source,int index,byte *dest,int x,int yl,int yh,int frac) {
 if(gametic!=atoi(getenv("OWNER_PROBE_TIC")) || dest!=screens[0]+atoi(getenv("OWNER_PROBE_DEST")))return;
 uintptr_t s=(uintptr_t)source,a=s+(unsigned)index,z=(uintptr_t)mainzone;
 if(s<z || a>=z+(unsigned)mainzone->size)I_Error("sample outside zone");
 memblock_t *sb=NULL,*ab=NULL;
 for(memblock_t *b=mainzone->blocklist.next;b!=&mainzone->blocklist;b=b->next){
  uintptr_t lo=(uintptr_t)b,hi=lo+(unsigned)b->size;
  if(s>=lo && s<hi)sb=b;if(a>=lo && a<hi)ab=b;
 }
 if(!sb || !ab)I_Error("missing sample header");
 unsigned rel=(unsigned)(a-(uintptr_t)ab);if(rel<offsetof(memblock_t,user)||rel>=offsetof(memblock_t,user)+sizeof(void*))return;
 int k=owner(ab->user);uintptr_t slot=(uintptr_t)ab->user;
 if(k<0 || k>=numlumps || ab->user!=&lumpcache[k] || lumpcache[k]!=(byte*)ab+sizeof(memblock_t))I_Error("owner identity mismatch");

 printf("\nOWNER_SAMPLE {\"tic\":%d,\"x\":%d,\"y\":%td,\"sourceOwner\":%d,\"sourceBlockOffset\":%d,\"sourceOffset\":%td,\"sampleOffset\":%d,\"sampleHeaderOffset\":%d,\"sampleBlockSize\":%d,\"tag\":%d,\"id\":%d,\"nextOffset\":%d,\"prevOffset\":%d,\"roverOffset\":%d,\"headerRelative\":%u,\"pointerByteIndex\":%u,\"slotIndex\":%d,\"slotStride\":%zu,\"slotRelativeOffset\":%llu,\"slotAddress\":\"%p\",\"arrayBase\":\"%p\",\"storedPayload\":\"%p\",\"payloadZoneOffset\":%d,\"zoneBase\":\"%p\",\"slotInsideZone\":%s,\"sampleByte\":%u,\"headerPointerBytes\":\"",
 gametic,x,(dest-screens[0])/320,owner(sb->user),ZoneOffset(sb),source-((byte*)sb+sizeof(memblock_t)),ZoneOffset((void*)a),ZoneOffset(ab),ab->size,ab->tag,ab->id,ZoneOffset(ab->next),ZoneOffset(ab->prev),ZoneOffset(mainzone->rover),rel,rel-(unsigned)offsetof(memblock_t,user),k,sizeof(*lumpcache),(unsigned long long)(slot-(uintptr_t)lumpcache),(void*)slot,(void*)lumpcache,lumpcache[k],ZoneOffset(lumpcache[k]),(void*)mainzone,slot>=z&&slot<z+(unsigned)mainzone->size?"true":"false",*(byte*)a);
 for(unsigned i=0;i<sizeof(void*);i++)printf("%02x",((byte*)&ab->user)[i]);puts("\"}");
}
'''
report=dict(startedUTC=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),virtualBaseChosenBeforeRendering='0x0000002000000000',scope='Unchanged original native renderer/allocator with observation hooks only; no fixed native mapping',profiles=[])
for name in ['O0','O2','sanitize']:
 build=OUT/('build-'+name);assert not build.exists();shutil.copytree(BASE/'E1M1/native-full'/('build-'+name),build)
 p=build/'r_draw.c';s=p.read_text();needle='*dest = dc_colormap[dc_source[(frac>>FRACBITS)&127]];';assert s.count(needle)==2
 p.write_text('void OwnerSample(unsigned char*,int,unsigned char*,int,int,int,int);\n'+s.replace(needle,'OwnerSample(dc_source,(frac>>FRACBITS)&127,dest,dc_x,dc_yl,dc_yh,frac);\n'+needle,1))
 p=build/'z_zone.c';p.write_text(p.read_text()+'\n'+hook)
 manifest=json.loads((build/'single-capture-manifest.json').read_text());flags=[f.replace('<BUILD>',str(build)).replace('<HARNESS>',str(ROOT/'tools/reference')).replace('/private/tmp/doom-evm-ultimate-speedruns',str(ROOT)) for f in manifest['flags']]
 binary=build/'owner-sample';cmd=['clang',*flags,'-I'+str(build),*[str(build/n) for n in renderer.UNITS+PUNITS],str(build/'game_functions.c'),str(build/'episode-host.c'),'-Wl,-dead_strip','-o',str(binary)]
 c=subprocess.run(cmd,capture_output=True);(build/'owner-build.log').write_bytes(c.stdout+c.stderr);assert c.returncode==0,c.stderr.decode()
 profile=dict(name=name,buildCommand=cmd,executableSHA256=sha(binary.read_bytes()),modifiedSourceHashes={n:sha((build/n).read_bytes()) for n in ['r_draw.c','z_zone.c']},samples=[])
 for map_,tic,x,y in [(3,923,99,112),(5,1064,34,150),(6,1736,4,137),(8,263,182,192)]:
  base=BASE/f'E1M{map_}'
  if map_==8:base=base/'alternatives/sedlo-046'
  out=OUT/name/f'E1M{map_}';out.mkdir(parents=True);tape=(base/'level-commands.txt').read_text().splitlines()[:tic];(out/'commands.txt').write_text('\n'.join(row.rsplit(' ',1)[0]+(' 1' if i+1==tic else ' 0') for i,row in enumerate(tape))+'\n')
  env={k:v for k,v in os.environ.items() if not k.startswith(('DOOM_','ASAN_','UBSAN_','Malloc','DYLD_'))};env.update(ASAN_OPTIONS='detect_leaks=0',SPEEDRUN_CAPTURE_TIC=str(tic),OWNER_PROBE_TIC=str(tic),OWNER_PROBE_DEST=str(y*320+x))
  cmd=[str(binary),str(ROOT/'artifacts/local/ultimate-doom/DOOM.WAD'),str(out),str(out/'commands.txt'),str(map_),'3','0'];start=time.perf_counter();c=subprocess.run(cmd,capture_output=True,env=env);(out/'stdout.log').write_bytes(c.stdout);(out/'stderr.log').write_bytes(c.stderr);assert c.returncode==0 and not c.stderr,c.stderr.decode()
  rows=[json.loads(line[len('OWNER_SAMPLE '):]) for line in c.stdout.decode().splitlines() if line.startswith('OWNER_SAMPLE ')];assert len(rows)==1;row=rows[0]
  native=states(gzip.decompress((base/'native-states.delta.bin.gz').read_bytes()),True);assert states((out/'states.bin').read_bytes())==[native[0],native[tic]]
  expected=json.loads((base/'render-diagnostic/decoded.json').read_text());assert row['sampleHeaderOffset']==expected['sampleBlock']['offset'] and row['slotIndex']==expected['sampleBlock']['owner'] and row['headerRelative']==expected['sampleBlock']['relative'] and row['sampleOffset']==expected['physicalOffset']
  assert row['slotStride']==8 and row['slotRelativeOffset']==row['slotIndex']*8 and not row['slotInsideZone'];ptr=int(row['slotAddress'],16);assert bytes.fromhex(row['headerPointerBytes'])==ptr.to_bytes(8,'little') and row['sampleByte']==bytes.fromhex(row['headerPointerBytes'])[row['pointerByteIndex']]
  row.update(map=f'E1M{map_}',worldExact=True,frameSHA256=sha((out/f'frame-{tic:06d}.bin').read_bytes()),elapsedSeconds=time.perf_counter()-start,command=cmd);profile['samples'].append(row);print(name,map_,row['slotIndex'],row['slotAddress'],flush=True)
 report['profiles'].append(profile)
report.update(pass_=True,endedUTC=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),verdict='RESTRICT; identities/stride/representation proved; absolute addresses are process observations, not native-equivalent virtual bytes')
(OUT/'proof.json').write_text(json.dumps(report,indent=2)+'\n')
commit=ROOT/'artifacts/ultimate-speedruns/owner-pointer';commit.mkdir(exist_ok=True);(commit/'native-samples.json').write_text(json.dumps(report,indent=2)+'\n')
