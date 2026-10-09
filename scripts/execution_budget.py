"""Shared configurable local gas policy; no compiler/memory/code-limit changes."""
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / 'execution-budget.json'
MAX_EXACT_METRIC = 2**53 - 1


def load_gas_budget(env=None, config_path=CONFIG):
    env = os.environ if env is None else env
    config = json.loads(Path(config_path).read_text())
    if config.get('schemaVersion') != 1:
        raise ValueError('Unsupported execution budget schema')
    import re
    source = 'DOOM_GAS_LIMIT' if 'DOOM_GAS_LIMIT' in env else (
        'FOUNDRY_GAS_LIMIT' if 'FOUNDRY_GAS_LIMIT' in env else str(config_path))
    raw = env.get('DOOM_GAS_LIMIT', env.get('FOUNDRY_GAS_LIMIT', config.get('gasLimit')))
    if isinstance(raw, float) and raw.is_integer():
        raw = int(raw)
    if not re.fullmatch(r'(?:[1-9]\d*|0x[\da-f]+)', str(raw), re.IGNORECASE):
        raise ValueError('Gas limit must be a positive integer')
    value = int(str(raw), 16 if str(raw).lower().startswith('0x') else 10)
    if not 0 < value <= MAX_EXACT_METRIC:
        raise ValueError('Gas limit exceeds exact metric range')
    return {'gasLimit': value, 'gasHex': hex(value), 'source': source}


def execution_env(env=None):
    env = dict(os.environ if env is None else env)
    gas = str(load_gas_budget(env)['gasLimit'])
    return dict(env, DOOM_GAS_LIMIT=gas, FOUNDRY_GAS_LIMIT=gas)


if __name__ == '__main__':
    print(load_gas_budget()['gasLimit'])
