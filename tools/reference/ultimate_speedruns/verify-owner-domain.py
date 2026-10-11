#!/usr/bin/env python3
"""Independently verify complete/partial receipts and declared pixel comparisons."""
import argparse,gzip,json,sys,subprocess
from fractions import Fraction
from PIL import Image
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/reference/speedrun'))
from verify_video import states,dynamic,sha,FRAME_TOPIC


def verify(base,recording,native_frames=None):
    load=lambda p:json.loads(p.read_text())
    r=load(recording/'evm.json');m=load(recording/'frame-manifest.json');n=load(base/'native-result.json')
    domain=json.loads((base/'native-domain.json').read_text())
    assert domain['pass'] and domain['profile']=='initial-zero-zone'
    assert r['nativeProfile']==domain['profile'] and r['nativeDomain']==domain
    assert sha((base/'native-result.json').read_bytes())==domain['nativeResultSha256']
    assert all(p['allStateBytesEqual'] for p in domain['profiles'] if p['name']!='sanitize-fill')
    assert r['memoryProfile']=='virtual' and r['provenanceObserver']
    assert r['ownedRuntimeStopped']
    native=states(gzip.decompress((base/'native-states.delta.bin.gz').read_bytes()),True)
    actual=states(gzip.decompress((recording/'evm.states.bin.gz').read_bytes()))
    assert actual==native[:len(actual)] and len(actual)==r['verifiedTics']+1
    demo=(base/'source-download').read_bytes();assert sha(demo)==r['demoSha256']==n['demoSha256']
    assert sha(demo[13:13+n['executedTics']*4])==r['originalCommandBytesSha256']
    replay=load_gzip(recording/'evm.replay-receipts.json.gz');captures=load_gzip(recording/'evm.capture-receipts.json.gz')
    observed=[];address=r['deployment']['address']
    for receipt in replay:
        assert receipt['status']=='0x1'
        for log in receipt['logs']:
            assert log['address']==address;data=bytes.fromhex(log['data'][2:]);tic=int.from_bytes(data[:32],'big')
            assert dynamic(data,32)==native[tic];observed.append(tic)
    assert observed==list(range(len(actual)))
    assert [f['tic'] for f in m['frames']]==list(range(1,len(m['frames'])+1))
    successes=[c for c in captures if c['status']=='0x1'];assert len(successes)==len(m['frames'])
    samples=[]
    for c,f in zip(successes,m['frames']):
        assert c['transactionHash']==f['transactionHash'] and int(c['gasUsed'],16)==f['gas']
        assert len(c['logs'])==3 and all(l['address']==address for l in c['logs'])
        log=next(l for l in c['logs'] if l['topics'][0]==FRAME_TOPIC)
        assert int(log['topics'][1],16)==int(f['frameId']) and int(log['topics'][2],16)==f['tic']
        pixels=dynamic(bytes.fromhex(log['data'][2:]),64);assert pixels==(recording/f['file']).read_bytes() and len(pixels)==64000 and sha(pixels)==f['indexed8Sha256']
        proof=bytes.fromhex(c['logs'][0]['data'][2:]);assert proof[:32].hex()==f['beforeStateSha256']==sha(native[f['tic']])
        assert proof[32:64].hex()==f['renderedMemoryStateSha256'] and f['savedStateUnchanged']
        assert f['validAfter']==f['validBefore']+1
        records=dynamic(bytes.fromhex(c['logs'][1]['data'][2:]),0);assert len(records)==512*len(f['virtualSamples'])
        for i,s in enumerate(f['virtualSamples']):
            v=[int.from_bytes(records[i*512+j*32:i*512+(j+1)*32],'big') for j in range(16)]
            assert v[15] in (4,5) and v[15]==s['provenance'] and v[7]==int(s['virtualPointer'],16) and v[8]==s['sourceByte'] and v[9]==s['drawnPixel']
            names='sourceBlock physicalOffset headerBlock headerOffset relative fieldOffset targetOffset virtualPointer sourceByte drawnPixel x y sampleIndex logicalLength sourceOffset provenance'.split()
            assert all(v[j]==(int(s[key],16) if key=='virtualPointer' else s[key]) for j,key in enumerate(names))
            assert s['physicalOffset']==s['headerOffset']+s['relative']
            assert s['fieldOffset'] in (8,24,32) and 0<=s['relative']-s['fieldOffset']<8
            pointer=v[7];assert pointer.to_bytes(8,'little').hex()==s['pointerBytesLittleEndian']
            assert pointer.to_bytes(8,'little')[s['relative']-s['fieldOffset']]==s['sourceByte']
            if v[15]==5:
                assert s['fieldOffset']==8 and s['targetOffset']%8==0 and s['ownerSlotIndex']==s['targetOffset']//8
                assert 0<=s['ownerSlotIndex']<len(load(ROOT/'artifacts/local/ultimate-speedruns/wad/bundle.json')['lumps']) and pointer==0x2000000000+s['targetOffset']
            else:
                assert pointer in (0,2) if s['fieldOffset']==8 else pointer==0x1000000000+s['targetOffset']
            assert pixels[s['y']*320+s['x']]==s['finalPixel'];samples.append(dict(tic=f['tic'],**s))
    for suffix,key in [('capture','captureReceiptsSha256'),('replay','replayReceiptsSha256'),('deployment','deploymentReceiptsSha256')]:assert sha((recording/f'evm.{suffix}-receipts.json.gz').read_bytes())==r[key]
    for file,digest in r['sourceHashes'].items():assert sha((ROOT/file).read_bytes())==digest,file+' source drift'
    comparisons=[]
    if native_frames:
        nr=load(native_frames/'native-frames.json')
        bytic={f['tic']:f for f in m['frames']}
        for f in nr['frames']:
            if f['tic'] not in bytic:continue
            evm=(recording/bytic[f['tic']]['file']).read_bytes();normal=(native_frames/f['file']).read_bytes()
            assert sha(normal)==f['indexed8Sha256']
            profiles=[p['name'] for p in nr['profiles'] if any(c['tic']==f['tic'] and c['sha256']==sha(evm) and c['preRenderWorldExact'] for c in p['captures'])]
            comparisons.append(dict(tic=f['tic'],O2Equal=evm==normal,equalProfiles=profiles,virtualSamples=len(bytic[f['tic']]['virtualSamples'])))
    complete=bool(r['pass']);assert complete==m['pass']
    if complete:
        assert len(actual)==n['executedTics']+1 and len(m['frames'])==n['executedTics'] and r['exit']['reached']
        assert r['actualStateStreamSha256']==n['statesSha256']
    mediaVerified=False
    if complete and 'media' in m:
        palette=(recording/'palette.bin').read_bytes()
        assert len(palette)==768 and sha(palette)==m['authenticatedPaletteSha256']==r['resourceIdentity']['paletteSha256']
        for f in m['frames']:
            pixels=(recording/f['file']).read_bytes();rgb=b''.join(palette[p*3:p*3+3] for p in pixels)
            png=recording/f['png'];assert Image.open(png).convert('RGB').tobytes()==rgb
            assert sha(rgb)==f['rgbSha256'] and sha(png.read_bytes())==f['pngSha256']
        media=m['media'];mp4=recording/media['mp4'];assert sha(mp4.read_bytes())==media['mp4Sha256']
        probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-select_streams','v:0','-show_streams','-show_format','-of','json',str(mp4)]))
        stream=probe['streams'][0];assert int(stream['nb_read_frames'])==n['executedTics'] and Fraction(stream['avg_frame_rate'])==35
        assert (stream['width'],stream['height'],stream['sample_aspect_ratio'],stream['display_aspect_ratio'])==(1280,800,'5:6','4:3')
        assert abs(float(probe['format']['duration'])-n['executedTics']/35)<0.00001
        assert all(f['durationTics']==1 for f in m['frames']);mediaVerified=True
    result=dict(nativeProfile='initial-zero-zone',alternateAllocationGatePassed=n['allProfilesExact'],mediaVerified=mediaVerified,evidenceVerified=True,recordingComplete=complete,gameplayObservations=len(actual),verifiedGameplayTics=r['verifiedTics'],EVMFrames=len(m['frames']),virtualSampleUses=len(samples),virtualDerivedDestinations=len({(s['tic'],s['x'],s['y']) for s in samples}),nativePixelComparisons=comparisons,unresolvedFailure=r.get('renderFailure') or r.get('error'),totalGas=r['totalGasIncludingStartupAndDeployment'])
    (recording/'verification.json').write_text(json.dumps(result,indent=2)+'\n');(recording/'virtual-samples.json').write_text(json.dumps(samples,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='nativePixelComparisons'},indent=2))
    return result

def load_gzip(p):return json.loads(gzip.decompress(p.read_bytes()))
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('base',type=Path);ap.add_argument('recording',type=Path);ap.add_argument('--native-frames',type=Path);a=ap.parse_args();verify(a.base.resolve(),a.recording.resolve(),a.native_frames.resolve() if a.native_frames else None)
