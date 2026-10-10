#!/usr/bin/env python3
"""Verify profile scope, mined evidence, native comparisons and observer samples."""
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'artifacts/local/virtual-pointer'
sys.path.insert(0,str(ROOT/'tools/reference/speedrun'))
from verify_video import states, dynamic, FRAME_TOPIC
sha=lambda b:hashlib.sha256(b).hexdigest()
load=lambda p:json.loads(p.read_text())


def replay(name, count, profile, observer=False):
    directory=OUT/name
    report=load(directory/'evm.json')
    assert report['pass'] and report['memoryProfile']==profile and report['provenanceObserver']==observer
    assert report['ownedRuntimeStopped'] and report['exit']['reached']
    assert report['verifiedTics']==report['executedTics']==279
    assert report['exit']['gameaction']==6 and report['exit']['nativeExitLine']==407
    native=states(gzip.decompress((ROOT/'artifacts/speedrun-e1m1/native-states.delta.bin.gz').read_bytes()),True)
    actual=states(gzip.decompress((directory/'evm.states.bin.gz').read_bytes()))
    assert len(actual)==len(native)==280 and actual==native
    for file,digest in report['sourceHashes'].items():
        assert sha((ROOT/file).read_bytes())==digest,file+' source drift'
    for suffix,key in [('capture','captureReceiptsSha256'),('replay','replayReceiptsSha256'),
                       ('deployment','deploymentReceiptsSha256')]:
        assert sha((directory/f'evm.{suffix}-receipts.json.gz').read_bytes())==report[key]
    captures=json.loads(gzip.decompress((directory/'evm.capture-receipts.json.gz').read_bytes()))
    assert len(captures)==len(report['frames'])==count
    for receipt,frame in zip(captures,report['frames']):
        assert receipt['status']=='0x1' and receipt['transactionHash']==frame['transactionHash']
        assert len(receipt['logs'])==(3 if observer else 2)
        assert all(log['address']==report['deployment']['address'] for log in receipt['logs'])
        log=next(log for log in receipt['logs'] if log['topics'][0]==FRAME_TOPIC)
        assert int(log['topics'][2],16)==frame['tic']
        pixels=(directory/frame['file']).read_bytes()
        assert pixels==dynamic(bytes.fromhex(log['data'][2:]),64)
        assert len(pixels)==64000 and sha(pixels)==frame['indexed8Sha256']
        assert frame['savedStateUnchanged'] and frame['validAfter']==frame['validBefore']+1
        if observer:
            samplelog=receipt['logs'][-2] # observer emits immediately before Frame
            records=dynamic(bytes.fromhex(samplelog['data'][2:]),0)
            assert len(records)==512*len(frame['virtualSamples'])
            for at,sample in enumerate(frame['virtualSamples']):
                values=[int.from_bytes(records[at*512+i*32:at*512+(i+1)*32],'big') for i in range(16)]
                assert values[15]==4 and values[7]==int(sample['virtualPointer'],16)
                assert values[8]==sample['sourceByte'] and values[9]==sample['drawnPixel']
                pointer=int(sample['virtualPointer'],16)
                assert pointer.to_bytes(8,'little').hex()==sample['pointerBytesLittleEndian']
                if sample['fieldOffset']!=8: assert pointer==0x1000000000+sample['targetOffset']
                else: assert pointer in [0,2]
                assert pointer.to_bytes(8,'little')[sample['relative']-sample['fieldOffset']]==sample['sourceByte']
                assert sample['finalPixel']==pixels[sample['y']*320+sample['x']]
    return report


def rejection(name, baseline=False):
    p=OUT/name/'evm.json';r=load(p);failure=r['renderFailure']
    assert not r['pass'] and failure['tic']==52 and failure['rpcError']['data']=='0x5b9a48fe'
    assert failure['gas']<10_000_000_000 and r['ownedRuntimeStopped']
    assert all(failure['rollback'][k] for k in ['allSavedFieldsUnchanged','nativeWorldExact','frameCounterUnchanged','noLogs'])
    for file,digest in r['sourceHashes'].items():
        data=subprocess.check_output(['git','show','c8392e9:'+file],cwd=ROOT) if baseline else (ROOT/file).read_bytes()
        assert sha(data)==digest,(name,file)
    return dict(name=name,gas=failure['gas'],elapsedMs=failure['elapsedMs'],transactionHash=failure['transactionHash'])


def main():
    full=replay('full-rate',279,'virtual')
    observed=replay('observer-full-rate',279,'virtual',True)
    sampled=replay('legacy-sampled',56,'legacy')
    assert [f['tic'] for f in full['frames']]==list(range(1,280))
    hashes=lambda r:[(f['tic'],f['indexed8Sha256']) for f in r['frames']]
    assert hashes(full)==hashes(observed),'Observer changed pixels'
    historical=load(ROOT/'artifacts/speedrun-e1m1-video/recording-result.json')
    assert hashes(sampled)==hashes(historical),'Existing56 sampled hashes changed'
    native=load(OUT/'native-frames/native-frames.json')
    assert len(native['frames'])==279 and len(native['profiles'])==3
    for profile in native['profiles']:
        assert len(profile['captures'])==279 and all(f['preRenderWorldExact'] for f in profile['captures'])
    # This is finite equality to declared captures, not portable pointer equality.
    assert hashes(full)==hashes(native),'Normal original-C captures changed'
    assert native['divergences']==[dict(profile='sanitize',tic=52,file='sanitize-frame-000052.indexed8',
        sha256='f356cafddcaaa15a5e309ff7cd0819ffbaed4a11800651be4af7c19a22f60411',pixels=1,
        first=[dict(offset=49901,x=301,y=155,O2=73,actual=105)])]
    samples=[dict(tic=f['tic'],**s) for f in observed['frames'] for s in f['virtualSamples']]
    assert len(samples)==1
    s=samples[0]
    assert s['tic']==52 and (s['x'],s['y'])==(301,155)
    assert s['physicalOffset']==12785689 and s['headerOffset']==12785664
    assert s['relative']==25 and s['fieldOffset']==24 and s['targetOffset']==12786048
    assert s['virtualPointer']=='0x0000001000c31980' and s['sourceByte']==25 and s['drawnPixel']==73
    assert s['drawnValueSurvives']
    original_samples=load(OUT/'native-sample/sample.json')
    for row in original_samples['profiles']:
        n=row['sample'];pointer=int(n['zoneAddress'],16)+n['sampleBlock']['next']
        assert ((pointer>>8)&255)==n['value']
        assert n['sample']==s['physicalOffset'] and n['sampleBlock']['next']==s['targetOffset']
        assert n['sourceBlock']['offset']==12785384 and n['sampleBlock']['offset']==s['headerOffset']
    pointer=load(OUT/'native-pointer/reference.json')
    assert pointer['pass_'] and len(pointer['runs'])==12
    decoder=load(OUT/'decoder-check.json')
    assert all(decoder[k] for k in ['pass_','oldABI','newABIFalse','newABITrue'])
    rejected=[rejection('baseline-'+p,True) for p in ['strict','legacy','episode']]
    rejected += [rejection('disabled-'+p) for p in ['strict','legacy','episode']]
    tests={}
    for name in ['virtual-tests','memory-regression','episode-regression']:
        log=(OUT/(name+'.log')).read_text()
        assert '[FAIL' not in log and '0 failed' in log,name
        tests[name]=next(line for line in reversed(log.splitlines()) if 'tests passed' in line)
    result=dict(pass_=True,virtualBase='0x0000001000000000',gameplayWorlds=280,gameplayTics=279,
        fullRateFrames=279,originalSampledHashes=56,originalCNormalFrameMatches=279,
        commonNativeExactFrames=278,virtualProfileSamples=samples,remainingRejectedSamples=0,
        nativeProfileDivergence=native['divergences'],rejections=rejected,tests=tests,
        diagnosticABI=decoder,
        fidelity='One recorded provenance4 sample remains a deterministic extension despite matching '
                 'normal O0/O2 native pixels. Sanitized native tic52 differs. No universal native equivalence.',
        deployment=full['deployment'],sourceHashes=full['sourceHashes'],
        totalCaptureGas=full['totalCaptureGas'],totalReplayGas=full['totalReplayGas'],
        replayElapsedMs=full['replayElapsedMs'],captureTransactionElapsedMs=full['captureTransactionElapsedMs'])
    (OUT/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
    manifest=dict(memoryProfile='experimental-virtual',virtualBase=result['virtualBase'],
                  pointerWidth=8,endianness='little',alignment=8,addressLimitExclusive='0x1000000000000',
                  samples=samples,frames=[dict(tic=f['tic'],indexed8Sha256=f['indexed8Sha256'],
                     category='virtual-pointer-extension' if f['virtualSamples'] else 'finite-native-exact',
                     virtualSampleCount=len(f['virtualSamples'])) for f in observed['frames']],
                  limitations=result['fidelity'])
    (OUT/'virtual-profile-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ['sourceHashes','deployment','rejections']},indent=2))


if __name__=='__main__':main()
