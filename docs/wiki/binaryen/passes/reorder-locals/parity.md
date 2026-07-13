---
kind: comparison
status: supported
last_reviewed: 2026-07-12
sources:
  - ../../../raw/research/1561-2026-07-12-reorder-locals-public-preset-scheduling.md
  - ../../../raw/research/1401-2026-07-02-reorder-locals-o4z-closeout.md
  - ../../../raw/research/1400-2026-07-02-reorder-locals-v130-source-inventory.md
  - ../../../raw/binaryen/2026-07-02-reorder-locals-version-130-source-refresh.md
  - ../../../raw/research/0709-2026-06-04-reorder-locals-preset-scheduling-reconciliation.md
  - ../../../raw/research/0547-2026-05-07-reorder-locals-boundary-policy-and-artifact-rerun.md
  - ../../../raw/research/0540-2026-05-06-reorder-locals-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-reorder-locals-current-main-recheck.md
  - ../../../raw/research/0472-2026-05-05-reorder-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-07-02-reorder-locals-version-130-source-refresh.md
  - ../../../raw/research/0430-2026-04-27-reorder-locals-validation-bridge.md
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

- Binaryen `version_130` keeps parameters fixed and reorders only body locals; the refreshed owner/lit files are byte-identical to the older `version_129` contract.
- Body locals sort by descending access count.
- Nonzero-count ties break by first observed access.
- Zero-count ties preserve original order, and the final zero-count suffix is dropped.
- `local.set` and `local.tee` count as accesses, so write-only locals survive this pass.
- The clean Starshine port is a module pass, not a hot pass, because local-name metadata and raw name-section invalidation are boundary-owned.
- The 2026-07-02 raw source refresh re-confirmed the same access-count plus first-use sorter story against the current local `version_130` oracle.

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/reorder_locals.mbt`](../../../../../src/passes/reorder_locals.mbt).
- The current local strategy and exact code map now live in [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md).
- The current explicit-pass-versus-preset signoff ladder lives in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
- The pass is wired through the module-pass dispatcher in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt).
- Registry and preset policy live in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) and [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt).
- CLI coverage for explicit pass execution lives in [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt).
- Binaryen-boundary compare controls live in [`../../../../../scripts/lib/self-optimize-compare-task.ts`](../../../../../scripts/lib/self-optimize-compare-task.ts) and the related command tests under `scripts/test/`.

## O4Z Audit Inventory

Current direct transform-family inventory against `version_130`:

| Family | Starshine status | Audit status |
| --- | --- | --- |
| Parameter stability / params-only no-op | Focused tests cover stable params and params-only no-op. | no current gap found |
| `local.get` / `local.set` / `local.tee` access counting | Starshine handles tee explicitly because its IR has a separate `LocalTee`. | no current gap found |
| Descending access count plus first-use tie ordering | Focused access-count and carrier fixtures cover the comparator. | no current gap found |
| Zero-count body-local truncation | Focused tests cover trailing unused drops and write-only/tee-only survival. | no current gap found; needs generated-profile density |
| Nested local-user reindexing | Focused nested block/loop/if/try-table test covers recursive rewrite. | no current gap found |
| Local-name repair and raw name payload invalidation | Focused name-section and CLI/binary tests cover metadata repair. | no current gap found |
| Multivalue scratch-local drift | Documented as Binaryen writer/IR-builder boundary, not `ReorderLocals.cpp`. | standing boundary decision |
| Repeated scheduler slots | Starshine public presets now claim the current Binaryen-shaped three-slot cleanup story: the early tuple/no-structure lane plus the late `simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum` cluster. | closed for current RL scheduling; remaining preset differences belong to other `[O4Z-PRESET-BEHAVIOR]` owners |
| TypeIdx/RecIdx invariant comment | Function-section type references are global `TypeIdx`; a local inline comment now marks `RecIdx` as an impossible function-section invariant failure. | `[AUDIT006-E]` closed for this pass |
| Dedicated GenValid profile | `reorder-locals-all` now covers hot-sort, unused-trim, and name-repair leaves. | closed; 10000-case dedicated lane is green |

## Preset And Signoff Rule

- In this repo, `reorder-locals` is intentionally available as an explicit module pass.
- Public `optimize` and `shrink` schedule the current Binaryen-shaped three-slot cleanup story: the early tuple/no-structure lane `code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs` plus the late cluster `simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum`.
- The 2026-07-12 public scheduling note `1561` closes RL's top-level repeated-slot policy gap using the already-landed ordered-neighborhood evidence; remaining preset divergence is now about neighboring passes such as `code-folding`, `redundant-set-elimination`, the second pre-pass `remove-unused-module-elements`, and the extra Starshine `remove-unused-brs` slot.
- Representation-stable comparison, local-name rewrite correctness, explicit module-pass coverage, and the current public three-slot cleanup schedule are the honest signoff targets.

## Refreshed Debug-Artifact Boundary Replay

- The 2026-05-07 current-head artifact lane ran `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --binaryen-nop-until-stable 5 --reorder-locals`.
- Binaryen no-pass writeback still did not converge within 5 roundtrips, so canonical emitted wasm stayed unequal on the full artifact.
- The representation-stable surfaces still compared green on that same replay: `Normalized WAT equal: yes` and `Canonical function compare equal: yes`.
- Starshine pass runtime on that lane was `56.953 ms` versus Binaryen `86.020 ms`.
- This keeps the repo scope decision intact: treat the remaining full-artifact raw-output drift as Binaryen multivalue-call writeback/materialization behavior, not as a remaining `reorder-locals` sorter bug.

## O4Z Direct Signoff

- The 2026-07-02 O4Z closeout added the dedicated `reorder-locals-all` GenValid aggregate and re-ran the current `version_130` direct evidence with `_build/native/release/build/cmd/cmd.exe`.
- Dedicated `reorder-locals-all`: `10000/10000` compared, `10000` normalized matches, zero mismatches/failures.
- Ordinary GenValid: `10000/10000` compared, `10000` normalized matches, zero mismatches/failures.
- Random all-profiles GenValid: `10000/10000` compared, `10000` normalized matches, zero mismatches/failures.
- External `wasm-smith` with `--normalize unreachable-control-debris`: `9956/10000` compared, `9955` raw normalized matches, `1` compare-normalized unreachable/control-debris case, zero remaining mismatches, and `44` Binaryen/oracle command failures.
- The external raw residual was classified as unreachable/control debris (`drop(unreachable)` under unreachable flow), not a `reorder-locals` sorter, local-name, or local-index remap gap.
- A 30-case dedicated timing probe found pass-local max times of `0.032 ms` for Starshine and `0.019 ms` for Binaryen; all samples are comfortably below the repo `<1s` target, with sub-0.05ms ratio noise.

## Historical Direct Signoff

- The 2026-05-06 post-fuzzer-change direct signoff ran `moon info`, `moon fmt`, `moon test`, and `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass reorder-locals --out-dir .tmp/pass-fuzz-reorder-locals`.
- The compare lane reached 6759 / 10000 compared cases, 6759 normalized matches, 0 semantic mismatches, 0 validation failures, 0 generator failures, and 20 Binaryen empty-recursion-group parser/canonicalization command failures.
- Those command failures were the same Binaryen-side empty-recursion-group failure class seen across the refreshed direct-pass lanes, not Starshine/Binaryen semantic output drift.

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

- O4Z closeout: [`../../../raw/research/1401-2026-07-02-reorder-locals-o4z-closeout.md`](../../../raw/research/1401-2026-07-02-reorder-locals-o4z-closeout.md)
- `version_130` source inventory: [`../../../raw/research/1400-2026-07-02-reorder-locals-v130-source-inventory.md`](../../../raw/research/1400-2026-07-02-reorder-locals-v130-source-inventory.md)
- `version_130` primary-source manifest: [`../../../raw/binaryen/2026-07-02-reorder-locals-version-130-source-refresh.md`](../../../raw/binaryen/2026-07-02-reorder-locals-version-130-source-refresh.md)
- Public preset scheduling: [`../../../raw/research/1561-2026-07-12-reorder-locals-public-preset-scheduling.md`](../../../raw/research/1561-2026-07-12-reorder-locals-public-preset-scheduling.md)
- Earlier one-slot reconciliation: [`../../../raw/research/0709-2026-06-04-reorder-locals-preset-scheduling-reconciliation.md`](../../../raw/research/0709-2026-06-04-reorder-locals-preset-scheduling-reconciliation.md)
- Current closure note: [`../../../raw/research/0547-2026-05-07-reorder-locals-boundary-policy-and-artifact-rerun.md`](../../../raw/research/0547-2026-05-07-reorder-locals-boundary-policy-and-artifact-rerun.md)
- Archived research doc: [`../../../raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md`](../../../raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md)
- Supplemental health rerun: [`../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md`](../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md)
- Current source inventory: [`../../../raw/binaryen/2026-07-02-reorder-locals-version-130-source-refresh.md`](../../../raw/binaryen/2026-07-02-reorder-locals-version-130-source-refresh.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderLocals.cpp>
- Scope decision: [`./multivalue-call-scope.md`](./multivalue-call-scope.md)
- Implementation: [`../../../../../src/passes/reorder_locals.mbt`](../../../../../src/passes/reorder_locals.mbt)
- CLI coverage: [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
