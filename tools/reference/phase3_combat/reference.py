#!/usr/bin/env python3
"""Isolated unchanged original p_inter functions + P_CheckAmmo with declared cyclic hooks."""
import argparse
import importlib.util
import json
import pathlib
import re
import struct
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[3]
HERE = pathlib.Path(__file__).resolve().parent
FIX = ROOT / 'test/fixtures/phase3_combat'
spec = importlib.util.spec_from_file_location('p1', HERE.parent / 'reference.py')
p1 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p1)


def extract(file, name):
    text = (p1.SOURCE / file).read_text()
    match = re.search(r'\n(?:void|boolean)\s+' + name + r'\s*\(', text)
    assert match, name
    start = match.start() + 1
    end = text.index('{', match.end()) + 1
    depth = 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    body = text[start:end]
    return body, {'file': file, 'function': name, 'startLine': text[:start].count('\n') + 1,
                  'endLine': text[:end].count('\n') + 1, 'sha256': p1.sha(body.encode())}


def rows():
    # op,arg,num,skill,mode,net,dm,ready,owned,oldammo,health,armor,armortype,powers,cards,RNG.
    base = [0, 0, 1, 2, 1, 0, 0, 0, 511, 0, 50, 0, 0, 0, 0, 0]
    out = []
    def row(**values):
        a = list(base)
        for key, value in values.items(): a[int(key[1:])] = value
        out.append(a)
    for ammo in range(4):
        for num in [0, 1, 2, 5]:
            for skill in [0, 2, 4]:
                for ready in range(9):
                    for old in [0, 1, [200, 50, 300, 50][ammo]]:
                        for owned in [0, 511]: row(a1=ammo, a2=num, a3=skill, a7=ready, a8=owned, a9=old)
    row(a1=5)
    for weapon in range(9):
        for net in [0, 1]:
            for dm in range(3):
                for dropped in [0, 1]:
                    for owned in [0, 511]: row(a0=1, a1=weapon, a2=dropped, a5=net, a6=dm, a8=owned)
    for health in [1, 20, 99, 100, 199]:
        for amount in [1, 10, 25, 100]: row(a0=2, a2=amount, a10=health)
    for armor in [0, 99, 100, 150, 199, 200]:
        for kind in [1, 2]: row(a0=3, a2=kind, a11=armor)
    for card in range(6):
        for cards in [0, 63]: row(a0=4, a1=card, a14=cards)
    for power in range(6):
        for powers in [0, 63]: row(a0=5, a1=power, a13=powers)
    sprites = ['ARM1','ARM2','BON1','BON2','SOUL','MEGA','BKEY','YKEY','RKEY','BSKU','YSKU','RSKU',
               'STIM','MEDI','PINV','PSTR','PINS','SUIT','PMAP','PVIS','CLIP','AMMO','ROCK','BROK','CELL',
               'CELP','SHEL','SBOX','BPAK','BFUG','MGUN','CSAW','LAUN','PLAS','SHOT','SGN2']
    header = (p1.SOURCE / 'info.h').read_text()
    names = re.findall(r'\bSPR_[A-Z0-9]+\b', header[header.index('SPR_TROO'):header.index('NUMSPRITES')])
    for sprite in sprites:
        for mode in [1, 2]:
            for net in [0, 1]:
                for dropped in [0, 1]:
                    for health in [0, 50, 100, 200]: row(a0=6, a1=names.index('SPR_' + sprite), a2=dropped, a4=mode, a5=net, a10=health)
    for skill in [0, 2, 4]:
        for armor in [0, 1, 33, 100, 200]:
            for kind in [0, 1, 2]:
                for damage in [1, 3, 10, 40, 99, 100, 101, 1000, 10000]:
                    for special in [0, 11]:
                        for invul in [0, 1]: row(a0=7, a1=special, a2=damage, a3=skill, a11=armor, a12=kind, a13=invul, a15=37)
    for ready in range(9):
        for mode in [0, 1, 2]:
            for ammo in [0, 1, 2, 3, 40, 41]:
                for owned in [0, 511]: row(a0=8, a4=mode, a7=ready, a8=owned, a9=ammo)
    names = re.findall(r'\bMT_[A-Z0-9]+\b', header[header.index('MT_PLAYER'):header.index('NUMMOBJTYPES')])
    for kind in ['POSSESSED','SHOTGUY','CHAINGUY','WOLFSS','SKULL','VILE','TROOP','BARREL']:
        for health in [-1, -1000]:
            for net in [0, 1]:
                for rng in [0, 37]: row(a0=9, a1=names.index('MT_' + kind), a2=health, a5=net, a15=rng)
    return out


def build(directory):
    assert p1.invoke(['git', '-C', str(p1.SOURCE), 'rev-parse', 'HEAD']).strip() == p1.UPSTREAM
    assert not p1.invoke(['git', '-C', str(p1.SOURCE), 'diff', '--name-only', 'HEAD'])
    version = p1.invoke(['clang', '--version']).splitlines()
    assert version[:2] == [p1.VERSION, 'Target: ' + p1.TARGET]
    names = ['P_GiveAmmo','P_GiveWeapon','P_GiveBody','P_GiveArmor','P_GiveCard','P_GivePower',
             'P_TouchSpecialThing','P_KillMobj','P_DamageMobj']
    units, records = zip(*(extract('p_inter.c', name) for name in names))
    check, record = extract('p_pspr.c', 'P_CheckAmmo')
    inter = (p1.SOURCE / 'p_inter.c').read_text()
    constants = '\n'.join(re.findall(r'int\s+(?:maxammo|clipammo)\[NUMAMMO\]\s*=\s*\{[^}]+\};', inter))
    info = (p1.SOURCE / 'info.c').read_text()
    states = re.search(r'state_t\s+states\[NUMSTATES\]\s*=\s*\{.*?\n\};', info, re.S)[0]
    # Declared action test double: canonical state metadata retained; cyclic callbacks suppressed.
    states = re.sub(r'\{A_\w+\}', '{NULL}', states)
    mobjs = re.search(r'mobjinfo_t\s+mobjinfo\[NUMMOBJTYPES\]\s*=\s*\{.*?\n\};', info, re.S)[0]
    generated = (HERE / 'host.c').read_text() + '\n#define BONUSADD 6\n#define BFGCELLS 40\n' + constants + '\n'
    generated += states + '\n' + mobjs + '\n' + '\n'.join(units) + '\n' + check + '\n' + (HERE / 'driver.c').read_text()
    path = directory / 'combat.c'; path.write_text(generated)
    flags = ['-std=c11','-fsigned-char','-fwrapv','-fno-strict-aliasing','-ffp-contract=off','-fno-fast-math']
    profiles = {'O0':['-O0'], 'O2':['-O2'], 'sanitize':['-O2','-fsanitize=address,undefined','-fno-sanitize-recover=all']}
    inputs = rows(); data = ''.join(' '.join(map(str, row)) + '\n' for row in inputs).encode()
    outputs = []
    for name, profile in profiles.items():
        binary = directory / name
        p1.invoke(['clang', *flags, *profile, '-I'+str(p1.SOURCE), str(path), str(p1.SOURCE/'m_random.c'), str(p1.SOURCE/'m_fixed.c'), str(p1.SOURCE/'tables.c'), str(p1.SOURCE/'d_items.c'), '-o', str(binary)])
        result = subprocess.run([str(binary)], input=data, capture_output=True, check=True)
        assert not result.stderr, result.stderr.decode()
        outputs.append(result.stdout)
    assert outputs[0] == outputs[1] == outputs[2]
    assert len(outputs[0]) == len(inputs) * (16 + 42) * 4
    vectors = struct.pack('>I',len(inputs)) + outputs[0]
    manifest = {'schemaVersion':1,'upstreamCommit':p1.UPSTREAM,'compiler':p1.VERSION,'target':p1.TARGET,
                'flags':flags,'profiles':profiles,'caseCount':len(inputs),'inputWords':16,'outputWords':42,
                'scope':'all give functions, all pickup sprites, damage/armor/invulnerability/sector11/death with null inflictor/source, CheckAmmo selection; cyclic state/audio/removal/spawn hooks declared test doubles; full gameplay oracle separate',
                'extractions':[*records,record], 'generatedSourceSha256':p1.sha(generated.encode()),
                'sources':{f:p1.sha((p1.SOURCE/f).read_bytes()) for f in ['p_inter.c','p_pspr.c','info.c','d_items.c','m_random.c','m_fixed.c','tables.c','doomdef.h','d_player.h','p_local.h','d_englsh.h']},
                'harnessSha256':{f:p1.sha((HERE/f).read_bytes()) for f in ['reference.py','host.c','driver.c']},'vectorsSha256':p1.sha(vectors)}
    return vectors,(json.dumps(manifest,indent=2)+'\n').encode()


def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--check',action='store_true'); args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='doom-phase3-combat-') as tmp: vectors,manifest=build(pathlib.Path(tmp))
    if not args.check: FIX.mkdir(parents=True,exist_ok=True)
    for name,data in [('vectors.bin',vectors),('manifest.json',manifest)]:
        path=FIX/name
        if args.check: assert path.read_bytes()==data,'Fixture drift '+name
        else: path.write_bytes(data)
    print('PASS isolated original combat functions: O0/O2/ASan/UBSan exact; '+str(struct.unpack_from('>I',vectors)[0])+' cases')


if __name__=='__main__': main()
