#!/usr/bin/env python3
"""Build HUD state/pixel vectors from original C; no chat or browser-generated pixels."""
import gameplay
import argparse, hashlib, importlib.util, json, os, pathlib, re, shutil, struct, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[3]
HERE=pathlib.Path(__file__).resolve().parent
SRC=ROOT/'original/DOOM/linuxdoom-1.10'
FIX=ROOT/'test/fixtures/phase4_hud'
sha=lambda x:hashlib.sha256(x).hexdigest()
spec=importlib.util.spec_from_file_location('combat',HERE.parent/'phase3_combat/reference.py')
combat=importlib.util.module_from_spec(spec);spec.loader.exec_module(combat)

def projection():
    original=(SRC/'hu_stuff.c').read_text()
    tables=original[original.index('char*\tmapnames[]'):original.index('const char*\tshiftxform;')]
    fragments=['#define HU_TITLE (mapnames[(gameepisode-1)*9+gamemap-1])\n#define HU_TITLE2 (mapnames2[gamemap-1])\n#define HU_TITLEX 0\n#define HU_TITLEY (167-SHORT(hu_font[0]->height))\n',tables]
    mapping=[]
    for name in ['HU_Init','HU_Stop','HU_Start','HU_Drawer','HU_Erase','HU_Ticker']:
        body,meta=combat.extract('hu_stuff.c',name);mapping.append(meta)
        if name=='HU_Start':
            start=body.index('    // create the chat widget');end=body.index('    headsupactive = true;',start)
            body=body[:start]+body[end:]
        if name=='HU_Drawer':body=body.replace('    HUlib_drawIText(&w_chat);\n','')
        if name=='HU_Erase':body=body.replace('    HUlib_eraseIText(&w_chat);\n','')
        if name=='HU_Ticker':body=body[:body.index('    // check for incoming chat characters')]+'}\n'
        fragments.append(body)
    responder,meta=combat.extract('hu_stuff.c','HU_Responder');mapping.append(meta)
    start=responder.index('\tif (ev->data1 == HU_MSGREFRESH)');end=responder.index('\telse if (netgame',start)
    fragments.append('boolean HU_Responder(event_t *ev) { boolean eatkey=false; if (ev->type != ev_keydown) return false;\n'+responder[start:end]+'return eatkey; }')
    for name in ['HUlib_init','HUlib_clearTextLine','HUlib_initTextLine','HUlib_addCharToTextLine','HUlib_delCharFromTextLine','HUlib_drawTextLine','HUlib_eraseTextLine','HUlib_initSText','HUlib_addLineToSText','HUlib_addMessageToSText','HUlib_drawSText','HUlib_eraseSText']:
        _,meta=combat.extract('hu_lib.c',name);mapping.append(meta)
    return '\n'.join(fragments),mapping

def cases():
    rows=[]
    def action(op,a=0,b=0,c=0,d=0,text=''):return [op,a,b,c,d,text]
    def add(name,*steps):rows.append({'name':name,'actions':list(steps)})
    A=action
    add('pickup-lifetime-expiry-refresh',A(1,text='Picked up a stimpack.'),A(3,1),A(5),A(3,139),A(5),A(3,1),A(5),A(4,0,13),A(5))
    add('latest-player-message-wins',A(1,text='first'),A(1,text='second'),A(3,1),A(5),A(1,text='third'),A(3,1),A(5))
    add('hidden-pending-and-forced-protection',A(2),A(1,text='hidden'),A(3,1),A(5),A(2,0,1),A(3,1),A(5),A(1,text='pending'),A(2,1),A(3,139),A(5),A(3,1),A(5))
    add('forced-replacement-and-refresh-protection',A(2,1,1),A(1,text='forced'),A(3,1),A(1,text='overwrite'),A(3,1),A(4,0,13),A(3,1),A(2,0,1),A(3,1),A(5))
    add('show-option-does-not-hide-existing',A(1,text='present'),A(3,1),A(2),A(3,1),A(5))
    add('restart-retains-counter-clears-flags',A(2,1,1),A(1,text='forced'),A(3,1),A(0,1,2,9),A(5,1),A(7),A(5,1))
    add('refresh-empty-and-unrelated-events',A(4,1,13),A(4,0,116),A(4,2,13),A(4,0,13),A(5),A(3,140))
    add('embedded-nul',A(1,text='one\0two'),A(3,1),A(5))
    add('line-limit-and-screen-right-break',A(1,text='w'*95),A(3,1),A(5))
    add('ring-order-four-lines',A(8,3,50,4),A(4,0,13),*[A(9,text=t) for t in ['one','two','three','four','five','six']],A(9,6,text='PREFIX'+'w'*90),A(5))
    for name,x,y,cursor,text in [
        ('mixed-ascii',0,20,0,'lowercase UPPER 0123456789!? @[]\\^_ `{}~'),
        ('right-glyph-partial',317,20,0,'AB'),('right-space-break',316,20,1,' A'),
        ('right-exact-cursor',313,20,1,''),('negative-origin',-2,0,0,'A!'),
        ('bottom-glyph-rejected',10,199,1,'abc'),('text-del-clear',10,40,1,'abc')]:
        add(name,A(10,x,y,cursor,text=text),A(12,2),A(11))
    for n in range(33,96):add(f'glyph-STCFN{n:03}',A(10,10,30,0,text=chr(n)))
    for mode,episodes,maps in [(1,range(1,6),range(1,10)),(2,[1],range(1,33)),(0,[1],[1]),(3,[4],[9]),(99,[1],[32])]:
        for ep in episodes:
            for m in maps:add(f'title-{mode}-{ep}-{m}',A(0,mode,ep,m),A(5),A(5,1))
    for name,view,am in [('full',(0,0,320,200),0),('top',(32,16,256,144),0),('sides',(32,0,256,168),0),('automap',(32,16,256,144),1)]:
        add('erase-'+name,A(1,text='erase'),A(3,1),A(5,am),A(6,*view),A(3,140),*[A(6,*view) for _ in range(5)])
    add('erase-automap-transition-native-countdown',A(1,text='erase'),A(3,1),A(5,1),A(6,32,16,256,144),A(5),A(6,32,16,256,144))
    return rows

def pack_action(a):
    text=a[5].encode('ascii');return struct.pack('>6i',*a[:5],len(text))+text

def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    rows=cases();bundle=json.loads((ROOT/'artifacts/local/wad/bundle.json').read_text());blob=(ROOT/'artifacts/local/wad/resources.bin').read_bytes();assert sha(blob)==bundle['blobSha256']
    with tempfile.TemporaryDirectory(prefix='doom-hud-native-') as directory:
        tmp=pathlib.Path(directory);built=tmp/'fixtures';built.mkdir();fonts=[]
        for n in range(33,96):
            name=f'STCFN{n:03}';lumps=[l for l in bundle['lumps'] if bytes.fromhex(l['nameHex']).rstrip(b'\0')==name.encode()];assert lumps
            lump=lumps[-1];data=blob[lump['offset']:lump['offset']+lump['length']];(built/(name+'.bin')).write_bytes(data)
            fonts.append({'name':name,'lumpId':lump['id'],'sha256':sha(data),'length':len(data),'dimensionsOffsets':list(struct.unpack('<4h',data[:8]))})
        inc,mapping=projection();(tmp/'hud_projection.inc').write_text(inc)
        gameplay_rows,gameplay_evidence=gameplay.messages(tmp)
        for i,row in enumerate(gameplay_rows):
            rows.append({'name':f'gameplay-{i}', 'gameplay':row,'actions':[[1,0,0,0,0,row['message']],[3,1,0,0,0,''],[5,0,0,0,0,'']]})
        inputs=struct.pack('>I',len(rows))+b''.join(struct.pack('>I',len(r['actions']))+b''.join(pack_action(a) for a in r['actions']) for r in rows);(tmp/'input.bin').write_bytes(inputs)
        outputs=[];profiles=[]
        for label,flags in [('O0',['-O0']),('O2',['-O2']),('sanitized',['-O1','-g','-fsanitize=address,undefined','-fno-sanitize=array-bounds','-fno-omit-frame-pointer'])]:
            cmd=['clang','-std=c11','-DRANGECHECK','-include',str(HERE/'compat.h'),'-I',str(tmp),*flags,str(SRC/'hu_lib.c'),str(SRC/'v_video.c'),str(SRC/'m_bbox.c'),str(HERE/'host.c'),'-o',str(tmp/label)]
            r=subprocess.run(cmd,capture_output=True);assert r.returncode==0,r.stderr.decode()
            env=os.environ.copy();env['ASAN_OPTIONS']='detect_leaks=0:halt_on_error=1';env['UBSAN_OPTIONS']='halt_on_error=1:print_stacktrace=1'
            r=subprocess.run([str(tmp/label),str(tmp/'input.bin'),str(built)],capture_output=True,env=env);assert r.returncode==0,r.stderr.decode()
            outputs.append(r.stdout);profiles.append({'name':label,'flags':flags,'outputSha256':sha(r.stdout),'returnCode':r.returncode})
        assert outputs[0]==outputs[1]==outputs[2]
        data=outputs[0];pos=0;integration=bytearray(struct.pack('>I',len(gameplay_rows)));packed=bytearray(struct.pack('>I',len(rows)));snapshots=0
        for row in rows:
            packed+=struct.pack('>I',len(row['actions']))
            for a in row['actions']:
                packed+=pack_action(a);state=data[pos:pos+40];pos+=40
                pending=struct.unpack('>I',state[36:40])[0];message=data[pos:pos+pending];pos+=pending
                lines=data[pos:pos+485];pos+=485;dirty=data[pos:pos+16];pos+=16;frame=data[pos:pos+64000];pos+=64000
                packed+=state+hashlib.sha256(message).digest()+lines+dirty+hashlib.sha256(frame).digest();snapshots+=1
                if 'gameplay' in row and a[0]==5:
                    g=row['gameplay'];text=g['message'].encode();integration+=struct.pack('>4I',g['kind'],g['arg'],g['health'],len(text))+text+hashlib.sha256(frame).digest()
        assert pos==len(data)
        (built/'cases.bin').write_bytes(packed)
        (built/'gameplay.bin').write_bytes(integration)
        (built/'gameplay.json').write_text(json.dumps({'cases':gameplay_rows,'native':gameplay_evidence,'sha256':sha(integration)},indent=2)+'\n')
        (built/'cases.json').write_text(json.dumps({'schemaVersion':1,'snapshotBytes':605,'caseCount':len(rows),'snapshots':snapshots,'casesSha256':sha(packed),'cases':rows},indent=2)+'\n')
        (built/'fonts.json').write_text(json.dumps({'provenance':bundle['provenance'],'resourceBlobSha256':sha(blob),'fonts':fonts},indent=2)+'\n')
        files=[SRC/x for x in ['hu_stuff.c','hu_stuff.h','hu_lib.c','hu_lib.h','v_video.c','d_englsh.h']]+[HERE/x for x in ['compat.h','host.c','reference.py','gameplay.py']]
        evidence={'status':'passed','profiles':profiles,'exactAgreement':True,'caseCount':len(rows),'snapshots':snapshots,'sourceSha256':{str(f.relative_to(ROOT)):sha(f.read_bytes()) for f in files},'projectionSha256':sha(inc.encode()),'functionMapping':mapping,'hostAdaptations':['hu_lib.c, v_video.c and m_bbox.c compiled unchanged; hu_stuff functions mechanically extracted','HU_Start chat widget/inputbuffer setup and HU_Drawer/HU_Erase chat calls removed; HU_Ticker incoming-chat branch removed','HU_Init keyboard translation selection uses inert host pointers; font loader is original sprintf/W_CacheLumpName loop','HU_Responder uses exact extracted single-player Enter branch and keydown gate; chat/modifier branches excluded','Existing Solidity Player empty string is the null-message sentinel; empty pending fixture input maps to C NULL',
                    'R_VideoErase equivalent memcpy screen1 to screen0; screen pattern explicitly seeded','ASCII C locale; invalid maps and signed-char toupper undefined inputs excluded','ASan/UBSan; only original variable-sized patch columnofs array-bounds check disabled; leak detection disabled for borrowed text/font fixture allocations']}
        (built/'native.json').write_text(json.dumps(evidence,indent=2)+'\n');shutil.copyfile(ROOT/'test/fixtures/wad/COPYING.txt',built/'COPYING.txt')
        if args.check:
            assert sorted(f.name for f in built.iterdir())==sorted(f.name for f in FIX.iterdir())
            for f in built.iterdir():assert f.read_bytes()==(FIX/f.name).read_bytes(),f.name
        else:
            for f in built.iterdir():shutil.copyfile(f,FIX/f.name)
        print(json.dumps({'status':'passed','cases':len(rows),'snapshots':snapshots,'profiles':3,'casesSha256':sha(packed)}))
if __name__=='__main__':main()
