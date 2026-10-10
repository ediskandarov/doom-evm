#!/usr/bin/env python3
"""Read-only audit evidence/source/fixture checks; never regenerates accepted data."""
import argparse, ast, hashlib, json, pathlib, re, struct
ROOT=pathlib.Path(__file__).resolve().parents[3]
SHA=lambda b:hashlib.sha256(b).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=pathlib.Path,default=ROOT/'artifacts/phase4/native-memory-audit');args=ap.parse_args();out=args.output
    report=json.loads((out/'experiment.json').read_text());inventory=json.loads((out/'inventory.json').read_text())
    checked=0
    for doc in [report,inventory]:
        for name,digest in doc['sourceHashes'].items():assert SHA((ROOT/name).read_bytes())==digest,name;checked+=1
    for b in report['builds']:
        raw=(out/(b['profile']+'-build.log')).read_bytes();assert SHA(raw)==b['buildLogSha256']
        assert len(b['executableSha256'])==64 and b['command'][0]==report['compiler']
    successes=failures=0;paddings={};pointer_values=set()
    for r in report['runs']:
        raw=(out/r['stdout']).read_bytes();err=(out/r['stderr']).read_bytes()
        assert SHA(raw)==r['stdoutSha256'] and SHA(err)==r['stderrSha256']
        if r['expectedFailure']:
            assert r['profile']=='original-align4-sanitized' and r['exitCode']!=0 and b'misaligned address' in err;failures+=1;continue
        assert r['exitCode']==0 and not err;successes+=1
        rows=[json.loads(x) for x in raw.splitlines()];layout=rows[0]
        assert layout['offsets']==[0,8,16,20,24,32] and layout['memblock']==40 and layout['memzone']==56 and layout['littleEndian']
        zones={x['stage']:x for x in rows if x['kind']=='zone'}
        for z in zones.values():
            for b in z['blocks']:
                header=bytes.fromhex(b['header']);assert b['allPointersBelow2Pow48']
                for key,offset in [('user',8),('next',24),('prev',32)]:
                    value=int(b[key],16);pointer_values.add(value);assert value<2**48
                    assert int.from_bytes(header[offset:offset+8],'little')==value
                    assert header[offset+6:offset+8]==b'\0\0'
        padding=bytes.fromhex(zones['alloc1-17-64']['blocks'][0]['header'])[4:8]
        paddings.setdefault(r['profile']+'/'+r['policy'],set()).add(padding.hex())
        if r['policy']!='malloc':assert padding==bytes([165 if r['policy']=='a5' else 0])*4
        if r['profile']!='original-align4':
            assert [b['offset'] for b in zones['alloc1-17-64']['blocks']]==[56,104,168,272]
            assert bytes.fromhex(zones['reuse7']['first256Bytes'])[144:161]==bytes([34])*17
        draw=next(x for x in rows if x['kind']=='draw');assert [draw[k] for k in ['headerByte527','payloadByte559','pixel527','pixel559']]==[0,98,0,98]
        comp=[x for x in rows if x['kind']=='composite'];assert [x['bytes'] for x in comp]==['0a141516'+'00'*12,'0a141516'+'a5'*12]
    repetitions=len({r['repetition'] for r in report['runs']})
    assert len(report['builds'])==7 and successes==21*repetitions and failures==repetitions
    for name,m in inventory['macros'].items():assert SHA((out/(name+'-macros.txt')).read_bytes())==m['sha256']
    assert inventory['records'][0]['matchedTypes']==26
    # Accepted fixture identity, original sources and all fixture payload hashes.
    folder=ROOT/'test/fixtures/phase2_data';manifest=json.loads((folder/'manifest.json').read_text())
    for name,digest in manifest['sources'].items():assert SHA((ROOT/'original/DOOM/linuxdoom-1.10'/name).read_bytes())==digest,name
    for name,digest in manifest['files'].items():assert SHA((folder/name).read_bytes())==digest,name
    for name,digest in manifest['shimSha256'].items():assert SHA((ROOT/'tools/reference/phase2_data'/name).read_bytes())==digest,name
    raw=(folder/'resources.bin').read_bytes();count=struct.unpack_from('<I',raw)[0];assert count==963
    composites=[]
    for i in range(count):
        pos=4+i*84;w,h,mask,size=struct.unpack_from('<4I',raw,pos);holes=struct.unpack_from('<I',raw,pos+80)[0]
        assert holes==0;composites.append(size)
    binding=json.loads((ROOT/'artifacts/phase4/episode-completion/composite-native-binding.json').read_text())
    pos=4+76*84;assert struct.unpack_from('<4I',raw,pos)[0:2]==(32,16)
    assert struct.unpack_from('<I',raw,pos+12)[0]==512
    assert raw[pos+48:pos+80].hex()==binding['sourceCompositeSha256']
    assert SHA(raw)==binding['nativeFixtureSha256']
    pointer_path=ROOT/'tools/reference/episode_completion/pointer.py';tree=ast.parse(pointer_path.read_text())
    host=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='host' for t in n.targets))
    pointer=json.loads((ROOT/'artifacts/phase4/episode-completion/pointer-native.json').read_text())
    assert SHA(pointer_path.read_bytes())==pointer['sourceHashes']['runner'] and SHA(host.encode())==pointer['sourceHashes']['host']
    assert SHA((ROOT/'original/DOOM/linuxdoom-1.10/z_zone.c').read_bytes())==pointer['sourceHashes']['z_zone.c']
    blood=json.loads((ROOT/'test/fixtures/drawbounds_blood/native.json').read_text())
    for name,digest in blood['sourceHashes'].items():assert SHA((ROOT/name).read_bytes())==digest,name
    assert len(blood['rows'])==9 and {x['seed'] for x in blood['rows']}=={0,85,165}
    assert all(x['paddingBefore']==x['paddingAfter']==x['seed'] and x['firstPixel']==x['expectedPixel'] for x in blood['rows'])
    print(json.dumps(dict(status='PASS',sourceBindings=checked,successfulProcessRuns=successes,expectedMisalignmentFailures=failures,textureRecords=count,nonemptyComposites=sum(x>0 for x in composites),compositeHoleBytes=0,record76Bound=True,bloodRows=len(blood['rows']),distinctObservedPointerValues=len(pointer_values),observedPadding={k:sorted(v) for k,v in paddings.items()}),indent=2))
if __name__=='__main__':main()
