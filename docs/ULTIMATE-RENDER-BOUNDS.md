# Reproduced Ultimate DOOM owner-pointer bounds failures

The integrated experimental virtual-pointer profile supports validated
same-zone links and source-written NULL/(void*)2 markers. It does not know an
allocated block's owner-slot address. The namespace identifies an owner but
records neither its native address nor a virtual slot location. This limitation
is explicit in `Z_ZoneVirtual.pointerFromValidatedHeader` (lines 68–83).
Increasing gas, EVM memory, RPC limits or disk space cannot establish that value.

An ignored error-only source clone retains every rejecting R_DrawColumn guard
and all draw arithmetic. It augments only the revert with sample index,
source/column identity and the current allocation ledger. Original C and the
production Solidity renderer/allocator are unchanged. Extra diagnostic fields
change memory/gas; diagnostic costs are not production-renderer costs. Each
probe replays every original tic, comparing the complete DSG1 bytes, and renders
only the rejected target frame. Its savedDigest exactly equals the original
full-rate failure's digest. Reverted capture receipts contain zero logs and
leave the whole saved state and frame counter unchanged.

| Map | Rejected tic | Source lump | Index / logical bytes | Header owner | Header byte | Physical offset | Screen x, y |
| --- | ---: | --- | --- | --- | ---: | ---: | --- |
| E1M3 | 923 | SPOSB1 | 1395 / 1384 | SPOSB2B8 | 11 | 3763387 | 99,112 |
| E1M5 | 1064 | BLUDC0 | 224 / 216 | BAL2A0 | 8 | 3009056 | 34,150 |
| E1M6 | 1736 | STEP04 | 565 / 552 | STEP03 | 13 | 824125 | 4,137 |
| E1M8, Sedlo alternate | 263 | STEP04 | 565 / 552 | STEP03 | 13 | 824125 | 182,192 |

LP64 `memblock_t.user` occupies offsets 8–15. Each sample is a low byte of a
non-NULL owner pointer in an allocated current-ring block, with provenance zero.
For these lump-cache blocks, original `W_CacheLumpNum` passes an actual
`&lumpcache[lump]` to `Z_Malloc`; the allocator stores it in `base->user`.
The virtual profile deliberately refuses to fabricate that address. Native
captures can display host-placement-dependent bytes, and successful native
rendering does not make those bytes universally reproducible.

This is a concrete unsupported memory domain, not MemoryOOG, a transaction gas
cap or evidence that map size exhausted memory. All failing production capture
transactions use less than 0.7B gas against a 10B limit. No speculative correction,
owner-address invention, bounds relaxation or golden change is applied. Full
independent gameplay replay continues through genuine exits, and accepted
partial frames remain receipt-authenticated. Missing frames are not repeated
or encoded as a complete MP4.

Reproduction in the dedicated worktree (source the pinned environment first):

```sh
python3 tools/reference/ultimate_speedruns/render-diagnostic.py
forge build artifacts/local/ultimate-speedruns/render-diagnostic/src/support/UltimateSpeedrunProbe.sol src/evm/ResourceStore.sol --out artifacts/local/ultimate-speedruns/render-diagnostic/out --cache-path artifacts/local/ultimate-speedruns/render-diagnostic/cache
node tools/reference/ultimate_speedruns/native-domain.mjs artifacts/local/ultimate-speedruns/E1M3
node tools/reference/ultimate_speedruns/evm-diagnostic.mjs --artifacts artifacts/local/ultimate-speedruns/E1M3 --output-prefix artifacts/local/ultimate-speedruns/E1M3/render-diagnostic/evm --port 18644 --batch 25 --diagnostic-tic 923
python3 tools/reference/speedrun/decode-diagnostic.py artifacts/local/ultimate-speedruns/E1M3/render-diagnostic/evm.json artifacts/local/ultimate-speedruns/E1M3/render-diagnostic/decoded.json
```

Other targets use the table above and separate output directories. The diagnostic
runner intentionally exits nonzero on rejection. Never confuse its single
capture attempt or gameplay-only continuation with full-rate recording success.
Decoded metadata/hashes may be committed; full ledgers, resources, frames and
commercial geometry remain under ignored `artifacts/local`.
