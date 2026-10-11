# Declared original-C allocation domains

The established native host supplies a64MiB initial `calloc` zone and uses the
original zone allocator without fresh-allocation zero filling. This profile is
preserved. An independent fresh-allocation0xa5 diagnostic deliberately changes
payload bytes and tests allocation sensitivity; its failed gates remain failed.

E1M3's real tape exits identically across O2/O0/ASan-UBSan and the fill diagnostic.
All complete normal-profile DSG1 streams are byte-identical. Starting at tic962,
the fill diagnostic changes only20 named stair `type`/`crush` fields from0 to
0xa5a5a5a5. Original `EV_BuildStairs` never initializes those fields; `T_MoveFloor`
and the observer read them. No universal original-C allocation equivalence can
be claimed for this domain.

E1M5 also exits identically. Its fill diagnostic differs only in one platform's
`low` field at tic121–281. Original `EV_DoPlat`'s raising-and-changing cases set
speed/high/wait/status but do not initialize `low`; the observer serializes it.
O2/O0/sanitized normal-zone observations agree byte for byte.

`native-domain.mjs` independently reads all four state streams, checks real
exit/time and hashes, compares every normal-profile byte, enumerates every
fill-dependent named field, checks actual0/0xa5 values and hashes the original
C functions and host adaptation. It does not mask any EVM field, alter original
C/fixtures, invent bytes or fix the undefined source behavior. Results are in
[the E1M3 audit](../artifacts/ultimate-speedruns/E1M3/native-domain.json) and
[the E1M5 audit](../artifacts/ultimate-speedruns/E1M5/native-domain.json), alongside
the unchanged failed native gate reports.

For these tapes, `evm-native-domain.mjs` explicitly selects the existing
**initial-zero-zone** native profile. Every complete EVM snapshot must still
match its complete original-C reference; renderer provenance guards remain
unchanged. The report embeds the domain audit and explicitly keeps
`alternateAllocationGatePassed=false`. This is finite profile equality, not
portable initialization or universal native equivalence. Any additional mismatch
or unknown renderer byte still fails and is investigated separately.
