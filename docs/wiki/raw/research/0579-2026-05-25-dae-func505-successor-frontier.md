---
kind: research
status: complete
date: 2026-05-25
sources:
  - ../../binaryen/passes/dae-optimizing/starshine-strategy.md
  - ../../../../agent-todo.md
  - ./0576-2026-05-25-dae-func505-frontier-classification.md
  - ./0577-2026-05-25-dae-func505-reduction-attribution.md
  - ./0578-2026-05-25-dae-func505-default-zero-guard-cleanup.md
  - ../../../../.tmp/dae-func505-recovery-artifact/result.json
  - ../../../../.tmp/dae-func505-recovery-artifact/func-defined505-abs522.starshine.pretty.txt
  - ../../../../.tmp/dae-func505-recovery-artifact/func-defined505-abs522.binaryen.pretty.txt
---

# DAE Func505 successor frontier after default-zero cleanup

## Question

After the focused default-zero high-guard cleanup from research note `0578`, does the both-canonical debug-artifact comparison advance past Func505, and if not, what is the next safe classification?

## Result

The both-canonical diagnostic comparison now completes, but the first differing function is still `defined=505 abs=522` in `.tmp/dae-func505-recovery-artifact`.

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --dae-optimizing \
  --canonicalize-binaryen-output \
  --out-dir .tmp/dae-func505-recovery-artifact
```

Summary from `result.json`:

- canonicalize Binaryen output: yes
- first differing function: `defined=505 abs=522`
- Starshine pass runtime: `3264.383ms`
- Binaryen pass runtime: `1033.990ms`
- Starshine pass is still slower than the 2x target
- Starshine canonical wasm size: `3541037`
- Binaryen canonical wasm size: `3293022`

Both produced canonical wasm outputs validate with `wasm-opt --all-features`; validation emitted only the existing large-local-count VM warning for function 518.

## Inspection

The focused high-bound guard from `0578` is no longer the leading suspicious subshape: Starshine now prints the false high-bound branch as `ifI32(i32.const 1) else (i32.const 0)` around the lower-bound digit check, rather than carrying the earlier `local.get $5; i32.const 57; i32.gt_s` default-zero comparison.

The remaining Func505 drift is broader and still live:

- loop induction and exit shape differ: Starshine keeps an explicit `i32.const 0; local.tee` induction carrier and later `local.get; i32.const 1; i32.add`, while Binaryen prints a tighter induction/control shape;
- the underscore/digit guard region is not a pure wrapper-only difference: Binaryen combines the digit check as unsigned `< 48` after the underscore rejection, while Starshine still has a value-producing lower-bound `if` feeding a later branch;
- overflow/error-return construction and local reuse differ substantially across side-effecting calls to `Func45`, `Func4211`, `Func41`, and allocator `Func24`;
- the final empty-input branch is inverted/reordered: Starshine keeps an explicit `i32.eq` test and then/else order, while Binaryen uses the loaded count directly with the opposite branch order.

These differences preserve similar parser-loop intent, but the affected regions include live control, stores, allocations, calls, and returns. This is not safe to erase with a diagnostic normalizer from the current evidence.

## Classification

Agent classification: **unknown/risky current DAE output-shape drift** for the remaining Func505 frontier.

Rationale: the one proven semantic-safe subshape from `0578` is cleaned up, but the successor artifact still differs in live loop/control and effectful error-construction regions. The evidence does not prove a representation-only relation, and no smaller focused regression has isolated a safe additional rewrite yet.

## Next action

Keep `[DAE]006` open. The next productive slice should reduce one of the remaining Func505 live regions before changing pass logic or compare tooling:

1. reduce the loop induction/exit carrier around the `0 .. len` parser loop;
2. reduce the lower-bound digit guard now that the high-bound default-zero guard is gone;
3. reduce the final empty-input count branch inversion/reordering;
4. only after a focused fixture proves equivalence, add either a pass-side cleanup or a diagnostic-only normalizer.
