---
kind: comparison
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../../../agent-todo.md
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/passes/remove_unused_module_elements_test.mbt
  - ../../../raw/research/0545-2026-05-06-rume-direct-revalidation.md
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
- The current Starshine slice is directly re-proven under the refreshed 2026-06-03 pass-fuzz harness.
- The major previously known semantic gaps are closed:
  - unused imported module elements are now dropped and survivors remapped
  - empty active data on both defined and imported memories is now dropped
  - no-op active nullref elem segments on imported tables are now dropped
  - non-constant active segment offsets are rooted in the full pass, not only the non-function variant
  - empty const-offset active element segments are pruned after liveness propagation
  - `ref.func` declaration-only element segments are retained, and declaration-only active segments on otherwise-dead tables are nullified to declarative elems instead of retaining dead tables

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
- active element segments with global offsets in the full `remove-unused-module-elements` pass
- declarative elems needed by live `ref.func`
- declaration-only active elems on otherwise-dead tables rewritten to declarative elems

## Current Direct Signoff

- Final 2026-06-03 direct command: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass remove-unused-module-elements --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-rume-audit-declonly-10000`.
- Result: `9972 / 10000` compared cases, `9972` normalized matches, `0` semantic mismatches, `0` validation failures, `0` generator failures, and `28` command failures.
- Command-failure classification: `22` Binaryen empty-recursion-group parser failures, `1` Binaryen bad-section-size parser failure, `1` Binaryen table-index-out-of-range parser failure, `1` Binaryen invalid-tag-index parser failure, and `3` Starshine command failures in the same non-mismatch command-failure bucket as prior RUME signoff.
- `DFE -> RUME` neighborhood smoke: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass duplicate-function-elimination --pass remove-unused-module-elements --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dfe-rume-audit-1000` reached `998 / 1000` compared, `998` normalized matches, `0` mismatches, and `2` Binaryen empty-recursion-group command failures.
- Debug-artifact pass-local timing: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --remove-unused-module-elements --timing-only --out-dir .tmp/rume-debug-artifact-timing-declonly` reported canonical wasm equality, Starshine pass runtime `25.198 ms`, Binaryen pass runtime `38.936 ms`, and no raw skip.
- The prior 2026-05-06 revalidation remains useful historical evidence; see [`../../../raw/research/0545-2026-05-06-rume-direct-revalidation.md`](../../../raw/research/0545-2026-05-06-rume-direct-revalidation.md).

## Remaining Gap

- The remaining post-fix compare noise is not currently a known RUME semantic mismatch.
- The saved backlog classifies the remaining failures as parser-compatibility and decoder or validator coverage work outside the pass's intended semantics.
- Historical direct-smoke evidence from `2026-04-11` still matters: `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --count 200 --seed 0x5eed ...` reported `199 / 200` compared, `199` normalized matches, `1` command failure (`binaryen-rec-group-zero`, `case-000029-wasm-smith`), and `0` mismatches.
- The later RUME blocker record is stronger and more specific after the semantic cleanup: `.tmp/pass-fuzz-rume-live-nullfuncref-rerun` reached `165 / 165` comparable `wasm-smith` cases with `0` mismatches before the `20` command-failure cutoff.
- In that later rerun Starshine contributed no command failures; the remaining failure slots were Binaryen-side parser or canonicalization blockers: `binaryen-invalid-type-index`, `binaryen-rec-group-zero`, `binaryen-invalid-wasm-type-neg64`, and three later Binaryen parser failures at cases `000162`, `000167`, and `000185`.
- Treat the direct pass as semantically signed off for the currently comparable corpus until a new semantic mismatch appears; the open work is parser-compatibility / coverage hardening, not another RUME keep/drop or remap bug.
- For future coverage-only RUME sweeps, `pass-fuzz-compare` now has `--keep-going-after-command-failures`, which records classified Binaryen parser/canonicalization failures without letting those known command-failure families consume the `--max-failures` cutoff.
- A `2026-04-24` keep-going rerun exposed one more real semantic mismatch at `.tmp/pass-fuzz-rume-keep-going-2026-04-24/failures/case-000186-wasm-smith`: Binaryen keeps imported tables and nonempty active expression elem segments even when every initializer is `ref.null`; Starshine had treated null-only expression elems as effect-free and dropped them.
- That mismatch is now fixed. The follow-up rerun `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator wasm-smith --count 300 --seed 0x5eed --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-rume-keep-going-2026-04-24-fix` reported `298 / 300` compared, `298` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `2` command failures.
- The 2026-05-06 refreshed full direct revalidation later exposed and fixed the non-constant active-segment rooting and empty active-elem pruning drift, then reached `9972 / 10000` compared cases with `0` semantic mismatches.

## Practical Rule

- Treat current RUME work as maintenance and coverage-hardening, not as an unresolved core semantic port.
- If a new mismatch appears, debug it as either:
  - liveness decision drift
  - imported-parent retention drift
  - or incomplete remap coverage

## Sources

- Backlog status source: [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Supplemental health rerun: [`../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md`](../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md)
- Implementation: [`../../../../../src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt)
- Focused tests: [`../../../../../src/passes/remove_unused_module_elements_test.mbt`](../../../../../src/passes/remove_unused_module_elements_test.mbt)
