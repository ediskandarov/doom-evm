#!/usr/bin/env python3
"""Exact indexed-frame comparison and verified reference-v0 artifact recording.

This does not render a frame. Phase 1 uses synthetic self-tests only.
"""
import argparse
import hashlib
import importlib.util
import json
import pathlib
import shutil
ROOT=pathlib.Path(__file__).resolve().parents[2]

def validate_reference(metadata, pixels):
    spec=importlib.util.spec_from_file_location('phase0_schema',ROOT/'scripts/check-schemas.py')
    module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    module.validate(metadata,json.loads((ROOT/'schemas/reference-v0.schema.json').read_text()))
    if len(pixels)!=metadata['width']*metadata['height']: raise ValueError('Frame dimensions do not match byte length')
    if hashlib.sha256(pixels).hexdigest()!=metadata['frameSha256']: raise ValueError('Reference frame SHA256 mismatch')
    if metadata['provenance']['kind']=='wad':
        if metadata['provenance']['wadSha256']!=metadata['resourceIdentity']['wadSha256']: raise ValueError('WAD identity mismatch')
        if metadata['resourceIdentity']['wadSha256']=='0'*64: raise ValueError('Real WAD reference needs nonzero identity')
    elif metadata['scope']!='synthetic-transport': raise ValueError('Synthetic pixels cannot claim a renderer golden')

def compare(expected,actual,width,height):
    if type(width)!=int or type(height)!=int or width<1 or height<1: raise ValueError('Invalid dimensions')
    if len(expected)!=width*height or len(actual)!=width*height: raise ValueError('Frame dimensions do not match byte length')
    mismatches=[{'x':i%width,'y':i//width,'expected':a,'actual':b} for i,(a,b) in enumerate(zip(expected,actual)) if a!=b]
    return {'width':width,'height':height,'mismatchCount':len(mismatches),'mismatches':mismatches,'expectedSha256':hashlib.sha256(expected).hexdigest(),'actualSha256':hashlib.sha256(actual).hexdigest()}

def main():
    parser=argparse.ArgumentParser(); sub=parser.add_subparsers(dest='command',required=True)
    diff=sub.add_parser('compare'); diff.add_argument('--expected',type=pathlib.Path,required=True); diff.add_argument('--actual',type=pathlib.Path,required=True); diff.add_argument('--reference',type=pathlib.Path,required=True); diff.add_argument('--actual-reference',type=pathlib.Path,required=True)
    record=sub.add_parser('record'); record.add_argument('--pixels',type=pathlib.Path,required=True); record.add_argument('--reference',type=pathlib.Path,required=True); record.add_argument('--output',type=pathlib.Path,required=True)
    args=parser.parse_args(); reference=json.loads(args.reference.read_text())
    if args.command=='record':
        pixels=args.pixels.read_bytes(); validate_reference(reference,pixels)
        args.output.mkdir(parents=True,exist_ok=False)
        (args.output/'pixels.bin').write_bytes(pixels); (args.output/'reference.json').write_text(json.dumps(reference,indent=2)+'\n')
        print(json.dumps({'recorded':str(args.output),'scope':reference['scope']})); return
    expected=args.expected.read_bytes(); actual=args.actual.read_bytes(); actual_reference=json.loads(args.actual_reference.read_text())
    validate_reference(reference,expected); validate_reference(actual_reference,actual)
    settings=lambda value:{key:item for key,item in value.items() if key not in ['frameSha256','provenance']}
    if settings(reference)!=settings(actual_reference): raise ValueError('Comparison camera/resource/render settings differ')
    report=compare(expected,actual,reference['width'],reference['height']); print(json.dumps(report,indent=2)); raise SystemExit(bool(report['mismatchCount']))
if __name__=='__main__': main()
