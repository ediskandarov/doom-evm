#!/usr/bin/env python3
"""Observation schema only; generates serializers, never expected transition results."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
fields=[]
def field(c,s): fields.append((c,s))
for c,s in [('gameaction','s.gameaction'),('gamestate','s.gamestate'),('gameskill','s.gameskill'),('gamemode','s.gamemode'),('gameepisode','s.gameepisode'),('gamemap','s.gamemap'),('gametic','int32(uint32(s.gametic))'),('leveltime','s.leveltime'),('paused','s.paused'),('menuactive','s.menuactive'),('respawnmonsters','s.respawnmonsters'),('fastparm','s.fastparm'),('nomonsters','s.nomonsters'),('consoleplayer','s.consoleplayer'),('displayplayer','s.displayplayer'),('prndindex','int32(s.prndindex)'),('rndindex','int32(s.rndindex)'),('skyflatnum','int32(s.skyflatnum)'),('skytexture','int32(s.skytexture)'),('secretexit','s.secretExit'),('totalkills','s.totalkills'),('totalitems','s.totalitems'),('totalsecret','s.totalsecret'),('turnheld','s.input.turnheld'),('onground','s.move.onground')]:field(c,s)
for c,s in [('d_skill','deferredSkill'),('d_episode','deferredEpisode'),('d_map','deferredMap'),('sendpause','sendpause'),('usergame','usergame'),('viewactive','viewactive'),('automapactive','automapactive'),('respawnparm','respawnparm'),('levelstarttic','levelstarttic'),('wipegamestate','wipegamestate')]:field(c,'int32(uint32(f.levelstarttic))' if s=='levelstarttic' else 'f.'+s)
for i in range(4):
    field(f'playeringame[{i}]',f's.playeringame[{i}]')
    p=f'players[{i}]';s=f's.players[{i}]'
    field(f'{p}.mo?{p}.mo-actors:-1',f'int32({s}.mo)')
    field(f'{p}.attacker?{p}.attacker-actors:-1',f'int32({s}.attacker)')
    field(f'{p}.playerstate',f'int32(uint32({s}.playerstate))')
    for name in ['forwardmove','sidemove','angleturn','consistancy','chatchar','buttons']:field(p+'.cmd.'+name,s+'.cmd.'+name)
    for name in ['viewz','viewheight','deltaviewheight','bob','health','armorpoints','armortype','backpack','readyweapon','pendingweapon','attackdown','usedown','cheats','refire','killcount','itemcount','secretcount','damagecount','bonuscount','extralight','fixedcolormap','colormap','didsecret']:field(p+'.'+name,s+'.'+name)
    field(p+'.message!=NULL',f'bytes({s}.message).length != 0')
    field(f'{p}.message?strlen({p}.message):0',f'bytes({s}.message).length')
    for j in range(17):field(f'{p}.message && strlen({p}.message)>{j}?(unsigned char){p}.message[{j}]:0',f'(bytes({s}.message).length>{j}?uint8(bytes({s}.message)[{j}]):0)')
    for name,n in [('powers',6),('cards',6),('frags',4),('ammo',4),('maxammo',4),('weaponowned',9)]:
        for j in range(n):field(f'{p}.{name}[{j}]',f'{s}.{name}[{j}]')
    for j in range(2):
        field(f'{p}.psprites[{j}].state?{p}.psprites[{j}].state-states:-1',f'int32({s}.psprites[{j}].state)')
        for name in ['tics','sx','sy']:field(f'{p}.psprites[{j}].{name}',f'{s}.psprites[{j}].{name}')
    field(f'actors[{i}].flags',f's.mobjs[{i}].flags')
for name in ['epsd','didsecret','last','next','maxkills','maxitems','maxsecret','maxfrags','partime','pnum']:field('wminfo.'+name,'f.wminfo.'+name)
for i in range(4):
    for c,s in [('in','inGame'),('skills','skills'),('sitems','sitems'),('ssecret','ssecret'),('stime','stime'),('score','score')]:field(f'wminfo.plyr[{i}].{c}',f'f.wminfo.plyr[{i}].{s}')
    for j in range(4):field(f'wminfo.plyr[{i}].frags[{j}]',f'f.wminfo.plyr[{i}].frags[{j}]')
for i in range(477,490):field(f'states[{i}].tics',f'c.definitions.states[{i}].tics')
for i in (16,32,31):field(f'mobjinfo[{i}].speed',f'c.definitions.mobjinfo[{i}].speed')
booleans=['paused','menuactive','respawnmonsters','fastparm','nomonsters','secretExit','onground','sendpause','usergame','viewactive','automapactive','respawnparm','backpack','didsecret','inGame']
def cast(s):
    if any(s.endswith('.'+b) for b in booleans) or '.playeringame[' in s or '.cards[' in s or '.weaponowned[' in s or ' != 0' in s:return f'({s} ? 1 : 0)'
    if any(s.endswith('.cmd.'+n) for n in ['forwardmove','sidemove','angleturn','consistancy']):return f'uint32(int32({s}))'
    return f'uint32({s})'
def generate():
    c='/* Generated observation schema; see snapshot.py. */\nstatic void snapshot(FILE *out){\n'
    c+='\n'.join(f' word(out, {x});' for x,_ in fields)
    c+='\n word(out,tracecount);for(int i=0;i<tracecount;i++)word(out,observations[i]);\n}\n'
    sol='// SPDX-License-Identifier: GPL-2.0-only\n// Generated observation schema; see tools/reference/gameflow/snapshot.py.\npragma solidity 0.8.37;\nimport {GameContext,GameState} from "../../src/doom/p_game_state.sol";\nimport {GameflowState} from "../../src/doom/g_game.sol";\nlibrary GameflowSnapshot {\n function snapshot(GameContext memory c,GameflowState memory f) internal pure returns(uint32[] memory v){\n GameState memory s=c.state;\n'
    sol+=f' v=new uint32[]({len(fields)}+1+s.brainTargetOn);\n'
    sol+='\n'.join(f' v[{i}]={cast(s)};' for i,(_,s) in enumerate(fields))
    sol+=f'\n v[{len(fields)}]=s.brainTargetOn;\n for(uint32 i;i<s.brainTargetOn;++i)v[{len(fields)+1}+i]=s.brainTargets[i];\n }}\n}}\n'
    return {'tools/reference/gameflow/snapshot.inc':c,'test/unit/GameflowSnapshot.sol':sol}
if __name__=='__main__':
    import sys
    for name,data in generate().items():
        p=ROOT/name
        if '--check' in sys.argv:assert p.read_text()==data,'stale '+name
        else:p.write_text(data)
