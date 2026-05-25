---
kind: research
status: working
date: 2026-05-25
sources:
  - ../../binaryen/passes/dae-optimizing/starshine-strategy.md
  - ../../../../agent-todo.md
  - ../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ../../../../.tmp/dae-func505-default-zero-guard-artifact/starshine.raw.wasm
  - ../../../../.tmp/dae-func505-default-zero-direct.stderr
---

# DAE Func505 default-zero high-guard cleanup

## Question

Continue `[DAE]006` from the Func505 reduction by verifying the suspicious high-bound guard carrier and landing the smallest safe pass-side cleanup.

## Finding

The printed `i32.gt_s (local.get $5) (i32.const 57)` in the post-DAE Func505 artifact is not a newly introduced DAE correctness bug. The original debug artifact body has the same shape before DAE as `local.get (Local 6) ... i32.gt_s`, and that local has no writes in the function body. After DAE removes one parameter, the local is renumbered to `$5`. It therefore reads the WebAssembly default-zero local value, so the `0 > 57` high-bound branch is always false.

This makes the high-bound guard a safe cleanup target, not a semantic repair target. The cleanup is intentionally narrow: after DAE rewrites a callee, it records written locals and rewrites only a value-producing `if` whose `then` is `i32.const 1` and whose `else` is exactly `local.get <unwritten non-param>; i32.const 57; i32.gt_s` to use `i32.const 0` for the else arm. It preserves the lower-bound condition, calls, loads, stores, returns, trapping operations, and all written or parameter locals.

## Implementation and tests

- Added focused coverage to `src/passes/dae_optimizing_test.mbt` in `dae-optimizing materializes selected Func505 literal actual`; it first failed because the reduced target kept the dead `i32.gt_s` high guard after selected Func505 exact-literal materialization.
- Implemented recursive written-local collection and default-zero high-guard simplification in `src/passes/dead_argument_elimination.mbt`, applied between local-index rewriting and the existing rewritten-control/add-zero cleanup in DAE candidate rewriting.
- The focused test now passes and asserts the selected Func505 target keeps the live `local.tee` / `i32.lt_s` lower-bound condition while removing `i32.gt_s`.
- A 200-case smoke fuzz lane at `.tmp/pass-fuzz-dae-func505-guard-200` compared `45/200` before hitting `--max-failures 20`: `26` normalized matches, `19` known-shape normalized mismatches, `0` validation failures, and `1` Binaryen/tool command failure (`binaryen-rec-group-zero`). Agent classification for the mismatches is unchanged from `[DAE]010`: size-winning semantic-safe raw-cleanup drift in `gen-valid` cases; the apparent `wasm-smith` failure directory is the Binaryen parser command failure, not a semantic mismatch.

## Artifact evidence

- Attempted both-canonical artifact replay:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --dae-optimizing \
  --canonicalize-binaryen-output \
  --out-dir .tmp/dae-func505-default-zero-guard-artifact
```

The command timed out after 600s during compare/reporting, but it produced both Starshine and Binaryen wasm outputs. Both validated with `wasm-opt --all-features`; validation emitted only the existing large-local-count VM warning for function 518.

- Direct Starshine replay validated and reported pass-local timing:

```sh
target/native/release/build/cmd/cmd.exe --tracing pass --dae-optimizing \
  --out .tmp/dae-func505-default-zero-direct.wasm \
  tests/node/dist/starshine-debug-wasi.wasm
wasm-opt --all-features .tmp/dae-func505-default-zero-direct.wasm \
  -o /tmp/dae-func505-default-zero-direct.validated.wasm
```

The trace reports `pass:dae-optimizing elapsed_us=3444026`. Compared to the previous Binaryen pass-local timing of `896.944ms` in `.tmp/dae-func504-tail-control-artifact`, this remains over the 2x target, so `[DAE]011` remains open.

- Printing Func505 from the new Starshine raw artifact shows the targeted high guard is gone: `local.get (Local 5)`, `i32.gt_s`, and `I32(57)` counts are zero in that reduced guard region, while the live lower-bound `i32.lt_s` remains.

## Classification

Agent classification: **semantic-safe, representation/cleanup improvement for the inspected Func505 high-bound guard subshape**.

Rationale: the removed high-bound branch read an unwritten non-parameter local whose WebAssembly default value is zero, and the comparison was exactly signed `0 > 57`, which is false. The cleanup does not remove or reorder effectful operations and is guarded against parameters and written locals.

The broader Func505 frontier is not fully closed by this slice because the full both-canonical compare timed out before producing a new first-diff report, and Func505 still has other local/control/debris differences. The next `[DAE]006` run should rerun a bounded artifact comparison or a more targeted Func505 extraction to determine whether this cleanup advances the first frontier.
