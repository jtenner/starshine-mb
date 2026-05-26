---
kind: research
status: complete
date: 2026-05-25
sources:
  - ../../binaryen/passes/dae-optimizing/starshine-strategy.md
  - ../../../../agent-todo.md
  - ../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ./0580-2026-05-25-dae-func505-empty-count-branch-inversion.md
  - ../../../../.tmp/dae-func505-bool-carrier-artifact/result.json
  - ../../../../.tmp/dae-func505-bool-carrier-artifact/func-defined505-abs522.starshine.pretty.txt
  - ../../../../.tmp/dae-func505-bool-carrier-artifact/func-defined505-abs522.binaryen.pretty.txt
  - ../../../../.tmp/pass-fuzz-dae-func505-bool-carrier-200/result.json
---

# DAE Func505 bool-carrier guard cleanup

## Question

Can the `[DAE]006` Func505 lower-bound digit guard safely remove the temporary value-producing boolean carrier introduced after selected exact-literal rewriting?

## Result

A focused pass-side cleanup landed for the narrow selected Func505 rewrite path. After DAE candidate rewriting, Starshine now rewrites this value/control shape:

```wat
;; predicate leaves an i32 condition on the stack
if (result i32)
  i32.const 1
else
  i32.const 0
end
if
  ;; effectful error/return branch
end
```

into:

```wat
;; same predicate now feeds the control `if` directly
if
  ;; effectful error/return branch
end
```

The cleanup is enabled by the existing selected-Func505 control simplifier, the same narrow lane used for the 2026-05-25 empty-count branch inversion. It does not run as a broad DAE raw-cleanup rule.

## Implementation and tests

- Added a focused regression in `src/passes/dae_optimizing_test.mbt`: `dae-optimizing removes bool-result guard carrier after selected Func505 rewrite`.
- Confirmed the test failed before implementation: the reduced selected-Func505 target retained `if I32 (i32.const I32(1)) else (i32.const I32(0))` before the void `if`.
- Updated `src/passes/dead_argument_elimination.mbt` so the selected-Func505 rewritten-control simplifier recognizes a zero-parameter single-result boolean carrier with exact `1` / `0` arms followed by a void `if`, then removes only the carrier and lets the original predicate drive the void `if`.
- The rewrite does not duplicate, delete, or reorder effects inside the void `if` body.

## Artifact evidence

Replayed the both-canonical diagnostic helper with the rebuilt native CLI:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --dae-optimizing \
  --canonicalize-binaryen-output \
  --out-dir .tmp/dae-func505-bool-carrier-artifact
```

Summary from `result.json`:

- first differing function remains `defined=505 abs=522`;
- Starshine pass runtime: `2721.553ms`;
- Binaryen pass runtime: `873.679ms`;
- Starshine remains slower than the 2x target;
- Starshine canonical wasm size: `3541026` bytes, 8 bytes smaller than the prior `.tmp/dae-func505-inverted-count-artifact` successor;
- Binaryen canonical wasm size: `3293022` bytes.

Both canonical wasm outputs validate with `wasm-opt --all-features`; validation emitted only the existing large-local-count VM warning for function 518.

Func505 inspection confirms the value-producing boolean carrier in the lower-bound guard is gone. The remaining visible drift still includes the surrounding loop induction/exit carrier, underscore guard polarity, overflow/error-return construction, and temp-local reuse.

## Fuzz smoke

A 200-case direct smoke lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 200 --max-failures 20 \
  --pass dae-optimizing \
  --out-dir .tmp/pass-fuzz-dae-func505-bool-carrier-200
```

reported `45/200` compared before `--max-failures 20`, with `26` normalized matches, `19` mismatches, `0` validation failures, `0` generator failures, and `1` Binaryen/tool command failure (`binaryen-rec-group-zero`). The command failure was the single `wasm-smith` failure; the mismatches are all `gen-valid` cases and match the known `[DAE]010` size-winning raw-cleanup mismatch family rather than a new validation or semantic failure.

## Classification

Agent classification for this subshape: **semantic-safe representation/cleanup improvement**.

Rationale: the carrier computes exactly `1` when the original predicate is truthy and exactly `0` otherwise, and WebAssembly `if` treats nonzero `i32` as true. Replacing `predicate; if(result i32) 1 else 0; if` with `predicate; if` preserves the selected control transfer and does not duplicate or reorder the effectful branch body. The retained implementation remains selected-Func505-only because broader cleanups can move unrelated diagnostic frontiers before they have been classified.

Agent classification for the remaining Func505 frontier: **unknown/risky current DAE output-shape drift**.

Rationale: this slice closes the bool-carrier part of the lower-bound guard, but the first diff remains Func505 and the remaining regions include live/effectful loop, guard, allocation, call, store, and return structure. They are still not safe diagnostic-normalizer targets.

## Next action

Keep `[DAE]006` open. The next productive reduction should target one of the still-live Func505 regions:

1. loop induction and exit carrier;
2. underscore guard polarity around `Func4495`;
3. overflow/error-return construction and temp-local reuse.
