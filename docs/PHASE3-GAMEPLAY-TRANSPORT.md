# Gameplay browser transport

The browser still receives indexed8 `Frame` bytes, expands the verified palette,
and presents them on Canvas. Gameplay, collisions, actors, weapon state, lighting,
visibility, and pixel generation stay in the EVM.

`web/input-loop.mjs` adds an explicit gameplay lifecycle on the planned production
ABI:

| Method | Selector | Browser use |
|---|---|---|
| `inputSeq()` | `0x3464285a` | Read the accepted counter on load/start/resume |
| `gameStarted()` | `0x5e123ce4` | Read whether one-time initialization is needed |
| `initializeGame()` | `0xa0a1f49b` | Driver transaction after explicit Start |
| `stepAndRender(uint32,uint32)` | `0x18e65d56` | One held packet, one original tic, one Frame |

Selectors were generated with the pinned `cast sig`. The existing Frame topic,
palette protocol, static `renderFrame`, and zero-button transaction path are
unchanged. New deployment configurations must explicitly set `gameplay: true`;
`rendererKind: "doom-world-view"` stays compatible with inherited tooling. Old
configurations do not query the new gameplay ABI.

## User controls and transaction order

The existing page gains Start/Stop controls when gameplay is advertised. Loading
the page never initializes or runs gameplay automatically. Start checks the
on-chain flag, initializes only when needed, confirms the flag, refreshes the
counter, and starts a serialized loop. A reloaded initialized game requires
explicit Resume. The ordinary frame button renders the static view before
initialization and performs a zero-input tic when gameplay has already begun.

Keyboard mappings are described in [INPUT_PROTOCOL.md](../INPUT_PROTOCOL.md).
Each scheduled command samples held keys once immediately before submission.
Aliases and repeats remain held-key state. The engine owns use/fire edges and
weapon selection semantics; the browser does not simulate them.

Initialization, manual stepping, and continuous gameplay share one transaction
lock. The loop schedules a successor only after the preceding receipt settles.
At most one timer and one transaction are pending; there is no catch-up queue.
Pacing permits at most 35 commands per second on a fast node, while a slower node
advances one logical tic per accepted transaction rather than simulating missed
wall-clock tics in JavaScript.

Stop, window blur, hidden visibility, and unload clear held keys and cancel future
input. A transaction already submitted may still settle; its accepted tic is
presented, then no successor is scheduled. Resume requires explicit Start.
Inactive keyboard bindings preserve normal browser key behavior.

Successful receipts must contain exactly one Frame from the configured contract,
with the submitted sequence. The existing inbox handles WS/receipt duplication
and frame ordering. A definite revert does not consume a sequence and stops the
loop. An ambiguous send/receipt failure keeps the transaction channel locked;
the page must be reloaded after checking the local chain. Malformed Frame output
or a removed-chain event invalidates the session. The client does not blindly
retry an uncertain transaction. These conditions are surfaced only when observed.

## Verification and integration boundary

```sh
node --test web/input.test.mjs web/input-loop.test.mjs web/input-app.test.mjs \
  tools/transport/protocol.test.mjs tools/transport/palette.test.mjs
node --check web/app.mjs
```

**29 isolated tests pass**, with zero failures/skips. They cover packet mapping,
all valid masks/ABI encoding, initialization once, legacy counter/static behavior,
pending transactions, uncertainty/reverts, stop during initialization/receipt,
held sampling without backlog, blur/visibility, invalid outputs, sequence limits,
and actual application Start/Stop wiring. The DOM/RPC/WS test uses explicit local
test doubles and checks complete 64,000-byte Frame palette presentation. It does
not claim a real browser or a real EVM execution gate.

The inherited `?autotest=1` behavior stays on two zero-button transactions and
verifies receipt fallback plus Canvas readback. Advertising gameplay does not
implicitly start it during that static check.

Controlled production gates can use:

```js
await window.fixtureClient.startGame({ run: false });
await window.fixtureClient.nextFrame({ buttons: 257 }); // forward + run, one tic
await window.fixtureClient.nextFrame({ buttons: 0, disconnect: true });
```

The normal UI Start enters the continuous serialized loop. `stopGame()` clears
input and prevents successor transactions. These helpers transport packets and
Frame bytes only; they introduce no host world/rendering code.

**Pending:** root production adapter integration and real Anvil → WS/receipt →
browser gameplay acceptance against the native C frame oracle. This browser
module checkpoint establishes no M2/M3 engine acceptance. No external telemetry
service or Forge command is introduced by this workstream.
