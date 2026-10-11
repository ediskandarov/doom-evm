#!/usr/bin/env python3
"""Select author-recorded single-player DSDA UV Speed demos, retain original ZIPs."""
import hashlib,html,json,re,subprocess,zipfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];base=ROOT/'artifacts/local/ultimate-speedruns';out=ROOT/'artifacts/ultimate-speedruns'
sha=lambda b:hashlib.sha256(b).hexdigest()
page=(base/'dsda-index.html').read_text();selected={};map_=category=None
plain=lambda s:html.unescape(re.sub('<[^>]+>','',s)).strip()
for tr in re.findall(r'<tr[^>]*>(.*?)</tr>',page,re.S):
    for c in re.findall(r'<td class="no-stripe-panel"[^>]*>(.*?)</td>',tr,re.S):
        v=plain(c)
        if re.fullmatch(r'E1M\d+s?',v):map_=v;category=None
        else:category=v
    if map_ not in [f'E1M{i}' for i in range(1,10)] or map_ in selected or category!='UV Speed':continue
    get=lambda cls:plain(re.search(r'<td class="'+cls+'"[^>]*>(.*?)</td>',tr,re.S)[1])
    if 'player-cell' not in tr:continue
    engine=get('engine-cell');note=get('note-cell')
    if 'DSDA-Doom' not in engine or 'cl3' not in engine or note:continue
    link=re.search(r'href="(/files/demos/doom/[^"]+)"',tr);assert link
    selected[map_]=dict(map=map_,author=get('player-cell'),engine=engine,category=category,note=note,downloadUrl='https://dsdarchive.com'+html.unescape(link[1]),runUrl='https://dsdarchive.com/wads/doom?category=UV+Speed&level='+map_,selection='First listed non-TAS single-player DSDA-Doom complevel3 UV Speed row; not a claim of world-record status.')
assert len(selected)==9,selected
for map_,r in selected.items():
    dest=base/map_;dest.mkdir(parents=True,exist_ok=True);archive=dest/'original.zip'
    if not archive.exists():subprocess.run(['curl','--connect-timeout','10','--max-time','30','-fsSL',r['downloadUrl'],'-o',str(archive)],check=True)
    with zipfile.ZipFile(archive) as z:
        assert not any(n.lower().endswith('.wad') for n in z.namelist()), 'Never commit commercial WAD payloads'
        demos=[n for n in z.namelist() if n.lower().endswith('.lmp')];assert len(demos)==1,demos
        data=z.read(demos[0]);(dest/'source-download').write_bytes(data)
        notes={n:z.read(n).decode('latin1') for n in z.namelist() if n.lower().endswith('.txt')}
    r.update(originalName=demos[0],demoBytes=len(data),demoSha256=sha(data),archiveSha256=sha(archive.read_bytes()),authorNotes=notes,IWADMD5='c4fe9fd920207691a9f493668e0a2083',IWADSHA256='6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f')
    (dest/'source.json').write_text(json.dumps(r,indent=2)+'\n');print(map_,r['author'],r['engine'],r['originalName'],len(data),flush=True)
    committed=out/map_;committed.mkdir(parents=True,exist_ok=True);(committed/Path(r['originalName']).name).write_bytes(data);(committed/'source.json').write_text(json.dumps(r,indent=2)+'\n');(committed/'original.zip').write_bytes(archive.read_bytes())
(out/'source-index.json').write_text(json.dumps(dict(pageUrl='https://dsdarchive.com/wads/doom?category=UV+Speed&level=Episode+1+ILs',pageSha256=sha(page.encode()),retrievedUTC=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),selected=list(selected.values())),indent=2)+'\n')
