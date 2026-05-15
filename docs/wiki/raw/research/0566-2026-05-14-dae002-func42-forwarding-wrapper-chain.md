# DAE002 Func 42 is blocked by a forwarding-wrapper chain, not by direct shape recovery

Date: 2026-05-14

## Question

After moving the live `--dae-optimizing` artifact frontier from Func 28 to `defined=25 abs=42`, is Func 42 another direct exact-literal miss, another shape-recovery family, or a later chain unlocked only after other rewrites?

## Answer

It is a later forwarding-wrapper chain.

Func 42 is **not** directly exact-literal rewritable on the original debug artifact, even though all callsite shapes are recoverable.
The blocking middle actual is a forwarded local, not a literal.

## Whitebox evidence

Added/updated characterization in `src/passes/pass_manager_wbtest.mbt`.

### Current frontier facts

- The first two productive DAE core rewrites on the original artifact are still:
  - `[11, 227]`
- So the current core does **not** reach Func 42 early just because Func 28 is fixed.
- Even after `64` repeated `dae_run_core_once(...)` iterations in whitebox replay, Func 42 still reports:
  - `Some([None, None, None])`
  for `dae_collect_uniform_const_actuals(...)`.

### Func 42 direct state

For original artifact Func 42 (`defined=25 abs=42`):

- `pass_manager_test_first_shape_failure(...) == None`
- `dae_collect_uniform_const_actuals(...) == Some([None, None, None])`
- the first non-constant middle actual is:
  - caller `abs=4559`
  - actual slice `[local.get 1]`

So this is **not** another ambient-entry / typed-block / repeated-call shape-recovery issue.
The callsite slice is recoverable; the value is just not yet literal.

## Chain characterization

The blocker is a wrapper chain:

- Func 4558 is already directly exact-literal rewritable on the original artifact:
  - `dae_collect_uniform_const_actuals(..., callee_abs=4558, ...)`
    returns `Some([None, Some(i32.const 0), None])`
- After rewriting Func 4558, Func 4559 becomes directly rewritable.
- After rewriting Func 4558 and then Func 4559, Func 42 becomes directly exact-literal rewritable.

So the dependency is:

- `4558 -> 4559 -> 42`

with Func 42 blocked by forwarded middle-param locals until the higher-index wrappers are reduced first.

## Interpretation

This reattributes the remaining Func 42 gap more precisely:

- not another direct-call shape recovery failure,
- not another missed mechanical rewrite when targeted directly,
- not solved by just letting the current low-to-high core replay for a few dozen more iterations in whitebox,
- but instead a **high-index forwarding-wrapper chain** whose earlier wrappers must fall before the low-index callee sees uniform literal actuals.

## Consequence for the next fix

A naive broad reverse exact-literal sweep was tested locally during investigation and immediately broke existing self-call/dead-suffix regressions, so that lane is not safe to land as-is.

The next safe slice should stay narrow and preserve current dead-suffix/self-call invariants while targeting the wrapper-chain family specifically.
Likely safe directions are:

1. a guarded wrapper-chain follow-up that reuses existing DAE safety conditions, or
2. a more surgical caller-forwarding propagation rule for exact-literal analysis.

Do **not** overclaim Func 42 as a simple iteration-cap problem.
The stronger statement supported here is only that the live blocker is a forwarding-wrapper chain headed by Func 4558/4559.

## Validation used

- `moon test src/passes`
- `moon build src/cmd --release`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/dae002-func42-wrapper-chain-artifact --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing`

## Current artifact status

- compare dir: `.tmp/dae002-func42-wrapper-chain-artifact`
- first diff remains: `defined=25 abs=42`
- Starshine pass runtime: `19796.658ms`
- Binaryen pass runtime: `951.761ms`
