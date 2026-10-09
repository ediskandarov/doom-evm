#!/usr/bin/env python3
"""Record actual EVM bytes, exact indexed diffs and PNGs; never render scene geometry."""
import argparse,importlib.util,json,pathlib,struct,zlib,hashlib
ROOT=pathlib.Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('pixel_diff',ROOT/'tools/reference/pixel_diff.py');diff=importlib.util.module_from_spec(spec);spec.loader.exec_module(diff)
def png(rgb,w=320,h=200):
    def chunk(name,data):return struct.pack('>I',len(data))+name+data+struct.pack('>I',zlib.crc32(name+data))
    raw=b''.join(b'\0'+rgb[y*w*3:(y+1)*w*3] for y in range(h))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b'')
p=argparse.ArgumentParser();p.add_argument('--native',type=pathlib.Path,required=True);p.add_argument('--actual',type=pathlib.Path,required=True);p.add_argument('--build',type=pathlib.Path,required=True);p.add_argument('--camera',required=True);a=p.parse_args()
pixels=(a.actual/'pixels.bin').read_bytes();expected=(a.native/'pixels.bin').read_bytes();reference=json.loads((a.native/'reference.json').read_text());diff.validate_reference(reference,expected)
actual=dict(reference);actual['provenance']=dict(reference['provenance'],build=json.loads(a.build.read_text()));actual['frameSha256']=hashlib.sha256(pixels).hexdigest();actual['camera']={**reference['camera'],**json.loads(a.camera)}
diff.validate_reference(actual,pixels);assert diff.comparison_settings(reference)==diff.comparison_settings(actual)
report=diff.compare(expected,pixels,320,200);(a.actual/'reference.json').write_text(json.dumps(actual,indent=2)+'\n');(a.actual/'diff.json').write_text(json.dumps(report,indent=2)+'\n')
palette=bytes.fromhex(json.loads((ROOT/'test/fixtures/wad/palette.json').read_text())['rgbHex']);rgb=b''.join(palette[v*3:v*3+3] for v in pixels)
(a.actual/'frame.png').write_bytes(png(rgb));(a.actual/'diff.png').write_bytes(png(b''.join(b'\xff\x00\x00' if x!=y else b'\0\0\0' for x,y in zip(expected,pixels))))
assert report['mismatchCount']==0,report
