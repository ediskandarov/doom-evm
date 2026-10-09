#!/usr/bin/env python3
"""Original p_tick scheduling under explicit deterministic callback fixtures."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import reference as ref

HOST = r'''
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "doomstat.h"
#include "p_local.h"
void P_Ticker(void);
player_t players[MAXPLAYERS]; boolean playeringame[MAXPLAYERS];
boolean paused,menuactive,demoplayback,netgame; int consoleplayer;
static thinker_t schedule_nodes[8]; static int events[64],eventcount,freed[8],created;
static int id(void *p) { return p==&thinkercap ? 0:(int)((thinker_t*)p-schedule_nodes); }
void Z_Free(void *p) { freed[id(p)]=1; }
void P_PlayerThink(player_t *p) { events[eventcount++]=100+(int)(p-players); }
void P_UpdateSpecials(void) { events[eventcount++]=200; }
void P_RespawnSpecials(void) { events[eventcount++]=201; }
static void act(void *p) {
int n=id(p);events[eventcount++]=1000+n;
if(n==1 && leveltime==17) {
created=5;schedule_nodes[5].function.acp1=act;P_AddThinker(schedule_nodes+5);P_RemoveThinker(schedule_nodes+4);
}
if(n==1 && leveltime==18) {
schedule_nodes[2].function.acp1=act;created=6;schedule_nodes[6].function.acp1=act;P_AddThinker(schedule_nodes+6);
}
if(n==5) P_RemoveThinker(schedule_nodes+5);
}
static void word(uint32_t v) { unsigned char b[4]={v>>24,v>>16,v>>8,v};fwrite(b,1,4,stdout); }
static void snapshot(void) {
word(leveltime);word(eventcount);for(int i=0;i<eventcount;i++) word(events[i]);
int count=0;for(thinker_t *t=thinkercap.next;t!=&thinkercap;t=t->next) count++;
word(count);for(thinker_t *t=thinkercap.next;t!=&thinkercap;t=t->next) {
word(id(t));word(id(t->prev));word(id(t->next));
word(t->function.acv==(actionf_v)-1?2:(!t->function.acv?1:0));
}
word(created);for(int i=1;i<=created;i++) word(freed[i]);
}
int main(void) {
memset(schedule_nodes,0,sizeof(schedule_nodes));P_InitThinkers();leveltime=17;
playeringame[0]=playeringame[2]=true;players[0].viewz=100;
created=4;for(int i=1;i<=4;i++) { schedule_nodes[i].function.acp1=act;P_AddThinker(schedule_nodes+i); }
schedule_nodes[2].function.acp1=NULL;P_RemoveThinker(schedule_nodes+3);
word(8);
for(int step=0;step<8;step++) {
paused=step==1;menuactive=step==2||step==3||step==4||step==6;
players[0].viewz=step==3?1:100;netgame=step==4;demoplayback=step==6;
if(step==7) playeringame[2]=false;
eventcount=0;P_Ticker();snapshot();
}
return 0;
}
'''


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--check', action='store_true')
    args = p.parse_args()
    assert ref.invoke(['git', '-C', str(ref.SOURCE), 'rev-parse', 'HEAD']).strip() == ref.UPSTREAM
    ref.invoke(['git', '-C', str(ref.SOURCE), 'diff', '--exit-code', 'HEAD', '--'])
    assert ref.invoke(['clang', '--version']).splitlines()[:2] == [ref.VERSION, 'Target: ' + ref.TARGET]
    with tempfile.TemporaryDirectory() as temporary:
        temp = Path(temporary)
        (temp/'host.c').write_text(HOST)
        outputs = []
        for opt, sanitizer in [('-O0', []), ('-O2', []), ('-O2', ['-fsanitize=address,undefined', '-fno-sanitize-recover=all'])]:
            result = subprocess.run(['clang', '-std=c99', opt, *sanitizer, '-I'+str(ref.SOURCE), str(ref.SOURCE/'p_tick.c'), str(temp/'host.c'), '-o', str(temp/'tick')], capture_output=True)
            if result.returncode:
                sys.stderr.buffer.write(result.stderr)
                raise SystemExit(result.returncode)
            outputs.append(subprocess.check_output([str(temp/'tick')]))
        assert outputs[0] == outputs[1] == outputs[2]
    data = outputs[0]
    report = dict(upstreamCommit=ref.UPSTREAM, compiler=ref.VERSION, target=ref.TARGET,
                  profiles='O0/O2/ASan+UBSan exact', scenarios=8,
                  sourceSha256={n:ref.sha((ref.SOURCE/n).read_bytes()) for n in ['p_tick.c', 'd_think.h', 'p_local.h', 'doomstat.h', 'd_player.h']},
                  hostSha256=ref.sha(HOST.encode()), generatorSha256=ref.sha(Path(__file__).read_bytes()), vectorsSha256=ref.sha(data),
                  scope='Original full p_tick.c: player order, pause/menu exceptions, append in same tic, stasis, lazy removal and current-next read after callbacks.',
                  adaptation='Unit Z_Free marks callback deallocation but retains static node bytes for original next-pointer read. No allocation/reuse equivalence claimed; real original z_zone is independently covered by the integrated gameplay oracle.',
                  encoding='u32 8; each step: leveltime,eventcount,events,count,(id,prev,next,status)*count,created,freedFlags*created; status active0/stasis1/removed2')
    for name, content in [('vectors.bin', data), ('manifest.json', (json.dumps(report,indent=2)+'\n').encode())]:
        path = ref.ROOT/'test/fixtures/phase3_tick'/name
        if args.check:
            assert path.read_bytes() == content, 'stale ' + str(path)
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(content)
    print('PASS original p_tick: eight live scheduling snapshots, O0/O2/ASan/UBSan exact')


if __name__ == '__main__':
    main()
