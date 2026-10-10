# Original DOOM cheat oracle

`reference.py` extracts `cht_CheckCheat`, `cht_GetParam`, the original sequence
arrays, ST's responder minus the excluded IDMUS branch, `P_GiveBody`,
`P_GivePower`, and AM's cheat branch from pinned source. Platform types come from
original headers. The host observes player/actor state and the deferred-game
boundary; it implements no cheat algorithms. Each scenario starts a fresh
recognizer/player instance; state then persists over every event in that scenario.

`vectors.bin` is big-endian: scenario count, then per scenario eight initial
words, event count, and per event four input words plus a 32-byte SHA-256 of the
native snapshot. See `manifest.json` for field names. The native snapshot contains
40 state words, message length/bytes, then 16 (cursor, length, sequence) triples.
Every byte of mutable parameters is included, even when it equals the encoded
terminator. The primitive file is count followed by 10 sequence bytes, cursor,
key, GetParam flag and the native snapshot hash. Its snapshot is completion,
cursor, sequence length/bytes, parameter-output length/bytes. Embedded NUL output
is observed using a sentinel buffer, rather than strlen, to retain extra zeros.

`presentation.py` reuses only resource/platform boundaries from the accepted
statusbar host and reads the accepted Freedoom status/HUD assets. It compiles
original status/widget/video logic, inserts actual original power/body functions,
and feeds raw cheat keys through native ST_Responder. It compares three native
profiles and writes hashes of the whole frame, status background and palette,
plus face/palette indices. Solidity drives its accepted ST/HU modules from the
same cheat keys; it does not load expected player mutations from fixtures.

`evm.mjs` deploys the dedicated support probe via ordinary CREATE on its own fresh
Anvil port 18695, compares every emitted event hash against native C, tests
rollback and duplicate sequence rejection, then stops its node. It refuses to
attach to an occupied port. `CHEATS_PORT` and `CHEATS_REPORT` allow isolated
reruns. The probe's event and reset APIs are verification-only.

Run `reference.py --check` and `presentation.py --check` to rebuild native data
and verify byte identity. Regenerate fixtures without `--check` only after a
source/harness change whose reason is understood. `checkpoint.py --check`
validates source/evidence bindings and protected baseline files; it is not a
substitute for executing the native, Foundry and ordinary-EVM checks.

The handoff and required production/AM/multi-map APIs are in
[PHASE4-CHEATS.md](../../../docs/PHASE4-CHEATS.md).
