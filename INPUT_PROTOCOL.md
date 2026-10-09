# Gameplay input protocol

The existing adapter ABI is `stepAndRender(uint32 buttons, uint32 inputSeq)`.
The first argument is a held-key packet, decoded by `src/evm/InputProtocol.sol`;
it is not the original DOOM `ticcmd_t.buttons` byte. One accepted command builds
one original DOOM tic command, with `ticdup = 1`. Sequence validation and storage
updates belong to the engine adapter. Input sampling alone does not advance the
world; duplicate/rejected transactions must not advance turn acceleration.

## Frozen packet layout

| Bits | Meaning | Browser defaults |
|---|---|---|
| 0 | `key_up` | Up arrow / W |
| 1 | `key_down` | Down arrow / S |
| 2 | `key_strafeleft` | Comma / A |
| 3 | `key_straferight` | Period / D |
| 4 | `key_left` | Left arrow |
| 5 | `key_right` | Right arrow |
| 6 | `key_use` | Space / E |
| 7 | `key_fire` | Left / right Control |
| 8 | `key_speed` | Left / right Shift |
| 9 | `key_strafe` | Left / right Alt |
| 10..13 | Original digit request, 0 = none, 1..9 = digit | Digits 1..9 |
| 14..31 | Reserved; must be zero | — |

Requests 10..15 and reserved bits revert before command construction. Digit 9 is
accepted but has no effect: the original `G_BuildTiccmd` loop tests only digits
1..8 (`i < NUMWEAPONS - 1`). The standalone browser sampler chooses the lowest
held digit, matching that loop when several number keys are down. Digit 9 alone
therefore produces the same command as no weapon request.

| Original digit | `BT_CHANGE` weapon index |
|---|---|
| 1 | 0 (`wp_fist`) |
| 2 | 1 (`wp_pistol`) |
| 3 | 2 (`wp_shotgun`) |
| 4 | 3 (`wp_chaingun`) |
| 5 | 4 (`wp_missile`) |
| 6 | 5 (`wp_plasma`) |
| 7 | 6 (`wp_bfg`) |
| 8 | 7 (`wp_chainsaw`) |

Original `P_PlayerThink` resolves fist/chainsaw, shotgun/supershotgun, ownership,
game-mode restrictions, and pending weapon state. Input construction does not
select a supershotgun directly or change a player's weapon inventory.

## Command and persistent input state

`src/doom/d_ticcmd.sol` maps original `d_ticcmd.h` field order and widths:
`int8 forwardmove`, `int8 sidemove`, `int16 angleturn`, `int16 consistancy`,
`uint8 chatchar`, `uint8 buttons`. The original `consistancy` spelling is retained.
Solidity storage/ABI encoding is not C struct byte encoding; native fixtures use
explicit big-endian 32-bit words rather than copying host struct padding.

`GameInputState { int32 turnheld; }` persists between accepted tic commands.
`InputProtocol.build(GameInputState memory state, uint32 held)` mutates this
memory state and returns a `Ticcmd memory`. The caller must persist `turnheld`
after a successful tic. The initial value is zero. Negative state is rejected.
Incrementing `INT32_MAX` while a turn key is held is rejected because original
signed C overflow is undefined. Releasing both turn keys resets even the maximum
counter to zero. Both turn keys down, and turn keys with the strafe modifier,
still increment the counter exactly as original C does.

Normal/run forward steps are 25/50; side steps are 24/40. Opposite keys cancel;
combined strafe keys accumulate before clamping to ±50. Right turns are negative,
left turns positive. The first five consecutive turn tics use 320; tic six onward
uses 640 while walking or 1280 while running. Strafe suppresses angle rotation
and maps left/right into side movement. `angleturn` is the signed 16-bit command
used by original gameplay to derive the binary-angle delta.

Attack and use are held flags: `BT_ATTACK = 1`, `BT_USE = 2`. A weapon request
adds `BT_CHANGE = 4` and `(digit - 1) << BT_WEAPONSHIFT`, with shift 3. The
builder preserves original attack/use/weapon ordering. Original player/weapon
logic owns `usedown` and `attackdown` edge behavior. The browser does not
substitute keypress edges for held bits.

## Declared host profile and fidelity evidence

`src/doom/g_game.sol` ports original `g_game.c::G_BuildTiccmd` for a single-player
keyboard profile: zero `I_BaseTiccmd`, zero consistency value and chat byte,
`ticdup = 1`, inactive mouse/joystick, and no pause/save special keys. The empty
base command makes forward/side/angle/button initialization zero. This profile
retains all keyboard movement, acceleration, cancellation, clamping, attack,
use, and original digit ordering. It is not a port of the entire `g_game.c`.

The original mouse/joystick double-click counters are omitted in Solidity:
device buttons are permanently zero and those counters cannot affect generated
commands in this profile. The native harness retains those original counters
and runs the entire unchanged original function. Mouse/joystick input, network
consistency, chat, demos, pause/save, and host tick scheduling require separately
declared profiles before support can be added.

Upstream is `a77dfb96cb91780ca334d0d4cfd86957558007e0`. The oracle mechanically
extracts the complete `G_BuildTiccmd`, its movement arrays, and turn/clamp macros;
it uses original headers and host globals/stubs. The generator verifies the
pristine upstream checkout and pinned Apple Clang 17.0.0 target/compiler. Builds
at O0, O2, and O2 with AddressSanitizer + UndefinedBehaviorSanitizer produce
identical packed output for 41,007 cases:

- Every 10-bit mask × requests 0..9 × initial `turnheld` 0, 4, 5, 20 (40,960).
- A persistent 47-tic sequence covering acceleration, release, run/strafe,
  opposed keys, weapon changes, held attack/use, and ignored digit 9.

The signed-char native profile matches `int8`, with static assertions for
8-bit signed char, 16-bit short, and 32-bit int. There are no disabled sanitizer
categories or original algorithm edits. Manifest hashes identify original
headers, exact extracted function, harness, compiler flags, and vector bytes.

```sh
python3 tools/reference/phase3_input/reference.py --check
.toolchain/bin/forge test --match-contract GGameTest -vv
node --test web/input.test.mjs
```

The Forge oracle tests compare every command field and the resulting counter;
the sequential test preserves one input state for all 47 commands. Separate
tests cover packet rejection and the explicitly rejected undefined-C overflow.

## Browser boundary

`web/input.mjs` exposes `KeyboardInput`, `bindKeyboard`, `validateInputMask`, and
`inputStepData(mask, sequence)`. It samples held physical key codes, preserves
aliases when only one is released, ignores key-repeat duplication, and clears
keys on blur/hidden/disposal. `inputStepData` encodes the existing two-uint32 ABI.
The module performs no movement, visibility, collision, projection, or rendering.
The engine integrator owns connecting it to the transaction queue and accepted
tic scheduling. These input proofs establish command fidelity; M2 and M3 require
separate full gameplay and frame acceptance evidence.
