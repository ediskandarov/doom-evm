# Combined Exact EVM Snapshot / Death–Respawn verification

These are integration checks, not canonical Save/Load implementation. Production
keeps the six-slot exact snapshot extension selected by the user. The canonical
research and its contrary recommendation remain historical evidence; no proposed
semantic archive, queued save/load lifecycle, or migration is implemented here.

Run only in the owned main worktree with the pinned tools and authenticated local
IWADs. Outputs stay under ignored `artifacts/local/death-save-main`. Commercial
IWADs, indexed images, palettes, browser screenshots and MP4s are never published.
The browser requires free owned ports19511/19512; memory checks use19513.
Reserved18880/8088 and other owners' worktrees/runtimes are excluded.

1. Build explicit `Doom`, `Doom2` and `ResourceStore` roots in an owned output/cache.
   Let Forge validate copied cache candidates; check the unchanged133-node schema
   with `python3 tools/reference/save_load/schema.py --check`. Repackage current
   artifacts using `python3 tools/reference/death_respawn/package.py <compiled>`.
2. Run the focused Forge imports listed in the published checkpoint, including
   `test/death_respawn/CombinedSaveRespawn.t.sol`, and the affected Node modules.
   Forge fixtures use the existing authenticated Freedoom chunk directory.
3. Build the unchanged original-C death oracle with
   `tools/reference/death_respawn/native.py` for O0/O2/ASan+UBSan, both Episode and
   commercial profiles, into `artifacts/local/death-save-main/native/{episode-,commercial-}/<profile>`.
   Run `python3 tools/reference/death_save/native.py --fixtures` to check original
   goldens without rewriting them.
4. Run `node tools/reference/death_save/browser.mjs --ultimate-wad <local DOOM.WAD>
   --doom2-wad <local DOOM2.WAD> --output-prefix artifacts/local/death-save-main/browser-final`.
   This uses browser File API/IndexedDB/ordinary CREATE, authentic gameplay damage,
   original menu packets, six snapshot slots, exact replay/rebirth/reload, real
   transactions and all-pixel Canvas comparisons. It reuses the unchanged source
   Save/Load gates, then original End Game/New Game isolates the fresh native trace.
5. Run `python3 tools/reference/death_save/native.py` to compare native gameplay
   fields and complete receipt frame/palette bytes for the original, loaded replay
   and rebirth traces under all three compiler profiles. Exact restore rewinds to
   an executed native prefix; it does not mimic lossy original C save-file loading.
6. For measured production memory, generate the observation-only clone with
   `python3 tools/reference/death_save/memory-prepare.py`, compile it into the owned
   production output, then run `node tools/reference/death_save/memory.mjs
   --resources artifacts/local/wad`. Compare unmodified production, GAS observer
   and same-cost MSIZE observer: state/root/frame/palette equality is mandatory.

The four new Forge cases cover active monsters, full-root/allocator/RNG replay,
dead/corpse snapshots, saves spanning original same-map rebirth, queued-reborn
snapshot restoration, six slots and atomic invalid/incompatible operations.
Controlled scenario setup exists only in test probes; browser acceptance uses
ordinary gameplay and original IDFA, with no EVM state/pixel injection.

Do not reuse occupied outputs for a new acceptance certificate. Preserve failed
or superseded attempts separately, and publish fresh bindings without rewriting
source certificates. Production defaults remain2; browser profile3 stays explicit.
No complete historical acceptance or full speedrun rerender is part of this gate.
