---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ./index.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/pick_load_signs.mbt
  - ../../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./parity.md
  - ./starshine-hot-ir-strategy.md
  - ./fuzzing.md
---

# Starshine strategy for `pick-load-signs`

## Status

`pick-load-signs` is an active hot/function pass and is closed at Binaryen-v131-or-better behavior parity.

The descriptor requires `use_def`; mutation invalidates CFG, dominance, liveness, use-def, effects, loop info, and SSA. The public preset places PLS before `precompute`.

## Code map

- `src/passes/pick_load_signs.mbt`
  - HOT candidate discovery, all-use evidence analysis, signed-weighted choice, load rewrite, and redundant-evidence deletion.
- `src/passes/pass_manager.mbt`
  - module no-memory skip, raw no-candidate skip, exact simple-shape rewrites, and hot-pass dispatch.
- `src/passes/pick_load_signs_test.mbt`
  - focused upstream-common transforms/bailouts plus every retained width/family cleanup shape and fail-closed source tests.
- `src/passes/perf_test.mbt`
  - raw no-lift and zero-HOT-allocation tests.
- `src/validate/gen_valid.mbt` and `gen_valid_tests.mbt`
  - repaired `pick-load-signs-all` aggregate and width-complete generated shapes.

## HOT strategy

The HOT path:

1. scans exact `LocalSet(Load(...))` writes;
2. gathers every local read and use site from use-def;
3. classifies signed, unsigned, or unknown evidence;
4. applies width agreement and `signed * 2 >= unsigned` selection;
5. rewrites matching load opcodes;
6. removes retained Starshine-only extension expressions only when every possible source is a matching final load.

Evidence deletion is fail-closed for parameters, non-load writes, mixed widths, mismatched final signedness, and locals where no load changes.

## Raw strategy

Exact straight-line direct-extension, mask, and shift-pair forms are rewritten before HOT lift. Upstream-common i32 forms preserve Binaryen's direct-pass shape; retained Starshine families also remove the now-redundant extension expression.

The raw path is both a size and speed feature:

- no HOT node allocation or use-def construction for exact generated shapes;
- representative 2,000-function workloads are faster than Binaryen v131;
- focused perf tests require `node_allocs=0` and no lift/use-def timer for those forms.

## Retained broader behavior

Binaryen v131 is i32-only, recognizes no unsigned shift pair, and requires masks on the right. Starshine retains commuted i32 masks, i32 unsigned shifts, and i64 direct/mask/shift evidence because every retained form now has:

- a source-completeness proof;
- focused TDD coverage;
- GenValid coverage;
- negative-value runtime equality;
- smaller canonical direct-pass output;
- performance within, and on the representative exact workloads better than, the repository target.

See [`./parity.md`](./parity.md) for measured deltas and [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) for implementation details.
