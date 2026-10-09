// Shared local execution policy. Compiler settings and memory/code limits are independent.
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const defaultPath = fileURLToPath(new URL('../execution-budget.json', import.meta.url));

export function loadGasBudget({env = process.env, configPath = defaultPath} = {}) {
  const config = JSON.parse(readFileSync(configPath, 'utf8'));
  if (config.schemaVersion !== 1) throw Error('Unsupported execution budget schema');
  const source = env.DOOM_GAS_LIMIT !== undefined ? 'DOOM_GAS_LIMIT'
    : env.FOUNDRY_GAS_LIMIT !== undefined ? 'FOUNDRY_GAS_LIMIT' : configPath;
  const raw = env.DOOM_GAS_LIMIT ?? env.FOUNDRY_GAS_LIMIT ?? config.gasLimit;
  if (!/^(?:[1-9]\d*|0x[\da-f]+)$/i.test(String(raw))) throw Error('Gas limit must be a positive integer');
  const value = BigInt(raw);
  if (value <= 0n || value > BigInt(Number.MAX_SAFE_INTEGER)) throw Error('Gas limit exceeds exact metric range');
  return {gasLimit: Number(value), gasHex: '0x' + value.toString(16), source};
}

export function executionEnv(env = process.env) {
  const {gasLimit} = loadGasBudget({env});
  return {...env, DOOM_GAS_LIMIT: String(gasLimit), FOUNDRY_GAS_LIMIT: String(gasLimit)};
}
