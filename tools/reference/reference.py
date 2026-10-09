#!/usr/bin/env python3
"""Pinned, mechanically extracted DOOM C oracle. No numerical algorithms duplicated here."""
import argparse, hashlib, json, os, pathlib, random, re, struct, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
HERE=ROOT/'tools/reference'
SOURCE=ROOT/'original/DOOM/linuxdoom-1.10'
FIXTURES=ROOT/'test/fixtures/reference'
UPSTREAM='a77dfb96cb91780ca334d0d4cfd86957558007e0'
FLAGS=['-std=c99','-O2','-fwrapv','-fno-strict-aliasing','-ffp-contract=off','-fno-fast-math']
VERSION='Apple clang version 17.0.0 (clang-1700.0.13.5)'
TARGET='arm64-apple-darwin24.6.0'
PINS={'m_fixed.h':'67aa3925a905d448fb947fb7358093a39367f534c3e26e3f8b06228f553227ef','tables.h':'54e366ed33a0bd65e5cad6c5b6f7df77573909e5974b8af296fdb1503c77fcf2','m_fixed.c':'a4472841bc8890c5d5a41b325ecf56d10d7026a7489967aa29100b5dee759fea','r_main.c':'2aae43cf807929a8758f71ed0205fc08017556541ba8df2ea9167c003d0dec5a','tables.c':'db8759f4311654c63785dcffb8f73a00a61cfe2713e4284c238dea420b6e5f89'}
def sha(data): return hashlib.sha256(data).hexdigest()
def canonical(value): return json.dumps(value,sort_keys=True,separators=(',',':')).encode()
def invoke(cmd,**kwargs): return subprocess.run(cmd,check=True,text=True,capture_output=True,**kwargs).stdout

def extract(filename,name,result):
    text=(SOURCE/filename).read_text()
    match=re.search(r'\n'+re.escape(result)+r'\s*\n'+name+r'\s*\(',text)
    assert match, name
    start=match.start()+1; opening=text.index('{',match.end()); end=opening+1; depth=1
    while depth:
        if text[end]=='{': depth+=1
        elif text[end]=='}': depth-=1
        end+=1
    body=text[start:end]
    return body,{'file':filename,'function':name,'startLine':text[:start].count('\n')+1,'endLine':text[:end].count('\n')+1,'sha256':sha(body.encode())}

def build(directory):
    assert invoke(['git','-C',str(SOURCE),'rev-parse','HEAD']).strip()==UPSTREAM,'Upstream commit mismatch'
    version=invoke(['clang','--version']).splitlines()
    assert version[0]==VERSION and version[1]=='Target: '+TARGET, 'Unreviewed native compiler profile'
    for name,digest in PINS.items(): assert sha((SOURCE/name).read_bytes())==digest,name
    # Headers are retained verbatim as part of the source identity.
    hashes={name:sha((SOURCE/name).read_bytes()) for name in PINS}
    records=[]; units=[]
    for file,name,result in [('m_fixed.c','FixedMul','fixed_t'),('m_fixed.c','FixedDiv','fixed_t'),('m_fixed.c','FixedDiv2','fixed_t'),('r_main.c','R_PointOnSide','int'),('r_main.c','R_PointToAngle','angle_t'),('r_main.c','R_PointToAngle2','angle_t')]:
        body,record=extract(file,name,result); units.append(body); records.append(record)
    body,record=extract('r_main.c','R_PointInSubsector','subsector_t*'); records.append(record)
    trace='''static int traced_side(fixed_t x,fixed_t y,node_t *node) {
        if(trace_count >= numnodes) I_Error("BSP cycle");
        trace[trace_count++]=(int)(node-nodes);
        return R_PointOnSide(x,y,node);
    }
    #define R_PointOnSide traced_side
    '''
    generated='#include "compat.h"\n'+'\n'.join(units)+'\n'+trace+body+'\n#undef R_PointOnSide\n#include "driver.c"\n'
    cfile=directory/'oracle.c'; cfile.write_text(generated)
    for opt in ['O0','O2']:
        flags=[('-'+opt if f=='-O2' else f) for f in FLAGS]
        invoke(['clang',*flags,'-I'+str(HERE),'-I'+str(SOURCE),str(cfile),str(SOURCE/'tables.c'),'-o',str(directory/opt)])
    invoke(['clang',*[f for f in FLAGS if f!='-fwrapv'],'-fsanitize=undefined,float-cast-overflow','-fno-sanitize-recover=all','-I'+str(HERE),'-I'+str(SOURCE),str(cfile),str(SOURCE/'tables.c'),'-o',str(directory/'sanitize')])
    patches={'compat.h':sha((HERE/'compat.h').read_bytes()),'driver.c':sha((HERE/'driver.c').read_bytes()),'traceAdapter':sha(trace.encode())}
    metadata={'compiler':'clang','version':VERSION,'target':TARGET,'flags':FLAGS,'sourceSha256':sha(canonical(hashes)),'harnessSha256':sha((HERE/'reference.py').read_bytes()),'patchSha256':sha(canonical(patches)),'integerSemantics':'32-bit int; 64-bit long long; arithmetic signed right shift; signed narrowing wraps on pinned Clang; -fwrapv; abs(INT_MIN) remains undefined and excluded','doubleSemantics':'IEEE binary64; round-to-nearest ties-to-even; no fast-math or contraction; original double division then exact power-of-two scale; 0/0 float-to-int is undefined'}
    return metadata,{'sources':hashes,'extractions':records,'generatedSourceSha256':sha(generated.encode()),'portabilityShims':patches}

def run(binary,rows,map_args=()):
    commands=''.join(row['function']+' '+' '.join(map(str,row['inputs']))+'\n' for row in rows)
    lines=invoke([str(binary),*map(str,map_args)],input=commands).splitlines(); assert len(lines)==len(rows)
    return [dict(row,status=line.split()[0],outputs=[int(x) for x in line.split()[1:]],note=('original I_Error intercepted by longjmp' if line=='error' else row['note'])) for row,line in zip(rows,lines)]

def row(fn,args,note=''): return {'function':fn,'inputs':list(args),'outputs':[],'status':'ok','note':note}

def numeric_rows():
    rng=random.Random(0x444f4f4d)
    edge=[-2147483648,-2147483647,-1073741824,-65537,-65536,-16384,-1,0,1,2,16383,16384,65535,65536,65537,1073741824,2147483647]
    rows=[]
    for fn in ['FixedMul','FixedDiv','FixedDiv2']:
        pairs=[(a,b) for a in edge for b in edge]
        pairs += [(rng.randint(-2147483648,2147483647),rng.randint(-2147483648,2147483647)) for _ in range(512)]
        # Division thresholds, quotient truncation and binary64 integer-neighbor cases.
        pairs += [(a,b) for a,b in [(-2147483648,65535),(-2147483647,65535),(-2147450881,65535),(-2147450880,65535),(2147450880,-65535),(2147450881,-65535),(2147483647,65536),(-2147483648,65536)]]
        pairs += [(a,b) for b in [-65536,-32768,-2,-1,1,2,32768,65536] for a in [max(-2147483648,min(2147483647,abs(b)*32768+d)) for d in [-1,0,1]]]
        pairs += [(sign*(abs(b)*16384+d),b) for b in [-65536,-32768,-2,-1,1,2,32768,65536] for d in [-1,0,1] for sign in [-1,1] if -2147483648<=sign*(abs(b)*16384+d)<=2147483647]
        for a,b in pairs:
            item=row(fn,[a,b])
            if fn=='FixedDiv' and -2147483648 in [a,b]: item.update(status='undefined',note='abs(INT_MIN) is undefined in original C; no equivalence claim')
            if fn=='FixedDiv2' and a==b==0: item.update(status='undefined',note='NaN to int conversion is undefined in original C')
            rows.append(item)
    unsigned=[0,1,511,512,513,65535,65536,536870911,536870912,2147483648,4294967295]
    rows += [row('SlopeDiv',[a,b]) for a in unsigned for b in unsigned]
    rows += [row('SlopeDiv',[rng.randrange(2**32),rng.randrange(2**32)]) for _ in range(512)]
    return rows

def geometry_rows():
    rows=[]; rng=random.Random(0x425350)
    for x,y in [(0,0),(65536,0),(-65536,0),(0,65536),(0,-65536),(65536,65536),(-65536,65536),(-65536,-65536),(65536,-65536)]:
        rows.append(row('R_PointToAngle2',[0,0,x,y],'axis, octant or coincident-point boundary'))
        for dx,dy in [(0,65536),(0,-65536),(65536,0),(-65536,0),(65536,65536),(-65536,65536)]: rows.append(row('R_PointOnSide',[x,y,0,0,dx,dy]))
    for _ in range(256):
        rows.append(row('R_PointToAngle2',[rng.randint(-1000,1000)*65536 for _ in range(4)]))
        rows.append(row('R_PointOnSide',[rng.randint(-1000,1000)*65536 for _ in range(6)]))
    for x,y in [(0,0),(-65536,0),(65536,0)]:
        for fn in ['R_PointInSubsector','BSPPath']: rows.append(row(fn,[x,y],'synthetic one-node vertical partition, children 0x8000 and 0x8001'))
    return rows

def evaluate(directory,rows,map_args=()):
    defined=[r for r in rows if r['status']!='undefined']
    baseline=run(directory/'O2',defined,map_args)
    assert baseline==run(directory/'O0',defined,map_args),'O0/O2 semantic mismatch'
    assert baseline==run(directory/'sanitize',defined,map_args),'sanitized semantic mismatch'
    outputs=iter(baseline)
    return [r if r['status']=='undefined' else next(outputs) for r in rows]

def emit_solidity(rows):
    data=b''
    for r in rows:
        op=['FixedMul','FixedDiv','FixedDiv2','SlopeDiv'].index(r['function']); status=['ok','error','undefined'].index(r['status'])
        data+=bytes([op,status])+struct.pack('>qqq',*r['inputs'],r['outputs'][0] if r['outputs'] else 0)
    source=('// SPDX-License-Identifier: GPL-2.0-only\npragma solidity 0.8.37;\n// Generated from original C by tools/reference/reference.py. Do not edit.\nlibrary ReferenceNumericVectors {\n'
        +f'    function count() internal pure returns (uint256) {{ return {len(rows)}; }}\n'
        +'    function data() internal pure returns (bytes memory) { return hex"'+data.hex()+'"; }\n'
        +'    function vector(uint256 index) internal pure returns (uint8, int64, int64, int64, uint8) { return vector(data(), index); }\n'
        +'    function vector(bytes memory packed, uint256 index) internal pure returns (uint8 op, int64 a, int64 b, int64 expected, uint8 status) {\n'
        +'        require(index < count() && packed.length == count() * 26);\n        uint256 offset = index * 26;\n'
        +'        op = uint8(packed[offset]); status = uint8(packed[offset + 1]);\n        uint64 aa; uint64 bb; uint64 ee;\n'
        +'        for (uint256 j; j < 8; ++j) { aa = (aa << 8) | uint8(packed[offset + 2 + j]); bb = (bb << 8) | uint8(packed[offset + 10 + j]); ee = (ee << 8) | uint8(packed[offset + 18 + j]); }\n'
        +'        return (op, int64(aa), int64(bb), int64(ee), status);\n    }\n}\n')
    return invoke([str(ROOT/'.toolchain/bin/forge'),'fmt','--root',str(ROOT),'--raw','-'],input=source).encode()

def wad_map(wad,directory):
    data=wad.read_bytes(); magic,count,offset=struct.unpack_from('<4sii',data)
    assert magic in [b'IWAD',b'PWAD'] and 0<=count and 0<=offset<=len(data)-16*count
    lumps=[]
    for i in range(count):
        pos,size,name=struct.unpack_from('<ii8s',data,offset+16*i); assert 0<=pos<=len(data) and 0<=size<=len(data)-pos
        lumps.append((name.rstrip(b'\0').decode('ascii'),data[pos:pos+size]))
    index=[i for i,(name,_) in enumerate(lumps) if name=='E1M1'][-1]
    selected=dict(lumps[index+1:index+11]); nodes=selected['NODES']; subsectors=selected['SSECTORS']
    assert len(nodes)%28==0 and len(subsectors)%4==0
    # Validate all graph references and cycles before native traversal.
    children=[struct.unpack_from('<HH',nodes,i+24) for i in range(0,len(nodes),28)]
    visited=set(); active=set()
    def visit(i):
        if i&32768: assert (i&32767)<len(subsectors)//4; return
        assert i<len(children) and i not in active
        if i in visited: return
        active.add(i)
        for child in children[i]: visit(child)
        active.remove(i); visited.add(i)
    for i in range(len(children)): visit(i)
    (directory/'nodes.bin').write_bytes(nodes)
    things=selected['THINGS']; starts=[struct.unpack_from('<hhhhh',things,i) for i in range(0,len(things),10) if struct.unpack_from('<h',things,i+6)[0]==1]; assert starts
    x,y,angle,_,_=starts[0]
    points=[(x*65536,y*65536),(0,0)]+[(struct.unpack_from('<hh',selected['VERTEXES'],i)[0]*65536,struct.unpack_from('<hh',selected['VERTEXES'],i)[1]*65536) for i in range(0,min(len(selected['VERTEXES']),4*128),4)]
    vertices=[struct.unpack_from('<hh',selected['VERTEXES'],i) for i in range(0,len(selected['VERTEXES']),4)]
    rng=random.Random(0x45314d31)
    points += [(rng.randint(min(v[0] for v in vertices),max(v[0] for v in vertices))*65536,rng.randint(min(v[1] for v in vertices),max(v[1] for v in vertices))*65536) for _ in range(256)]
    rows=[row(fn,p) for p in points for fn in ['R_PointInSubsector','BSPPath']]
    leaf=run(directory/'O2',[row('R_PointInSubsector',[x*65536,y*65536])],[directory/'nodes.bin',len(subsectors)//4])[0]['outputs'][0]
    firstseg=struct.unpack_from('<H',subsectors,leaf*4+2)[0]
    linedef,side=struct.unpack_from('<HH',selected['SEGS'],firstseg*12+6)
    assert side in [0,1]
    sidedef=struct.unpack_from('<H',selected['LINEDEFS'],linedef*14+10+side*2)[0]
    sector=struct.unpack_from('<H',selected['SIDEDEFS'],sidedef*30+28)[0]
    floor,ceiling=struct.unpack_from('<hh',selected['SECTORS'],sector*26)
    camera={'x':x*65536,'y':y*65536,'z':min(floor+41,ceiling-4)*65536,'angle':((int(angle/45)*0x20000000)&0xffffffff),'coordinateFormat':'signed-16.16','angleFormat':'binary-angle-uint32'}
    config={'kind':'camera-test-configuration','rendererGoldenAvailable':False,'reason':'Phase 1 does not port or render original full engine frames','wadSha256':sha(data),'map':'E1M1','camera':camera,'viewZPolicy':'stationary initial camera: min(sector floor+VIEWHEIGHT(41), ceiling-4), bob=0; configuration only, no frame rendered','spawnSubsector':leaf,'spawnSector':sector,'detail':'high','colormap':0,'lighting':{'extraLight':0,'fixedColormap':-1},'gametic':0,'width':320,'height':200,'nodesSha256':sha(nodes),'subsectorCount':len(subsectors)//4}
    return rows,[directory/'nodes.bin',len(subsectors)//4],config

def artifact(meta,scope,rows,wadsha='0'*64,mapname=''):
    return {'schemaVersion':1,'upstreamCommit':UPSTREAM,'wadSha256':wadsha,'scope':scope,'map':mapname,'build':meta,'vectors':rows}

def validate_vectors(document):
    """Semantic layer after vectors-v1 schema validation; also safe standalone."""
    def require(condition, message):
        if not condition: raise ValueError(message)
    require(document['schemaVersion']==1 and document['upstreamCommit']==UPSTREAM,'Wrong source identity/version')
    scope=document['scope']; digest=document['wadSha256']
    require(re.fullmatch('[0-9a-f]{64}',digest) is not None,'Invalid WAD hash')
    require(scope in ['numeric','geometry-synthetic','geometry-wad'],'Invalid scope')
    require((digest!='0'*64 and document['map']=='E1M1') if scope=='geometry-wad' else (digest=='0'*64 and document['map']==''),'Scope/WAD/map mismatch')
    signatures={'FixedMul':(2,False),'FixedDiv':(2,False),'FixedDiv2':(2,False),'SlopeDiv':(2,True),'R_PointOnSide':(6,False),'R_PointToAngle2':(4,False),'R_PointInSubsector':(2,False),'BSPPath':(2,False)}
    require(bool(document['vectors']),'Empty fixture')
    for entry in document['vectors']:
        fn=entry['function']; require(fn in signatures,'Unknown function'); arity,unsigned=signatures[fn]
        require((fn in ['FixedMul','FixedDiv','FixedDiv2','SlopeDiv'])==(scope=='numeric'),'Function/scope mismatch')
        require(len(entry['inputs'])==arity,'Wrong input arity')
        require(all(type(value)==int and (0<=value<=4294967295 if unsigned else -2147483648<=value<=2147483647) for value in entry['inputs']),'Input range/type')
        status=entry['status']; output=entry['outputs']; require(status in ['ok','error','undefined'],'Status invalid')
        undefined=(fn=='FixedDiv' and -2147483648 in entry['inputs']) or (fn=='FixedDiv2' and entry['inputs']==[0,0])
        require((status=='undefined')==undefined,'Wrong undefined-domain classification')
        if status=='error': require(fn=='FixedDiv2','Unexpected error function')
        if status!='ok':
            require(output==[] and bool(entry['note']),'Non-ok output/note invalid'); continue
        require(len(output)>=1 if fn=='BSPPath' else len(output)==1,'Wrong output arity')
        require(all(type(value)==int for value in output),'Noninteger output')
        if fn in ['FixedMul','FixedDiv','FixedDiv2']: require(-2147483648<=output[0]<=2147483647,'Fixed output range')
        elif fn=='SlopeDiv': require(0<=output[0]<=2048,'Slope output range')
        elif fn=='R_PointOnSide': require(output[0] in [0,1],'Side output range')
        elif fn=='R_PointToAngle2': require(0<=output[0]<=4294967295,'Angle output range')
        elif fn=='R_PointInSubsector': require(0<=output[0]<32768,'Subsector output range')
        else: require(all(0<=value<32768 for value in output[:-1]) and 32768<=output[-1]<=65535,'BSP trace encoding')


def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--check',action='store_true'); parser.add_argument('--wad',type=pathlib.Path); args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='doom-c-reference-') as temporary:
        directory=pathlib.Path(temporary); meta,extractions=build(directory)
        numeric=evaluate(directory,numeric_rows()); geometry=evaluate(directory,geometry_rows())
        dump=directory/'dump.c'; dump.write_text('#include <stdio.h>\n#include "tables.h"\nint main(void){fwrite(finesine,4,10240,stdout);fwrite(finesine+2048,4,8192,stdout);fwrite(finetangent,4,4096,stdout);fwrite(tantoangle,4,2049,stdout);return 0;}\n')
        invoke(['clang',*FLAGS,'-I'+str(SOURCE),str(dump),str(SOURCE/'tables.c'),'-o',str(directory/'dump')])
        native_tables=subprocess.run([str(directory/'dump')],check=True,capture_output=True).stdout
        table_hashes={}; offset=0
        for name,count in [('finesine',10240),('finecosine',8192),('finetangent',4096),('tantoangle',2049)]:
            table_hashes[name]={'count':count,'sha256':sha(native_tables[offset:offset+count*4])}; offset+=count*4
        assert len(native_tables)==offset
        results={'native-table-hashes.json':{'encoding':'little-endian-32-bit-native-arm64','tables':table_hashes},'numeric-v1.json':artifact(meta,'numeric',numeric),'geometry-synthetic-v1.json':artifact(meta,'geometry-synthetic',geometry),'extraction-manifest.json':extractions}
        # Intentionally execute undefined cases separately; outputs are observations, never vectors.
        observations=[]
        for fn,a,b in [('FixedDiv',-2147483648,1),('FixedDiv',1,-2147483648),('FixedDiv',-2147483648,-2147483648),('FixedDiv2',0,0)]:
            item={'function':fn,'inputs':[a,b],'classification':'undefined','runs':{}}
            for profile in ['O0','O2','sanitize']:
                p=subprocess.run([str(directory/profile)],input=f'{fn} {a} {b}\n',text=True,capture_output=True)
                item['runs'][profile]={'exitCode':p.returncode,'stdout':p.stdout.strip(),'diagnostic':p.stderr.replace(str(directory),'<build>').strip()}
            observations.append(item)
        # libc/builtin abs is not reliably UBSan-instrumented; explicitly audit its required negation.
        audit=directory/'abs-audit.c'; audit.write_text('#include <limits.h>\nint main(void){volatile int x=INT_MIN; return x<0 ? -x:x;}\n')
        invoke(['clang','-O2','-fsanitize=undefined','-fno-sanitize-recover=all',str(audit),'-o',str(directory/'abs-audit')])
        p=subprocess.run([str(directory/'abs-audit')],text=True,capture_output=True)
        assert p.returncode!=0 and 'negation of -2147483648' in p.stderr
        results['undefined-audit.json']={'note':'Original outputs are compiler-profile observations only. abs audit is a separate instrumentation surrogate, not patched oracle. Sanitizer paths normalized.','original':observations,'absDomainAudit':{'exitCode':p.returncode,'diagnostic':p.stderr.replace(str(directory),'<build>').strip()}}
        if args.wad:
            rows,mapargs,camera=wad_map(args.wad,directory)
            camera.update(upstreamCommit=UPSTREAM,build=meta)
            results['geometry-wad-v1.json']=artifact(meta,'geometry-wad',evaluate(directory,rows,mapargs),camera['wadSha256'],'E1M1'); results['camera-e1m1.json']=camera
        for value in results.values():
            if isinstance(value,dict) and 'vectors' in value: validate_vectors(value)
        files={name:(json.dumps(value,indent=2)+'\n').encode() for name,value in results.items()}
        files['ReferenceNumericVectors.sol']=emit_solidity(numeric)
        for name,content in files.items():
            path=FIXTURES/name
            if args.check: assert path.read_bytes()==content, 'Reference drift: '+str(path)
            else: path.write_bytes(content)
        print(json.dumps({'numericVectors':len(numeric),'geometryVectors':len(geometry),'files':list(files),'O0O2':'identical','definedSanitizer':'clean','mode':'check' if args.check else 'generate'}))
if __name__=='__main__': main()
