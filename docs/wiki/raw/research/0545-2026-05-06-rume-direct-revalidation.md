---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/remove-unused-module-elements/index.md
  - ../../binaryen/passes/remove-unused-module-elements/parity.md
  - ../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../src/passes/remove_unused_module_elements_test.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/remove-unused-module-elements/index.md
  - ../../binaryen/passes/remove-unused-module-elements/parity.md
  - ./0513-2026-05-06-starshine-pass-audit.md
  - ./0539-2026-05-06-runfe-direct-revalidation.md
---

# `remove-unused-module-elements` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh exposed fresh `remove-unused-module-elements` mismatches, can the direct pass be fixed and removed from the AUD002 stale-evidence lane?

## Fix

The stale-fuzzer rerun exposed two Binaryen parity drifts that were still reachable in the direct pass:

- active element/data segments with non-constant offsets were not rooted for full `remove-unused-module-elements`, so Starshine could delete their parent table/global/memory surfaces while Binaryen kept them
- empty const-offset active element segments on otherwise live tables could remain after liveness propagation, while Binaryen drops those no-op segments

The implementation now roots non-constant or potentially trapping active segments in the full pass as well as the non-function variant, then prunes empty const-offset active element segments before applying the final module rewrite.

Focused regression coverage added:

- `remove-unused-module-elements drops empty const-offset active elems on live tables`
- `remove-unused-module-elements keeps active elem segments with global offsets`

## Evidence

Commands run on 2026-05-06:

- `moon test src/passes` before the implementation change: failed on the new active-element/global-offset regression
- `moon test src/passes` after the implementation change: 750 passed, 0 failed
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass remove-unused-module-elements --out-dir .tmp/pass-fuzz-remove-unused-module-elements-fix2 --keep-going-after-command-failures`

The final direct-pass run reported:

- compared cases: 9972 / 10000
- normalized matches: 9972
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 28

The command failures were command/parser/tool failures, not Starshine/Binaryen semantic mismatches in compared outputs:

- Binaryen empty-recursion-group parser failures: 22
- Binaryen bad-section-size parser failures: 1
- Binaryen invalid-tag-index parser failures: 2
- Starshine missing-output command failures: 3

## Conclusion

`remove-unused-module-elements` is re-proven for direct explicit-pass parity under the refreshed harness and can be pruned from the AUD002 stale-evidence lane.

This does not make the full no-DWARF optimize preset proven. The pass still participates in repeated early and late slots, so ordered-neighborhood and artifact proof remain separate optimize-path work.
