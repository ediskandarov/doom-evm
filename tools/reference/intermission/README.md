# Original Episode One intermission verification

Run from the feature worktree with the pinned toolchain in `.toolchain/bin`.
The oracle reads the pinned original source and redistributable Freedoom WAD;
it never edits either. An uninitialized feature-worktree submodule can use a
read-only source checkout by supplying `--source`.

```sh
python3 tools/reference/intermission/reference.py --check \
  --source /path/to/original/DOOM/linuxdoom-1.10 \
  --wad /path/to/freedoom1.wad
python3 tools/reference/intermission/focused.py
node tools/reference/intermission/evm.mjs
python3 tools/reference/intermission/preview.py --wad /path/to/freedoom1.wad
# Copy the focused runner logs to artifacts/phase4/intermission after an evidence refresh.
python3 tools/reference/intermission/checkpoint.py --check
```

Omit `--check` only when intentionally generating this goal's own fixtures.
DOOM_ORIGINAL and DOOM_WAD supply the corresponding defaults. The full original
WI translation unit is included unchanged in the observation host; original
video/bbox/RNG translation units compile unchanged. Source spans/hashes and all
declaration/platform/resource adaptations are in the native manifest.

The focused runner selects WI and existing video/RNG tests, skipping unrelated
build roots. It disables Foundry's dynamic test linking so test resource/host
deployment uses ordinary CREATE without granting artifact-file cheatcode access.
Solc 0.8.37, viaIR, optimizer200, Cancun and the 10B gas budget remain unchanged.
Failed initial native/Forge attempts remain separate local checkpoints; they are
not acceptance evidence. No full inherited regression suite is invoked.

The EVM runner refuses occupied/reserved ports and owns only the Anvil child it
starts on 18746. INTERMISSION_PORT and INTERMISSION_REPORT select isolated output.
It ordinarily deploys STOP-prefixed resource code and four WI support hosts,
checks every byte of resource/runtime code, compares every native observation,
compares complete Frame pixels and exercises separate-call persistence/rollback.
The 79-name resource view is a compact support selection with original full-WAD
provenance, not production full-WAD authentication or a new resource schema.
Three explicitly declared synthetic profiles exercise normally invisible markers
and fallback placement. No production/browser integration is performed.

Rerunning the runtime gate changes receipt/timing metadata. After an intentional
evidence refresh, copy focused.json/focused.log from artifacts/local/intermission
to artifacts/phase4/intermission and regenerate the certificate by running
checkpoint.py without --check. Then use --check to verify that recorded checkpoint.

Fixture inputs contain 16 big-endian header words, an action count and five-word
actions. The independent module receives completion/input structures and named
resource bytes only. No expected state or expected image enters the EVM.
Each expected snapshot contains 113 big-endian observation words, four dirtybox
words, and SHA-256 of all 64,000 screen0 and screen1 bytes (532 bytes total).
The native host additionally emits complete pixels, retained as per-case final
`.pixels` fixtures for byte-for-byte mined Frame comparison.

See [the integration report](../../../docs/PHASE4-INTERMISSION.md) for lifecycle
guards, original quirks, ownership and future Gameflow/Episode Runtime hooks.
