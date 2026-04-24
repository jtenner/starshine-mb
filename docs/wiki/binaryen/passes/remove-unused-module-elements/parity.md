---
kind: comparison
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../../../agent-todo.md
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/passes/remove_unused_module_elements_test.mbt
  - ../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./retention-and-index-rewrites.md
  - ../../../../../src/cmd/cmd_wbtest.mbt
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
- Explicit pass execution also has CLI and compare-tool coverage through [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt) and [`../../../../../scripts/self-optimize-compare.ts`](../../../../../scripts/self-optimize-compare.ts).

## Focused Coverage Now Locked In

- explicit memarg memory-index rewrites
- imported-parent retention for active segments
- unused imported module-element drop plus survivor remap
- empty active data drop on live and imported memories
- no-op active nullref elem drop on imported tables
- non-noop active `nullfuncref` elem retention on live defined tables

## Remaining Gap

- The remaining post-fix compare noise is not currently a known RUME semantic mismatch.
- The saved backlog classifies the remaining failures as parser-compatibility and decoder or validator coverage work outside the pass's intended semantics.
- Historical direct-smoke evidence from `2026-04-11` still matters: `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --count 200 --seed 0x5eed ...` reported `199 / 200` compared, `199` normalized matches, `1` command failure (`binaryen-rec-group-zero`, `case-000029-wasm-smith`), and `0` mismatches.
- The later RUME blocker record is stronger and more specific after the semantic cleanup: `.tmp/pass-fuzz-rume-live-nullfuncref-rerun` reached `165 / 165` comparable `wasm-smith` cases with `0` mismatches before the `20` command-failure cutoff.
- In that later rerun Starshine contributed no command failures; the remaining failure slots were Binaryen-side parser or canonicalization blockers: `binaryen-invalid-type-index`, `binaryen-rec-group-zero`, `binaryen-invalid-wasm-type-neg64`, and three later Binaryen parser failures at cases `000162`, `000167`, and `000185`.
- Treat the direct pass as semantically signed off for the currently comparable corpus until a new semantic mismatch appears; the open work is parser-compatibility / coverage hardening, not another RUME keep/drop or remap bug.
- For future coverage-only RUME sweeps, `pass-fuzz-compare` now has `--keep-going-after-command-failures`, which records classified Binaryen parser/canonicalization failures without letting those known command-failure families consume the `--max-failures` cutoff.

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
