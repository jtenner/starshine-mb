# DAEO forwarded-cycle precompute refinement

Date: 2026-07-14

## Scope

This bounded follow-up implements the reusable constant-anchored forwarded-parameter transaction, replays it on the current direct artifact, and retains one measured source-backed cycle-neighborhood refinement. It does **not** claim that the Func `7007..7010` parameter gap is closed.

## Binaryen source contract

Binaryen v130's DAE repeatedly scans current calls, applies constant values, removes newly unused parameters, and—only for `dae-optimizing`—runs `OptUtils::optimizeAfterInlining(...)` on functions changed during the iteration before rescanning. `ParamUtils::applyConstantValues(...)` itself accepts only constant expressions or immutable globals; it does not treat arbitrary `local.get` or computed local carriers as constants.

Sources:

- [`DeadArgumentElimination.cpp`](https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/DeadArgumentElimination.cpp), especially the converging iteration, `applyConstantValues`, and optimizing-only `optimizeAfterInlining` scheduling;
- [`param-utils.cpp`](https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/param-utils.cpp), especially `applyConstantValues`;
- [`possible-constant.h`](https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/possible-constant.h), which defines the literal/immutable-global constant boundary.

## Retained generic behavior

The new optimizing-only machinery:

1. starts from current DAE-touched definitions plus the already selected broad adjacent pair;
2. follows parameter-position dependencies only through exact single-instruction `local.get` actuals, with a guarded suffix fallback when every later call operand is independently one `[] -> [value]` instruction;
3. records the exact backedge cycle rather than a direct-callee reachability closure;
4. runs `precompute-propagate-prefix` only on those cycle-member definitions;
5. rescans current call facts and applies a constant-anchored cycle transaction only when every participating actual is an identical materializable literal or another proven parameter dependency;
6. rewrites all participating callsites, callee bodies, local maps, and signatures atomically, rejecting conflicts, writes, exports/`ref.func` escapes, tail calls, malformed slices, localized/effectful removals, count drift, and partial application.

Plain `dead-argument-elimination` does not schedule either the cycle precompute or the transaction. No artifact function index is hardcoded.

Focused coverage includes:

- a successful two-function constant-anchored transaction;
- exact unanchored-cycle precompute without parameter removal;
- conflicting literal anchors;
- parameter writes;
- exported/escaped participants.

## Artifact replay

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Fresh explicit native binary:

```text
_build/native/release/build/cmd/cmd.exe
```

The dependency walk identifies the exact forwarded-reference cycle members `7007`, `7008`, and `7010` and emits:

```text
pass[dae-optimizing]:forwarded-param-cycle-precompute defs=[7007, 7008, 7010]
```

The targeted prefix cleanup removes redundant local-copy/dead-value debris in Func `7010`. The output validates under `wasm-tools validate --features all`.

| dimension | note 1602 | retained cycle precompute | Binaryen v130 | retained delta vs Binaryen |
|---|---:|---:|---:|---:|
| raw wasm | `3197420` | `3197404` | `3177421` | `+19983` |
| canonical wasm (`wasm-opt v130 --strip-debug`) | `3274877` | `3274861` | `3262456` | `+12405` |
| DAEO pass-local | `13234.748ms` | `13838.931ms` | `8538.02ms` | `1.62x` |

This is a measured `-16` raw / `-16` canonical Starshine size win with valid output and pass-local time still inside the required `<=2x` Binaryen bound. It is retained.

## Remaining blocker

The constant-anchored transaction intentionally does not fire on the artifact. The removable `i32` chain reaches Func `7010` through Func `7007` body locals such as the observed `local.set 391; ... local.get 391; call 7031` family. Those values are computed call results, not literal/immutable-global constants and not exact forwarded parameter `local.get`s. Treating them as equal to the cycle anchor would exceed Binaryen v130's `PossibleConstantValues` contract and would be unsound without a separate value proof.

Therefore the remaining Func `7007..7010` signature difference stays an open parity gap. The next slice should attribute which optimizing-after-inlining subpass exposes Binaryen's zero actuals at those computed local carriers, or derive an equivalent source-backed local-value proof. It must not widen to reachability-selected definitions or assume computed recursive actuals equal the external anchor.

## Validation for this slice

- `moon info`;
- focused `src/passes/dae_optimizing_test.mbt`: `319/319`;
- native release `src/cmd` build;
- direct artifact replay and `wasm-tools validate --features all`;
- Binaryen v130 strip-debug canonical size comparison;
- source/diff review and `git diff --check` before commit.
