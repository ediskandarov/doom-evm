# Phase 2 sprite port

`src/doom/r_things.sol` maps every original r_things.c routine to the frozen
memory context: sprite definitions/rotations, visible pool, projection,
sector collection, stable sorting, masked posts, silhouette clipping, masked
pass ordering, and both player psprite overlays. `src/doom/p_setup_static.sol`
provides `P_SetupStatic.load(RenderContext, InfoData)` for the declared static
medium-skill single-player scene. Call `Info.load()`, initialize sprite
names with `R_Things.R_InitSprites(ctx, info.spriteNames)`, then load static
things. The adapter reads the raw map THINGS already loaded inside the EVM and
original info.c metadata; it does not accept host visibility or projected data.

The adapter retains the original spawn-state sprite/frame, mobj flags, ambush
flag, angle quantization, floor/ceiling placement, and reverse insertion into
sector thing lists. It performs no action, thinker, or tick. This is the pinned
E1M1 static scene policy, not a general gameplay P_SpawnMapThing replacement.
The full 209 things and every sector head/next link match the native host.

## Original-source comparisons

```sh
python3 tools/reference/phase2_sprites/verify.py --check
.toolchain/bin/forge test --match-path test/unit/r_things.t.sol -vv
```

The native extension imports the existing renderer builder without editing it.
Its owned observation code is inserted into a temporary host copy, leaving the
original algorithms in their native translation units. The manifest records
upstream/source hashes, builder adaptations, compiler profile, original host,
observer, generator, and every fixture hash. The source pin remains
`a77dfb96cb91780ca334d0d4cfd86957558007e0`. O0, O2, and ASan/UBSan with the pinned
`-fwrapv` profile agree on all observations.

Real fixtures contain all 138 sprite definitions, all static thing fields and
sector lists, and all 13 projected vissprite fields plus stable order for
angles 0 through 7. Visible counts are 26, 17, 1, 4, 5, 6, 1, 14. The projection
unit gate uses genuine BSP clipping/collection with an observation-only wall
callback; full pixels require the real wall and masked-range callbacks.

Synthetic native fixtures exercise near-plane/side rejection, the preserved
empty projection at x1==viewwidth, left clipping, flip, shadow/fixed/fullbright
precedence, translation flags, pool overflow, and stable equal-scale sorting.
Separate synthetic patch frames exercise ordinary, fuzz, translated columns,
and two active player psprites with ordinary/fullbright/invisibility lighting.
These are independent native outputs, never inputs to a production frame.

## Preserved behavior and bounds

- Original sprite lump scan order, signed-short lump narrowing, and modifiedgame
  asymmetry are retained: the primary frame uses W_GetNumForName, while the
  second flipped frame uses the scanned lump itself.
- The 128-entry pool uses one overflow sink; it does not append extra sprites.
  Sort selection uses strict less-than, preserving source order for equal scale.
- World projection retains x1==viewwidth empty sprites. DrawVisSprite ignores
  its x1/x2 arguments and consumes the vissprite's own range, as original C does.
- Masked columns receive a post-header offset. A terminal FF requires only one
  byte; drawn posts retain original integer rounding and clipping. Low-detail
  drawing mutations of dc_x remain visible to subsequent posts/callers.
- Shadow takes precedence over translation in drawing, and over fixed/fullbright
  lighting in projection. Translated and fuzz columns retain their original
  detail-mode quirks. The masked pass draws sorted sprites, remaining masked
  walls in reverse drawseg order, then active psprites only at viewangleoffset 0.
- Invalid source/destination addresses, missing rotations, INT_MIN absolute
  value, and INT_MAX sort scales reject explicitly. These replace unsafe or
  undefined original behavior, not defined-C outputs. Signed arithmetic wrap
  follows the pinned native profile; this is not a claim of strict ISO C
  equivalence at overflow/negative-shift boundaries.

The production port adds no assembly. Tests use a bounded directory-word load
and read the allocator solely for labeled diagnostic observations. Foundry
resource fixtures use vm.etch only in isolated tests; ordinary authenticated
resource deployment is separately proven in PHASE2-SOURCE.md.

## Initial costs before the integrator's table optimization

Angle 0 stage measurements use gasleft differences. DoomScene.load plus the
unit fixture resource view costs 525,200,976 gas. Info.load plus sprite
initialization costs 61,272,223; static spawning costs 22,427,102. BSP collection,
projection, and sorting with the no-op wall callback cost 61,027,310. The full
angle-0 comparison test costs approximately 671 million gas.

Allocator observations after scene, definitions, spawn, and collection are
11,495,808; 11,814,656; 11,887,424; 13,076,224 bytes. These are free-pointer
observations, **not literal MSIZE or whole-frame memory peaks**. Full-frame
ordinary deployment and literal-memory measurements belong to the integrated
renderer gate; this intermediate report makes no such completion claim.
