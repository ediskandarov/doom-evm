# Production startup and memory verification

The ordinary production runner uses one `initializeGame()` transaction. With
`--native-zone`, resource preparation and level startup execute in source order
inside that transaction. The allocator capability does not select staged startup.
Only an explicit historical `--staged-initialization` run calls old preparation
methods; that separately labeled profile retains its old guards. Current atomic
runs retain the original thirteen authorization/sequence/input/rollback gates.
The default atomic prefix is `artifacts/local/gameplay-production-zone-atomic`,
leaving earlier proof files intact.

Repeated deployments can attach to an explicitly local node and reuse resource
addresses from a previous production report. Every byte of all 1,755 STOP-prefixed
chunk runtimes is rechecked against the resource blob and the resource identity
must match. The normal constructor still authenticates those chunks and the
packed directory; engine deployments always use ordinary CREATE. No resource
or engine code is installed through `etch`/`setCode` in these runners.

```sh
node tools/reference/gameplay/production.mjs --native-zone --keep-node
node tools/reference/gameplay/production.mjs --native-zone \
  --rpc http://127.0.0.1:18679 \
  --resources-report artifacts/local/gameplay-production-zone-atomic.json \
  --output-prefix artifacts/local/gameplay-production-zone-atomic-repeat \
  --no-web-palette-write
```

External-node flags are explicitly unverified by the attached runner. A previous
report is a resource-address source, not a substitute for current byte checks.
The default managed node keeps the established local Cancun/code-size/gas/memory
configuration. Gas comes from `tools/execution-budget.mjs` and
`execution-budget.json`, default 10B with `DOOM_GAS_LIMIT` override. Attached local
Anvil block budgets are configured to that selected policy; all emitted browser
configs include its `gasLimit` and explicit `stagedInitialization: false` for
current runs. Memory/code/compiler constraints remain separate. Higher budgets
must preserve source fidelity rather than motivating a split startup.
`--no-web-palette-write` still exports the prefix config/palette, but preserves
the web palette when another browser gate is active.

## Separate engine-boundary memory clone

`production-memory.mjs` mechanically copies a frozen Doom source snapshot. It
changes the contract name/project-root import paths and inserts only an observer call after
original work at the end of prepare/init/step/stepAndRender/renderFrame external
entry points. It rejects methods with early returns that would bypass the marker.
The tool never edits production or automatically invokes Forge.

```sh
node tools/reference/gameplay/production-memory.mjs --generate
# Run only in the root agent's assigned compiler slot:
.toolchain/bin/forge build artifacts/local/production-memory/DoomMemoryProbe.sol
node tools/reference/gameplay/production-memory.mjs \
  --resources-report artifacts/local/gameplay-production-zone-atomic.json
```

The compiler sees an ordinary `gasleft()` marker. The established source-map
instrumenter changes only GAS opcodes in that private helper to MSIZE in a
separately deployed clone's creation/runtime bytes. GAS and MSIZE both cost two
gas and push one word; bytecode length and jump destinations stay fixed. This
avoids optimizer restrictions on direct MSIZE source instructions and avoids
unbounded opcode trace collection.

The runner ordinarily deploys three fresh contracts sharing verified resource
code: production, an unpatched marker clone, and the MSIZE clone. It compares
all storage roots and exported state after every selected call, every Frame byte
across all three, native camera/status fields, and selected native Frame bytes.
Patched/unpatched clone transaction gas must match exactly. Default memory
sampling uses the independently bound six-tic all-frame browser native profile.
Use `--native artifacts/local/gameplay-production-native --limit 6` to also
exercise no-render steps with the corresponding native rendering cadence.

MSIZE is the active memory extent in the current call frame. It never shrinks
within that frame, so a final reading is its high-water through the marker. The
following observer event/ABI encoding may expand memory further; separate
external calls and precompiles have separate memory. Marker clone source/code
generation can also alter memory reuse relative to untouched production. Reports
therefore describe **measured clone engine-boundary high-water**, excluding later
observer work and separate frames, and never claim an exact untouched-production
peak. The source snapshot, compiler settings, source maps, patched PCs, hashes and
comparison results are retained in the measurement report.

Seven isolated tests passed for clone source boundaries/guards, constructor
encoding, source-mapped opcode selection and bounded memory-trace calibration.
The frozen source clone compiled with the unchanged optimizer settings. Two
three-deployment runtime gates passed: the six-tic all-frame browser stream, and
the first six production tics with one selected frame and five no-render steps.
Every sampled storage root, exported state and Frame matched across deployments;
fourteen fields and selected live pixels matched the native oracle. These memory
samples do not constitute a full 129-tic replay.

| Measured clone boundary | Bytes |
| --- | ---: |
| Atomic initialization | 19,665,056 |
| Static Frame before start | 8,841,664 |
| Sampled no-render tics | 8,749,760–8,753,856 |
| Six live Frames | 11,918,816–11,956,800 |

The ordinary atomic initialization used 1,621,868,997 gas. The observer clone
used 429,916 less initialization gas and 223,822 less gas per all-frame tic,
reflecting different compiler output. Patched and unpatched observer clone gas
was identical. These measurements are bounded to the tested source, commands,
cadence and final call-frame marker, with the limitations described above.
Retained hashes, patched PCs, deployment receipts and comparison scopes are in
`production-memory-evidence.json`; full local reports retain every boundary.

Two independent ordinary production deployments also completed the entire
129-tic stream, each comparing 130 rows of fourteen fields, six live native
Frames, the pre-start static Frame and thirteen storage-rollback guards.
Commands, rendering cadence, all observed fields, Frame hashes and receipt gas
were identical between runs. `production-reproducibility-evidence.json` binds
both reports and distinguishes that full replay from the smaller memory samples.
