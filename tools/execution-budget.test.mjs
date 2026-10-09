import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {loadGasBudget,executionEnv} from './execution-budget.mjs';

test('shared policy defaults to10B and agrees with direct Forge fallback', () => {
  const config=JSON.parse(readFileSync('execution-budget.json','utf8'));
  const budget=loadGasBudget({env:{}});
  assert.equal(budget.gasLimit,config.gasLimit);
  assert.equal(budget.gasLimit,10000000000);
  assert.equal(budget.gasHex,'0x2540be400');
  const foundry=readFileSync('foundry.toml','utf8').match(/^gas_limit\s*=\s*(\d+)$/m);
  assert.equal(Number(foundry[1]),config.gasLimit);
});

test('explicit DOOM override wins and child Forge/Node policy is normalized', () => {
  const env={DOOM_GAS_LIMIT:'0x2cb417800',FOUNDRY_GAS_LIMIT:'1000000000',KEEP:'yes'};
  assert.equal(loadGasBudget({env}).gasLimit,12000000000);
  const child=executionEnv(env);
  assert.equal(child.DOOM_GAS_LIMIT,'12000000000');
  assert.equal(child.FOUNDRY_GAS_LIMIT,child.DOOM_GAS_LIMIT);
  assert.equal(child.KEEP,'yes');
  assert.equal(loadGasBudget({env:{FOUNDRY_GAS_LIMIT:'20000000000'}}).gasLimit,20000000000);
});

test('Python and Node agree for defaults, higher and historical overrides', () => {
  const code="import json,sys; from scripts.execution_budget import load_gas_budget; print(json.dumps(load_gas_budget(json.loads(sys.argv[1]))))";
  for(const env of [{},{DOOM_GAS_LIMIT:'20000000000'},{DOOM_GAS_LIMIT:'0x3b9aca00'},{FOUNDRY_GAS_LIMIT:'12000000000'}]) {
    const python=JSON.parse(execFileSync('python3',['-c',code,JSON.stringify(env)],{encoding:'utf8'}));
    assert.deepEqual(python,loadGasBudget({env}));
  }
});

test('malformed, zero, fractional and inexact budgets fail before execution', () => {
  const code="import json,sys; from scripts.execution_budget import load_gas_budget; load_gas_budget(json.loads(sys.argv[1]))";
  for(const value of ['0','-1','1.5','1e10','NaN','10B','9007199254740992','0x0']) {
    const env={DOOM_GAS_LIMIT:value};
    assert.throws(()=>loadGasBudget({env}));
    assert.throws(()=>execFileSync('python3',['-c',code,JSON.stringify(env)],{stdio:'pipe'}));
  }
});

test('shell setup propagates one override in both Bash and Zsh', () => {
  const code='source scripts/env.sh\nprintf "%s/%s" "$DOOM_GAS_LIMIT" "$FOUNDRY_GAS_LIMIT"';
  for(const shell of ['/bin/bash','/bin/zsh']) {
    assert.equal(execFileSync(shell,['-c',code],{env:{...process.env,DOOM_GAS_LIMIT:'12000000000'},encoding:'utf8'}),'12000000000/12000000000');
  }
});
