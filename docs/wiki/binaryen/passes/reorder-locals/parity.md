---
kind: comparison
status: supported
last_reviewed: 2026-06-04
sources:
  - ../../../raw/research/0709-2026-06-04-reorder-locals-preset-scheduling-reconciliation.md
  - ../../../raw/research/0547-2026-05-07-reorder-locals-boundary-policy-and-artifact-rerun.md
  - ../../../raw/research/0540-2026-05-06-reorder-locals-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-reorder-locals-current-main-recheck.md
  - ../../../raw/research/0472-2026-05-05-reorder-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-reorder-locals-validation-primary-sources.md
  - ../../../raw/research/0430-2026-04-27-reorder-locals-validation-bridge.md
  - ../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md
  - ../../../raw/research/0253-2026-04-22-reorder-locals-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0237-2026-04-21-reorder-locals-starshine-strategy-followup.md
  - ../../../raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md
  - ../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md
related:
  - ./starshine-hot-ir-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ./multivalue-call-scope.md
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../scripts/lib/self-optimize-compare-task.ts
---

# `reorder-locals` Binaryen Parity

## Durable Conclusions

- Binaryen `version_129` keeps parameters fixed and reorders only body locals.
- Body locals sort by descending access count.
- Nonzero-count ties break by first observed access.
- Zero-count ties preserve original order, and the final zero-count suffix is dropped.
- `local.set` and `local.tee` count as accesses, so write-only locals survive this pass.
- The clean Starshine port is a module pass, not a hot pass, because local-name metadata and raw name-section invalidation are boundary-owned.
- The 2026-05-05 raw primary-source capture re-confirmed that the official Binaryen `version_129` release page showed publish date **2026-04-01**, and that the reviewed `version_129/src/passes/ReorderLocals.cpp` plus dedicated pass tests still match the dossier's access-count plus first-use sorter story on the checked current-`main` surfaces.

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/reorder_locals.mbt`](../../../../../src/passes/reorder_locals.mbt).
- The current local strategy and exact code map now live in [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md).
- The current explicit-pass-versus-preset signoff ladder lives in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
- The pass is wired through the module-pass dispatcher in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt).
- Registry and preset policy live in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) and [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt).
- CLI coverage for explicit pass execution lives in [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt).
- Binaryen-boundary compare controls live in [`../../../../../scripts/lib/self-optimize-compare-task.ts`](../../../../../scripts/lib/self-optimize-compare-task.ts) and the related command tests under `scripts/test/`.

## Preset And Signoff Rule

- In this repo, `reorder-locals` is intentionally available as an explicit module pass.
- Public `optimize` and `shrink` schedule it exactly once in the proven early tuple/no-structure cleanup lane: `code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs`.
- Extra upstream-style `reorder-locals` slots are not yet claimed; any future widening still needs neighboring-slot evidence and exact preset tests.
- Representation-stable comparison, local-name rewrite correctness, explicit module-pass coverage, and the current single public slot are the honest signoff targets.

## Refreshed Debug-Artifact Boundary Replay

- The 2026-05-07 current-head artifact lane ran `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --binaryen-nop-until-stable 5 --reorder-locals`.
- Binaryen no-pass writeback still did not converge within 5 roundtrips, so canonical emitted wasm stayed unequal on the full artifact.
- The representation-stable surfaces still compared green on that same replay: `Normalized WAT equal: yes` and `Canonical function compare equal: yes`.
- Starshine pass runtime on that lane was `56.953 ms` versus Binaryen `86.020 ms`.
- This keeps the repo scope decision intact: treat the remaining full-artifact raw-output drift as Binaryen multivalue-call writeback/materialization behavior, not as a remaining `reorder-locals` sorter bug.

## Refreshed Direct Signoff

- The 2026-05-06 post-fuzzer-change direct signoff ran `moon info`, `moon fmt`, `moon test`, and `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass reorder-locals --out-dir .tmp/pass-fuzz-reorder-locals`.
- The compare lane reached 6759 / 10000 compared cases, 6759 normalized matches, 0 semantic mismatches, 0 validation failures, 0 generator failures, and 20 Binaryen empty-recursion-group parser/canonicalization command failures.
- Those command failures are the same Binaryen-side empty-recursion-group failure class seen across the refreshed direct-pass lanes, not Starshine/Binaryen semantic output drift.

## Historical Parity Gap

- Older raw mismatch evidence below is superseded for direct AUD002 purposes by the 2026-05-06 zero-mismatch run, but remains useful background for Binaryen boundary controls.
- The remaining historical raw mismatch was not the sort comparator itself.
- `2026-04-11` `--pass reorder-locals` smoke evidence on `version_129` from `both` generator:
  - `199 / 200` compared
  - `198` normalized matches
  - `1` command failure (`binaryen-rec-group-zero`, smith)
  - `1` mismatch
- `2026-04-11` `--pass reorder-locals --generator gen-valid --count 200 --seed 0x5eed` reports:
  - `199 / 200` compared
  - `199` normalized matches
  - `0` command failures
  - `1` normalized mismatch
- The mismatch case (`case-000150-gen-valid`) matches a write/read local index swap on dead locals with no visible behavioral impact in `wasmtime` probe runs on the raw outputs, so this lane is currently treated as a comparator normalization gap that still needs a cleaner classification path before claiming a semantic blocker.

Use the Binaryen boundary controls when comparing this pass:

- `--binaryen-nop-roundtrips <n>`
- `--binaryen-nop-until-stable <max>`
- `--require-binaryen-nop-converged`
- For block-only multivalue repros the Binaryen boundary can converge; for multivalue call repros and the debug artifact it can remain non-convergent.

## Sources

- Current preset-scheduling reconciliation: [`../../../raw/research/0709-2026-06-04-reorder-locals-preset-scheduling-reconciliation.md`](../../../raw/research/0709-2026-06-04-reorder-locals-preset-scheduling-reconciliation.md)
- Current closure note: [`../../../raw/research/0547-2026-05-07-reorder-locals-boundary-policy-and-artifact-rerun.md`](../../../raw/research/0547-2026-05-07-reorder-locals-boundary-policy-and-artifact-rerun.md)
- Archived research doc: [`../../../raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md`](../../../raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md)
- Supplemental health rerun: [`../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md`](../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md)
- Validation primary-source manifest: [`../../../raw/binaryen/2026-04-27-reorder-locals-validation-primary-sources.md`](../../../raw/binaryen/2026-04-27-reorder-locals-validation-primary-sources.md)
- Raw primary-source manifest: [`../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderLocals.cpp>
- Scope decision: [`./multivalue-call-scope.md`](./multivalue-call-scope.md)
- Implementation: [`../../../../../src/passes/reorder_locals.mbt`](../../../../../src/passes/reorder_locals.mbt)
- CLI coverage: [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
