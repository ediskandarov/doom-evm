#!/usr/bin/env python3
"""Mechanically extracted original r_segs bodies, synthetic scene branch cases."""
import argparse,importlib.util,json,pathlib,struct,subprocess,tempfile,re,sys
HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parents[2]
spec=importlib.util.spec_from_file_location('renderer_builder',HERE.parent/'renderer/build.py');builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
ref=builder.ref
FIELDS=['frontfloor','frontceil','backfloor','backceil','back','flags','mid','top','bottom','rowoffset','textureoffset','segoffset','frontsky','backsky','frontlight','backlight','start','stop','fixed','extra','translate','orientation','stale']
def cases():
    rows=[]
    def row(name,**kw):
        d=dict(frontfloor=0,frontceil=128,backfloor=0,backceil=128,back=0,flags=0,mid=2,top=2,bottom=2,rowoffset=0,textureoffset=-32,segoffset=12,frontsky=0,backsky=0,frontlight=160,backlight=160,start=80,stop=239,fixed=-1,extra=0,translate=0,orientation=0,stale=0);d.update(kw);rows.append({'name':name,'inputs':[d[k] for k in FIELDS]})
    row('one-sided');row('bottom-pegged',flags=16);row('negative-rowoffset',rowoffset=-16)
    row('translated-height-original',flags=16,mid=1,translate=1)
    for flags in [0,8,16,24]:row('window-pegging-'+str(flags),back=1,backfloor=32,backceil=96,mid=0,flags=flags,rowoffset=13)
    row('masked-window',back=1,backfloor=32,backceil=96)
    row('masked-identical',back=1)
    row('both-silhouettes',back=1,backfloor=-32,backceil=160,mid=0)
    row('floor-above-eye',back=1,backfloor=64,backceil=96,mid=0)
    row('ceiling-below-eye',back=1,backceil=32,mid=0)
    row('closed-bottom',back=1,backfloor=-32,backceil=0,mid=0)
    row('closed-top',back=1,backfloor=128,backceil=160,mid=0)
    row('joined-sky',back=1,backceil=96,frontsky=1,backsky=1,mid=0)
    row('front-only-sky',back=1,backceil=96,frontsky=1,mid=0)
    row('front-floor-above-eye',frontfloor=64)
    row('front-ceiling-below-eye',frontceil=32)
    row('fixed-colormap',fixed=6)
    row('bright-clamp',extra=32)
    row('dark-clamp',extra=-32)
    row('single-column-stale-step',start=160,stop=160,stale=1)
    row('horizontal-light',orientation=1)
    row('diagonal-light',orientation=2)
    return rows

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
    wad=ROOT/'artifacts/local/freedoom/freedoom1.wad';assert ref.sha(wad.read_bytes())=='7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d'
    upstream=(ref.SOURCE/'r_segs.c').read_text();prefix=upstream[:upstream.index('//\n// R_RenderMaskedSegRange')]
    units=[];records=[]
    for name in ['R_RenderMaskedSegRange','R_RenderSegLoop','R_StoreWallRange']:
        m=re.search(r'\nvoid\s+'+name+r'\s*\(',upstream);start=m.start()+1;end=upstream.index('{',m.end())+1;depth=1
        while depth:
            if upstream[end]=='{':depth+=1
            if upstream[end]=='}':depth-=1
            end+=1
        body=upstream[start:end];units.append(body);records.append(dict(function=name,startLine=upstream[:start].count('\n')+1,endLine=upstream[:end].count('\n')+1,sha256=ref.sha(body.encode())))
    generated=prefix+'\n#define HEIGHTBITS 12\n#define HEIGHTUNIT (1<<HEIGHTBITS)\n'+'\n'.join(units)+'\n'
    original_here=builder.HERE;host=(original_here/'host.c').read_text();host=host[:host.index('int main(')]+(HERE/'driver.c').read_text()
    rows=cases();outputs={};profiles={}
    with tempfile.TemporaryDirectory(prefix='doom-segs-') as temporary:
        tmp=pathlib.Path(temporary);custom=tmp/'host';custom.mkdir();(custom/'host.c').write_text(host);(custom/'trace.h').write_bytes((original_here/'trace.h').read_bytes());builder.HERE=custom
        for profile in ['O0','O2','sanitize']:
            build=tmp/profile;binary=builder.build(build,opt='O0' if profile=='O0' else 'O2',sanitize=profile=='sanitize')
            # Replace whole original r_segs unit with mechanically extracted bodies, without trace injection.
            (build/'r_segs.c').write_text(generated)
            manifest=json.loads((build/'build-manifest.json').read_text());flags=[f.replace('<HARNESS>',str(custom)) for f in manifest['flags']]
            ref.invoke(['clang',*flags,'-I'+str(build),*[str(build/n) for n in builder.UNITS],str(build/'map_loader.c'),str(build/'actions.c'),str(custom/'host.c'),'-Wl,-dead_strip','-o',str(binary)])
            profilefiles={}
            for index,row in enumerate(rows):
                dest=tmp/(profile+'-'+str(index));dest.mkdir()
                try:ref.invoke([str(binary),str(wad),str(dest),*map(str,row['inputs'])])
                except subprocess.CalledProcessError as error:print(error.stderr);raise
                for name in ['pixels.bin','clips.bin','planes.bin','drawsegs.bin','globals.bin']:profilefiles[str(index)+'/'+name]=(dest/name).read_bytes()
            profiles[profile]=profilefiles
        assert profiles['O0']==profiles['O2']==profiles['sanitize'],'native optimization/sanitizer mismatch'
        outputs.update(profiles['O2'])
    rows=[dict(row,files={n:ref.sha(outputs[str(i)+'/'+n]) for n in ['pixels.bin','clips.bin','planes.bin','drawsegs.bin','globals.bin']}) for i,row in enumerate(rows)]
    outputs['cases.bin']=b''.join(struct.pack('>23i',*r['inputs']) for r in rows)
    outputs['manifest.json']=(json.dumps({'upstreamCommit':ref.UPSTREAM,'wadSha256':ref.sha(wad.read_bytes()),'rSegsSha256':ref.sha(upstream.encode()),'extractions':records,'generatedSourceSha256':ref.sha(generated.encode()),'hostSha256':ref.sha(host.encode()),'harnessSha256':ref.sha(pathlib.Path(__file__).read_bytes()),'sharedRendererBuilderSha256':ref.sha((original_here/'build.py').read_bytes()),'compiler':ref.VERSION,'target':ref.TARGET,'profiles':['O0 -fwrapv','O2 -fwrapv','O2 ASan/UBSan -fwrapv'],'fields':FIELDS,'cases':rows,'scope':'Original wall functions with original r_main/r_data/r_draw/r_plane dependencies. Host initializes synthetic scene globals only; no host visibility or drawing. Native inputs preserve signed arithmetic pinned -fwrapv behavior; this is not a claim of ISO C overflow validity.'},indent=2)+'\n').encode()
    for name,data in outputs.items():
        p=ROOT/'test/fixtures/phase2_segs'/name
        if args.check:assert p.read_bytes()==data,'drift '+str(p)
        else:p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
    print(json.dumps({'cases':len(rows),'profiles':'byte-identical O0/O2/ASan+UBSan -fwrapv','files':len(outputs)}))
if __name__=='__main__':main()
