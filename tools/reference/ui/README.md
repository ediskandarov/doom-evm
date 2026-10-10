# Production UI verification — Goal 4.11

Use the pinned local toolchain, original C checkout, Freedoom IWAD and packaged
resources/chunks under `artifacts/local`. The original source pin, compiler
profile, resource identity and declared host adaptations are checked and recorded.

```sh
.toolchain/bin/forge build --offline src/evm/Doom.sol src/evm/ResourceStore.sol test/integration/ProductionUI.t.sol
python3 tools/reference/ui/reference.py
python3 tools/reference/ui/verify.py
python3 tools/reference/ui/verify.py --node-only
node tools/reference/ui/production.mjs --browser --output-prefix artifacts/local/ui/production-complete
python3 tools/reference/ui/checkpoint.py
python3 tools/reference/ui/checkpoint.py --check
```

`reference.py --check` reproduces the separate local oracle. Original keyboard
input runs/reverses through a real E1M1 health bonus, switches supported view
sizes, fires the pistol and reaches message expiry. O0/O2/sanitizers/alternate
allocation fill must agree. Original ST/HU/video translation units execute with
borrowed immutable UI patches and consumer-owned screen4 outside the existing
gameplay zone. This preserves the accepted renderer backing profile; it makes
no new whole-process allocation-equivalence claim.

`production.mjs` refuses occupied/reserved ports, starts only its own Anvil on
18711, deploys all 1,755 immutable resource contracts and unmodified production
Doom with ordinary CREATE, and compares state after every transaction. Native
states/pixels never enter production. Selected receipts, WebSocket logs and
frame-associated EVM palettes must match all native bytes. `--browser` deploys
a fresh production instance on that owned node and runs the real Chrome gate.
The runner stops its Anvil; the browser runner stops its Chrome/server/profile.

Focused consumer vectors also cover every weapon, armor, card/skull priority,
stale-key behavior, backpack, sustained fire, damage directions, pain, and
original face quirks across storage calls. Existing producer/HUD/video tests
remain part of the focused gate. Named skips remove unrelated build roots,
never tests in the selected gate.

The [report](../../../docs/PHASE4-UI-INTEGRATION.md) identifies finite coverage,
integration requirements, commands, measurements and preserved legacy evidence.
`checkpoint.py --check` validates source/evidence bindings and recorded results;
it does not execute or replace the gates.
