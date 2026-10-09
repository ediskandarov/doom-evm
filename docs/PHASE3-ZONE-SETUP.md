# Native physical allocation order during level setup

`P_Zone_Setup` mirrors the original `p_setup.c` allocation chronology independently of the logical renderer/map adapters. It is enabled only when `GameState.nativeZone.byteLength` is nonzero. Counts and requested sizes come from the authenticated parsed map and source-derived LP64 layout constants. Native observations are comparison inputs only.

The order is original `Z_FreeTags(PU_LEVEL..PU_PURGELEVEL-1)`, BLOCKMAP cache, blocklinks pointers, vertexes, sectors, sides, lines, subsectors, nodes, segs, REJECT cache, sector-line pointer buffer, THINGS cache, actual original thing spawns, THINGS free, then actual original special spawns. Each map array retains its original temporary lump cache/free sequence. `P_Heap` owns actual actor/mover physical allocations; the setup adapter adds no separate thinker allocation.

`nativeMapBlocks` retains the original typed allocation IDs in this order: blocklinks, vertexes, sectors, sides, lines, subsectors, nodes, segs, sector-line pointer buffer. Setup clears these and the per-kind `nativePayloadBlocks` after `FreeTags`, before the real spawn functions execute. Resource caches outside the original level-tag interval remain intact.

The independent native harness adds only a stage observation after original `P_GroupLines`. Four compiler/allocation profiles agree on 25 completed outer geometry operations, all normalized headers/owners at that boundary, and all headers/owners after full original setup. The observer preserves all original browser six-command frames, worlds, ticks and diagnostics. See [native evidence](../tools/reference/phase3_zone_setup/README.md) and its source-bound manifest.

The component tests construct startup state through the actual source-derived `DoomZoneStartup.replay`, persist that generated state with ordinary Solidity storage, then compare setup results against the immutable native headers. The observation-enabled geometry path uses the same allocation/cache/free primitives and recipe as normal setup. Its rolling digest additionally checks operation order, size, tag, owner and returned physical placement. The full setup test calls the actual `DoomGame.initializeWithZone` once, installing its real gameplay hooks and executing all setup/spawn functions. It avoids holding a duplicate resource graph in the same test call.

Engine code and allocation history are never replaced with fixtures. The only `etch` in these component tests installs the pinned STOP-prefixed resource chunks; it is a test resource adapter, not an ordinary authenticated deployment claim. The existing one-billion-gas limit is unchanged. Pointer bytes and uninitialized free-fragment IDs are outside the portable header claims.

The EVM setup gate passed all three tests in session73296:

- Actual geometry functions: 841,226,923 gas.
- Same-recipe observation digest and headers: 756,455,921 gas.
- Actual full initializer and original spawn hooks, all setup headers/owners and counts: 921,597,231 gas.

The completed scope is original setup allocation order and normalized heap headers/owners. It is not a whole-game or browser/M2/M3 acceptance claim. The earlier full-test duplicate-parse scaffolding hit MemoryOOG at999,978,936 gas; it was corrected in test code without changing the production algorithm, gas limit or assertions. Full code generation also exposed local-variable liveness limits in R_LoadMap and the backing reader; their source-preserving memory scratch changes are reviewed and verified separately.
