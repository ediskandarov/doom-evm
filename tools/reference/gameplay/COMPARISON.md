# Native gameplay and ordinary EVM comparison

`GameplayProbe` is a separately deployed test host for the same `DoomGame.initialize`,
`load`, `tick` and `render` libraries used by production integration. Its authenticated
`WadResources` constructor receives the pinned bundle through 1,755 ordinarily deployed
`ResourceStore` chunks. It accepts direct original ticcmds and the explicitly documented
native scenario setup, never native-provided world state or pixels.

The verified run covers all eight existing medium-skill E1M1 scenarios: 8 startup states,
2,205 original tics, 24 selected full 320×200 frames, and 8 final stored states. Every
DSG1 observation and pixel agrees with the pinned original C. The evidence and exact
consumed-source hashes are in `test/fixtures/gameplay_evm/evidence.json`; execution
commands, compiler/tool identities and artifact hashes are in `validation.json`.
This is the bounded direct-ticcmd kernel comparison. Production keyboard, input sequence,
Frame protocol, browser and broader performance gates have separate evidence.

## Observation boundaries

The original host records DSG1 **before** each selected render. The probe observes state
at the same point, then calls the actual renderer only when that native command requests
it. Renderer globals, caches, framebuffer and mapped-line flags persist into following
tics and transactions. Batches contain at most five commands; state is loaded through
`DoomGame.load` and written to Solidity storage between batches.

Rendering legitimately sets `ML_MAPPED=256`. An earlier harness incorrectly compared
final stored state, after rendering, against the final native pre-render state. All idle
and movement tick observations and six frames passed before that erroneous check found
movement line 543's flags 1 versus 257. Idle happened to match because its final render
added no new mapped flags. The preserved failure and explanation are committed alongside
the corrected evidence; no production behavior or comparison field was masked.

The separate `post_render_host.c` wraps the unchanged original host. Its wrapper calls
original `R_RenderPlayerView`, then observes DSG1 without changing any original state.
`post_render.py` proves 24 exact post-render observations across O0/O2/ASan+UBSan and
alternate allocation fill. It additionally verifies every retained pre-render state,
trace, diagnostic, event, summary and frame byte remains unchanged. The corrected
comparator uses these post-render goldens for final persisted state.

## Canonical mapping

Serialization follows `observe.h` field order, big-endian 32-bit words and live thinker
list order. Actor pool indices become their monotonic thinker IDs; all actor links,
target/tracer/attacker references, player `mo`, sector heads and block heads use that
conversion. Solidity `NULL=0xffffffff` becomes native null identity 0; thinker cap 0
becomes native sentinel −1. Nullable state/player/subsector fields become −1, while
original state `S_NULL=0` remains distinct from a null state pointer.

Native thinker kinds are actor 1, door 2, floor 3, ceiling 4, plat 5, light flash 6,
strobe 7, glow 8 and fire flicker 9. Active/stasis/removal callback states become
1/0/−1. Linked removed thinkers retain their original kind until actual list removal.
Active plat/ceiling pool references are translated through each payload's thinker ID.

The native observer deliberately replaces inactive, uninitialized special-action fields
with `INT32_MIN`; the probe applies exactly those same predicates. Inactive button
userdata and untouched respawn queue slots are omitted. The queue serializes only its
logical tail-to-head range. No machine pointers, padding, allocator addresses or inactive
pool capacity are compared. Static map/resource definitions have their existing native
data proof; the DSG1 schema is the authoritative observation scope, not every host global.

## Reproduction

```sh
# Reproduce the unchanged original pre-render oracle.
python3 tools/reference/gameplay/verify.py --check
# Reproduce the separately committed post-render goldens.
python3 tools/reference/gameplay/post_render.py --check
# Build once, with the existing pinned profile; coordinate the single compiler slot.
.toolchain/bin/forge build src/support/GameplayProbe.sol src/evm/ResourceStore.sol
# Validate the named decoder without starting any EVM node.
node tools/reference/gameplay/compare.mjs --decode-native-only
# Ordinary deployment, complete native scenario set and exact post-state checks.
node tools/reference/gameplay/compare.mjs --skip-build --output-prefix artifacts/local/gameplay-complete
```

The runner owns and terminates its Anvil process, refuses an occupied port and uses the
existing Cancun, 1-billion-gas and 1-GiB memory configuration. It uses ordinary CREATE,
verifies all chunk and probe runtime bytes, and compares actual transaction logs. It
reports only the first differing field or pixel. Actual emitted state streams are
reversible ignored local artifacts; their SHA256 values equal the independently decoded
native streams. Byte-identical duplicates are not committed.

## Measurement scope

Probe runtime is 418,858 bytes. The successful run used 441 five-tic transactions with
248,874,694–685,367,991 gas. Startup transactions include initialization and test-only
DSG1 serialization; advance transactions include loading, simulation, selected rendering,
serialization, Observation logs and storage persistence. These are test-probe costs,
not isolated module or production Doom costs. First reset initializes fresh storage;
later resets reuse previously initialized slots, so their gas differs.

Wall times include local RPC, EVM execution and mining. This harness does not measure
isolated interpreter CPU time, actual peak EVM memory, or peak host RSS. Native numeric,
LP64 and undefined-arithmetic adaptations remain those of the existing pinned oracle.
The finite eight scenarios do not certify every monster species, weapon, multiplayer,
nightmare, level transition or special-world branch; their separate isolated proofs
retain their own scopes. Renderer cadence is exactly the native selected cadence.
