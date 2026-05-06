---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0540-2026-05-06-reorder-locals-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-reorder-locals-current-main-recheck.md
  - ../../../raw/research/0472-2026-05-05-reorder-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-reorder-locals-validation-primary-sources.md
  - ../../../raw/research/0430-2026-04-27-reorder-locals-validation-bridge.md
  - ../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md
  - ../../../raw/research/0253-2026-04-22-reorder-locals-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0237-2026-04-21-reorder-locals-starshine-strategy-followup.md
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/reorder_locals_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./names-roundtrip-and-porting.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ./multivalue-call-scope.md
  - ../simplify-locals-nostructure/index.md
  - ../coalesce-locals/index.md
---

# Starshine validation bridge for `reorder-locals`

## Why this page exists

`reorder-locals` is already implemented in Starshine, but the old folder split made one important distinction too implicit:

- **explicit-pass correctness** is mostly solved and covered by focused tests;
- **preset-readiness** is still intentionally blocked on neighboring local passes and ordered no-DWARF replay evidence.

This page is the bridge from the algorithm pages to validation work. Use it when deciding whether a future change only preserves the standalone pass, or whether it is trying to move `reorder-locals` into `optimize` / `shrink` preset slots.

## Current Starshine status

The 2026-05-06 refreshed direct signoff re-proved the explicit pass with 6759/10000 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group command failures; see [`../../../raw/research/0540-2026-05-06-reorder-locals-direct-revalidation.md`](../../../raw/research/0540-2026-05-06-reorder-locals-direct-revalidation.md).

Starshine currently exposes `reorder-locals` as an active module pass:

- registry entry: `src/passes/optimize.mbt:257`
- dispatcher case: `src/passes/pass_manager.mbt:8684`
- owner entrypoint: `src/passes/reorder_locals.mbt:544`
- registry category test: `src/passes/registry_test.mbt:56`
- explicit CLI coverage: `src/cmd/cmd_wbtest.mbt:4296`

Starshine deliberately does **not** schedule it in the public presets yet:

- `src/passes/optimize_test.mbt:390` asserts that `optimize` and `shrink` do not contain `reorder-locals` before neighboring local passes land.

That means new work should not treat preset omission as an implementation bug by itself. It is a policy guard for scheduler honesty.

## Explicit-pass contract to preserve

A local change to `src/passes/reorder_locals.mbt` should preserve these source-backed rules:

| Rule | Local implementation surface | Test surface |
| --- | --- | --- |
| Parameters never move. | `rl_defined_func_param_cache(...)`, `rl_params_for_type_idx(...)`, and the param prefix in `rl_rewrite_func(...)`. | Multiple-defined-function and params-only tests in `src/passes/reorder_locals_test.mbt:210` and `:280`. |
| Body-local accesses are counted across `local.get`, `local.set`, and Starshine's separate `local.tee`. | `rl_scan_instruction(...)` in `src/passes/reorder_locals.mbt:105`. | Access-count / first-use, write-only, and tee-only tests in `src/passes/reorder_locals_test.mbt:294`, `:328`, and `:364`. |
| Live body locals sort by descending count, then first observed use, then original index as a stable fallback. | `rl_sort_used_body_locals(...)` in `src/passes/reorder_locals.mbt:125`. | Access-count / first-use test plus carrier fixture in `src/passes/reorder_locals_test.mbt:294` and `:500`. |
| Zero-access body locals are removed, but write-only and tee-only locals survive. | `rl_note_access(...)`, `rl_rewrite_func(...)`, and the `old_to_new` `-1` dropped-local sentinel. | Write-only, tee-only, and trailing-local trim tests at `src/passes/reorder_locals_test.mbt:328`, `:364`, and `:346`. |
| Nested structured bodies have local indices rewritten uniformly. | `rl_rewrite_instrs_in_place(...)` covers `block`, `loop`, `if`, and `try_table`. | Nested rewrite test at `src/passes/reorder_locals_test.mbt:391`. |
| Grouped local runs are rebuilt, not flattened permanently. | `rl_flatten_locals(...)` plus `rl_push_local_run(...)`. | Local-run assertions throughout `src/passes/reorder_locals_test.mbt`. |
| Local names follow the new indices and stale raw name payloads are cleared. | `rl_rewrite_name_map(...)`, `rl_rewrite_local_names(...)`, and `rl_rewrite_name_sec(...)`. | Name-section test at `src/passes/reorder_locals_test.mbt:454`; CLI binary-write path at `src/cmd/cmd_wbtest.mbt:4296`. |
| Imported-function local names are preserved. | `rl_rewrite_local_names(...)` keeps entries with `func_idx < imported_func_count`. | Name-section test at `src/passes/reorder_locals_test.mbt:454`. |

## Binaryen strategy mapping

The upstream strategy remains the small `ReorderLocals.cpp` contract described in [`./binaryen-strategy.md`](./binaryen-strategy.md):

1. Count `LocalGet` and `LocalSet` uses.
2. Keep parameters before body locals.
3. Sort live body locals by descending count and first-use order.
4. Truncate the body-local list at the first zero-count local.
5. Rewrite local users.
6. Rebuild local-name maps.

The main representation difference is tee handling:

- Binaryen's tee path is represented through `LocalSet`.
- Starshine's boundary instruction enum has a distinct `LocalTee`, so `rl_scan_instruction(...)` and `rl_rewrite_instrs_in_place(...)` mention it explicitly.

That is not semantic divergence. It is an IR-shape difference that tests must keep visible.

## Preset-readiness gate

Do **not** move `reorder-locals` into Starshine `optimize` or `shrink` just because the explicit pass is green.

Binaryen's no-DWARF optimizer uses `reorder-locals` as repeated glue around neighboring local passes:

1. `simplify-locals-nostructure -> vacuum -> reorder-locals`
2. `simplify-locals -> vacuum -> reorder-locals -> coalesce-locals`
3. `... -> coalesce-locals -> reorder-locals -> vacuum`

A faithful Starshine preset change should therefore bring evidence for the ordered cluster, not only for this pass alone.

Minimum preset-readiness evidence:

- `moon info`, `moon fmt`, and focused `moon test src/passes` / `moon test src/cmd` remain green.
- Explicit `--pass reorder-locals` or equivalent pass-fuzz comparisons still pass against Binaryen for ordinary generated modules.
- The neighboring local-pass cluster has local equivalents or documented no-op/removed decisions for the specific preset slot being claimed.
- Ordered no-DWARF replay shows that inserting `reorder-locals` does not introduce raw-writeback, local-name, or multivalue-call regressions beyond the already documented writer boundary in [`./multivalue-call-scope.md`](./multivalue-call-scope.md).
- Preset tests update from the current exclusion assertion in `src/passes/optimize_test.mbt:390` to a positive schedule assertion only in the same change that supplies the replay evidence.

## Beginner-to-advanced validation ladder

Start with small, semantic checks before running broader parity:

1. **Shape tests:** preserve the examples in [`./wat-shapes.md`](./wat-shapes.md): hot-local reordering, first-use ties, write-only survival, tee-only survival, dead-tail removal, all-body-local removal, fixed params, nested users, and metadata repair.
2. **Module-representation tests:** keep grouped local runs and function-type parameter lookup covered. This is where Starshine differs most from Binaryen's in-memory AST view.
3. **Metadata tests:** always include a local-name map and a raw name-section payload when touching name repair; dropping or reordering locals without invalidating raw payload is a binary-output bug.
4. **CLI/binary roundtrip:** keep an adapter-level wasm input/output test because Binaryen's dedicated print-roundtrip fixtures prove that declaration order must survive serialization.
5. **Oracle parity:** compare explicit `reorder-locals` against Binaryen for generated modules before changing scheduler behavior.
6. **Preset replay:** only after the local-pass neighbors are ready, test the ordered no-DWARF sequence that contains all three Binaryen `reorder-locals` slots.

## Non-goals and stale-reference guardrails

- Do not describe `reorder-locals` as `coalesce-locals`, register allocation, dead-store elimination, or a generic liveness pass.
- Do not use the multivalue-call caveat as evidence that `ReorderLocals.cpp` is more complex than it is; that caveat belongs to writer/lowering compatibility.
- Do not call the Starshine implementation a HOT pass. It is module-scoped because it needs function type parameters, grouped local declarations, local-name maps, and raw custom-section invalidation.
- Do not remove the preset-exclusion test without adding the cluster-level scheduling evidence described above.

## Sources

- [`../../../raw/binaryen/2026-04-27-reorder-locals-validation-primary-sources.md`](../../../raw/binaryen/2026-04-27-reorder-locals-validation-primary-sources.md)
- [`../../../raw/research/0430-2026-04-27-reorder-locals-validation-bridge.md`](../../../raw/research/0430-2026-04-27-reorder-locals-validation-bridge.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
- [`./parity.md`](./parity.md)
- [`./multivalue-call-scope.md`](./multivalue-call-scope.md)
- [`../../../../../src/passes/reorder_locals.mbt`](../../../../../src/passes/reorder_locals.mbt)
- [`../../../../../src/passes/reorder_locals_test.mbt`](../../../../../src/passes/reorder_locals_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
