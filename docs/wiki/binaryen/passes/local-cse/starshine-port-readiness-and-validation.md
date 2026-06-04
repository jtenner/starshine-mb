---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../../../raw/research/0464-2026-05-05-local-cse-port-readiness-and-validation.md
  - ../../../raw/research/0495-2026-05-06-local-cse-current-main-line-anchor-refresh.md
  - ../../../raw/research/0533-2026-05-06-local-cse-direct-revalidation.md
  - ../../../raw/research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md
  - ../../../raw/research/0491-2026-05-05-local-cse-starshine-active-direct-pass-correction.md
  - ../../../raw/binaryen/2026-05-06-local-cse-current-main-line-anchor-refresh.md
  - ../../../raw/binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md
  - ../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md
  - ../../../raw/research/0453-2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/research/0358-2026-04-25-local-cse-current-main-and-test-map.md
  - ../../../raw/research/0262-2026-04-22-local-cse-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/local_cse.mbt
  - ../../../../../src/passes/local_cse_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./basic-block-windows-and-barriers.md
  - ../flatten/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../coalesce-locals/index.md
  - ../simplify-locals/index.md
  - ../reorder-locals/index.md
---

# Starshine Port Readiness And Validation For `local-cse`

This page is the bridge between the upstream source-backed `local-cse` contract and the remaining Starshine ordered-neighborhood claim, now refreshed by the 2026-05-06 line-anchor note and the 2026-06-04 `version_130` / current-main audit refresh.
It does **not** claim exact public preset parity.
It says what is already in-tree, what the nearest landing zone is, and what still needs to be proven before the exact ordered slots are claimed.

For the exact upstream algorithm and source/test map, read:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)

## Current readiness status

Starshine now treats `local-cse` as an active direct pass.
The owner file, direct tests, registry entry, dispatcher route, debug-artifact evidence, and 2026-05-06 refreshed direct-pass fuzz evidence have landed.

The refreshed direct lane in `.tmp/pass-fuzz-local-cse` reached 6759/10000 compared cases with 6759 normalized matches, 0 mismatches, and 20 known Binaryen empty-recursion-group command failures. A later 2026-06-04 O4z audit lane in `.tmp/pass-fuzz-local-cse-audit-1000` reached 998/1000 compared cases with 998 normalized matches, 0 mismatches, and 2 known Binaryen empty-recursion-group command failures. After fixing the before-`if` into `then` missed optimization, `.tmp/pass-fuzz-local-cse-then-arm-fix-10000` reached 6768/10000 compared cases with 6768 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After adding return-boundary coverage, `.tmp/pass-fuzz-local-cse-return-boundary-10000` reached 6771/10000 compared cases with 6771 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After adding `br_table` boundary coverage, `.tmp/pass-fuzz-local-cse-br-table-boundary-10000` reached 6771/10000 compared cases with 6771 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After adding `unreachable` boundary coverage, `.tmp/pass-fuzz-local-cse-unreachable-boundary-10000` reached 6765/10000 compared cases with 6765 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After adding `struct.new` generative-root coverage, `.tmp/pass-fuzz-local-cse-struct-new-generative-10000` reached 6769/10000 compared cases with 6769 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After fixing the simple named-block missed optimization, `.tmp/pass-fuzz-local-cse-named-block-positive-10000` reached 6771/10000 compared cases with 6771 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After adding `struct.new_default` generative-root coverage, `.tmp/pass-fuzz-local-cse-struct-new-default-generative-10000` reached 6764/10000 compared cases with 6764 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After implementing the annotated idempotent direct-call positive, `.tmp/pass-fuzz-local-cse-idempotent-call-10000` reached 6770/10000 compared cases with 6770 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After adding `call_indirect` root coverage, `.tmp/pass-fuzz-local-cse-call-indirect-root-10000` reached 6768/10000 compared cases with 6768 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After adding core-built `call_ref` root coverage, `.tmp/pass-fuzz-local-cse-call-ref-root-10000` reached 6768/10000 compared cases with 6768 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After adding core `array.new` generative-root coverage, `.tmp/pass-fuzz-local-cse-array-new-generative-10000` reached 6770/10000 compared cases with 6770 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After adding core `array.new_default` generative-root coverage, `.tmp/pass-fuzz-local-cse-array-new-default-generative-10000` reached 6768/10000 compared cases with 6768 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After adding core `array.new_fixed` generative-root coverage, `.tmp/pass-fuzz-local-cse-array-new-fixed-generative-10000` reached 6771/10000 compared cases with 6771 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After fixing the `try_table` body positive, `.tmp/pass-fuzz-local-cse-try-table-body-positive-10000` reached 6767/10000 compared cases with 6767 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After adding `try_table` body unreachable-boundary coverage, `.tmp/pass-fuzz-local-cse-try-table-unreachable-boundary-10000` reached 6769/10000 compared cases with 6769 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After adding throw-boundary coverage, `.tmp/pass-fuzz-local-cse-throw-boundary-10000` reached 6769/10000 compared cases with 6769 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After adding `br` boundary coverage, `.tmp/pass-fuzz-local-cse-br-boundary-10000` reached 6770/10000 compared cases with 6770 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After fixing `return_call_indirect` unreachable-continuation reuse, `.tmp/pass-fuzz-local-cse-return-call-indirect-continuation-10000` reached 6765/10000 compared cases with 6765 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After fixing `throw_ref` unreachable-continuation reuse, `.tmp/pass-fuzz-local-cse-throw-ref-continuation-10000` reached 6768/10000 compared cases with 6768 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After fixing core-built `return_call_ref` unreachable-continuation reuse, `.tmp/pass-fuzz-local-cse-return-call-ref-continuation-10000` reached 6771/10000 compared cases with 6771 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After adding core `array.new_data` generative-root coverage, `.tmp/pass-fuzz-local-cse-array-new-data-generative-10000` reached 6767/10000 compared cases with 6767 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After adding core `array.new_elem` generative-root coverage, `.tmp/pass-fuzz-local-cse-array-new-elem-generative-10000` reached 6763/10000 compared cases with 6763 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After fixing direct `return_call` unreachable-continuation reuse, `.tmp/pass-fuzz-local-cse-return-call-continuation-10000` reached 6766/10000 compared cases with 6766 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After fixing `br_on_null` fallthrough-continuation reuse, `.tmp/pass-fuzz-local-cse-br-on-null-continuation-10000` reached 6764/10000 compared cases with 6764 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After fixing `struct.set` local-only reuse, `.tmp/pass-fuzz-local-cse-struct-set-local-only-10000` reached 6769/10000 compared cases with 6769 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After fixing `br_on_non_null` fallthrough-continuation reuse, `.tmp/pass-fuzz-local-cse-br-on-non-null-continuation-10000` reached 6766/10000 compared cases with 6766 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After fixing `array.set` local-only reuse, `.tmp/pass-fuzz-local-cse-array-set-local-only-10000` reached 6768/10000 compared cases with 6768 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After fixing `array.fill` local-only reuse, `.tmp/pass-fuzz-local-cse-array-fill-local-only-10000` reached 6770/10000 compared cases with 6770 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After fixing `br_on_cast` fallthrough-continuation reuse, `.tmp/pass-fuzz-local-cse-br-on-cast-continuation-only-10000` reached 6769/10000 compared cases with 6769 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures. After fixing `br_on_cast_fail` fallthrough-continuation reuse, `.tmp/pass-fuzz-local-cse-br-on-cast-fail-continuation-10000` reached 6766/10000 compared cases with 6766 normalized matches, 0 mismatches, and 20 Binaryen/tool command failures.

The honest remaining state is preset-slot restraint until the missing ordered neighborhoods are representable, plus broader shape-hardening follow-up for remaining hard-control and GC/generative-root variant negatives. Tiny-root repeated `global.get` no-op, repeated `struct.new`, `struct.new_default`, and core `array.new`, `array.new_default`, `array.new_fixed`, `array.new_data`, and `array.new_elem` generative-root no-ops, the annotated idempotent direct-call positive with ordinary direct-call, `call_indirect`, and `call_ref` root negatives, before-`if` / then-arm, before-block / straight-line block, before-`try_table` / try-body, and `return_call` / `return_call_indirect` / `return_call_ref` / `throw_ref` unreachable-continuation positives, `br_on_null` / `br_on_non_null` / `br_on_cast` / `br_on_cast_fail` fallthrough-continuation positives, `struct.set` / `array.set` / `array.fill` local-only reuse positives, and before-loop into loop-body, `br`, `br_table`, `return`, `throw`, top-level `unreachable`, and `try_table` body unreachable-boundary coverage are now durable in the direct test surface. Legacy `rethrow` has Binaryen spot-check evidence as a hard boundary but remains a documented local deferral because valid WAST `rethrow` lowers to `unreachable` and the raw module instruction surface has no distinct `Rethrow` variant.

## What already exists locally

The nearest local surfaces are:

| Surface | Why it matters |
| --- | --- |
| `src/passes/local_cse.mbt:1-18,543-559,809-816` | Active owner file for the direct `local-cse` transform. |
| `src/passes/local_cse_test.mbt` | Direct repeated-tree, parent-cancellation, load/store barrier, local-write, before-`if` / then-arm, before-block / straight-line block, before-`try_table` / try-body, and `return_call` / `return_call_indirect` / `return_call_ref` / `throw_ref` unreachable-continuation positives, `br_on_null` / `br_on_non_null` / `br_on_cast` / `br_on_cast_fail` fallthrough-continuation positives, `struct.set` / `array.set` / `array.fill` local-only reuse positives, annotated idempotent direct-call reuse with ordinary direct-call, `call_indirect`, and core-built `call_ref` root negatives, paired after-`if` / else-arm negative, before-loop into loop-body negative, `br_table` boundary negative, return-boundary negative, unreachable-boundary negative, tiny-root `global.get` no-op, and `struct.new` / `struct.new_default` / core `array.new` / `array.new_default` / `array.new_fixed` / `array.new_data` / `array.new_elem` generative-root no-op tests. |
| `src/passes/optimize.mbt:253,437-449,456-472` | Registers `local-cse` as an active module pass while keeping the exact preset neighborhood gated. |
| `src/passes/pass_manager.mbt:8939-8943` | Dispatches the active `local-cse` module pass. |
| `src/passes/optimize_test.mbt:510-512,520-527,567-568` | Keeps `local-cse` classified as an active module pass in the regression surface. |
| `src/passes/simplify_locals.mbt` | Already models local effect/conflict checks and cleanup behavior close to the pass's safety questions. |
| `src/passes/reorder_locals.mbt` | Already handles local-index rewriting and is the closest landed example of temp-local bookkeeping work. |
| `src/cmd/cmd_wbtest.mbt:7564-7619` | Carries the artifact replay lane that still matters for the neighborhood claim. |
| `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` | Documents the canonical late-cluster slot where the pass belongs. |
| `agent-todo.md` | Holds the `LCSE` slice that tracks the remaining ordered-neighborhood work. |

For the exact local code-map anchors, see [`./starshine-strategy.md`](./starshine-strategy.md).

## What the exact ordered-neighborhood claim still needs

1. **Whole-tree candidate matching**
   - repeated whole expressions, not generic subtree CSE
   - first-occurrence originals
   - parent-over-child request cancellation
2. **Window safety**
   - limited linear reuse windows
   - explicit resets around non-linear control
   - effect and generativity filtering
3. **Temp-local materialization**
   - append locals honestly
   - rewrite originals with `local.tee`
   - rewrite repeats with `local.get`
4. **Local-index repair and replay**
   - keep the new locals consistent with the existing rewrite and replay machinery
   - preserve the late clean-up relationship with `simplify-locals`

## Validation ladder

Start small and stay honest about the remaining ordered neighborhoods.

### 1. Shape tests stay green

The landed direct pass already covers part of the source-backed family map in [`./wat-shapes.md`](./wat-shapes.md):

- repeated arithmetic roots
- repeated loads
- parent-over-child cancellation
- local-write invalidation

The remaining shape-test gap from the 2026-06-04 audit is:

- additional generative GC-root variants beyond the covered `struct.new` / `struct.new_default` WAT fixtures and core-built `array.new` / `array.new_default` / `array.new_fixed` fixtures
- additional hard control-boundary negatives beyond after-`if`, else-arm, before-loop into loop-body, `br`, `br_table`, return, throw, top-level `unreachable`, and `try_table` body unreachable; legacy `rethrow` is spot-checked as a Binaryen hard boundary but deferred locally until a distinct raw instruction can be modeled

### 2. Registry and CLI proof stay green

Keep proving that:

- the pass name is active for direct execution
- explicit `--local-cse` requests execute cleanly
- the current catalog text points at the active implementation and the remaining preset-neighborhood gap
- the surrounding `flatten -> simplify-locals-notee-nostructure -> local-cse` gate stays false in the local regression surface

### 3. Pass-targeted parity stays green

Keep signoff with pass-targeted fuzz compare against Binaryen on the canonical pass spelling.

The 2026-06-04 audit also measured pass-local timing on `tests/node/dist/starshine-debug-wasi.wasm`: Starshine traced `pass:local-cse` at about `63-67 ms` before the fix and `70-72 ms` after the fix, while Binaryen `wasm-opt --debug --local-cse` reported about `107-110 ms`, so the sampled direct-pass runtime cleared the repository 2x Binaryen budget.

### 4. Adjacent-window positives are covered

The source-backed Binaryen positives where a repeated tree before an `if` is reused inside the `then` arm, before a straight-line block is reused inside that block body, before a `try_table` is reused inside its body, across `br_on_null` / `br_on_non_null` / `br_on_cast` / `br_on_cast_fail` into fallthrough continuation code, and across `struct.set` / `array.set` / `array.fill` for local-only repeated expressions are now covered in `src/passes/local_cse_test.mbt`. Paired after-`if` and else-arm negatives keep the `if` fix from widening the reuse window past Binaryen's `LinearExecutionWalker` boundaries, and the block / `try_table` fixes remain straight-line body bridges rather than loop or hard-terminator reuse. The implementation stays narrow: it shares eligible outer whole-tree bindings with the `then`, straight-line block body, or straight-line `try_table` body only and does not turn LCSE into CFG-wide CSE. The same direct test file now also protects the loop-boundary rule by proving an expression before a loop is not reused inside the loop body, protects switch-like `br_table`, return, and `unreachable` boundaries by proving expressions before those terminators are not reused after them, protects the tiny-root profitability rule by proving repeated `global.get` roots remain unmaterialized, protects `br` and throw boundaries by proving expressions before `throw` are not reused after it, protects `try_table` body unreachable boundaries by proving a hard terminator inside the body clears outer reuse before later unreachable body code, protects indirect and reference-call root barriers by proving repeated `call_indirect` and `call_ref` roots remain separate, protects the `return_call_indirect`, `return_call_ref`, and `throw_ref` operand-taking continuation positives plus `br_on_cast` / `br_on_cast_fail` reference-control continuation reuse without treating indirect-call, throwing, or branch-control roots as reusable, and protects four GC generativity rules by proving repeated `struct.new`, `struct.new_default`, and core-built `array.new` / `array.new_default` / `array.new_fixed` roots remain separate.

### 5. Neighborhood replay remains gated

Only after the adjacent local cleanup neighbors are represented locally should the no-DWARF neighborhood replay claim be made.
That means the validation story should stay conservative until the `flatten -> simplify-locals-notee-nostructure -> local-cse` and `coalesce-locals -> local-cse -> simplify-locals` slots are actually testable end to end.

## Bottom line

`local-cse` is an active direct pass plus an implementation-readiness bridge for the remaining ordered neighborhoods.
The current repo now has the direct pass and nearby local machinery for future neighborhood/preset work.
Keep this page as the implementation-readiness bridge until the exact ordered slots are proven.
