# Status-bar reference

See [Goal 4.2 mapping, domains and evidence](../../../docs/PHASE4-STATUSBAR.md).

`reference.py` regenerates the dedicated status fixtures using original C, and
`--check` compares every byte and the fixture inventory. `world.py --check`
verifies the native reduced-view composition using the accepted renderer oracle.
Both need the pinned local WAD/resources under `artifacts/local` (same prerequisites
as Goal4.1). They never modify accepted fixtures or original sources.

`evm.mjs` consumes built test/ResourceStore artifacts and starts/stops only its
own isolated Anvil on port18695. An occupied port is an error. It uses ordinary
CREATE/transactions, with no runtime injection or impersonated state.

`checkpoint.py --check` verifies source/fixture bindings, the unchanged baseline
ownership boundary, all original gamma bytes, native agreement metadata and
recorded focused/receipt gates. It does not replace executing those gates.
