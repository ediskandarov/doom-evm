#!/usr/bin/env python3
"""Local QA contact sheets; palette decoding/scaling only, never video UI overlays."""
import argparse,json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
ap=argparse.ArgumentParser();ap.add_argument('recordings',nargs='+',type=Path);a=ap.parse_args()
for out in a.recordings:
 out=out.resolve();r=json.loads((out/'recording.json').read_text());assert r['pass'];frames=r['frames'];game=[f for f in frames if f['kind']==0];ui=[f for f in frames if f['kind'] in [3,4]];entry=[f for f in frames if f['kind']==2 and f['gameplayTic']==1]
 chosen=[frames[0],entry[len(entry)//2],game[len(game)//2],game[-1],ui[0],ui[-1]]
 if r['identity']['map']!=8:chosen[-2]=frames[r['postExitInputs'][1]['frameId']-1]
 sheet=Image.new('RGB',(960,768),(16,16,16));draw=ImageDraw.Draw(sheet)
 for i,f in enumerate(chosen):
  pixels=(out/f['file']).read_bytes();palette=(out/f['paletteFile']).read_bytes();assert hashlib.sha256(pixels).hexdigest()==f['sha256'];im=Image.frombytes('P',(320,200),pixels);im.putpalette(palette);im=im.convert('RGB').resize((320,240),Image.Resampling.NEAREST);x=i%3*320;y=i//3*384;sheet.paste(im,(x,y+24));draw.text((x+4,y+4),f"E1M{r['identity']['map']} frame{f['frameId']} kind{f['kind']} tic{f['gameplayTic']}",fill='white')
 file=out/'presentation-qa.png';sheet.save(file);report=dict(map=r['identity']['map'],sourceFrames=[dict(frameId=f['frameId'],sha256=f['sha256'],paletteSha256=f['paletteSha256']) for f in chosen],contactSheet=file.name,contactSheetSHA256=hashlib.sha256(file.read_bytes()).hexdigest(),scope='QA artifact only; labels outside EVM image bounds. Production MP4s contain no host overlays.');(out/'visual-qa.json').write_text(json.dumps(report,indent=2)+'\n');print(file)
