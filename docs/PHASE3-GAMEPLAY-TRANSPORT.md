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
| `gameResourcesPrepared()` | `0x8874965d` | Historical staged preparation flag |
| `prepareGameResources()` | `0x4cc5dc3f` | Historical staged driver preparation transaction |
| `initializeGame()` | `0xa0a1f49b` | Driver transaction after explicit Start |
| `stepAndRender(uint32,uint32)` | `0x18e65d56` | One held packet, one original tic, one Frame |

Selectors were generated with the pinned `cast sig`. The existing Frame topic,
palette protocol, static `renderFrame`, and zero-button transaction path are
unchanged. New deployment configurations must explicitly set `gameplay: true`;
`rendererKind: "doom-world-view"` stays compatible with inherited tooling. Old
configurations do not query the new gameplay ABI. Allocator-integrated deployments additionally advertise `nativeZone: true`.
That flag does not imply staged startup. The current default is one
`initializeGame()` transaction performing source-derived resource preparation
and level startup in original order. Only explicit historical
`stagedInitialization: true` enables the old preparation ABI. Missing or false
staging flags never query or call it.

## User controls and transaction order

The existing page gains Start/Stop controls when gameplay is advertised. Loading
the page never initializes or runs gameplay automatically. Start checks the
on-chain flag, initializes only when needed, confirms the flag, refreshes the
counter, and starts a serialized loop. Only on explicitly staged historical deployments, Start first checks
`gameResourcesPrepared`, prepares once when needed, confirms preparation, then
initializes. Those historical stages share one lock. They emit no Frame and consume no input
sequence or tic. A reload after successful preparation skips that transaction;
a later initialization failure does not erase completed preparation. A reloaded initialized game requires
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
input. On historical staged deployments, Stop during pending preparation lets it settle and prevents submission
of initialization until another explicit Start. Direct controlled
`startGame({ run: false })` deliberately completes the configured startup path. A
transaction already submitted may still settle; its accepted tic is
presented, then no successor is scheduled. Resume requires explicit Start.
Inactive keyboard bindings preserve normal browser key behavior.

Successful receipts must contain exactly one Frame from the configured contract,
with the submitted sequence. The existing inbox handles WS/receipt duplication
and frame ordering. A definite revert does not consume a sequence and stops the
loop. An ambiguous send/receipt failure keeps the transaction channel locked;
the page must be reloaded after checking the local chain. Malformed Frame output
or a removed-chain event invalidates the session. The client does not blindly
retry an uncertain transaction. These conditions are surfaced only when observed.


The browser uses `config.gasLimit` for submitted transactions. Config generators
use the shared repository execution budget (default 10B, configurable through
`DOOM_GAS_LIMIT`). Older configurations without a gas field query the local
node's latest block budget. The browser imposes neither a fixed 1B nor a fixed
10B limit. Gas policy is separate from compiler, memory and source fidelity.

## Verification and integration boundary

```sh
node --test web/budget.test.mjs web/input.test.mjs web/input-loop.test.mjs web/input-app.test.mjs \
  tools/transport/protocol.test.mjs tools/transport/palette.test.mjs
node --check web/app.mjs
```

**44 isolated tests pass**, with zero failures/skips. They cover packet mapping,
all valid masks/ABI encoding, initialization once, legacy counter/static behavior,
pending transactions, uncertainty/reverts, stop during initialization/receipt,
held sampling without backlog, blur/visibility, invalid outputs, sequence limits,
and actual application Start/Stop wiring. The eight additional staged tests
cover prepare-then-initialize ordering, a shared lock, prepared reload, Stop
between stages, definite/uncertain preparation failure, initialization failure
after preparation, confirmation/counter/Frame guards, and staged app wiring.
The previous 29 tests are retained. A follow-up direct-Start regression proves
that chain invalidation during pending preparation prevents initialization
submission, including controlled `run: false` startup. Six new atomic/budget
tests prove that `nativeZone: true` alone never calls preparation, both app and
transaction client use one initialization, all send budgets come from the chosen
configuration/node, old static configurations discover node budget, and malformed
budgets fail rather than silently imposing a fixed limit. The DOM/RPC/WS test uses explicit local
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

**Pending for current atomic startup:** allocator-integrated production artifact
and real Anvil → WS/receipt → browser gameplay acceptance against the native C frame oracle. This browser
module checkpoint establishes no M2/M3 engine acceptance; historical staged
production evidence remains separately labeled. No external telemetry
service or Forge command is introduced by this workstream.
