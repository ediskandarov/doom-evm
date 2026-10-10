#!/usr/bin/env python3
"""Generate separate, exact-IWAD authenticated test adapters, keeping engine bodies."""
import json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
pin=json.loads((ROOT/'artifacts/local/ultimate-speedruns/wad/pin.json').read_text());r=pin['resourceIdentity']
replacements={'1755':str(pin['chunks']),'1754':str(pin['chunks']-1),'3163':str(pin['lumps']),'28741889':str(pin['blobBytes']),'4354':str(pin['lastChunkRuntimeBytes']),
'7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d':r['wadSha256'],
'd379076f21645cf7cc5acb056663d0faacc4065489a0ca99738479323c9f7a47':r['bundleSha256'],
'4acf70e1a550810a0682365afb4a717b8258082e18962f898554eac4dbd1d012':pin['directorySha256'],
'62a3aec2214b5b7776713b87435b010d6f6300929e3b169d0b6e7e03de01fb6a':pin['chunkHashesSha256']}
files={}
for source,target in [('src/evm/WadResources.sol','src/support/UltimateWadResources.sol'),('src/evm/EpisodeStartup.sol','src/support/UltimateStartup.sol')]:
    s=(ROOT/source).read_text()
    for before,after in replacements.items():s=s.replace(before,after)
    s=s.replace('abstract contract WadResources','abstract contract UltimateWadResources').replace('library EpisodeStartup','library UltimateStartup')
    s=s.replace('"./ResourceTypes.sol"','"../evm/ResourceTypes.sol"').replace('"./DoomGame.sol"','"../evm/DoomGame.sol"').replace('"./DoomZoneStartup.sol"','"../evm/DoomZoneStartup.sol"')
    s=s.replace('Freedoom 0.13.0 E1M1 renderer','classic Ultimate DOOM 1.9 experiment').replace('Same v0 identity as WadResources','Separate exact-IWAD v0 identity; original WadResources is preserved')
    (ROOT/target).write_text(s);files[target]=dict(originalSource=source,originalSha256=hashlib.sha256((ROOT/source).read_bytes()).hexdigest(),generatedSha256=hashlib.sha256(s.encode()).hexdigest())
s=(ROOT/'src/support/EpisodeSpeedrunProbe.sol').read_text().replace('import {WadResources} from "../evm/WadResources.sol";','import {UltimateWadResources as WadResources} from "./UltimateWadResources.sol";').replace('import {EpisodeStartup} from "../evm/EpisodeStartup.sol";','import {UltimateStartup as EpisodeStartup} from "./UltimateStartup.sol";').replace('contract EpisodeSpeedrunProbe','contract UltimateSpeedrunProbe')
(ROOT/'src/support/UltimateSpeedrunProbe.sol').write_text(s)
(ROOT/'artifacts/local/ultimate-speedruns/adapter-generation.json').write_text(json.dumps(dict(pin=pin,scope='Resource identity/dimensions and separate import/library names only; no original C or gameplay/renderer algorithm changes.',replacements=replacements,files=files),indent=2)+'\n')
