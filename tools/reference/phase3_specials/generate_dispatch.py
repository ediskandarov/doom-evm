#!/usr/bin/env python3
"""Mechanically adapt original numeric special switch cases into Solidity if branches."""
import argparse, pathlib, re, hashlib, json
ROOT=pathlib.Path(__file__).resolve().parents[3]
SOURCE=ROOT/'original/DOOM/linuxdoom-1.10'
def body(file,name):
    text=(SOURCE/file).read_text();m=re.search(r'\n(?:void|boolean)\s+'+name+r'\s*\([^;{}]*\)\s*\{',text);assert m,name
    p=m.end();depth=1
    while depth:
        depth+=(text[p]=='{')-(text[p]=='}');p+=1
    return text[m.end():p-1]
def main_switch(text):
    matches=list(re.finditer(r'switch\s*\(line->special\)\s*\{',text));assert matches
    p=matches[-1].end();start=p;depth=1
    while depth:
        depth+=(text[p]=='{')-(text[p]=='}');p+=1
    return text[start:p-1]
def cases(text):
    text=re.sub(r'//[^\n]*','',text);matches=list(re.finditer(r'case\s+(\d+)\s*:',text));out=[];pending=[]
    for i,m in enumerate(matches):
        pending.append(int(m.group(1)));chunk=text[m.end():matches[i+1].start() if i+1<len(matches) else len(text)].strip()
        if not chunk:continue
        assert chunk.endswith('break;'),chunk;chunk=chunk[:-6].strip();out.append((pending,chunk));pending=[]
    assert not pending;return out
def convert(chunk):
    chunk=chunk.replace('!thing->player','c.state.mobjs[thing].player == C.NULL')
    chunk=chunk.replace('thing->player','c.state.mobjs[thing].player != C.NULL').replace('line->special','c.map.lines[line].special')
    libs={'EV_DoDoor':('P_Doors','DoorType'),'EV_DoLockedDoor':('P_Doors','DoorType'),'EV_VerticalDoor':('P_Doors',None),'EV_DoFloor':('P_Floor','FloorType'),'EV_BuildStairs':('P_Floor','StairType'),'EV_DoCeiling':('P_Ceilng','CeilingType'),'EV_DoPlat':('P_Plats','PlatType'),'EV_StopPlat':('P_Plats',None),'EV_CeilingCrushStop':('P_Ceilng',None),'EV_LightTurnOn':('P_Lights',None),'EV_StartLightStrobing':('P_Lights',None),'EV_TurnTagLightsOff':('P_Lights',None),'EV_Teleport':('P_Telept',None),'EV_DoDonut':('P_Spec',None),'P_ChangeSwitchTexture':('P_Switch',None)}
    for fn,(lib,enum) in libs.items():
        def adapt(m):
            args=[a.strip() for a in m.group(1).split(',')]
            if enum:args[1]=enum+'.'+args[1]
            return lib+'.'+fn+'(c, '+', '.join(args)+')'
        chunk=re.sub(r'\b'+fn+r'\s*\(([^()]*)\)',adapt,chunk)
    chunk=re.sub(r'G_ExitLevel\s*\(\s*\)','G_Game.G_ExitLevel(c.state)',chunk)
    chunk=re.sub(r'G_SecretExitLevel\s*\(\s*\)','G_Game.G_SecretExitLevel(c)',chunk)
    chunk=re.sub(r'if\s*\((P_[\w.]+\([^()]*\))\)',r'if (\1 != 0)',chunk)
    return chunk
def generate(file,name,header,guards,returns):
    parsed=cases(main_switch(body(file,name)));lines=[header,'{',guards]
    for i,(labels,chunk) in enumerate(parsed):
        cond=' || '.join(f'c.map.lines[line].special == {n}' for n in labels)
        lines.append(('if' if i==0 else 'else if')+' ('+cond+') {\n'+convert(chunk)+'\n}')
    lines.extend([returns,'}']);return '\n'.join(lines),[n for labels,_ in parsed for n in labels]
def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
    crossGuard='''if (c.state.mobjs[thing].player == C.NULL) {
        uint32 kind = c.state.mobjs[thing].mobjType;
        if (kind == P_Info.MT_ROCKET || kind == P_Info.MT_PLASMA || kind == P_Info.MT_BFG || kind == P_Info.MT_TROOPSHOT || kind == P_Info.MT_HEADSHOT || kind == P_Info.MT_BRUISERSHOT) return;
        int16 special = c.map.lines[line].special;
        if (!(special == 39 || special == 97 || special == 125 || special == 126 || special == 4 || special == 10 || special == 88)) return;
    }'''
    useGuard='''if (side != 0 && c.map.lines[line].special != 124) return false;
    if (c.state.mobjs[thing].player == C.NULL) {
        if (c.map.lines[line].flags & 32 != 0) return false;
        int16 special = c.map.lines[line].special;
        if (!(special == 1 || special == 32 || special == 33 || special == 34)) return false;
    }'''
    shootGuard='if (c.state.mobjs[thing].player == C.NULL && c.map.lines[line].special != 46) return;'
    specs=[('p_spec.c','P_CrossSpecialLine','function P_CrossSpecialLine(GameContext memory c, uint32 line, int32 side, uint32 thing) internal view',crossGuard,''),('p_spec.c','P_ShootSpecialLine','function P_ShootSpecialLine(GameContext memory c, uint32 thing, uint32 line) internal view',shootGuard,''),('p_switch.c','P_UseSpecialLine','function P_UseSpecialLine(GameContext memory c, uint32 thing, uint32 line, int32 side) internal view returns (bool)',useGuard,'return true;')]
    generated={};matrix={}
    for file,name,header,guards,ret in specs:
        code,nums=generate(file,name,header,guards,ret);generated[name]=code;matrix[name]=dict(file=file,specials=nums,originalBodySha256=hashlib.sha256(body(file,name).encode()).hexdigest())
    # The tested source embeds these functions. Validate it directly; duplicate snippets need not be tracked.
    def normalize(s):
        s=re.sub(r'//[^\n]*','',s)
        # forge fmt inserts braces around a multiline single call guarded by if.
        s=re.sub(r'(if\s*\([^;\n]*\))\s*([A-Za-z_][\w.]*\([^;]*\);)',r'\1 { \2 }',s)
        return re.sub(r'\s+','',s)
    for name,code in generated.items():
        source=(ROOT/'src/doom'/('p_switch.sol' if name=='P_UseSpecialLine' else 'p_spec.sol')).read_text()
        start=source.index('function '+name+'(');opening=source.index('{',start);end=opening+1;depth=1
        while depth:depth+=(source[end]=='{')-(source[end]=='}');end+=1
        assert normalize(source[start:end])==normalize(code),'Embedded original dispatch drift '+name
    manifest={'upstream':'a77dfb96cb91780ca334d0d4cfd86957558007e0','scope':'Original special-number switch cases mechanically adapted into Solidity; guard semantics source reviewed separately','functions':matrix,'generatorSha256':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest()}
    path=ROOT/'test/fixtures/phase3_specials/dispatch-matrix.json';out=json.dumps(manifest,indent=2)+'\n'
    if a.check:assert path.read_text()==out
    else:path.write_text(out)
    print('Generated original special branches:',{k:len(v['specials']) for k,v in matrix.items()})
if __name__=='__main__':main()
