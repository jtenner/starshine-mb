---
kind: research
status: current
last_reviewed: 2026-06-07
sources:
  - ../../binaryen/passes/remove-unused-names/binaryen-strategy.md
  - ../../binaryen/passes/remove-unused-names/wat-shapes.md
  - ../../binaryen/passes/remove-unused-names/control-names-implicit-blocks-and-delegates.md
  - ../../../../src/passes/remove_unused_names_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ./0703-2026-06-03-remove-unused-names-o4z-audit.md
related:
  - ../../binaryen/passes/remove-unused-names/index.md
  - ../../binaryen/passes/remove-unused-names/starshine-hot-ir-strategy.md
---

# `remove-unused-names` O4z implementation inventory

## Question

Which `remove-unused-names` (`RUN`) optimization shapes needed to be explicitly accounted for before removing the O4z blanket no-op guard, and what implementation covered them?

## Initial blocker

Before this slice, `src/passes/pass_manager.mbt` returned the original function with trace reason `o4z-remove-unused-names-noop` whenever `optimize_level >= 4 && shrink_level >= 1`. That made every O4z RUN slot correctness-safe but hid both profitable no-label-use cleanup and edge-case reasoning behind one broad skip.

The first `moon test src/passes` after adding the tests confirmed the expected red state: 13 focused `remove_unused_names_test.mbt` failures, all caused by the blanket O4z no-op trace.

## Shape inventory represented by tests

New tests in `src/passes/remove_unused_names_test.mbt` cover these RUN families:

1. **Branchless same-typed block peel**
   - Input shape: one void block containing one same-typed child block.
   - Implemented O4z behavior: run the raw no-label-use rewrite and peel the child, not blanket no-op.

2. **Branchless typed value block peel**
   - Input shape: one explicit type-index block containing one same-typed explicit type-index child block with a value body.
   - Implemented O4z behavior: preserve type equality and peel the wrapper.

3. **Recursive branchless control-body peel**
   - Input shape: branchless same-typed block candidates nested under both `if` arms.
   - Implemented O4z behavior: recurse through branchless control bodies in the raw lane instead of treating nested candidates as needing unsafe HOT fallback.

4. **Dead-label loop demotion**
   - Input shape: a loop with no syntactic continue target.
   - Implemented O4z behavior: demote to the local block/body representation used by the direct pass.

5. **Stale label-name metadata cleanup**
   - Input shape: structural block peel with a label-name map in the wasm name section.
   - Implemented O4z behavior: preserve non-label names but remove stale label-name maps after control rewrites, matching the direct pass expectation.

6. **Parent-target `br` retargeting**
   - Input shape: same-type parent/child blocks where a plain `br` targets the parent.
   - Implemented O4z behavior: HOT fallback retargets the removed wrapper target to the surviving wrapper label and then peels the same-type chain.

7. **Parent-target `br_if` retargeting**
   - Input shape: same-type parent/child blocks where `br_if` targets the parent.
   - Implemented O4z behavior: account for conditional branch target replacement, not just plain `br`.

8. **Parent-target `br_table` retargeting**
   - Input shape: same-type parent/child blocks where `br_table` arm/default targets include the parent.
   - Implemented O4z behavior: account for all `br_table` target slots.

9. **Repeated RUN slot after branch cleanup**
   - Input shape: `remove-unused-names -> remove-unused-brs -> remove-unused-names` where branch cleanup can expose a profitable later RUN slot.
   - Implemented O4z behavior: repeated O4z RUN slots are individually accountable rather than all swallowed by a blanket no-op. The current O4z `remove-unused-brs` slot still has its own no-op behavior, so the fixture proves RUN accounting rather than full RUB-derived branch deletion.

10. **Still-targeted block-label guard**
    - Input shape: nested block where an inner `if` branch still targets the wrapper.
    - Implemented O4z behavior: retarget the nested branch through the same-type peel when the removed wrapper's exit is equivalent to the surviving wrapper.

11. **Live loop-continue guard**
    - Input shape: loop with `br 0` continue target.
    - Implemented O4z behavior: run/account for the pass and preserve the loop because the continue label is live.

12. **`try_table` catch-label guard**
    - Input shape: `try_table` catch target points at a candidate wrapper label.
    - Implemented O4z behavior: retarget the catch label through the same-type peel.

13. **Type-mismatch loop-demotion guard**
    - Input shape: unused-label typed loop whose body/type mismatch makes demotion unsafe.
    - Implemented O4z behavior: do not hide the shape behind the blanket no-op. The local representation demotes the typed unreachable loop to a typed block while preserving validation.

## Implementation

The implementation removed the blanket O4z early return in `run_hot_pipeline_raw_remove_unused_names(...)`. O4z now follows the same shape decision as direct execution: raw branchless rewrite for no-label-use candidates, no-candidate skip for functions without RUN work, and HOT fallback for label-use cases.

The HOT pass was widened for same-type block-chain peeling. Before replacing the outer block body with the peeled child body, it retargets branch-like uses of labels owned by the removed wrapper chain to the surviving outer label. This covers single-target branches, `br_table` targets/defaults, delegates, and `try_table` catches. New public HOT mutation helpers in `src/ir/hot_mutate.mbt` keep those updates inside the IR package instead of constructing read-only `HotNode` values in pass code.

## Validation

- Red confirmation: `moon test src/passes` failed 13 new RUN/O4z tests with the blanket `o4z-remove-unused-names-noop` trace.
- After implementation: `moon fmt` finished successfully; `moon test src/ir` passed 245 / 245; `moon test src/passes` passed 1977 / 1977; full `moon test` passed 5169 / 5169.
- Native build: `moon build --target native --release src/cmd` finished with pre-existing pass-manager unused-function warnings and produced `target/native/release/build/cmd/cmd.exe`.
- Direct compare: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass remove-unused-names --out-dir .tmp/pass-fuzz-remove-unused-names-o4z-run-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared 7606 / 10000 cases, with 7606 normalized matches, 0 mismatches, 0 validation/property/generator failures, and 20 Binaryen/tool command failures.
- Requested final-style compare before the size fix: `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass remove-unused-names --out-dir .tmp/pass-fuzz-remove-unused-names-o4z-run-final-100000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared 99751 / 100000 cases, with 99746 normalized matches, 5 mismatches, 0 validation/property/generator failures, and 249 Binaryen/tool command failures (`binaryen-rec-group-zero` 219, `binaryen-bad-section-size` 12, `binaryen-command-failed` 11, `binaryen-table-index-out-of-range` 6, `binaryen-invalid-tag-index` 1). The 5 mismatches were agent-classified as semantic-safe but size-losing unreachable-control debris: cases 023083, 044811, 046375, 082547, and 085577 differed only because Starshine preserved an extra `drop (unreachable)` or nested `drop (drop (unreachable))` immediately before an unconditional `unreachable`, while Binaryen removed that unreachable prefix debris. Both variants trap before any following code can execute; no RUN label-retargeting semantic difference was involved. Starshine outputs were 2-3 bytes larger in those five cases.
- Size fix: the raw RUN adapter now removes dropped-unreachable debris even when the normal RUN candidate scan would skip or fall back to HOT, and the normal raw rewrite path runs the same debris cleanup after block/loop rewriting. Focused tests cover the single-drop and nested-drop families.
- Requested final-style compare after the size fix: `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass remove-unused-names --out-dir .tmp/pass-fuzz-remove-unused-names-o4z-run-final-100000-sizefix --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared 99751 / 100000 cases, with 99751 normalized matches, 0 mismatches, 0 validation/property/generator failures, and 249 Binaryen/tool command failures.
- `moon info` and `moon check src/ir` still hit the known local Moon panic (`index out of bounds: the len is 36 but the index is 8329485`).

Post-size-fix focused validation: `moon fmt`; `moon test src/ir` 245 / 245; `moon test src/passes` 1979 / 1979; native `src/cmd` build with pre-existing pass-manager unused-function warnings; full `moon test` 5171 / 5171. O4z artifact/slot replay and pass-local timing remain follow-up evidence before closing `[O4Z-AUDIT-RUN]` completely.

## Not yet represented

The local WAT/public test surface still does not exercise every Binaryen scope-name-use spelling directly, especially legacy `delegate` text forms and some `br_on_*` variants. Existing helper-level delegate coverage proves the label-use helper marks delegate targets in direct HOT mode. A later O4z HOT-fallback slice should add public or helper-level O4z tests for those surfaces once the local test builders expose a stable lowered/public fixture shape.
