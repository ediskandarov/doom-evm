# Original-C gameflow oracle

See [the scope, source mapping and integration API](../../../docs/PHASE4-GAMEFLOW.md).
`reference.py` mechanically extracts fourteen original g_game definitions plus
P_Ticker/P_DeathThink/P_CalcHeight. Host doubles observe external boundaries;
the Solidity boundary harness uses the same controlled initial conditions.
Par tables are extracted from g_game.c as well. The fixture has 219 records.

`reference.py --check` rebuilds O0/O2/ASan+UBSan and requires exact checked-in
bytes and provenance. Omit `--check` only for intentional fixture regeneration.
`snapshot.py --check` checks generated observation serializers. `legacy.py
--check` checks the accepted native E1M1 setup/first-tic fixtures and the copied
observation serializer without modifying inherited artifacts.

The C driver records six input words followed by every field listed in
`snapshot.py`, a call-count word and the ordered boundary call IDs:

| ID | Boundary |
|---|---|
| 1 | P_Ticker entry |
| 2 | P_SetupLevel |
| 3 | Z_CheckHeap |
| 4 | AM_Stop |
| 5 | WI_Start |
| 6 | F_StartFinale |
| 7, 8, 9 | ST_Ticker, AM_Ticker, HU_Ticker |
| 10, 11 | WI_Ticker, F_Ticker |
| 12 | P_PlayerThink boundary (real P_DeathThink when dead) |
| 13, 14, 15 | P_RunThinkers, P_UpdateSpecials, P_RespawnSpecials |
| 16 | P_MovePsprites |
| 20 | R_FlatNumForName(F_SKY1) |
| 21, 23 | R_TextureNumForName(SKY1), R_TextureNumForName(SKY3) |

Setup resets counters and invokes the real G_PlayerReborn for reborn players;
it installs controlled actors instead of loading a WAD. The independent E1M1
integration test supplies the real existing map loader and gameplay hooks.
This distinction is intentional and recorded in the manifest.
