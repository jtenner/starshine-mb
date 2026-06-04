---
kind: entity
status: working
last_reviewed: 2026-06-04
sources:
  - ../../../raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md
  - ../../../raw/research/0522-2026-05-06-code-folding-direct-revalidation.md
  - ../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md
  - ../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md
  - ../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md
  - ../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md
  - ../../../raw/research/0112-2026-04-20-code-folding-binaryen-research.md
  - ../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./terminating-tails.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../late-pipeline-dispatch.md
  - ../../no-dwarf-default-optimize-path.md
---

# `code-folding`

## Role

- `code-folding` is an upstream Binaryen late function-cleanup pass.
- It is currently an active narrow HOT pass in Starshine, with owner file [`../../../../../src/passes/code_folding.mbt`](../../../../../src/passes/code_folding.mbt) and focused tests in [`../../../../../src/passes/code_folding_test.mbt`](../../../../../src/passes/code_folding_test.mbt).
- Its job is not generic CSE. Binaryen uses it to merge identical **tails** of code when multiple paths already reach the same semantic exit.

## Why it matters

- The canonical Binaryen no-DWARF function pipeline runs `code-folding` late, right before `merge-blocks` and the late branch-cleanup cluster.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - top-level slot `38`
- The saved Binaryen debug log also shows repeated nested reruns of the same late cluster under optimizing passes, so `code-folding` is not just a one-off top-level detail.
- The repo backlog already treats it as a real parity blocker under slice `CF` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).

## Beginner summary

A safe beginner mental model is:

- find two or more paths that already end in the same place
- check whether the last few instructions are identical
- if moving that identical suffix to one shared place is still safe,
- keep only one copy of the suffix

Binaryen does that in **two** different families:

1. **expression exits**
   - named block exits
   - `if-else` arms
2. **function-ending terminators**
   - `return`
   - `return_call*`
   - `unreachable`

That split is important. The pass is not one generic “merge any duplicate region” algorithm.

## Current durable takeaways

- Binaryen only records block-exit branch tails when the branch is **unconditional** and is the **last child** of its parent block.
- Unsupported branch forms deliberately poison label-based folding. The source comment and tests both call out `br_on_*` as a current bailout family.
- `if` folding only works on unnamed block arms, or on a one-block/one-non-block case where Binaryen can safely wrap the non-block arm in a synthetic block first.
- Binaryen uses a real movement-safety check before hoisting shared code:
  - branch-target scope must remain valid
  - EH-specific `pop` / `throw` movement hazards must remain valid
- The pass is willing to add helper blocks and helper branches when the size heuristic says the fold is worth it.
- After successful rewrites Binaryen may need EH-specific repair through `EHUtils::handleBlockNestedPops(...)`.
- The pass runs to a per-function **fixpoint** because one fold can expose another.
- The folder now has a dedicated implementation/test-map page that points beginners and future porters to Binaryen's owner file, helper surfaces, lit proof families, scheduler location, and exact local Starshine status/code surfaces.
- The folder also has a Starshine port-readiness page that turns the upstream contract into a staged local implementation and validation ladder: narrow expression-exit positives first, source-backed negative gates second, terminating-tail helper-label sharing later, and EH movement only after focused proof.
- Current Starshine has an accepted direct implementation for a narrowed tail-sharing / cleanup subset. The 2026-05-10 refreshed direct lane recorded `6759/10000` compared cases, `6759` normalized matches, `0` semantic mismatches, and `20` Binaryen empty-recursion-group command failures; the direct debug-artifact timing stayed inside the <=2x Binaryen floor, and the focused late cleanup replay did not expose a `code-folding`-specific downstream blocker. The 2026-06-04 O4z audit start added focused terminal-`unreachable`, unsupported `br_on_null`, and live-label suffix fixtures; the continuation widened the pass for single-result typed named-block exits by sharing matching plain-`br` payloads with a fallthrough value or other branch payloads. The follow-up source-matrix/candidate-model slice now also shares single-result multi-root named-block suffixes before the final value root, with tests for branch-plus-fallthrough and branch-only tails. Validation for the latest widened slice is green at `moon test src/passes` (`1592/1592`), a 1000-case direct compare smoke (`998` normalized matches, `0` mismatches), and debug-WASI pass-local timing (`196.213ms` Starshine vs `187.281ms` Binaryen). The June audit still needs 10000-case compare, late-slot evidence, and broader Binaryen behavior-parity slices before `[O4Z-AUDIT-CF]` can close.

## Freshness and provenance

- The latest full 10000-case Starshine direct-pass evidence is the 2026-05-10 refresh: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass code-folding --max-failures 20 --out-dir .tmp/pass-fuzz-code-folding-cf002-terminal-if` with zero semantic mismatches, direct debug-artifact replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1680352`, and focused cleanup replay at `.tmp/cf002-late-cleanup-artifact`. The June 4 single-result typed block-exit payload widening has baseline evidence in [`../../../raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md`](../../../raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md): direct 1000-case compare at `.tmp/pass-fuzz-code-folding-audit-1000` with `998` normalized matches, `0` mismatches, and `2` `binaryen-rec-group-zero` command failures, plus debug-WASI pass-local timing at `.tmp/code-folding-audit-self-compare`. The follow-up multi-root named-block suffix widening has current smoke evidence at `.tmp/pass-fuzz-code-folding-bd-1000` with the same `998` normalized matches, `0` mismatches, and `2` `binaryen-rec-group-zero` command failures, plus debug-WASI pass-local timing at `.tmp/code-folding-bd-self-compare` (`196.213ms` Starshine vs `187.281ms` Binaryen). The earlier 2026-05-06 baseline remains archived in [`../../../raw/research/0522-2026-05-06-code-folding-direct-revalidation.md`](../../../raw/research/0522-2026-05-06-code-folding-direct-revalidation.md).
- The dossier has an immutable tagged raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md).
- On 2026-04-22 the reviewed official Binaryen `version_129` release page showed publish date **2026-04-01**.
- A 2026-05-05 focused current-`main` recheck in [`../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md) did not surface teaching-relevant drift beyond the existing Binaryen pages. The current-main bridge specifically rechecked `CodeFolding.cpp`, `pass.cpp`, `opt-utils.h`, `passes.h`, and `code-folding.wast`.
- A second 2026-04-25 port-readiness manifest in [`../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md) reuses those official primary sources to anchor the local first-slice and validation plan without changing the upstream semantic contract.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: candidate collection, movement safety, expression-tail folding, function-ending tail folding, profitability rules, scheduler placement, and source provenance.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner-file, helper-surface, lit-test, scheduler, and Starshine code-map page for readers who need exact follow-along locations before implementing or validating the pass.
- [`./terminating-tails.md`](./terminating-tails.md)
  Dedicated guide to the easiest part of the pass to misunderstand: how Binaryen folds duplicated `return` / `return_call*` / `unreachable` tails at the end of a function body.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status and expansion-planning bridge: active HOT owner, focused tests, prior direct parity evidence plus required June refresh, backlog slice `CF`, canonical scheduler slot, and the implemented neighboring cleanup passes broader local work must compose with.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Practical expansion-readiness bridge: landed narrow slice, remaining HOT builder / region / label / branch-verification prerequisites, official-test-family-first validation ladder, neighborhood replay plan, and open design questions before broader `code-folding` parity claims.

## Current maintenance rule

- Treat this folder as the canonical home for future `code-folding` research and port planning.
- Keep it explicitly marked as an active narrow direct pass until the broader Binaryen late-slot and artifact replay work is complete; do not treat the direct revalidation as preset-readiness proof.
- New `code-folding` findings should update the Binaryen strategy page, the shape pages, the Starshine status page, and the Starshine port-readiness page together so the upstream algorithm, concrete examples, and local implementation plan stay aligned.

## Sources

- [`../../../raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md`](../../../raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md)
- [`../../../raw/research/0522-2026-05-06-code-folding-direct-revalidation.md`](../../../raw/research/0522-2026-05-06-code-folding-direct-revalidation.md)
- [`../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md)
- [`../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md`](../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md)
- [`../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md`](../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md)
- [`../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md`](../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md)
- [`../../../raw/research/0112-2026-04-20-code-folding-binaryen-research.md`](../../../raw/research/0112-2026-04-20-code-folding-binaryen-research.md)
- [`../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md`](../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodeFolding.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-folding.wast>
