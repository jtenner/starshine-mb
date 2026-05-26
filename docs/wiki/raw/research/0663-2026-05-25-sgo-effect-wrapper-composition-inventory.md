---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../agent-todo.md
  - ../../../../src/passes/simplify_globals_optimizing.mbt
  - ../../../../src/passes/simplify_globals_optimizing_test.mbt
  - ./0636-2026-05-25-sgo-transparent-block-wrapper-guardrails.md
  - ./0637-2026-05-25-sgo-try-table-block-wrapper-guardrails.md
  - ./0661-2026-05-25-sgo-load-table-get-independence-audit.md
  - ./0662-2026-05-25-sgo-store-bulk-independence-audit.md
---

# SGO effect wrapper composition inventory (`[SGO]003D1`)

## Scope

This research/backlog slice resolves the generic wrapper/control-composition inventory that was made explicit as `[SGO]003D1`. It does not change optimizer behavior and does not claim full Binaryen `SimplifyGlobals.cpp` parity.

## Inventory

No behavior-ready wrapper/control composition was found that should remain hidden under `[SGO]003D1`:

- Transparent result-block wrappers are already source-aligned by 0636. That slice probed Binaryen, added a positive nested result-block guardrail, added a branchy-wrapper negative, and observed Starshine already covered the positive without matcher changes.
- No-catch `try_table` plus transparent result-block composition is already source-aligned by 0637. That slice probed Binaryen, added the no-catch positive and caught-wrapper negative, and observed Starshine already covered the positive without matcher changes.
- The current FlowScanner family already recurses through clean void blocks/loops/ifs, clean value-producing blocks/loops/ifs, and nested arm-result scans while preserving branch/control, extra-read/write, tainted-operand, and trapped-consumer boundaries.
- Focused tests cover the named independent-effect families from 0661 and 0662 under direct/nested arm-flow shapes, plus many block/loop/if/no-catch `try_table` wrapper guardrails. Existing conservative tests intentionally keep branchy wrappers, caught `try_table`, loop-wrapped trapping consumers, global-steered effects, and tainted operands out of the accepted surface.

## Decision

Close `[SGO]003D1` as a research-only inventory. There is no single generic wrapper-composition implementation task to keep open: future wrapper/control work must name an exact uncovered Binaryen-positive grammar as a new child slice instead of broadening the FlowScanner by analogy.

## Validation

No optimizer behavior, tests, public API, or pass docs changed in this slice. `git diff --check` is sufficient commit validation.

## Remaining risks

This does not prove every possible wrapper/control shape. It only removes the generic hidden-work bucket. Potential future positives involving new wrappers, branches, catches, loops/backedges, effect ordering, or joins remain out of scope until a concrete Binaryen-positive fixture is named and paired with candidate-derived/global-steered negatives.
