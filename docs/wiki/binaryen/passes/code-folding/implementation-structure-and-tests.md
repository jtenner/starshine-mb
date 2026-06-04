---
kind: concept
status: supported
last_reviewed: 2026-06-04
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
| Active owner | `src/passes/code_folding.mbt` | `code-folding` owns a real HOT descriptor and narrow direct transform, including explicit named-block value-exit candidate provenance and the June single-result typed block-exit payload/multi-root suffix-sharing slices. |
| Focused tests | `src/passes/code_folding_test.mbt` | current void/value-tail positives, one-block/one-non-block `if` value-suffix positives, typed block-exit branch-payload and multi-root suffix positives, terminal `return`/`unreachable` full-`if` sharing, adjacent no-else `if` plus fallthrough terminal-tail sharing, unsupported `br_on_null` poison negative, live-label suffix bailout, and cleanup regressions are covered. |
| Registry entry | `src/passes/optimize.mbt` | `code-folding` is an active hot-pass registry entry. |
| Dispatcher owner | `src/passes/pass_manager.mbt` | active requests dispatch through `code_folding_run(ctx, func)`. |
| CLI pass-token parsing | `src/cli/cli_test.mbt` | `--code-folding` remains parseable as a kebab-case pass token. |
| CLI ordering preservation | `src/cli/cli_test.mbt` | explicit pass order with `code-folding` is preserved. |
| Backlog slice | `agent-todo.md` `[O4Z-AUDIT-CF]` | The active audit tracks new fixture validation, direct compare, pass-local timing, and late-slot replay deliverables. |
| Canonical scheduler context | `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:33` | The intended late slot sits before the final `merge-blocks` cleanup cluster. |

## What a faithful Starshine test ladder should start with

The detailed local slice order and HOT prerequisite map now live in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md). In short, a future implementation should use the upstream lit families as the first local tests:

1. unnamed `if` arm duplicate-tail positives, including the covered one-block/one-non-block value-suffix orientations
2. named block branch-value positives, keeping the covered single-result plain-`br` payload-root and multi-root suffix cases green and adding multi-value cases only with new tests
3. branch-plus-fallthrough positives, keeping covered void and single-result payload-root / multi-root suffix cases green
4. terminating `return`, `return_call*`, and `unreachable` positives, keeping the covered adjacent no-else `if` plus fallthrough `return`/`unreachable` tails green while adding the full helper-label subset search separately
5. `br_on_*` / unsupported branch poison negatives
6. branch-target-scope and EH-motion negatives
7. late-neighbor interaction with `merge-blocks`, `remove-unused-brs`, `remove-unused-names`, and `rse`

As of the 2026-06-04 O4z audit continuation, focused tests cover the local terminal `return` and `unreachable` full-`if` subset, one `br_on_null` poison negative, a live-label structured suffix bailout, the widened single-result typed named-block plain-`br` payload sharing slice with and without fallthrough, the first safe multi-root named-block payload suffix cases with branch-plus-fallthrough and branch-only tails, the one-block/one-non-block `if` value-suffix positives in both orientations, and the first adjacent no-else `if` plus fallthrough `return`/`unreachable` terminal-tail positives. The latest terminating-tail-adjacent slice is green at `moon test src/passes` (`1596/1596`), direct 1000-case compare (`998` normalized matches, `0` mismatches, `2` `binaryen-rec-group-zero` command failures), and debug-WASI pass-local timing (`187.189ms` Starshine vs `198.305ms` Binaryen). General function-ending helper-label subset/deeper-suffix search, `return_call*`, multi-value branch-payload folding, exact named-unused/unreachable-condition caveats, EH motion, 10000-case compare closeout, and late-neighbor evidence remain open audit items.

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
