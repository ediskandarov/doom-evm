# Original thinker and ticker port

`src/doom/p_tick.sol` maps all six active functions in original `p_tick.c` at
`a77dfb96cb91780ca334d0d4cfd86957558007e0`: P_InitThinkers, P_AddThinker,
P_RemoveThinker, P_AllocateThinker, P_RunThinkers and P_Ticker. The original
P_AllocateThinker is empty; allocation belongs to the explicit P_Heap adapter.

The doubly linked list preserves original tail insertion, lazy removal and
null-callback stasis. The runner reads the current node's next link after its
callback, so a new tail can execute in the same tic. Array capacity never drives
thinker iteration. Removal retains a stable tombstone in place of zone storage
deallocation; actor spatial removal remains owned by P_RemoveMobj.

The ticker retains player-slot order, menu/pause/demo/net exceptions, thinker
execution, specials, item respawn and signed leveltime increment. Original
35-tic simulation time is independent of block timestamps. The outer game
adapter owns gametic, matching the original outer-loop increment.

Native comparison compiles the entire unchanged original p_tick.c against
explicit recorded callbacks. Eight sequential snapshots cover player order,
same-tic tail spawn, removal before visitation, self-removal, stasis/resumption,
pause, menu early-return, initial-view exception, networking and demo exceptions.
Every callback event, live list ID/link/status, deallocation marker and leveltime
matches Solidity. O0/O2/ASan+UBSan agree byte for byte.

```sh
python3 tools/reference/phase3_tick/reference.py --check
.toolchain/bin/forge test --match-contract TickTest -vv
```

TickTest passed in the integrator's 22-test batch (432,876 test gas). The native
unit host retains static node bytes when Z_Free records deallocation, preserving
the original runner's next-pointer read. It does not claim allocation/reuse
equivalence; the separate full-gameplay C oracle compiles actual original
z_zone.c with documented LP64 alignment. Bounds failures for invalid/null/cap
removal are explicit adapter extensions outside valid original caller behavior.

This checkpoint proves scheduling under declared callbacks. Full-world state,
storage persistence and resulting EVM frames remain M2/M3 acceptance work.
