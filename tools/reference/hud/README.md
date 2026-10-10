# Original HUD oracle

Run `python3 tools/reference/hud/reference.py --check` from the repository root.
Run `python3 tools/reference/hud/verify.py` to reproduce the focused native,
format, Foundry and accepted-source integrity checks and emit the verification
certificate under `artifacts/phase4/hud/`.

Omit `--check` only when intentionally regenerating the dedicated fixtures.
Requires the pinned local Freedoom bundle/resources under `artifacts/local/wad`
and the original source submodule, plus clang and its sanitizer runtime.

The tool mechanically extracts the original no-chat `hu_stuff.c` functions and
compiles unchanged `hu_lib.c`, `v_video.c`, and `m_bbox.c`. It compares O0, O2,
and ASan+UBSan output before packing snapshots for Foundry. Every action has a
snapshot, including intermediate timer and visibility states. The snapshot record
is 605 bytes: ten 32-bit state words, pending-message SHA-256, five text line
records (four signed words + 81 bytes each), four dirty-box words, and screen0
SHA-256. Action records are five signed words + text byte length + ASCII text.
`cases.bin` begins with a case count; each case starts with an action count.

`gameplay.py` uses the existing declared native combat/world hosts to execute
original pickup and locked-door producers. Their exact strings feed native HUD
cases. `gameplay.bin` holds kind/argument/health/text length, text and resulting
frame SHA-256 for actual Solidity producer → HUD → Frame integration tests.

Fonts are authentic unmodified STCFN033–095 WAD patches. See `fonts.json` and
`COPYING.txt` for provenance and redistribution terms. No expected pixel buffer
is supplied to EVM rendering; tests supply only fonts, gameplay inputs and the
explicit patterned initial framebuffer. See [Goal 4.3 report](../../../docs/PHASE4-HUD.md)
for adaptations, source mapping, focused tests, and deferred integration scope.
