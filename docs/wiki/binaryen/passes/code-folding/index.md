---
kind: entity
status: working
last_reviewed: 2026-06-06
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
- Current Starshine has an accepted direct implementation for a narrowed tail-sharing / cleanup subset. The 2026-05-10 refreshed direct lane recorded `6759/10000` compared cases, `6759` normalized matches, `0` semantic mismatches, and `20` Binaryen empty-recursion-group command failures; the direct debug-artifact timing stayed inside the <=2x Binaryen floor, and the focused late cleanup replay did not expose a `code-folding`-specific downstream blocker. The 2026-06-04 O4z audit start added focused terminal-`unreachable`, unsupported `br_on_null`, and live-label suffix fixtures; the continuation widened the pass for single-result typed named-block exits by sharing matching plain-`br` payloads with a fallthrough value or other branch payloads. The follow-up source-matrix/candidate-model slice now also shares single-result multi-root named-block suffixes before the final value root, with tests for branch-plus-fallthrough and branch-only tails. The next `if` slice added one-block/one-non-block value-suffix sharing in both orientations, later widened it to both-arm-prefix partial suffixes, full one-block/non-block value-arm folds, full one-block/non-block void-arm folds, full multi-root non-block value-arm folds, the embedded-`select` full-arm and partial typed-wrapper variants, plus the source-backed embedded `drop`, `call`, `call_ref`, `unary`, `binary`, `compare`, `convert`, `load`, `local.set`, `local.tee`, `global.set`, `store`, `br` payload, `br_if` payload/condition, `return`, `return_call`, `return_call_indirect`, `return_call_ref`, `struct.new`, `struct.get`, `struct.get_s`, `struct.get_u`, `array.new`, `array.new_default`, `array.new_fixed`, `array.new_data`, `array.new_elem`, `array.new_elem`, `struct.set`, `array.get`, `array.get_s`, `array.get_u`, `array.len`, `array.set`, `array.fill`, `array.copy`, `array.init_data`, `array.init_elem`, `ref.eq`, `ref.as_non_null`, `any.convert_extern`, `extern.convert_any`, `ref.i31`, `ref.is_null`, `ref.test`, `ref.cast`, `table.get`, `table.set` index, `table.copy` dest, `table.init` dest, `call_indirect`, `memory.grow`, `table.grow`, `table.fill`, `memory.fill`, `memory.copy`, and `memory.init` value-parent typed-wrapper variants, and added a HOT-level unreachable-condition bailout, with public fixture coverage still blocked by local bottom-condition handling. The terminating-tail work now shares adjacent no-else `if` then-tails with immediate fallthrough `return`/`unreachable` tails and also covers a root-anchored helper-label subset for non-adjacent `return`, block-backed `unreachable`, typed-result direct `return_call`, `return_call_indirect`, and core-built `return_call_ref` tails. The latest H/I/J batch added focused `br_table` / outside-target / switch-scope movement negatives, initially chose conservative `try` / `try_table` bailouts for this pass, and reruns the current local root-anchored implementation to fixpoint with a small late-neighborhood helper-label fixture. The June 5 continuation adds exact partial non-block `if` coverage, crossed nested-label movement guards through `return_call_indirect`, a narrow non-terminal `try_table` body `if` suffix fold, `catch_all_ref` terminal-tail bailout classification, source-backed multi-value named-block payload coverage including a branch-only/unreachable-fallback variant, and nested self-branching non-null `return_call_ref` coverage while keeping EH movement/repair and terminal-tail collection across EH boundaries open. A later invalid-output fix batch preserves bottom sentinels in typed result regions, avoids flattening multi-result dead wrappers, fixes HOT lift arity for branches to the implicit function label, and clears the validator bottom stack on repeated unreachable/branch escapes. Focused validation is green after the source-backed embedded miscellaneous heap value-parent increment, with `moon test src/passes` (`1730/1730`), `moon fmt`, `moon info`, full `moon test` (`4915/4915`), and native `src/cmd` build passing; the latest direct smoke is `.tmp/pass-fuzz-code-folding-misc-heap-parents-1000` with `998/1000` compared cases, `998` normalized matches, `0` mismatches, and `2` tool/Binaryen command failures. The latest large lane remains `.tmp/pass-fuzz-code-folding-table-memory-bulk-100000-maxfail2000` / the earlier `.tmp/pass-fuzz-code-folding-100000-after-td-fixes` family evidence with `0` Starshine command failures, `0` validation failures, tool/Binaryen command failures only, and `5` agent-classified semantic-safe representation/cleanup mismatches; replay at `.tmp/pass-fuzz-code-folding-replay-5-pure-drop-cleanup` fixed the only two raw-size-detrimental inspected families (`023083` and `082547`) while keeping those semantic-safe text-shape mismatches documented. The June audit still needs generated late-slot evidence, arbitrary non-root subset parity, exact helper cost/fixpoint parity, broader Binaryen behavior-parity slices, timing recovery/attribution, and a final decision to fix or accept the remaining documented mismatch families before `[O4Z-AUDIT-CF]` can close.

## Freshness and provenance

- The latest full 10000-case Starshine direct-pass evidence is the 2026-05-10 refresh: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass code-folding --max-failures 20 --out-dir .tmp/pass-fuzz-code-folding-cf002-terminal-if` with zero semantic mismatches, direct debug-artifact replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1680352`, and focused cleanup replay at `.tmp/cf002-late-cleanup-artifact`. The June 4 single-result typed block-exit payload widening has baseline evidence in [`../../../raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md`](../../../raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md): direct 1000-case compare at `.tmp/pass-fuzz-code-folding-audit-1000` with `998` normalized matches, `0` mismatches, and `2` `binaryen-rec-group-zero` command failures, plus debug-WASI pass-local timing at `.tmp/code-folding-audit-self-compare`. The follow-up multi-root named-block suffix widening has smoke evidence at `.tmp/pass-fuzz-code-folding-bd-1000` with the same `998` normalized matches, `0` mismatches, and `2` `binaryen-rec-group-zero` command failures, plus debug-WASI pass-local timing at `.tmp/code-folding-bd-self-compare` (`196.213ms` Starshine vs `187.281ms` Binaryen). The one-block/one-non-block `if` widening has smoke evidence at `.tmp/pass-fuzz-code-folding-e-1000` with `998` normalized matches, `0` mismatches, and `2` `binaryen-rec-group-zero` command failures, plus debug-WASI pass-local timing at `.tmp/code-folding-e-self-compare` (`208.362ms` Starshine vs `185.945ms` Binaryen). The adjacent `return`/`unreachable` terminal-tail widening has smoke evidence at `.tmp/pass-fuzz-code-folding-f-1000` with `998` normalized matches, `0` mismatches, and `2` `binaryen-rec-group-zero` command failures, plus debug-WASI pass-local timing at `.tmp/code-folding-f-self-compare` (`187.189ms` Starshine vs `198.305ms` Binaryen). The root-anchored `return` / `unreachable` / `return_call*` terminal-tail widening has smoke evidence at `.tmp/pass-fuzz-code-folding-fg-1000` with `998` normalized matches, `0` mismatches, and `2` `binaryen-rec-group-zero` command failures, plus debug-WASI pass-local timing at `.tmp/code-folding-fg-self-compare` (`210.383ms` Starshine vs `187.861ms` Binaryen, within <=2x). The H/I/J movement-safety, EH-bailout, and local-fixpoint batch has current smoke evidence at `.tmp/pass-fuzz-code-folding-hij-1000` with `998` normalized matches, `0` mismatches, and `2` `binaryen-rec-group-zero` command failures, plus debug-WASI pass-local timing at `.tmp/code-folding-hij-self-compare` (`231.629ms` Starshine vs `195.691ms` Binaryen, within <=2x). The latest invalid-output fix and large-smoke evidence lives in [`../../../raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md`](../../../raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md): `.tmp/pass-fuzz-code-folding-100000-after-td-fixes` reached `99742` normalized matches, `5` documented semantic-safe mismatches, `0` Starshine command/validation failures, and `253` tool/Binaryen command failures. The latest embedded direct/indirect `return_call` value-parent 1000-case smoke is `.tmp/pass-fuzz-code-folding-misc-heap-parents-1000` with `998` normalized matches, `0` mismatches, and `2` tool/Binaryen command failures; the preceding replay of the requested five mismatch families at `.tmp/pass-fuzz-code-folding-replay-5-pure-drop-cleanup` kept five semantic-safe text-shape mismatches but made the two raw-size-detrimental families raw-size-winning. The earlier 2026-05-06 baseline remains archived in [`../../../raw/research/0522-2026-05-06-code-folding-direct-revalidation.md`](../../../raw/research/0522-2026-05-06-code-folding-direct-revalidation.md).
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
