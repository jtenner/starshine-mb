---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0528-2026-05-06-dead-code-elimination-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-dead-code-elimination-current-main-recheck.md
  - ../../../raw/research/0449-2026-05-05-dead-code-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-dead-code-elimination-primary-sources.md
  - ../../../raw/research/0250-2026-04-22-dead-code-elimination-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0203-2026-04-21-dead-code-elimination-source-confirmation-followup.md
  - ../../../../../src/passes/dead_code_elimination.mbt
  - ../../../../../src/passes/dead_code_elimination_test.mbt
  - ../../../../../src/passes/dead_code_elimination_live_repro_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./typed-control-voidification-and-eh.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../vacuum/index.md
  - ../remove-unused-brs/index.md
  - ../remove-unused-names/index.md
---

# Starshine Strategy For `dead-code-elimination`

Use this page together with the fresh current-main bridge in [`../../../raw/binaryen/2026-05-05-dead-code-elimination-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-dead-code-elimination-current-main-recheck.md), the upstream strategy in [`./binaryen-strategy.md`](./binaryen-strategy.md), the source map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), and the exact HOT code map in [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md).

## Current status

`dead-code-elimination` is an active Starshine hot pass. Its refreshed direct compare lane on 2026-05-06 reached 6759 compared cases with 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures under `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dead-code-elimination --out-dir .tmp/pass-fuzz-dead-code-elimination`.

The local strategy is **not** a direct AST port of Binaryen `dce`.
Current Starshine keeps a broader HOT rewrite family that covers:

- unreachable-tail pruning in lifted hot regions
- dead dropped-value cleanup
- explicit unreachable-tail repair where lowering still needs it
- artifact-sensitive payload-forwarder rewrites
- raw-skip heuristics and writeback validation in the hot pipeline manager

That is broader than upstream Binaryen's tiny `TypeUpdater`-centered unreachable-shape postwalk.
The local docs should keep that gap explicit instead of pretending the two contracts are the same.

## Exact local code map today

The quickest read-along path is:

- active pass owner
  - `src/passes/dead_code_elimination.mbt`
    - `dead_code_elimination_descriptor()` and `dead_code_elimination_summary()` at `:2-17`
    - branch-payload forwarder rewrites at `:952-1491`
    - split-drop-control voidification at `:2061-2085`
    - explicit unreachable-tail repair at `:2529-2565`
    - HOT region traversal and pass entry at `:2567-2808`
- active pass-name status
  - `src/passes/optimize.mbt:174`
    - `"dead-code-elimination"` remains an active hot-pass registry entry
  - `src/passes/optimize.mbt:287-299` and `:443-457`
    - repeated late-cluster placement
- dispatch and pipeline guards
  - `src/passes/pass_manager.mbt:8986`
    - dispatcher arm calls `dead_code_elimination_run(ctx, func)`
  - `src/passes/perf_test.mbt:5896-6150`
    - raw-skip trace coverage for `no-dce-candidates`
  - `src/cmd/cmd_wbtest.mbt:5960-7480`
    - CLI and artifact replay guards
- direct proof surfaces
  - `src/passes/dead_code_elimination_test.mbt:33-1543`
    - main HOT rewrite coverage
  - `src/passes/dead_code_elimination_live_repro_test.mbt`
    - artifact-sensitive repros and lowering survival cases

## What Starshine currently claims

Current Starshine `dead-code-elimination` should be read as a HOT-region cleanup pass that:

1. keeps branch-free rewrite opportunities alive inside lifted hot regions;
2. removes dead tails only when the local region proof is already stable;
3. preserves lowered payload forwarding and wrapper shapes until they can be rewritten safely;
4. inserts explicit unreachable tails only when the current lowering shape still needs them;
5. stays honest about raw-skip and writeback failure modes in the surrounding pipeline.

That is a useful Starshine pass, but it is **not** upstream Binaryen's AST contract.

## What this page rules out

Do not use the local Starshine page to claim upstream Binaryen behavior.
The upstream `dce` contract is narrower and should still be read from [`./binaryen-strategy.md`](./binaryen-strategy.md) and [`./typed-control-voidification-and-eh.md`](./typed-control-voidification-and-eh.md).

Do not use the upstream strategy page to erase the local HOT-specific behavior.
The local owner file includes payload-forwarder, split-wrapper, raw-skip, and writeback concerns that are simply not part of Binaryen `version_129` `DeadCodeElimination.cpp`.

## How the local pages fit together

- [`./index.md`](./index.md)
  - durable overview and maintenance rule
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - exact line-by-line HOT code map and integration surfaces
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - upstream source-backed contract
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - owner-file and test-map companion
- [`./typed-control-voidification-and-eh.md`](./typed-control-voidification-and-eh.md)
  - the narrow control/EH explanation for the upstream contract
- [`./wat-shapes.md`](./wat-shapes.md)
  - beginner-friendly shape catalog
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - exact line-by-line HOT code map and integration surfaces

## Bottom line

Current Starshine `dead-code-elimination` is a broader HOT cleanup family with exact code locations, raw-skip heuristics, and writeback guards.
That keeps the pass honest for Starshine today while leaving the upstream Binaryen contract in the right separate page.

## Sources

- [`../../../raw/research/0528-2026-05-06-dead-code-elimination-direct-revalidation.md`](../../../raw/research/0528-2026-05-06-dead-code-elimination-direct-revalidation.md)
- [`../../../raw/binaryen/2026-05-05-dead-code-elimination-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-dead-code-elimination-current-main-recheck.md)
- [`../../../raw/research/0449-2026-05-05-dead-code-elimination-current-main-recheck.md`](../../../raw/research/0449-2026-05-05-dead-code-elimination-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-dead-code-elimination-primary-sources.md`](../../../raw/binaryen/2026-04-22-dead-code-elimination-primary-sources.md)
- [`../../../raw/research/0250-2026-04-22-dead-code-elimination-primary-sources-and-code-map-followup.md`](../../../raw/research/0250-2026-04-22-dead-code-elimination-primary-sources-and-code-map-followup.md)
- [`../../../raw/research/0203-2026-04-21-dead-code-elimination-source-confirmation-followup.md`](../../../raw/research/0203-2026-04-21-dead-code-elimination-source-confirmation-followup.md)
- [`../../../../../src/passes/dead_code_elimination.mbt`](../../../../../src/passes/dead_code_elimination.mbt)
- [`../../../../../src/passes/dead_code_elimination_test.mbt`](../../../../../src/passes/dead_code_elimination_test.mbt)
- [`../../../../../src/passes/dead_code_elimination_live_repro_test.mbt`](../../../../../src/passes/dead_code_elimination_live_repro_test.mbt)
- [`../../../../../src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
