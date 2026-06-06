---
kind: concept
status: supported
last_reviewed: 2026-06-06
sources:
  - ../../../raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md
  - ../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md
  - ../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md
  - ../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md
  - ../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md
  - ../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./terminating-tails.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../no-dwarf-default-optimize-path.md
---

# `code-folding` implementation structure and tests

This page maps the upstream Binaryen owner files, helper surfaces, official tests, and current Starshine code/status surfaces for `code-folding`.
Read it when you want to move from the conceptual pages to exact files.

## Status in one sentence

Binaryen implements `code-folding` as a function-parallel pass in `src/passes/CodeFolding.cpp`; Starshine now has an active narrow HOT implementation in `src/passes/code_folding.mbt` with focused coverage in `src/passes/code_folding_test.mbt`.

## Upstream owner map

| Surface | Role | Why it matters |
| --- | --- | --- |
| Binaryen `src/passes/CodeFolding.cpp` | Main implementation | Owns candidate collection, expression-exit folding, function-ending tail folding, profitability, helper-block creation, and per-function fixpoint iteration. |
| Binaryen `src/passes/pass.cpp` | Pass registration and scheduler placement | Creates the public `code-folding` pass and places it in the late function-cleanup sequence used by optimization presets. |
| Binaryen `src/passes/passes.h` | Pass-constructor declaration | Keeps `code-folding` as a public pass constructor rather than a private helper. |
| Binaryen `src/passes/opt-utils.h` | Neighboring optimize helper context | Shows how late cleanup helpers compose around inlining and repeated optimization clusters. |
| Binaryen `test/lit/passes/code-folding.wast` | Dedicated behavior proof | Exercises the positive, negative, and movement-safety shapes that should seed any Starshine port tests. |

Primary current-main URLs are captured in [`../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md). The tagged `version_129` source anchor remains [`../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md). The implementation-readiness recheck and Starshine test ladder now live in [`../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md) and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Binaryen implementation structure

### 1. Function-level pass wrapper

`CodeFolding.cpp` defines a function-parallel pass. The function-level wrapper is important because all candidate maps, modified-subtree tracking, helper-label creation, and fixpoint retries are scoped to one function at a time.

Beginner takeaway: this is not a whole-module deduplication pass. It folds duplicate tails *inside each function*.

### 2. Candidate collection during the walk

The source records several different candidate families:

- unconditional block-ending branches to named block exits
- possible block fallthrough tails for the same exit
- foldable unnamed `if` arm blocks
- function-ending `return` tails
- `return_call`, `return_call_indirect`, and `return_call_ref` tails
- `unreachable` tails

Unsupported branching instructions that target a label mark that label unoptimizable for label-based folding. The living strategy page explains that as the `br_on_*` poison rule; the implementation/test map matters because the dedicated lit file keeps this negative family concrete.

### 3. Expression-exit folding

The expression-exit path matches duplicate suffixes that already flow to the same expression exit:

- named block exits
- foldable `if-else` arms

It compares suffixes from the end backward, checks movement safety, applies profitability heuristics, strips duplicate suffixes from the old tails, and inserts one shared suffix after the expression.

The important implementation boundary is that equality is never enough by itself. Movement safety checks still reject folds that would strand branch targets or move EH-sensitive code through a scope where it no longer belongs.

### 4. Function-ending tail folding

The terminating-tail path is a separate algorithm.
It searches for profitable common suffixes among tails that already end a function path:

- `return`
- `return_call*`
- `unreachable`

When it commits, Binaryen builds helper label structure near the end of the function body and rewrites the selected old tails to branch to the shared suffix. See [`./terminating-tails.md`](./terminating-tails.md) for the detailed mental model.

### 5. EH repair and fixpoint iteration

A successful fold may add block structure. When that happens in EH-sensitive code, Binaryen can run nested-pop repair before trying another iteration.

The pass loops because one fold can expose another. A faithful local port should not assume one walk is enough.

## Official test surface

Binaryen's central proof file is:

- `test/lit/passes/code-folding.wast`

The behavior families to preserve are:

| Test family | What it proves | Local port implication |
| --- | --- | --- |
| Identical unnamed `if` arm blocks | Simple expression-exit tails can move out of the `if` | Add reduced WAT tests before implementing broader shapes. |
| Branch-value tails | A branch payload can be shared while the branch shell remains | Do not model the pass as branch deletion. |
| Branch plus fallthrough to a named block | Explicit exits and normal fallthrough can share the same suffix | Candidate collection needs both tail kinds. |
| Terminating `return` / `unreachable` tails | Function-ending suffixes use helper-label sharing | Implement this separately from block/`if` folding. |
| `br_on_*` / unsupported branch targets | Unsupported branch forms poison label folding | Keep negative tests early; do not silently broaden label motion. |
| Outside-target bailout cases | Equal-looking tails may still be unsafe to move | Movement-safety tests are correctness tests, not just optimization quality tests. |

## Current Starshine code map

Starshine implements an active narrowed transform, and the current status is represented in code and docs.

| Local surface | Exact location | Meaning |
| --- | --- | --- |
| Active owner | `src/passes/code_folding.mbt` | `code-folding` owns a real HOT descriptor and narrow direct transform, including explicit named-block value-exit candidate provenance, the June typed block-exit payload/multi-root suffix-sharing slices plus the first multi-value branch-plus-fallthrough and branch-only/unreachable-fallback payload suffixes, HOT-level `if` unreachable-condition bailout, two-unnamed-block `if` value-suffix sharing including a multi-root suffix case, widened one-block/non-block suffix matching for both-arm-prefix, full-value block, full-void block, full multi-root non-block value, and embedded value-parent full/partial typed-wrapper cases for `select`, `drop`, `call`, `unary`, `binary`, `compare`, `convert`, `load`, `local.set`, `local.tee`, `global.set`, `store`, `br` payload, `return`, `ref.is_null`, `table.get`, `table.set` index, `call_indirect`, `memory.grow`, `table.grow`, `table.fill`, `memory.fill`, `memory.copy`, and `memory.init` parents, the simple full-value non-block/non-block `if` no-op boundary, the root-anchored terminating-tail helper-label candidate model with local fixpoint reruns, focused movement-safety gates including narrow nested internal-label self-branching suffix cases for `return`, `unreachable`, `return_call`, `return_call_indirect`, and `return_call_ref`, crossed-label guards for `return`/`unreachable`/`return_call`/`return_call_indirect` plus tail-call operand-only profitability guards, simple result direct/indirect tail-call sibling bailout coverage, narrow non-terminal EH-body `if` suffix folding with `catch_all`, explicit-`catch`, and nested `try_table` text coverage, plus conservative EH boundary bailouts including checked `catch_ref` and `catch_all_ref` terminal tails. |
| Focused tests | `src/passes/code_folding_test.mbt` | current void/value-tail positives, one-block/one-non-block and two-unnamed-block `if` value-suffix positives and the two-block void suffix positive including both one-block multi-root value suffix orientations, both-arm-prefix one-block partial suffixes, full one-block value-arm and void-arm folding, full multi-root non-block value-arm and embedded value-parent full/partial typed-wrapper folding, the simple full-value non-block/non-block `if` no-op, typed block-exit branch-payload, multi-root, and first multi-value fallthrough/branch-only suffix positives, terminal `return`/`unreachable` full-`if` sharing, adjacent no-else `if` plus fallthrough terminal-tail sharing, root-anchored non-adjacent `return`, block-backed `unreachable`, direct `return_call`, `return_call_indirect`, and core-built `return_call_ref` positives, nested internal-label self-branching suffix sharing for `return`, `unreachable`, `return_call`, `return_call_indirect`, and `return_call_ref`, root-anchored fixpoint and small late-neighborhood fixtures including a simple direct tail-call bailout neighborhood, unsupported `br_on_null` / `br_if` / `br_table` poison negatives, outside-target, crossed-label, live-label, and careful-switch movement negatives, `catch_all`, explicit-`catch`, and nested non-terminal `try_table` body `if` suffix positives, `try_table` EH bailout negatives including the outer-`catch_all`, `catch_ref`, and `catch_all_ref` terminal-tail shapes, and cleanup regressions are covered. |
| Registry entry | `src/passes/optimize.mbt` | `code-folding` is an active hot-pass registry entry. |
| Dispatcher owner | `src/passes/pass_manager.mbt` | active requests dispatch through `code_folding_run(ctx, func)`. |
| CLI pass-token parsing | `src/cli/cli_test.mbt` | `--code-folding` remains parseable as a kebab-case pass token. |
| CLI ordering preservation | `src/cli/cli_test.mbt` | explicit pass order with `code-folding` is preserved. |
| Backlog slice | `agent-todo.md` `[O4Z-AUDIT-CF]` | The active audit tracks new fixture validation, direct compare, pass-local timing, and late-slot replay deliverables. |
| Canonical scheduler context | `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:33` | The intended late slot sits before the final `merge-blocks` cleanup cluster. |

## What a faithful Starshine test ladder should start with

The detailed local slice order and HOT prerequisite map now live in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md). In short, a future implementation should use the upstream lit families as the first local tests:

1. unnamed `if` arm duplicate-tail positives, including the covered exact partial non-block value suffix, one-block/one-non-block value-suffix orientations plus both-arm-prefix/full-value block cases, and two-unnamed-block single-root and multi-root value-suffix cases
2. named block branch-value positives, keeping the covered single-result plain-`br` payload-root, multi-root suffix, and first multi-value payload suffix cases green and adding broader multi-value cases only with new tests
3. branch-plus-fallthrough positives, keeping covered void, single-result payload-root / multi-root suffix, and first multi-value suffix cases green
4. terminating `return`, `return_call*`, and `unreachable` positives, keeping the covered adjacent no-else `if` plus fallthrough and root-anchored helper-label subsets green while adding arbitrary non-root subset search separately
5. `br_on_*` / unsupported branch poison negatives
6. branch-target-scope and EH-motion negatives
7. late-neighbor interaction with `merge-blocks`, `remove-unused-brs`, `remove-unused-names`, and `rse`

As of the 2026-06-05 O4z audit continuation, focused tests cover the local terminal `return` and `unreachable` full-`if` subset, the simple full-value non-block `if` no-op, `br_on_null`, `br_if`, and `br_table` poison negatives, outside-target, crossed-label, live-label, and careful-switch movement negatives, `try_table` terminal/block-exit EH bailout negatives plus the explicit outer-`catch_all` and `catch_all_ref` terminal-tail bailouts matched to Binaryen, `catch_all`, explicit-`catch`, and nested non-terminal `try_table` body `if` suffix positives, the widened single-result typed named-block plain-`br` payload sharing slice with and without fallthrough, the first safe multi-root named-block payload suffix cases with branch-plus-fallthrough and branch-only tails, source-backed multi-value branch-plus-fallthrough and branch-only/unreachable-fallback payload suffixes, the exact partial non-block value-arm fixture, the one-block/one-non-block `if` value-suffix positives in both orientations plus both source-backed multi-root orientations, both-arm-prefix partial suffixes, full one-block value-arm folding, full one-block void-arm folding, full multi-root non-block value-arm plus embedded `select`, `drop`, `call`, `unary`, `binary`, `compare`, `convert`, `load`, `local.set`, `local.tee`, `global.set`, `store`, `br` payload, `return`, `ref.is_null`, `table.get`, `table.set` index, `call_indirect`, `memory.grow`, `table.grow`, `table.fill`, `memory.fill`, `memory.copy`, and `memory.init` typed-wrapper folding, and two-block void-arm suffix folding, the two-unnamed-block `if` value-suffix positives and the two-block void suffix positive including a multi-root shared `call`/value suffix, the first adjacent no-else `if` plus fallthrough `return`/`unreachable` terminal-tail positives, the root-anchored helper-label subset for non-adjacent `return`, block-backed `unreachable`, typed-result direct `return_call`, `return_call_indirect`, and core-built `return_call_ref` tails, nested internal-label self-branching suffix positives for `return`, `unreachable`, `return_call`, `return_call_indirect`, and `return_call_ref`, crossed nested-label guards for `return`, `unreachable`, `return_call`, and `return_call_indirect`, a root-anchored fold-exposes-fold fixpoint, and a small late-neighborhood helper-label fixture. The invalid-output fix continuation added focused tests for bottom-tail preservation and typed-dead cleanup around multi-result blocks, loops, `try_table`, root typed debris, and branches after typed dead operands. Latest focused validation is green at `moon test src/passes` (`1724/1724`) after the embedded direct/indirect `return_call` value-parent suffix breadth fix; `moon fmt`, `moon info`, and full `moon test` passed (`4909/4909`), and direct 1000-case compare at `.tmp/pass-fuzz-code-folding-return-call-parents-1000` had `998` normalized matches, `0` mismatches, and `2` tool/Binaryen command failures. The latest large direct smoke at `.tmp/pass-fuzz-code-folding-100000-after-td-fixes` compared `99747/100000` cases with `99742` normalized matches, `0` Starshine command failures, `0` validation failures, `253` tool/Binaryen command failures, and `5` agent-classified semantic-safe size-winning representation/cleanup mismatches after the `046375` follow-up. The pass-local timing blocker from the `046375` check remains open under `[O4Z-AUDIT-CF-L]`. Arbitrary non-root terminating-tail subset search, broader multi-value branch-payload folding, exact named-unused/unreachable-condition public fixtures, broader EH motion/repair, final mismatch acceptance decisions, pass-local timing recovery/attribution, and generated late-neighbor evidence remain open audit items.

After reduced tests are green, use the pass parity workflow from `AGENTS.md`: compare `--pass code-folding` against Binaryen, then replay the canonical no-DWARF late slot and generated-artifact cases.

## Non-goals to keep explicit

Do not document or implement `code-folding` as any of these:

- whole-module function deduplication
- generic common subexpression elimination
- arbitrary CFG region merging
- branch deletion
- an always-profitable structural cleanup

The source-backed contract is narrower: duplicate *tails* that already share an exit can be moved to one shared suffix only when equality, movement safety, and size heuristics all agree.

## Sources

- [`../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md)
- [`../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md`](../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md)
- [`../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md`](../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md)
- [`../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md`](../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md)
- Binaryen current `main` `CodeFolding.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodeFolding.cpp>
- Binaryen current `main` `code-folding.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-folding.wast>
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
