#!/usr/bin/env python3
"""Export receipt-generated indexed8 images with the authenticated base WAD palette.

This is evidence presentation only, not a production renderer or browser UI.
"""
import argparse, hashlib, json, pathlib, struct
from PIL import Image
ROOT=pathlib.Path(__file__).resolve().parents[3]
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--wad',required=True);args=ap.parse_args()
    wad=pathlib.Path(args.wad).read_bytes();count,at=struct.unpack_from('<ii',wad,4)
    palette=None
    for i in range(count):
        offset,n,name=struct.unpack_from('<ii8s',wad,at+16*i)
        if name.rstrip(b'\0')==b'PLAYPAL':palette=wad[offset:offset+768]
    assert len(palette)==768
    evidence=json.loads((ROOT/'artifacts/phase4/intermission/evm.json').read_text());assert evidence['pass']
    output=ROOT/'artifacts/phase4/intermission';rows=[]
    for name,path,scope in [('statistics','statistics.pixels','original WAD statistics, completion input from case4'),
                            ('next-map','4.pixels','original WAD next-map presentation; transparent original marker assets'),
                            ('secret-return','6.pixels','original WAD background/titles and declared synthetic visible marker assets')]:
        pixels=(ROOT/'artifacts/local/intermission/frames'/path).read_bytes();assert len(pixels)==64000
        if path!='statistics.pixels':assert sha(pixels)==evidence['rows'][int(path.split('.')[0])]['frameSha256']
        else:
            cases=json.loads((ROOT/'test/fixtures/phase4_intermission/cases.json').read_text())
            assert sha(pixels)==cases['cases'][4]['hashes'][1]['frameSha256']
        img=Image.frombytes('P',(320,200),pixels);img.putpalette(palette);target=output/(name+'.png');img.save(target)
        rows.append(dict(name=name,pixelSha256=sha(pixels),pngSha256=sha(target.read_bytes()),scope=scope))
    (output/'previews.json').write_text(json.dumps(dict(paletteSha256=sha(palette),presentation='Base raw PLAYPAL; indexed-pixel equivalence is the acceptance claim, PNG RGB is a review aid',rows=rows),indent=2)+'\n')
    print(json.dumps({'previews':len(rows),'output':str(output)}))
if __name__=='__main__':main()
