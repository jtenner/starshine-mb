# Wasm Knowledge Base Index

This is the human-readable catalog for living wiki pages under `docs/wiki/`. Update it whenever a durable page is added, renamed, merged, or substantially reframed.

## Schema And Operations

- [`../../AGENTS.md`](../../AGENTS.md) - Short operational contract for repo work and wiki maintenance.
- [`../README.md`](../README.md) - Canonical docs and wiki schema for this repo.
- [`raw/README.md`](raw/README.md) - Rules for committed raw sources.

## Concepts

- [`binaryen/no-dwarf-default-optimize-path.md`](binaryen/no-dwarf-default-optimize-path.md) - Canonical phase split, ordered pass path, and nested rerun rules for Binaryen's no-DWARF `-O` / `-Os` optimize pipeline on the MoonBit debug artifact.
- [`binaryen/passes/remove-unused-brs/returned-ladder-hot-shapes.md`](binaryen/passes/remove-unused-brs/returned-ladder-hot-shapes.md) - Lifted HOT shape guide for the remaining returned-ladder `remove-unused-brs` families.
- [`ir2/execution-plan.md`](ir2/execution-plan.md) - Current IR2 handoff contract, active registry surface, and preferred next slice order for future pass migration.
- [`ir2/pass-porting-checklist.md`](ir2/pass-porting-checklist.md) - Shared helper rules, mutation discipline, and validation floor for porting passes onto the IR2 pipeline.
- [`ir2/registry-map.md`](ir2/registry-map.md) - Current live pass registry categories, preset composition, and the caveat that the original March batch map is now partially stale.
- [`ir2/test-matrix.md`](ir2/test-matrix.md) - Shared helper and golden matrix for deterministic IR2 lift, analysis, lowering, and pass-trace coverage.

## Entities

- No pages yet.

## Decisions

- [`binaryen/passes/reorder-locals/multivalue-call-scope.md`](binaryen/passes/reorder-locals/multivalue-call-scope.md) - Current project decision: non-converging Binaryen multivalue-call writeback stays out of scope for `reorder-locals` parity.
- [`ir2/cfg-contract.md`](ir2/cfg-contract.md) - Normative IR2 CFG boundary, successor, and exceptional-edge policy for `HotFunc`.
- [`ir2/local-ssa-policy.md`](ir2/local-ssa-policy.md) - Normative locals-only SSA overlay policy, phi ownership rule, and predecessor-copy destruction rule.

## Comparisons

- [`binaryen/passes/duplicate-function-elimination/parity.md`](binaryen/passes/duplicate-function-elimination/parity.md) - Current module-wide merge contract, metadata rewrite rules, and remaining artifact parity gap for `duplicate-function-elimination`.
- [`binaryen/passes/heap2local/parity.md`](binaryen/passes/heap2local/parity.md) - Current Binaryen parity surface, in-tree coverage, and remaining fixup gap for `heap2local`.
- [`binaryen/passes/global-struct-inference/parity.md`](binaryen/passes/global-struct-inference/parity.md) - Closed-world direct-global slice, current parity result, and scope limit for `global-struct-inference`.
- [`binaryen/passes/pick-load-signs/parity.md`](binaryen/passes/pick-load-signs/parity.md) - Active rewrite rules, current signoff, and pass-manager fast-skip behavior for `pick-load-signs`.
- [`binaryen/passes/remove-unused-brs/parity.md`](binaryen/passes/remove-unused-brs/parity.md) - Current Binaryen phase model, in-tree coverage, and the remaining final-shape gap for `remove-unused-brs`.
- [`binaryen/passes/reorder-locals/parity.md`](binaryen/passes/reorder-locals/parity.md) - Exact Binaryen ordering rule, module-pass scope, and current stable-boundary signoff rule for `reorder-locals`.
- [`binaryen/passes/remove-unused-names/invalid-tag-index-parser-gap.md`](binaryen/passes/remove-unused-names/invalid-tag-index-parser-gap.md) - Treat `invalid tag index` `remove-unused-names` failures as Binaryen parser-family gaps, not Starshine semantic mismatches.

## Sessions

- No pages yet.
