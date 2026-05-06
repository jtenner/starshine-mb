---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0543-2026-05-06-slns-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md
  - ../../../raw/research/0433-2026-05-04-simplify-locals-nostructure-current-main-recheck.md
  - ../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md
  - ../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tuple-optimization/index.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nonesting/index.md
  - ../reorder-locals/index.md
  - ../coalesce-locals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./variant-surface.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../tuple-optimization/index.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nonesting/index.md
  - ../reorder-locals/index.md
  - ../coalesce-locals/index.md
---

# Starshine `simplify-locals-nostructure` port readiness and validation

## Why this page exists

The landing, strategy, variant, and WAT-shape pages explain what Binaryen does.
This page answers the follow-along question:

- what is the smallest honest local slice?
- what must stay disabled so the sibling does not become full `simplify-locals`?
- what tests and oracle lanes prove the no-structure contract?

## Current hold point

The direct pass is landed. Starshine now treats `simplify-locals-nostructure` as an active hot pass, and also accepts the local compatibility spelling `simplify-locals-no-structure`.

Current state:

- upstream Binaryen spelling: `simplify-locals-nostructure`
- local alias: `simplify-locals-no-structure`
- local category: active hot pass
- CLI / pipeline behavior: runnable direct pass
- owner: `src/passes/simplify_locals.mbt`
- preset role: still omitted from `optimize` / `shrink` until ordered-neighborhood replay proves the slot

## Exact local code map today

- `src/passes/optimize.mbt`
  - active hot entries for `simplify-locals-nostructure` and `simplify-locals-no-structure`
  - `tuple_optimization_exact_slot_prereqs_ready()` now sees the no-structure neighbor as active
  - public presets remain conservative pending ordered replay
- `src/passes/simplify_locals.mbt`
  - owns the no-structure descriptors and alias descriptor
  - runs the shared local-sink/dead-cleanup cycles with structure-result rewrites disabled
- `src/passes/pass_manager.mbt`
  - dispatches both spellings to `simplify_locals_nostructure_run(...)`
  - shares the raw simplify-locals artifact skip/rewrite gates and writeback validation guards
- `src/passes/simplify_locals_nostructure_test.mbt`
  - covers straight-line sinking and the negative guarantee that the pass does not synthesize `if` result structures
- `scripts/lib/pass-fuzz-compare-task.ts` and `scripts/lib/self-optimize-compare-task.ts`
  - accept the canonical flag and compatibility alias, mapping the alias to Binaryen's canonical `--simplify-locals-nostructure` spelling

## Validation evidence

Direct-pass validation on the landed slice:

1. 2026-05-06 refreshed standard signoff:
   - `moon info`
   - `moon fmt`
   - `moon test`
   - `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-simplify-locals-nostructure`
     - `6759/10000` comparable mixed-generator cases
     - `6759` normalized matches
     - `0` mismatches, validation failures, or generator failures
     - `20` Binaryen empty-recursion-group parser/canonicalization command failures
   - `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals-no-structure --out-dir .tmp/pass-fuzz-simplify-locals-no-structure`
     - `6759/10000` comparable mixed-generator cases
     - `6759` normalized matches
     - `0` mismatches, validation failures, or generator failures
     - `20` Binaryen empty-recursion-group parser/canonicalization command failures
2. Earlier landed-slice focused evidence:
   - `moon test src/passes`
   - `moon test src/cmd`
   - `bun scripts/pass-fuzz-compare.ts --starshine-bin _build/native/release/build/cmd/cmd.exe --pass simplify-locals-nostructure --generator gen-valid --count 10000 --seed 0x5eed --min-compared 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-slns-genvalid-10000-after-raw`
     - `10000/10000` compared
     - `10000` normalized matches
     - `0` mismatches, validation failures, generator failures, or command failures
   - `bun scripts/pass-fuzz-compare.ts --starshine-bin _build/native/release/build/cmd/cmd.exe --pass simplify-locals-nostructure --count 10000 --seed 0x5eed --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-slns-10000-keepgoing-after-raw`
     - `9975/10000` comparable mixed-generator cases
     - `9975` normalized matches
     - `0` mismatches
     - `25` Binaryen-side command failures (`binaryen-rec-group-zero`, `binaryen-bad-section-size`, `binaryen-table-index-out-of-range`, `binaryen-invalid-tag-index`)
3. Earlier artifact evidence:
   - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/self-opt-slns-direct-rerun --simplify-locals-nostructure`
     - normalized WAT equal through fallback
     - canonical function compare equal
     - Starshine pass time `325.166ms`; Binaryen pass time `509466.000ms` in this run

## Remaining validation before preset placement

The direct pass is implemented and oracle-checked, but public preset placement still needs ordered-neighborhood proof. Before adding it to `optimize` / `shrink`, replay at least:

- `tuple-optimization -> simplify-locals-nostructure`
- `simplify-locals-nostructure -> vacuum`
- `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals`
- later local-neighborhood chains once `coalesce-locals` and `local-cse` land

Keep those preset claims separate from direct-pass signoff so the tracker can say “implemented” without overstating full no-DWARF / saved-`O4z` preset parity.

## Sources

- [`../../../raw/research/0543-2026-05-06-slns-direct-revalidation.md`](../../../raw/research/0543-2026-05-06-slns-direct-revalidation.md)
- [`../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
- [`../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md)
- [`../../../raw/research/0433-2026-05-04-simplify-locals-nostructure-current-main-recheck.md`](../../../raw/research/0433-2026-05-04-simplify-locals-nostructure-current-main-recheck.md)
- [`../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
- [`../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md`](../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md`](../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- Binaryen `version_129` dedicated tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>
