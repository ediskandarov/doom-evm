#!/usr/bin/env python3
"""Explain encoded-file differences without modifying accepted media or frames."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'artifacts/ultimate-speedruns/owner-pointer'
sha=lambda data:hashlib.sha256(data).hexdigest()
containers={b'moov',b'trak',b'mdia',b'minf',b'stbl',b'edts',b'dinf',b'udta'}
def atoms(data,start=0,end=None,path=''):
 end=len(data) if end is None else end;out={}
 while start<end:
  size=int.from_bytes(data[start:start+4],'big');kind=data[start+4:start+8];header=8
  if size==1:size=int.from_bytes(data[start+8:start+16],'big');header=16
  if size==0:size=end-start
  assert size>=header and start+size<=end
  name=path+'/'+kind.decode('ascii')
  if kind in containers:
   children=atoms(data,start+header,start+size,name);assert not out.keys()&children.keys();out.update(children)
  else:
   assert name not in out;out[name]=(start,size,sha(data[start+header:start+size]))
  start+=size
 return out
p=OUT/'episode-summary.json';episode=json.loads(p.read_text());rows=[]
allowed={'/moov/mvhd':set(range(20,28)),'/moov/trak/tkhd':set(range(28,32)),'/moov/trak/edts/elst':set(range(16,20))}
for row in episode['maps']:
 reg=row['acceptedRegression']
 if not reg:continue
 base=ROOT/'artifacts/local/ultimate-speedruns'/row['map'];old=base/'full-rate'/f"speedrun-{row['map'].lower()}.mp4";new=ROOT/row['media']['MP4']
 a=old.read_bytes();b=new.read_bytes();assert sha(a)==reg['oldMP4SHA256'] and sha(b)==reg['newMP4SHA256']
 aa=atoms(a);bb=atoms(b);assert aa.keys()==bb.keys();changed=[]
 for name in aa:
  if aa[name]==bb[name]:continue
  assert name in allowed and aa[name][:2]==bb[name][:2],name
  offset,size,_=aa[name];assert a[offset+8]==b[offset+8]==0,'only proven v0 clock layouts admitted'
  differences=[i-offset for i in range(offset,offset+size) if a[i]!=b[i]]
  assert set(differences)<=allowed[name]
  changed.append(dict(atom=name,changedByteOffsets=differences))
 assert aa['/mdat']==bb['/mdat']
 moov=aa['/moov/mvhd'][0];moovnew=bb['/moov/mvhd'][0]
 clock=lambda data,offset:dict(timescale=int.from_bytes(data[offset+20:offset+24],'big'),durationUnits=int.from_bytes(data[offset+24:offset+28],'big'))
 oldClock=clock(a,moov);newClock=clock(b,moovnew)
 assert newClock==dict(timescale=35000,durationUnits=row['frames']*1000)
 assert reg['pixelChanges']==0 and reg['allFrameHashesAndPriorVirtualProvenanceUnchanged']
 rows.append(dict(map=row['map'],oldPath=str(old.relative_to(ROOT)),newPath=str(new.relative_to(ROOT)),oldSHA256=sha(a),newSHA256=sha(b),MP4BytesIdentical=a==b,compressedVideoPayloadIdentical=True,videoPayloadSHA256=aa['/mdat'][2],allOtherAtomPayloadsIdentical=True,changedClockAtoms=changed,oldMovieClock=oldClock,newMovieClock=newClock,indexedPixelChanges=0,virtualProvenanceChanges=0))
assert len(rows)==5
proof=dict(pass_=True,episodeSummarySHA256=sha(p.read_bytes()),maps=rows,explanation='E1M1/E1M2/E1M4/E1M7 re-express movie/track/edit durations from 1000 Hz millisecond-rounded headers to exact 35000 Hz tic units. Every compressed video payload and all other atom payloads are identical. E1M9 files are wholly identical. Original files remain untouched; indexed pixels and provenance changes are zero.',toolSHA256=sha(Path(__file__).read_bytes()))
(OUT/'media-regression.json').write_text(json.dumps(proof,indent=2)+'\n')
print(json.dumps(dict(pass_=True,maps=len(rows),allCompressedVideoPayloadsIdentical=True,indexedPixelChanges=0,provenanceChanges=0)))
