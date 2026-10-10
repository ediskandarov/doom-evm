# Automap native oracle and EVM gate

See [integration API and behavior](../../../docs/PHASE4-AUTOMAP.md).

`reference.py --check` regenerates every fixture from mechanically included
original `am_map.c` plus unchanged video/fixed/table/cheat code and authentic
Freedoom resource bytes. The local bundle under `artifacts/local/wad` must match
its manifest hash. Fixture patch provenance/license are retained in `native.json`
and `COPYING.txt`. No original source or production adapter is patched.

Fixture input words are big-endian 32-bit: episode/map/console/net/death/demo/
allmap/blockX/blockY, four players (x/y/angle/ingame/invisible), vertex count and
x/y records, wall count and (ax/ay/bx/by/flags/special/back/frontFloor/backFloor/
frontCeiling/backCeiling) records, thing count and x/y/angle records, action
count then five-word actions (op/a/b/c/d). Input files contain no pixels.

Actions: 0 original responder; 1 ticker a times; 2 drawer; 3 update player a
position/angle; 4 stop; 5 start episode a/map b; 6 allmap power; 7 linedef a flags
b; 8 net/death/demo; 9 set mark a position; 10 invoke optional original light
helper; 11 slope helper for endpoints (a,b)/(c,d). Opcode 11 places helper
results in the host notification observation slot on both sides only for
verification. The production library does not perform that substitution.

State observations: 66 words in the exact order in `host.c:snapshot` and
`AutomapFixture.snapshot`, message length then message bytes. `cases.bin`
contains case count, each input length/input, then state SHA-256 and full-frame
SHA-256 pairs per action. Individual `N.hashes.bin` files hold the same pairs.
`cases.json` carries names, actions, geometry and digests for inspection.

`evm.mjs` reads compiled AutomapProbe artifacts, starts isolated Anvil, sends
ordinary CREATE/render/revert transactions and writes receipt evidence.
`verify.py` checks native/source/ownership/receipt bindings and writes or checks
the final verification/source-map artifacts. Re-run the focused Foundry gate
before generating final verification evidence; full inherited tests are deferred.
