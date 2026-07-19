---
kind: entity
status: working
last_reviewed: 2026-07-19
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodeFolding.cpp
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
- It is an active, directly parity-closed HOT pass in Starshine, with owner file [`../../../../../src/passes/code_folding.mbt`](../../../../../src/passes/code_folding.mbt), focused tests in [`../../../../../src/passes/code_folding_test.mbt`](../../../../../src/passes/code_folding_test.mbt), and the canonical late O4z slot in both public presets.
- Its job is not generic CSE. Binaryen uses it to merge identical **tails** of code when multiple paths already reach the same semantic exit.

## Why it matters

- The canonical Binaryen no-DWARF function pipeline runs `code-folding` late, right before `merge-blocks` and the late branch-cleanup cluster.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - top-level slot `38`
- The saved Binaryen debug log also shows repeated nested reruns of the same late cluster under optimizing passes, so `code-folding` is not just a one-off top-level detail.
- The repo ledger records the direct pass, canonical slot, external validity, and pass-local performance as closed in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).

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
- The arbitrary-subset terminating-tail search is not a naive repeated tree walk: Binaryen caches each queried candidate root's exiting-branch summary for one fixpoint iteration and lazily computes function-body branch targets once per recursive search. These are performance controls, not replacements for equality, scope, or EH proofs; see [`./terminating-tails.md`](./terminating-tails.md).
- The folder now has a dedicated implementation/test-map page that points beginners and future porters to Binaryen's owner file, helper surfaces, lit proof families, scheduler location, and exact local Starshine status/code surfaces.
- The folder also has a Starshine port-readiness page that turns the upstream contract into a staged local implementation and validation ladder: narrow expression-exit positives first, source-backed negative gates second, terminating-tail helper-label sharing later, and EH movement only after focused proof.
- Current Starshine has an accepted direct implementation for a narrowed tail-sharing / cleanup subset. The 2026-05-10 refreshed direct lane recorded `6759/10000` compared cases, `6759` normalized matches, `0` semantic mismatches, and `20` Binaryen empty-recursion-group command failures; the direct debug-artifact timing stayed inside the <=2x Binaryen floor, and the focused late cleanup replay did not expose a `code-folding`-specific downstream blocker. The 2026-06-04 O4z audit start added focused terminal-`unreachable`, unsupported `br_on_null`, and live-label suffix fixtures; the continuation widened the pass for single-result typed named-block exits by sharing matching plain-`br` payloads with a fallthrough value or other branch payloads. The follow-up source-matrix/candidate-model slice now also shares single-result multi-root named-block suffixes before the final value root, with tests for branch-plus-fallthrough and branch-only tails. The next `if` slice added one-block/one-non-block value-suffix sharing in both orientations, later widened it to both-arm-prefix partial suffixes, full one-block/non-block value-arm folds, full one-block/non-block void-arm folds, full multi-root non-block value-arm folds, the embedded-`select` full-arm and partial typed-wrapper variants, plus the source-backed embedded `drop`, `call`, `call_ref`, `unary`, `binary`, `compare`, `convert`, `load`, `local.set`, `local.tee`, `global.set`, `store`, `br` payload, `br_if` payload/condition, `return`, `return_call`, `return_call_indirect`, `return_call_ref`, `struct.new`, `struct.get`, `struct.get_s`, `struct.get_u`, `array.new`, `array.new_default`, `array.new_fixed`, `array.new_data`, `array.new_elem`, `array.new_elem`, `struct.set`, `array.get`, `array.get_s`, `array.get_u`, `array.len`, `array.set`, `array.fill`, `array.copy`, `array.init_data`, `array.init_elem`, `ref.eq`, `ref.as_non_null`, `any.convert_extern`, `extern.convert_any`, `ref.i31`, `ref.is_null`, `ref.test`, `ref.cast`, `table.get`, `table.set` index, `table.copy` dest, `table.init` dest, `call_indirect`, `memory.grow`, `table.grow`, `table.fill`, `memory.fill`, `memory.copy`, and `memory.init` value-parent typed-wrapper variants, and added a HOT-level unreachable-condition bailout, with public fixture coverage still blocked by local bottom-condition handling. The terminating-tail work now shares adjacent no-else `if` then-tails with immediate fallthrough `return`/`unreachable` tails and also covers a root-anchored helper-label subset for non-adjacent `return`, block-backed `unreachable`, typed-result direct `return_call`, `return_call_indirect`, and core-built `return_call_ref` tails. The latest H/I/J batch added focused `br_table` / outside-target / switch-scope movement negatives, initially chose conservative `try` / `try_table` bailouts for this pass, and reruns the current local root-anchored implementation to fixpoint with a small late-neighborhood helper-label fixture. The June 5 continuation adds exact partial non-block `if` coverage, crossed nested-label movement guards through `return_call_indirect`, a narrow non-terminal `try_table` body `if` suffix fold, `catch_all_ref` terminal-tail bailout classification, source-backed multi-value named-block payload coverage including a branch-only/unreachable-fallback variant, and nested self-branching non-null `return_call_ref` coverage while keeping EH movement/repair and terminal-tail collection across EH boundaries open. A later invalid-output fix batch preserves bottom sentinels in typed result regions, avoids flattening multi-result dead wrappers, fixes HOT lift arity for branches to the implicit function label, and clears the validator bottom stack on repeated unreachable/branch escapes. Focused validation is green after the source-backed embedded miscellaneous heap value-parent increment, with `moon test src/passes` (`1730/1730`), `moon fmt`, `moon info`, full `moon test` (`4915/4915`), and native `src/cmd` build passing; the latest direct smoke is `.tmp/pass-fuzz-code-folding-misc-heap-parents-1000` with `998/1000` compared cases, `998` normalized matches, `0` mismatches, and `2` tool/Binaryen command failures. The latest large lane remains `.tmp/pass-fuzz-code-folding-table-memory-bulk-100000-maxfail2000` / the earlier `.tmp/pass-fuzz-code-folding-100000-after-td-fixes` family evidence with `0` Starshine command failures, `0` validation failures, tool/Binaryen command failures only, and `5` agent-classified semantic-safe representation/cleanup mismatches; replay at `.tmp/pass-fuzz-code-folding-replay-5-pure-drop-cleanup` fixed the only two raw-size-detrimental inspected families (`023083` and `082547`) while keeping those semantic-safe text-shape mismatches documented. `[O4Z-AUDIT-CF-E]` is closed for feasible if expression-exit breadth with local caveats documented in the research note. The June audit still needs generated late-slot evidence, arbitrary non-root subset parity, exact helper cost/fixpoint parity, broader Binaryen behavior-parity slices, timing recovery/attribution, and a final decision to fix or accept the remaining documented mismatch families before `[O4Z-AUDIT-CF]` can close.

## 2026-07-19 superseding status

The current implementation removes the former whole-function, arm, candidate, and embedded-control search limits; accepts structured terminating payloads under the same movement checks; uses Binaryen's helper-cost profitability boundary; and emits Binaryen's terminating-tail wrapper/return shape. Focused coverage is `193/193` and includes large searches, structured payloads, helper-cost boundaries, EH, multivalue, named/unnamed exits, expression parents, and an intentional typed-tail-region block-exit bailout.

The externally validated direct four-lane matrix is green for every compared case: regular GenValid `100000/100000`, dedicated `code-folding-all` `10000/10000`, and random all-profiles `10000/10000`; explicit wasm-smith compared `9956/10000` with zero mismatches or validation failures and 44 classified Binaryen/tool failures. See [`./fuzzing.md`](./fuzzing.md) for the v131-prefixed artifacts and the post-performance replay. The typed-tail validity incident and retained performance changes are summarized below and in [`../../../log.md`](../../../log.md).

Both public presets schedule `code-folding` in the exact late sequence `vacuum -> code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks`, protected by an exact-order test. Direct semantics, external validity, and scheduling are closed. The effectful neighborhood replay still exposes downstream cleanup-shape gaps in `merge-blocks` / branch cleanup for block-exit and EH fixtures; those are classified preset-neighborhood evidence rather than direct `code-folding` behavior gaps.

Pass-local performance is closed under the ordinary `<=2x` floor. Five-run medians from the final current native binary are `7.582 ms` Starshine vs `4.450 ms` Binaryen v131 (`1.70x`) on the exact-equality candidate-heavy fixture and `677.087 ms` vs `341.391 ms` (`1.98x`) on the externally validating large debug artifact. Candidate raw and canonical outputs are byte-identical; the large Starshine canonical output remains `63862` bytes (`1.35%`) smaller.

## Freshness and provenance

- The latest direct evidence is the externally validated 2026-07-19 four-lane refresh documented in [`./fuzzing.md`](./fuzzing.md), followed by the rebuilt post-rebase `code-folding-all` replay at `.tmp/pass-fuzz-code-folding-post-rebase-current-10000`. Older audit evidence below is retained as historical progression, not current status.
- The previous full 10000-case Starshine direct-pass evidence was the 2026-05-10 refresh: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass code-folding --max-failures 20 --out-dir .tmp/pass-fuzz-code-folding-cf002-terminal-if` with zero semantic mismatches, direct debug-artifact replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1680352`, and focused cleanup replay at `.tmp/cf002-late-cleanup-artifact`. Subsequent June widening and invalid-output repairs are preserved in git history and the artifact names recorded on this page; the July closeout supersedes their earlier partial status.
- The 2026-04-22 tagged `version_129` source recheck has been ingested; its direct primary-source URLs remain in [`./binaryen-strategy.md`](./binaryen-strategy.md), with a retained current-main bridge below.
- On 2026-04-22 the reviewed official Binaryen `version_129` release page showed publish date **2026-04-01**.
- The retained 2026-05-05 research recheck did not surface teaching-relevant drift beyond the existing Binaryen pages; it reviewed `CodeFolding.cpp`, `pass.cpp`, `opt-utils.h`, `passes.h`, and `code-folding.wast`. The later 2026-07-11 current-main performance recheck remains the newest retained raw bridge.
- The retained 2026-04-25 port-readiness research reuses those official primary sources to anchor the local first-slice and validation plan without changing the upstream semantic contract.

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
- Keep direct semantic parity, external validity, preset scheduling, and pass-local performance marked closed under the 2026-07-19 evidence.
- New `code-folding` findings should update the Binaryen strategy page, the shape pages, the Starshine status page, and the Starshine port-readiness page together so the upstream algorithm, concrete examples, and local implementation plan stay aligned.

## Sources

- research note 0713
- research note 0522
- research note 0373
- research note 0351
- research note 0442
- research note 0112
- research note 0257
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodeFolding.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-folding.wast>
