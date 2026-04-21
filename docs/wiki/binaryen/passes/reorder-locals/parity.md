---
kind: comparison
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0237-2026-04-21-reorder-locals-starshine-strategy-followup.md
  - ../../../raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md
  - ../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md
related:
  - ./starshine-hot-ir-strategy.md
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
- A `2026-04-09` review of `version_129/src/passes/ReorderLocals.cpp` confirms the same access-count plus first-use sorter captured here.

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/reorder_locals.mbt`](../../../../../src/passes/reorder_locals.mbt).
- The current local strategy and exact code map now live in [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md).
- The pass is wired through the module-pass dispatcher in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt).
- Registry and preset policy live in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) and [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt).
- CLI coverage for explicit pass execution lives in [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt).
- Binaryen-boundary compare controls live in [`../../../../../scripts/lib/self-optimize-compare-task.ts`](../../../../../scripts/lib/self-optimize-compare-task.ts) and the related command tests under `scripts/test/`.

## Preset And Signoff Rule

- In this repo, `reorder-locals` is intentionally available as an explicit module pass.
- It stays out of the `optimize` and `shrink` presets until `simplify-locals-nostructure`, `local-subtyping`, and `coalesce-locals` land and the neighboring Binaryen slots can be modeled honestly.
- Representation-stable comparison, local-name rewrite correctness, and explicit module-pass coverage are the current honest signoff targets.

## Remaining Parity Gap

- The remaining raw mismatch is still not the sort comparator itself.
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

- Archived research doc: [`../../../raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md`](../../../raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md)
- Supplemental health rerun: [`../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md`](../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderLocals.cpp>
- Scope decision: [`./multivalue-call-scope.md`](./multivalue-call-scope.md)
- Implementation: [`../../../../../src/passes/reorder_locals.mbt`](../../../../../src/passes/reorder_locals.mbt)
- CLI coverage: [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
