// SPDX-License-Identifier: GPL-2.0-only
import { makeRpc, FrameInbox, FrameSubscription, backfill, expandPalette } from './protocol.mjs';
import { validatePalette } from './palette.mjs';
import { KeyboardInput, bindKeyboard } from './input.mjs';
import { InputTransactions, GameplayLoop } from './input-loop.mjs';
import { FramePresentation } from './ui-palette.mjs';
const status = document.querySelector('#status'), button = document.querySelector('#step'), canvas = document.querySelector('#frame');
const proof = window.__transportProof = { ready: false, frames: [], errors: [], inputs: [], fallbackVerified: false };
const fail = error => { status.textContent = error.message; proof.errors.push(error.message); };
const hex = bytes => [...bytes].map(x => x.toString(16).padStart(2, '0')).join('');
let subscription, reconnectTimer, stopped = false, transactions, loop, binding;
try {
  const config = await (await fetch('/config.local.json')).json();
  const genuine = config.rendererKind === 'doom-world-view';
  const gameplay = config.gameplay === true;
  if (genuine) {
    document.title = 'DOOM EVM · Freedoom';
    document.querySelector('.eyebrow').textContent = 'DOOM / running inside the EVM';
    document.querySelector('h1').textContent = 'It runs. In a transaction.';
    document.querySelector('.pill').textContent = gameplay ? 'FREEDOOM E1M1 · GAMEPLAY READY' : 'FREEDOOM E1M1 · STATIC WORLD VIEW';
    document.querySelector('p').textContent = gameplay
      ? 'Start the game, then use WASD or the arrow keys. Shift runs, Ctrl fires, Space or E uses doors, and 1–8 select weapons. Stop pauses input; blur also stops it.'
      : 'Walls, floors, ceilings and sprites rendered by the DOOM port in the EVM. Send a transaction to draw the next frame.';
    canvas.setAttribute('aria-label', gameplay ? 'Freedoom gameplay rendered in the EVM' : 'Freedoom world view rendered in the EVM');
    button.textContent = 'Run DOOM →';
  }
  proof.rendererKind = genuine ? 'doom-world-view' : 'synthetic';
  proof.gameplayAvailable = gameplay;
  proof.nativeZoneAvailable = gameplay && config.nativeZone === true;
  proof.stagedInitialization = gameplay && config.stagedInitialization === true;
  const rpc = makeRpc(config.rpcUrl);
  const palette = await (await fetch(config.paletteUrl)).json();
  const rgb = await validatePalette(palette, config.resourceIdentity, config.paletteKind ?? 'synthetic');
  proof.paletteKind = palette.kind; proof.paletteSha256 = palette.resourceIdentity.paletteSha256;
  let latestBlock = config.deploymentBlock;
  const presentation = new FramePresentation(rpc, rgb, config.productionUI === true, (frame, source, frameRGB, framePalette) => {
    canvas.width = frame.width; canvas.height = frame.height;
    canvas.getContext('2d').putImageData(new ImageData(expandPalette(frame, frameRGB), frame.width, frame.height), 0, 0);
    latestBlock = frame.log.blockNumber;
    proof.frames.push({ frameId: String(frame.frameId), inputSeq: frame.inputSeq, source, transactionHash: frame.log.transactionHash, pixelBytes: frame.pixels.length });
    proof.latestPixelsHex = hex(frame.pixels);
    proof.latestPalette = framePalette ? { revision: framePalette.revision, palette: framePalette.palette,
      gamma: framePalette.gamma, rgbHex: hex(frameRGB) } : null;
    status.textContent = `Frame ${frame.frameId} · input ${frame.inputSeq} · ${frame.width}×${frame.height}\n${frame.pixels.length.toLocaleString()} indexed8 bytes · via ${source}\n${frame.log.transactionHash}`;
  });
  let pendingPresentation = Promise.resolve();
  const inbox = new FrameInbox((frame, source) => {
    pendingPresentation = presentation.present(frame, source);
    pendingPresentation.catch(error => { invalidate(); fail(error); });
  });
  const invalidate = () => { stopped = true; presentation.invalidate(); loop?.stop(); transactions?.invalidate(); button.disabled = true; subscription?.close(); };
  const reconnect = async () => {
    try { await subscription.connect(); await backfill(rpc, config.address, latestBlock, inbox); }
    catch (error) {
      if (error.message.startsWith('Removed Frame')) { invalidate(); fail(error); return; }
      if (!stopped) reconnectTimer = setTimeout(reconnect, 1000);
      status.textContent = error.message;
    }
  };
  subscription = new FrameSubscription(config.wsUrl, config.address, log => inbox.accept(log, 'ws'), error => {
    status.textContent = error.message;
    if (error.message.startsWith('Removed Frame')) { invalidate(); return; }
    if (!stopped) { clearTimeout(reconnectTimer); reconnectTimer = setTimeout(reconnect, 1000); }
  });
  await subscription.connect();
  await backfill(rpc, config.address, config.deploymentBlock, inbox);
  let updateControls = () => {};
  transactions = new InputTransactions(rpc, config, inbox, {
    onState: () => updateControls(),
    onFrame: input => { proof.inputs.push(input); proof.duplicates = inbox.duplicates; },
  });
  await transactions.load();
  proof.gasLimit = transactions.gas; proof.gasBudgetSource = transactions.gasSource;
  const keyboard = new KeyboardInput();
  const nextFrame = async ({ disconnect = false, buttons = 0 } = {}) => {
    if (stopped) throw Error('Session invalidated; reload after checking the local chain');
    if (loop?.running) throw Error('Stop continuous input before a manual step');
    const mined = await transactions.nextFrame(buttons, { beforeSend: disconnect ? () => subscription.close() : undefined });
    await pendingPresentation;
    if (disconnect) {
      proof.fallbackVerified = proof.frames.at(-1).source === 'receipt';
      await subscription.connect();
      proof.backfilled = await backfill(rpc, config.address, config.deploymentBlock, inbox);
    }
    proof.duplicates = inbox.duplicates;
    return mined;
  };
  let startGame;
  if (gameplay) {
    const controls = document.createElement('div');
    const startButton = document.createElement('button'), stopButton = document.createElement('button');
    controls.setAttribute('aria-label', 'Gameplay controls');
    startButton.id = 'game-start'; startButton.type = 'button'; startButton.textContent = 'Start game →';
    stopButton.id = 'game-stop'; stopButton.type = 'button'; stopButton.textContent = 'Stop input'; stopButton.style.marginLeft = '8px';
    controls.append(startButton, stopButton); status.before(controls);
    loop = new GameplayLoop(transactions, keyboard, { onState: () => updateControls(), onError: fail });
    updateControls = () => {
      proof.gameStarted = transactions.started;
      if (config.stagedInitialization === true) proof.resourcesPrepared = transactions.prepared;
      proof.gameplayRunning = loop.running;
      button.disabled = stopped || !transactions.canSend || loop.running || (config.productionUI === true && !transactions.started);
      button.textContent = transactions.started ? 'Step one tic →' : 'Run DOOM →';
      startButton.disabled = stopped || !transactions.canSend || loop.running || loop.starting;
      startButton.textContent = loop.running ? (loop.starting ? 'Starting…' : 'Running…') : transactions.started ? 'Resume game →' : 'Start game →';
      stopButton.disabled = !loop.running && !loop.starting;
    };
    binding = bindKeyboard(window, keyboard, document, {
      enabled: () => loop.running && !stopped,
      onReset: () => loop.stop(),
    });
    // Controlled gates can initialize without launching a timer, then send precise masks.
    // Normal user Start always enters the serialized loop.
    startGame = async ({ run = true } = {}) => {
      if (stopped) throw Error('Session invalidated; reload after checking the local chain');
      if (run) return loop.start();
      if (loop.running) throw Error('Gameplay input is already running');
      keyboard.clear(); await transactions.startGame(); updateControls(); return true;
    };
    startButton.addEventListener('click', () => startGame().catch(fail));
    stopButton.addEventListener('click', () => loop.stop());
  } else {
    updateControls = () => { button.disabled = stopped || !transactions.canSend; };
  }
  window.fixtureClient = { nextFrame, config, inbox, startGame, stopGame: () => loop?.stop(), keyboard, transactions, loop };
  button.addEventListener('click', () => nextFrame().catch(fail)); updateControls(); proof.ready = true;
  status.textContent = gameplay
    ? 'Subscribed. Start gameplay when ready, or render the static view first.'
    : genuine ? 'Subscribed. Send a transaction to render Freedoom.' : 'Subscribed. Send a frame to run the synthetic fixture in the EVM.';
  if (new URLSearchParams(location.search).has('autotest')) {
    // Inherited transport acceptance deliberately stays on its static zero-button path.
    await nextFrame(); await nextFrame({ disconnect: true });
    proof.rgbaSha256 = hex(new Uint8Array(await crypto.subtle.digest('SHA-256', canvas.getContext('2d').getImageData(0, 0, 320, 200).data)));
    proof.done = true;
  }
} catch (error) { loop?.stop(); fail(error); }
window.addEventListener('beforeunload', () => { stopped = true; loop?.stop(); binding?.dispose(); transactions?.invalidate(); clearTimeout(reconnectTimer); subscription?.close(); });
