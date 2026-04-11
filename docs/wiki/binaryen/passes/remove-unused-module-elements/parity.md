---
kind: comparison
status: supported
last_reviewed: 2026-04-11
sources:
  - ../../../../../agent-todo.md
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/passes/remove_unused_module_elements_test.mbt
  - ../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md
related:
  - ./index.md
  - ./retention-and-index-rewrites.md
  - ../../../../../src/cmd/cmd_test.mbt
  - ../../../../../scripts/self-optimize-compare.ts
---

# `remove-unused-module-elements` Binaryen Parity

## Durable Conclusions

- `remove-unused-module-elements` is an active module pass, not a HOT-IR pass.
- The current Starshine slice is canonically correct on the debug artifact for the direct pass surface tracked in-tree.
- The major previously known semantic gaps are closed:
  - unused imported module elements are now dropped and survivors remapped
  - empty active data on both defined and imported memories is now dropped
  - no-op active nullref elem segments on imported tables are now dropped

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt).
- The focused suite lives in [`../../../../../src/passes/remove_unused_module_elements_test.mbt`](../../../../../src/passes/remove_unused_module_elements_test.mbt).
- Explicit pass execution also has CLI and compare-tool coverage through [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt) and [`../../../../../scripts/self-optimize-compare.ts`](../../../../../scripts/self-optimize-compare.ts).

## Focused Coverage Now Locked In

- explicit memarg memory-index rewrites
- imported-parent retention for active segments
- unused imported module-element drop plus survivor remap
- empty active data drop on live and imported memories
- no-op active nullref elem drop on imported tables
- non-noop active `nullfuncref` elem retention on live defined tables

## Remaining Gap

- The remaining post-fix compare noise is not currently a known RUME semantic mismatch.
- The saved backlog now classifies the remaining failures as parser-compatibility and decoder or validator coverage work outside the pass's intended semantics.
- A `2026-04-11` `--pass remove-unused-module-elements` smoke rerun (200 mixed cases, `seed 0x5eed`) reports:
  - `199 / 200` compared
  - `199` normalized matches
  - `1` command failure (`binaryen-rec-group-zero`, `case-000029-wasm-smith`)
  - `0` mismatches
- The `2026-04-11` parity lane therefore has no semantic deltas relative to this direct comparator, and the remaining saved noise stays in parser-compatibility buckets.

## Practical Rule

- Treat current RUME work as maintenance and coverage-hardening, not as an unresolved core semantic port.
- If a new mismatch appears, debug it as either:
  - liveness decision drift
  - imported-parent retention drift
  - or incomplete remap coverage

## Sources

- Active backlog slice: [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Supplemental health rerun: [`../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md`](../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md)
- Implementation: [`../../../../../src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt)
- Focused tests: [`../../../../../src/passes/remove_unused_module_elements_test.mbt`](../../../../../src/passes/remove_unused_module_elements_test.mbt)
