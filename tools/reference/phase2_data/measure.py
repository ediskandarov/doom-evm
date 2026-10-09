#!/usr/bin/env python3
"""Record measured EVM function gas and allocator positions; these are not total transaction gas or MSIZE."""
import pathlib,subprocess,re,json,hashlib
ROOT=pathlib.Path(__file__).resolve().parents[3]
cmd=['.toolchain/bin/forge','test','--match-contract','RDataTest','--match-test','testLazyCacheReuseAndFlatAccessCosts|testNativeAllE1M1MapFields|testNativeRepresentativeCompositesAndDirectColumns|testNativeAllLookupAndSpriteMetadata','-vvvv']
p=subprocess.run(cmd,cwd=ROOT,check=True,text=True,capture_output=True)
rows=[{'function':n,'gas':int(g),'allocatorEnd':int(m)} for n,g,m in re.findall(r'emit Measurement\(name: "([^"]+)", gasUsed: (\d+)(?: \[[^]]+\])?, freeMemory: (\d+)',p.stdout)]
assert len(rows)==21,len(rows)
report={'description':'Foundry actual EVM gasleft deltas; free-memory pointer is allocator high-water bound, not opcode MSIZE. Test fixture uses vm.etch for full WAD chunks; a separate test uses ordinary CREATE across a 16KiB boundary. Full ordinary-deployment Anvil/render costs belong to integration gate. Uncached means first lump allocation in this frame; code accounts may already be warm from init.', 'command':cmd,'sources':{n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in ['src/doom/r_data.sol','src/doom/r_data_types.sol','src/evm/ResourceStore.sol','test/unit/r_data.t.sol','foundry.toml']},'measurements':rows}
out=ROOT/'test/fixtures/phase2_data/measurements.json';out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(rows,indent=2))
