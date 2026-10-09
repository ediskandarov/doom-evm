#!/usr/bin/env python3
"""Actual pinned LP64 sizeof/offsetof, private typedefs mechanically extracted unchanged."""
import importlib.util,json,pathlib,re,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[3]
spec=importlib.util.spec_from_file_location('ref',ROOT/'tools/reference/reference.py');ref=importlib.util.module_from_spec(spec);spec.loader.exec_module(ref)
OUT=ROOT/'test/fixtures/phase3_zone_lifecycle/layout.json'
fields={
'memblock_t':'size user tag id next prev', 'memzone_t':'size blocklist rover',
'vertex_t':'x y','sector_t':'floorheight ceilingheight floorpic ceilingpic lightlevel special tag soundtraversed soundtarget blockbox soundorg validcount thinglist linecount lines specialdata',
'side_t':'textureoffset rowoffset toptexture bottomtexture midtexture sector','line_t':'v1 v2 dx dy flags special tag sidenum bbox slopetype frontsector backsector validcount specialdata',
'seg_t':'v1 v2 offset angle sidedef linedef frontsector backsector','subsector_t':'sector numlines firstline','node_t':'x y dx dy bbox children','mapthing_t':'x y angle type options',
'mobj_t':'thinker x y z snext sprev angle sprite frame bnext bprev subsector floorz ceilingz radius height momx momy momz validcount type info tics state flags health movedir movecount target reactiontime threshold player lastlook spawnpoint tracer',
'vldoor_t':'thinker type sector topheight speed direction topwait topcountdown','floormove_t':'thinker type crush sector direction newspecial texture floordestheight speed',
'ceiling_t':'thinker type sector bottomheight topheight speed crush direction tag olddirection','plat_t':'thinker sector speed low high wait count status oldstatus crush tag type',
'fireflicker_t':'thinker sector count maxlight minlight','lightflash_t':'thinker sector count maxlight minlight maxtime mintime','strobe_t':'thinker sector count minlight maxlight darktime brighttime','glow_t':'thinker sector minlight maxlight direction',
'spritedef_t':'numframes spriteframes','spriteframe_t':'rotate lump flip','vissprite_t':'prev next x1 x2 gx gy gz gzt startfrac scale xiscale texturemid patch colormap mobjflags',
'visplane_t':'height picnum lightlevel minx maxx pad1 top pad2 pad3 bottom pad4','texpatch_t':'originx originy patch','texture_t':'name width height patchcount patches','thinker_t':'prev next function'}
private=[];extractions=[]
for file,name in [('z_zone.c','memzone_t'),('r_data.c','texpatch_t'),('r_data.c','texture_t')]:
 s=(ref.SOURCE/file).read_text();end=re.search(r'}\s*'+name+r'\s*;',s).end();start=s.rfind('typedef struct',0,end);body=s[start:end];private.append(body);extractions.append({'file':file,'type':name,'sha256':ref.sha(body.encode()),'startLine':s[:start].count('\n')+1})
source='#include <stdio.h>\n#include <stddef.h>\n#include "r_local.h"\n#include "p_local.h"\n#include "z_zone.h"\n'+'\n'.join(private)+'\nint main(void){ puts("{");\n'
for i,(name,fs) in enumerate(fields.items()):
 source+='printf("'+('' if i==0 else ',')+'\\"'+name+'\\":{\\"size\\":%zu,\\"alignment\\":%zu,\\"offsets\\":{",sizeof('+name+'),_Alignof('+name+'));\n'
 for j,f in enumerate(fs.split()):source+='printf("'+('' if j==0 else ',')+'\\"'+f+'\\":%zu",offsetof('+name+','+f+'));\n'
 source+='puts("}}");\n'
source+='printf(",\\"primitive\\":{\\"pointer\\":%zu,\\"int\\":%zu,\\"short\\":%zu,\\"fixed_t\\":%zu,\\"blockmapPointer\\":%zu}\\n",sizeof(void*),sizeof(int),sizeof(short),sizeof(fixed_t),sizeof(short*));puts("}");}\n'
with tempfile.TemporaryDirectory(prefix='doom-zone-layout-') as t:
 tmp=pathlib.Path(t);(tmp/'layout.c').write_text(source);(tmp/'values.h').write_text('#include <limits.h>\n#include "doomtype.h"\n')
 cmd=['clang','-std=c11','-I'+str(tmp),'-I'+str(ref.SOURCE),str(tmp/'layout.c'),'-o',str(tmp/'layout')];r=subprocess.run(cmd,text=True,capture_output=True);assert r.returncode==0,r.stderr
 result=subprocess.run([str(tmp/'layout')],text=True,capture_output=True,check=True);data=json.loads(result.stdout)
 assert data['memblock_t']['size']==40 and data['memzone_t']['size']==56
 metadata={'compiler':ref.VERSION,'target':ref.TARGET,'upstreamCommit':ref.UPSTREAM,'allocationAlignment':8,'layout':data,'privateTypeExtractions':extractions,'sourceHeaders':{p.name:ref.sha(p.read_bytes()) for p in ref.SOURCE.glob('*.h')},'generatorSha256':ref.sha(pathlib.Path(__file__).read_bytes())}
 OUT.write_text(json.dumps(metadata,indent=2,sort_keys=True)+'\n');print(json.dumps({n:x.get('size',x) for n,x in data.items()},sort_keys=True))
