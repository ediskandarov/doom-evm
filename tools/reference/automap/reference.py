#!/usr/bin/env python3
"""Original am_map.c oracle: unchanged bodies, native state and framebuffer comparisons."""
import argparse, hashlib, json, os, pathlib, random, re, shutil, struct, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[3]; HERE=pathlib.Path(__file__).resolve().parent
SRC=ROOT/'original/DOOM/linuxdoom-1.10'; FIX=ROOT/'test/fixtures/phase4_automap'
sha=lambda b:hashlib.sha256(b).hexdigest()
pack=lambda xs:struct.pack('>'+str(len(xs))+'I',*(x&0xffffffff for x in xs))
U=65536

def world():
    vertices=[[-256*U,-256*U],[256*U,-256*U],[256*U,256*U],[-256*U,256*U]]
    walls=[]
    # Every wall color/visibility branch, and priority of special/secret/floor/ceiling.
    variants=[(256,0,0,0,0,128,128),(0,0,0,0,0,128,128),(384,0,0,0,0,128,128),
              (256,39,1,0,32,128,64),(288,0,1,0,32,128,64),(256,0,1,0,32,128,64),
              (256,0,1,0,0,128,64),(256,0,1,0,0,128,128),(128,0,1,0,0,128,128),
              (0,0,1,0,0,128,128)]
    for i,v in enumerate(variants):
        walls.append([-220*U,(-210+i*40)*U,220*U,(-210+i*40)*U,*v[:3],*(h*U for h in v[3:])])
    return dict(episode=1,map=1,console=0,net=0,death=0,demo=0,allmap=0,block=[-300*U,-300*U],
                players=[[13*U,-17*U,0,1,0],[80*U,60*U,0x40000000,1,0],[-80*U,50*U,0x80000000,1,1],[0,120*U,0xc0000000,1,0]],
                vertices=vertices,walls=walls,things=[[100*U,-100*U,0],[-100*U,100*U,0x40000000],[100*U,100*U,0x12345678]])

def encode(w,actions):
    words=[w[k] for k in ['episode','map','console','net','death','demo','allmap']]+w['block']
    words+=sum(w['players'],[])+[len(w['vertices'])]+sum(w['vertices'],[])
    words+=[len(w['walls'])]+sum(w['walls'],[])+[len(w['things'])]+sum(w['things'],[])
    words+=[len(actions)]+sum(actions,[])
    return pack(words)

def cases(bundle,blob):
    rows=[]
    def A(op,a=0,b=0,c=0,d=0):return [op,a,b,c,d]
    def K(k,t=0):return A(0,t,ord(k) if isinstance(k,str) else k)
    start=K(9); draw=A(2);tick=A(1,1)
    def add(name,steps,w=None):rows.append(dict(name=name,world=w or world(),actions=steps))
    def cheat():return [K(c) for c in 'iddt']
    add('walls-discovery-allmap-cheat-cycle',[start,tick,draw,A(6,1),draw,A(7,1,256),draw,*cheat(),draw,*cheat(),draw,*cheat(),draw])
    add('pan-zoom-follow',[A(2),K(9,1),start,K(0xae),tick,K('f'),K(0xae),K(0xad),A(1,10),draw,K(0xae,1),K(0xad,1),K('='),A(1,35),draw,K('=',1),K('-'),A(1,35),draw,K('-',1),K('f'),A(3,0,-33*U,23*U,0x40000000),tick,draw])
    add('clamps-big-restore-and-reopen',[start,K('f'),K(0xac),K(0xaf),A(1,200),draw,K(0xac,1),K(0xaf,1),K('='),A(1,220),draw,K('=',1),K('0'),draw,K('0'),draw,K('-'),A(1,260),draw,K('-',1),K('0'),K(9),draw,start,tick,draw,A(5,1,2),tick,draw])
    add('grid-negative-origin-marks',[start,K('g'),draw,*sum(([K('m'),K('f') if i==0 else K(0xae),tick,draw] for i in range(12)),[]),K('c'),draw,K('g'),draw])
    add('follow-stationary-zoom-restore',[start,tick,K('='),A(1,10),K('=',1),draw,K('0'),draw,K('0'),tick,draw,A(4),A(1,4),A(5,2,1),tick,draw])
    add('cheat-mismatch-event-and-deathmatch',[start,K('i'),K('i'),K('d'),K('d'),K('t'),draw,K('i'),K('d',1),K('d'),K('d'),K('t'),draw,A(8,1,1),*cheat(),draw,A(8,1,1,1),draw,A(8,1,0),*cheat(),draw])
    w=world();w['console']=2;w['players'][2][3]=0;w['players'][0][3]=0
    add('fallback-player',[start,tick,draw,A(8,1),draw,A(8,1,1),draw,A(8,1,1,1),draw],w)
    add('mark-edge-and-sentinel',[start,tick,*[A(9,i,x*U,y*U) for i,(x,y) in enumerate([(-1,0),(0,0),(-256,256),(256,-256),(-100,80),(100,-80)])],draw])
    for i,angle in enumerate([0,1,0x1fffffff,0x20000000,0x40000000,0x80000000,0xc0000000,0xffffffff,0x12345678]):
        add('rotation-'+str(i),[start,A(3,0,0,0,angle),tick,draw,*cheat(),draw,*cheat(),draw])
    # Clipping on every edge, all octants, points, reversed segments and exact boundary.
    w=world();w['walls']=[]
    for ax,ay,bx,by in [(-1000,0,1000,0),(0,-1000,0,1000),(-1000,-1000,1000,1000),(-1000,1000,1000,-1000),(-1000,500,1000,300),(500,-1000,300,1000),(-1000,-500,-900,-400),(0,0,0,0),(-256,-256,256,-256),(-256,256,256,256),(256,-256,256,256)]:
        for reverse in [False,True]:
            coords=[ax,ay,bx,by] if not reverse else [bx,by,ax,ay]
            w['walls'].append([*(v*U for v in coords),256,0,0,0,0,128*U,128*U])
    add('clip-octants-boundaries',[start,draw,K('0'),draw,K('='),A(1,50),draw],w)
    # Real E1M1 map geometry; native and EVM consume the same projected original definitions.
    def lump(name):
        row=next(l for l in bundle['lumps'] if bytes.fromhex(l['nameHex']).rstrip(b'\0')==name.encode());return blob[row['offset']:row['offset']+row['length']]
    w=world();verts=list(struct.iter_unpack('<hh',lump('VERTEXES')));sects=list(struct.iter_unpack('<hh8s8shhh',lump('SECTORS')));sides=list(struct.iter_unpack('<hh8s8s8sh',lump('SIDEDEFS')))
    w['vertices']=[[x*U,y*U] for x,y in verts];w['walls']=[]
    for i,(v1,v2,flags,special,tag,s1,s2) in enumerate(struct.iter_unpack('<7H',lump('LINEDEFS'))):
        front=sects[sides[s1][-1]];back=sects[sides[s2][-1]] if s2!=65535 else front
        w['walls'].append([*w['vertices'][v1],*w['vertices'][v2],flags|(256 if i%3==0 else 0),special,int(s2!=65535),front[0]*U,back[0]*U,front[1]*U,back[1]*U])
    origin=struct.unpack('<hh',lump('BLOCKMAP')[:4]);w['block']=[v*U for v in origin]
    things=list(struct.iter_unpack('<5h',lump('THINGS')));player=next(t for t in things if t[3]==1)
    w['players'][0]=[player[0]*U,player[1]*U,(player[2]*0x100000000//360)&0xffffffff,1,0]
    w['things']=[[t[0]*U,t[1]*U,(t[2]*0x100000000//360)&0xffffffff] for t in things]
    add('e1m1-discovered-grid-allmap-cheats',[start,tick,draw,K('g'),draw,K('m'),draw,A(6,1),draw,*cheat(),draw,*cheat(),draw,K('0'),draw],w)
    rng=random.Random(45);w=world();w['walls']=[]
    for _ in range(128):
        coords=[rng.randrange(-1024*U,1024*U) for _ in range(4)]
        w['walls'].append([*coords,256,0,0,0,0,128*U,128*U])
    add('random-fixed-coordinate-clipping',[start,draw,K('0'),draw,K('='),A(1,60),draw],w)
    add('original-slope-and-light-helpers',[start,*[A(11,*coords) for coords in [(0,0,U,0),(0,0,0,U),(0,0,-U,0),(0,0,0,-U),(13*U,-17*U,-31*U,29*U)]],
        *sum(([A(1,7),A(10)] for _ in range(10)),[]),draw])
    w=world();w['vertices']=[[-256*U,-256*U],[-300*U,-300*U],[-400*U,-400*U],[256*U,256*U]]
    add('boundary-vertex-order',[start,draw,K('0'),draw],w)
    return rows

def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    bundle=json.loads((ROOT/'artifacts/local/wad/bundle.json').read_text());blob=(ROOT/'artifacts/local/wad/resources.bin').read_bytes();assert sha(blob)==bundle['blobSha256']
    rows=cases(bundle,blob);original=(SRC/'am_map.c').read_text();projection=re.sub(r'^#include[^\n]*','',original,flags=re.M)
    with tempfile.TemporaryDirectory(prefix='doom-automap-') as tmp:
        tmp=pathlib.Path(tmp);built=tmp/'fixtures';built.mkdir();(tmp/'automap_projection.inc').write_text(projection)
        patches=[]
        for i in range(10):
            name=f'AMMNUM{i}';r=next(l for l in bundle['lumps'] if bytes.fromhex(l['nameHex']).rstrip(b'\0')==name.encode());data=blob[r['offset']:r['offset']+r['length']];(built/(name+'.bin')).write_bytes(data)
            patches.append(dict(name=name,sha256=sha(data),length=len(data),lumpId=r['id']))
        profiles=[];outputs=[]
        for label,flags in [('O0',['-O0']),('O2',['-O2']),('sanitized',['-O1','-g','-fsanitize=address,undefined','-fno-sanitize=shift,array-bounds','-fno-omit-frame-pointer'])]:
            cmd=['clang','-std=gnu11','-Wno-implicit-int','-DRANGECHECK','-include',str(HERE/'compat.h'),'-I',str(tmp),*flags,str(HERE/'host.c'),*[str(SRC/f) for f in ['v_video.c','m_bbox.c','m_fixed.c','m_cheat.c','tables.c']],'-o',str(tmp/label)]
            r=subprocess.run(cmd,capture_output=True);assert r.returncode==0,r.stderr.decode()
            out=[]
            for row in rows:
                inp=encode(row['world'],row['actions']);(tmp/'input.bin').write_bytes(inp)
                env=os.environ.copy();env['ASAN_OPTIONS']='detect_leaks=0:halt_on_error=1';env['UBSAN_OPTIONS']='halt_on_error=1:print_stacktrace=1'
                r=subprocess.run([str(tmp/label),str(tmp/'input.bin'),str(built)],capture_output=True,env=env);assert r.returncode==0,(row['name'],r.stderr.decode())
                out.append(r.stdout)
            outputs.append(out);profiles.append(dict(name=label,flags=flags,outputSha256=sha(b''.join(out)),returnCode=0))
        assert outputs[0]==outputs[1]==outputs[2]
        packed=bytearray(pack([len(rows)]));snapshots=0
        for i,(row,out) in enumerate(zip(rows,outputs[0])):
            inp=encode(row['world'],row['actions']);(built/f'{i}.bin').write_bytes(inp);packed+=pack([len(inp)])+inp
            count=struct.unpack('>I',out[:4])[0];assert count==len(row['actions']);pos=4;hashes=[]
            for step in row['actions']:
                n=struct.unpack('>I',out[pos+264:pos+268])[0];state=out[pos:pos+268+n];pos+=268+n;frame=out[pos:pos+64000];pos+=64000
                packed+=hashlib.sha256(state).digest()+hashlib.sha256(frame).digest();snapshots+=1
                hashes.append(dict(stateSha256=sha(state),frameSha256=sha(frame)))
            assert pos==len(out),(row['name'],pos,len(out));row['hashes']=hashes;row['inputSha256']=sha(inp)
            (built/f'{i}.hashes.bin').write_bytes(b''.join(bytes.fromhex(h['stateSha256'])+bytes.fromhex(h['frameSha256']) for h in hashes))
        (built/'cases.bin').write_bytes(packed)
        # Source mapping includes all original functions, not only frequently called ones.
        names=re.findall(r'\b(AM_\w+)\s*\([^;{}]*\)\s*\{',original)
        mapping=[]
        for name in names:
            m=re.search(r'\b'+name+r'\s*\([^;{}]*\)\s*\{',original);opening=original.index('{',m.start());depth=1;end=opening+1
            while depth:
                if original[end]=='{':depth+=1
                if original[end]=='}':depth-=1
                end+=1
            mapping.append(dict(function=name,lineStart=original.count('\n',0,m.start())+1,lineEnd=original.count('\n',0,end)+1,sourceSpanSha256=sha(original[m.start():end].encode()),solidity='src/doom/am_map.sol'))
        files=[SRC/f for f in ['am_map.c','am_map.h','m_cheat.c','m_cheat.h','m_fixed.c','tables.c','v_video.c','doomdata.h','doomdef.h','r_defs.h','d_englsh.h']]+[HERE/f for f in ['host.c','compat.h','reference.py']]
        evidence=dict(status='passed',caseCount=len(rows),snapshots=snapshots,profiles=profiles,exactAgreement=True,projectionSha256=sha(projection.encode()),functionMapping=mapping,sourceSha256={str(f.relative_to(ROOT)):sha(f.read_bytes()) for f in files},
                      hostAdaptations=['Only #include lines removed from am_map.c; every function body, static, vector glyph and constant unchanged','Original v_video/m_bbox/m_fixed/m_cheat/tables compiled unchanged','Minimal named-field geometry/player structures; borrowed coordinates and flags; resource cache/tag/status-bar calls observed by stubs','Each case runs in a fresh process to reset statics; all actions emit complete state and 64000-byte frame','ASan/UBSan: shift disabled for original FTOM signed left shift; array-bounds disabled for original variable-sized patch columnofs; leak detection disabled for process-lifetime fixture allocations','E1M1 geometry from authentic Freedoom WAD; discovery flags seeded by index modulo 3; thing order is fixture order, both sides consume same traversal'],resourceBlobSha256=sha(blob),patches=patches,provenance=bundle['provenance'])
        (built/'native.json').write_text(json.dumps(evidence,indent=2)+'\n');(built/'cases.json').write_text(json.dumps(dict(cases=rows,caseCount=len(rows),snapshots=snapshots,casesSha256=sha(packed)),indent=2)+'\n')
        shutil.copyfile(ROOT/'test/fixtures/wad/COPYING.txt',built/'COPYING.txt')
        FIX.mkdir(exist_ok=True)
        if args.check:
            assert sorted(f.name for f in built.iterdir())==sorted(f.name for f in FIX.iterdir())
            for f in built.iterdir():assert f.read_bytes()==(FIX/f.name).read_bytes(),f.name
        else:
            for f in built.iterdir():shutil.copyfile(f,FIX/f.name)
        print(json.dumps(dict(status='passed',cases=len(rows),snapshots=snapshots,profiles=3,casesSha256=sha(packed))))
if __name__=='__main__':main()
