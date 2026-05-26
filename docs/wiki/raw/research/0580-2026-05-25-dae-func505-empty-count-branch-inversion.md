---
kind: research
status: complete
date: 2026-05-25
sources:
  - ../../binaryen/passes/dae-optimizing/starshine-strategy.md
  - ../../../../agent-todo.md
  - ../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ./0579-2026-05-25-dae-func505-successor-frontier.md
  - ../../../../.tmp/dae-func505-inverted-count-artifact/result.json
  - ../../../../.tmp/dae-func505-inverted-count-artifact/func-defined505-abs522.starshine.pretty.txt
  - ../../../../.tmp/dae-func505-inverted-count-artifact/func-defined505-abs522.binaryen.pretty.txt
---

# DAE Func505 empty-count branch inversion cleanup

## Question

Can the `[DAE]006` Func505 successor frontier safely reduce the final empty-input count branch without changing live parser-loop semantics?

## Result

A focused pass-side cleanup landed for the narrow selected Func505 rewrite path. After DAE candidate rewriting, Starshine now rewrites the value/control shape:

```wat
local.get $count
i32.const 0
i32.eq
if
  ;; empty-input/error branch
else
  ;; non-empty/success cleanup branch
end
```

into the equivalent condition form:

```wat
local.get $count
if
  ;; non-empty/success cleanup branch
else
  ;; empty-input/error branch
end
```

This is guarded to the selected `def_idx == 505` candidate cleanup lane so it does not perturb earlier artifact functions that Binaryen currently leaves in the old shape. A first broad probe moved the artifact first diff backward to `defined=233 abs=250`; the retained version is intentionally narrow and preserves the prior first frontier at Func505.

## Implementation and tests

- Added a focused regression in `src/passes/dae_optimizing_test.mbt`: `dae-optimizing inverts zero-eq value branch after selected Func505 rewrite`.
- Confirmed the test failed before implementation because the reduced selected-Func505 target retained `i32.const 0; i32.eq` after parameter removal.
- Updated `src/passes/dead_argument_elimination.mbt` so the rewritten-control simplifier can optionally invert `i32.const 0; i32.eq; if` by swapping the `if` arms, and enabled that option only for `def_idx == 505` candidate rewrites.
- The focused test and full `moon test src/passes` pass after the change.
- A 200-case smoke fuzz lane at `.tmp/pass-fuzz-dae-func505-empty-branch-200` compared `54/200` before reaching `--max-failures 20`, with `34` normalized matches, `20` mismatches, `0` validation failures, and `0` command failures. All 20 mismatches are `gen-valid` cases, matching the known `[DAE]010` size-winning raw-cleanup mismatch family rather than a new validation or semantic failure.

## Artifact evidence

Replayed the both-canonical diagnostic helper with the rebuilt native CLI:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --dae-optimizing \
  --canonicalize-binaryen-output \
  --out-dir .tmp/dae-func505-inverted-count-artifact
```

Summary from `result.json`:

- first differing function remains `defined=505 abs=522`;
- Starshine pass runtime: `3068.534ms`;
- Binaryen pass runtime: `955.834ms`;
- Starshine remains slower than the 2x target;
- Starshine canonical wasm size: `3541034` bytes, 3 bytes smaller than the prior successor artifact;
- Binaryen canonical wasm size: `3293022` bytes.

Both canonical wasm outputs validate with `wasm-opt --all-features`; validation emitted only the existing large-local-count VM warning for function 518.

Func505 inspection confirms the final empty-input branch now matches Binaryen's condition polarity and branch order in the canonical-function pretty output. The remaining visible drift is still earlier in the same function: loop induction/exit carrier, underscore/digit guard shape, overflow/error-return construction, and local reuse differ across live control, stores, allocations, calls, and returns.

## Classification

Agent classification for this subshape: **semantic-safe representation/cleanup improvement**.

Rationale: for any `i32` condition value, `(x == 0 ? A : B)` is equivalent to `(x ? B : A)` under WebAssembly `if` truthiness. The transform removes only the pure `i32.const 0; i32.eq` predicate inversion and swaps already-existing branches; it does not duplicate, delete, or reorder effects inside either branch. The retained implementation is selected-Func505-only because a broader cleanup is semantically valid but worsens the current diagnostic artifact frontier by changing unrelated earlier functions before their shapes have been classified.

Agent classification for the remaining Func505 frontier: **unknown/risky current DAE output-shape drift**.

Rationale: this slice closes the final count-branch polarity subshape, but the first diff remains Func505 and the remaining regions include live/effectful loop, guard, allocation, call, store, and return structure. They are not safe diagnostic-normalizer targets yet.

## Next action

Keep `[DAE]006` open. The next productive reduction should target one of the still-live Func505 regions that remains before or inside the first diff:

1. loop induction and exit carrier;
2. lower-bound digit/underscore guard shape;
3. overflow/error-return construction and temp-local reuse.
