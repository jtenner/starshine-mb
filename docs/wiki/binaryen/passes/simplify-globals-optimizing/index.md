---
kind: entity
status: supported
last_reviewed: 2026-07-07
sources:
  - ../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md
  - ../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md
  - ../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md
  - ../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./linear-traces-read-only-to-write-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-globals/index.md
  - ../propagate-globals-globally/index.md
  - ../inlining-optimizing/index.md
  - ../remove-unused-module-elements/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `simplify-globals-optimizing`

## Role

- `simplify-globals-optimizing` is an upstream Binaryen late global optimizing pass.
- It is **implemented and audit-complete for the current Binaryen `version_130` / Starshine v0.1.0 scope** as an active module pass in [`../../../../../src/passes/simplify_globals_optimizing.mbt`](../../../../../src/passes/simplify_globals_optimizing.mbt), with registry and dispatcher wiring in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) and [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt). The exact local contract, source-backed exclusions, and reopening criteria live in [`./starshine-strategy.md`](./starshine-strategy.md).
- Binaryen also exposes the related plain pass name `simplify-globals`.
- The `simplify-globals-optimizing` variant is the same core global pass **plus** a nested rerun of the default function optimization pipeline on changed functions.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` post-pass phase runs `simplify-globals-optimizing` after `duplicate-import-elimination` and before `remove-unused-module-elements`.
- The saved generated-artifact `-O4z` audit records one real skipped top-level upstream slot:
  - top-level slot `52`
- The saved debug log also shows that this pass is bigger than one top-level name suggests. The committed audit note [`0093`](../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md) preserves the generated-artifact summary and debug-log replay facts; between top-level `simplify-globals-optimizing` and the next top-level `remove-unused-module-elements`, repo-local counting over the original log found:
  - `3` nested pass batches
- The backlog already tracks this as slice `SGO` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- It is also the remaining late boundary/global cleanup dossier nearest the freshly documented late neighbors:
  - `dae-optimizing`
  - `inlining-optimizing`
  - `duplicate-import-elimination`
  - `simplify-globals-optimizing`
  - `remove-unused-module-elements`
  - `string-gathering`
  - `reorder-globals`

## Beginner summary

A safe beginner mental model is:

- scan the whole module to learn which globals are really observed,
- fold single-use globals into later global initializers when that is still one-time work,
- remove writes whose value never matters,
- canonicalize immutable copy chains,
- propagate known values through later global initializers and segment offsets,
- propagate known values through function code only when the current runtime trace is still simple,
- then rerun normal function cleanup on the functions that changed.

That is much closer to the real Binaryen pass than “replace constant `global.get`s.”

## Current durable takeaways

- The reviewed official Binaryen `version_129` release page on 2026-04-24 showed publish date **2026-04-01**; the retained 2026-04-24 research inventory, direct source URLs, and [`../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md`](../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md) retain the exact source, lit-test, and current-main port-readiness record for this folder. The 2026-05-18 refresh in [`../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md`](../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md) rechecked official Binaryen `main` at commit `d3029d2b975488acdf9253eb2994a3fc55bd3549` (committer date 2026-05-15) and found no SGO semantic drift from the `version_129` contract; the only `SimplifyGlobals.cpp` changes were comment typo fixes. The 2026-07-06 audit kickoff in [`../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md`](../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md) refreshed the behavior-family matrix against official Binaryen `version_130` source/lit surfaces and found the next local blocker is Starshine coverage/signoff, not known upstream SGO churn.
- `simplify-globals-optimizing` is a **module / boundary** pass, not a function-local peephole.
- The pass has several distinct algorithm families, not one:
  - practical-immutability discovery
  - single-use global-init folding
  - dead or redundant `global.set` removal
  - `read-only-to-write` elimination
  - immutable copy-chain canonicalization
  - startup-time constant propagation into later globals and offsets
  - runtime constant propagation into function code with a cheap linear-trace model
- The `optimizing` part really matters: Binaryen reruns the default function optimization pipeline on changed functions after constant replacement or removed writes.
- That nested rerun is **not** the same helper used by `dae-optimizing` and `inlining-optimizing`:
  - it does **not** prepend `precompute-propagate`
  - it reruns per changed function through a nested `PassRunner`
- Imports, exports, actual calls, nonlinear control flow, and type mismatches are major bailout or conservatism families.
- The active Starshine slice preserves both halves narrowly:
  - a first module-owned global rewrite algorithm for private never-written globals, single-use initializer folding into later globals, exact-type immutable copy-chain canonicalization, never-read, single-const same-as-init/ref-null/ref.func same-as-init guardrails including defined `global.get`/alias-init one-pass/two-pass and imported/exported boundary coverage, now including funcref and externref alias chains, and adjacent/eqz/bidirectional compare-const/simple-pure-condition (including i32 unary/bitwise/shift-rotate ops, i64 equality/compare and non-trapping value ops, f32/f64 compares, non-trapping f32/f64 value operators, non-trapping numeric conversion/reinterpret/sign-extension/trunc_sat operators, non-trapping `ref.is_null` / `ref.eq` predicates, and `local.get` pure operands), transparent, nested, block-wrapped-pure-condition, block-yielded-condition, block-yielded operators after pure block condition bodies, block-yielded external pure-condition chains, block-yielded short external pure operators, block-yielded reverse external pure operators, no-op-condition-prefix, const-drop-body, the 2026-07-06 source-backed safe-side-effect result-`if` arm read-only-to-write subset including pure arm-local value flow, pure post-result value flow before the final guarded-write condition, the function-level if-return/set variant, a nested result-if-arm value-flow subset, and nested result-if-arm pure-suffix value flow, the first official side-effecting `select` value-flow subset with independent load/local.tee operand effects, now including the official `select` result through `i32.eqz` before the guarded write and the function-level `if return; set` variant, plus the source-backed independent-call, independent memory-op, independent table-op, and independent constant-local-tee first/second-operand `select` subsets including their if-return variants, independent-call, independent memory-op, independent table-op, and independent constant-local-tee compare operand guarded-write and if-return subsets, plus the block-prefix independent-call (zero-parameter/result and zero-parameter/void), independent memory-op, independent table-op (table.size/table.grow/table.set/table.fill/table.copy/table.init/elem.drop), independent local-write, and independent global-write condition subsets and their if-return variants, and the official nested-thrice block-condition carveout where a nested same-global guard prefix safely yields the final same-global read, plus the official multi-global nested-body carveout where nested different-global guards surround the guarded constant write, plus exact/eqz/bidirectional compare/pure-condition/block-wrapped-condition/block-wrapped-pure-condition/nested-block-wrapped-condition/block-yielded-condition/block-yielded-condition+set/block-yielded operators after pure block condition bodies/block-yielded external pure-condition chains/block-yielded short external pure operators/block-yielded reverse external pure operators/block-wrapped-set/block-wrapped-condition+set `if return; set` dead writes, supported constant global reads including typed `ref.null` / typed externref-null direct-alias-block-result / direct, alias, and block-result `ref.func` function-body replacements, startup constants in table/global/offset module expressions, typed element item-expression preservation for refinalization safety, and straight-line, adjacent/nested plain-block, and if-then-body runtime propagation for single-const global writes, including imported/exported globals and reference-typed `ref.func` / `ref.null` facts inside the same linear trace with reference-specific and externref-null call/loop/branch/`try_table`/post-if guardrails plus mixed scalar/reference independent-write preservation
  - a touched-function nested default cleanup lane without the `precompute-propagate` prefix
- Current Starshine accepts direct `simplify-globals-optimizing` requests and schedules the pass in the public late-tail presets. The v130 audit classifies every top-level engine family and the broad `FlowScanner` contract: pure single-result carriers across block, loop, result-if, and try_table are covered; exact independent-effect handlers cover calls, memory/table queries and growth, local/global writes, stores, table mutations, and element drops; true multivalue, dangerous guarded-value nested conditions, and guarded values entering effect operands are source/probe-backed negatives. Broader future optimization breadth is optional follow-up, not an unclassified v0.1.0 parity gap.
- The first active slice has generated-input oracle evidence: 10000/10000 `gen-valid` normalized matches against Binaryen, repeated 9975/9975 compared mixed-generator matches, a post-select 1000/1000 regular GenValid smoke at `.tmp/pass-fuzz-sgo-select-flow-genvalid-1000`, a post-select-eqz regular smoke `.tmp/pass-fuzz-sgo-select-eqz-genvalid-1000` `1000/1000`, a post-select-eqz dedicated smoke `.tmp/pass-fuzz-sgo-select-eqz-dedicated-1000` `1000/1000`, post-select-eqz-if-return smokes at `.tmp/pass-fuzz-sgo-select-ifreturn-genvalid-1000` and `.tmp/pass-fuzz-sgo-select-ifreturn-dedicated-1000` (`1000/1000` each), post-select-call-if-return smokes at `.tmp/pass-fuzz-sgo-select-call-ifreturn-genvalid-1000` and `.tmp/pass-fuzz-sgo-select-call-ifreturn-dedicated-1000` (`1000/1000` each), post-select-memory-if-return smokes at `.tmp/pass-fuzz-sgo-select-memory-ifreturn-genvalid-1000` and `.tmp/pass-fuzz-sgo-select-memory-ifreturn-dedicated-1000` (`1000/1000` each), post-nested-thrice regular and dedicated smokes at `.tmp/pass-fuzz-sgo-nested-thrice-genvalid-1000` and `.tmp/pass-fuzz-sgo-nested-thrice-dedicated-1000` (`1000/1000` each), post-multi-global-nested regular and dedicated smokes at `.tmp/pass-fuzz-sgo-multiglobal-nested-genvalid-1000b` and `.tmp/pass-fuzz-sgo-multiglobal-nested-dedicated-1000b` (`1000/1000` each), post-pure-if-arm regular and dedicated smokes at `.tmp/pass-fuzz-sgo-if-arm-pure-genvalid-1000` and `.tmp/pass-fuzz-sgo-if-arm-pure-dedicated-1000` (`1000/1000` each), post-if-arm-pure-post-operator smokes at `.tmp/pass-fuzz-sgo-if-arm-post-pure-genvalid-1000` and `.tmp/pass-fuzz-sgo-if-arm-post-pure-dedicated-1000` (`1000/1000` each), post-select-call smokes at `.tmp/pass-fuzz-sgo-select-call-genvalid-1000` and `.tmp/pass-fuzz-sgo-select-call-dedicated-1000` (`1000/1000` each), post-independent-call-compare smokes at `.tmp/pass-fuzz-sgo-call-compare-genvalid-1000` and `.tmp/pass-fuzz-sgo-call-compare-dedicated-1000` (`1000/1000` each) plus random-all `.tmp/pass-fuzz-sgo-call-compare-random-all-1000` (`1000/1000`), post-independent-memory-compare smokes at `.tmp/pass-fuzz-sgo-memory-compare-genvalid-1000`, `.tmp/pass-fuzz-sgo-memory-compare-dedicated-1000`, and `.tmp/pass-fuzz-sgo-memory-compare-random-all-1000` (`1000/1000` each), post-independent-table-compare smokes at `.tmp/pass-fuzz-sgo-table-compare-genvalid-1000`, `.tmp/pass-fuzz-sgo-table-compare-dedicated-1000`, and `.tmp/pass-fuzz-sgo-table-compare-random-all-1000` (`1000/1000` each), post-independent-table-select smokes at `.tmp/pass-fuzz-sgo-table-select-genvalid-1000`, `.tmp/pass-fuzz-sgo-table-select-dedicated-1000`, and `.tmp/pass-fuzz-sgo-table-select-random-all-1000` (`1000/1000` each), post-independent-local-tee-select smokes at `.tmp/pass-fuzz-sgo-localtee-select-genvalid-1000`, `.tmp/pass-fuzz-sgo-localtee-select-dedicated-1000`, and `.tmp/pass-fuzz-sgo-localtee-select-random-all-1000` (`1000/1000` each), post-float-value pure-condition smokes at `.tmp/pass-fuzz-sgo-float-value-genvalid-1000` and `.tmp/pass-fuzz-sgo-float-value-dedicated-1000` (`1000/1000` each), post-conversion pure-condition smokes at `.tmp/pass-fuzz-sgo-conversion-genvalid-1000` and `.tmp/pass-fuzz-sgo-conversion-dedicated-1000` (`1000/1000` each), post-ref-predicate pure-condition smokes at `.tmp/pass-fuzz-sgo-ref-pure-genvalid-1000` and `.tmp/pass-fuzz-sgo-ref-pure-dedicated-1000` (`1000/1000` each), post-select-memory smokes at `.tmp/pass-fuzz-sgo-select-memory-genvalid-1000` and `.tmp/pass-fuzz-sgo-select-memory-dedicated-1000` (`1000/1000` each), post-select-second-call smokes at `.tmp/pass-fuzz-sgo-select-second-call-genvalid-1000` and `.tmp/pass-fuzz-sgo-select-second-call-dedicated-1000` (`1000/1000` each), post-select-second-memory smokes at `.tmp/pass-fuzz-sgo-select-second-memory-genvalid-1000` and `.tmp/pass-fuzz-sgo-select-second-memory-dedicated-1000` (`1000/1000` each), post-pure-add grow select smokes at `.tmp/pass-fuzz-sgo-pure-add-grow-select-genvalid-1000` and `.tmp/pass-fuzz-sgo-pure-add-grow-select-dedicated-1000` (`1000/1000` each), post-reverse-pure-add grow select smokes at `.tmp/pass-fuzz-sgo-reverse-pure-add-grow-select-genvalid-1000` and `.tmp/pass-fuzz-sgo-reverse-pure-add-grow-select-dedicated-1000` (`1000/1000` each), post-pure-add grow compare smokes at `.tmp/pass-fuzz-sgo-pure-add-grow-compare-genvalid-1000` and `.tmp/pass-fuzz-sgo-pure-add-grow-compare-dedicated-1000` (`1000/1000` each), post-block-prefix-call smokes at `.tmp/pass-fuzz-sgo-block-prefix-call-genvalid-1000` and `.tmp/pass-fuzz-sgo-block-prefix-call-dedicated-1000` (`1000/1000` each), post-block-prefix void-call smokes at `.tmp/pass-fuzz-sgo-void-call-genvalid-1000` and `.tmp/pass-fuzz-sgo-void-call-dedicated-1000` (`1000/1000` each), post-block-prefix table.set/init/elem.drop smokes at `.tmp/pass-fuzz-sgo-block-prefix-tableset-init-genvalid-1000` and `.tmp/pass-fuzz-sgo-block-prefix-tableset-init-dedicated-1000` (`1000/1000` each), post-if-return-block-prefix-call smokes at `.tmp/pass-fuzz-sgo-ifreturn-block-prefix-call-genvalid-1000` and `.tmp/pass-fuzz-sgo-ifreturn-block-prefix-call-dedicated-1000` (`1000/1000` each), post-block-prefix-local smokes at `.tmp/pass-fuzz-sgo-block-prefix-local-genvalid-1000` and `.tmp/pass-fuzz-sgo-block-prefix-local-dedicated-1000` (`1000/1000` each), post-if-arm-if-return smokes at `.tmp/pass-fuzz-sgo-ifarm-ifreturn-genvalid-1000` and `.tmp/pass-fuzz-sgo-ifarm-ifreturn-dedicated-1000` (`1000/1000` each), post-nested-if-arm smokes at `.tmp/pass-fuzz-sgo-nested-ifarm-genvalid-1000` and `.tmp/pass-fuzz-sgo-nested-ifarm-dedicated-1000` (`1000/1000` each), post-nested-if-arm-pure-suffix smokes at `.tmp/pass-fuzz-sgo-nested-ifarm-pure-genvalid-1000` and `.tmp/pass-fuzz-sgo-nested-ifarm-pure-dedicated-1000` (`1000/1000` each), a 10000/10000 dedicated `simplify-globals-optimizing-all` profile lane at `.tmp/pass-fuzz-sgo-genvalid-simplify-globals-optimizing-all-10000`, regular GenValid `100000/100000`, explicit wasm-smith `9956/10000` compared with zero mismatches plus 44 Binaryen/tool failures, random-all `.tmp/pass-fuzz-sgo-genvalid-random-all-profiles-10000-safe-trunc-prefix-locals` `10000/10000`, and representative 1x timing. The older mixed lanes include the latest external block-yielded guardrail-negative lane, adjacent-runtime-block lane, nested-runtime-block lane, runtime-block-guardrail lane, no-else-if-runtime lane, and then-else-runtime lane, and then-guardrail/top-noise lane, same-as-init guardrail lane, global-get-init guardrail lane, alias/import-export runtime lane, imported/exported runtime-barrier guardrail lane, ref.func same-as-init guardrail lane, reference-runtime guardrail lane, reference-alias guardrail lane, externref-alias guardrail lane, typed-element/refinalization guardrail lane, reference deep-control runtime guardrail lane, externref deep-control runtime guardrail lane, mixed independent runtime guardrail lane, typed ref-func function-body guardrail lane, and typed externref function-body guardrail lane, with only known Binaryen/tool command failures in the mixed lanes.
- The 2026-07-06 / 2026-07-07 recursive audit closed the source-backed `FlowScanner` family classification with tested scalar, independent-effect, and structured-carrier handlers plus explicit negatives. The final fresh matrix is green: regular GenValid `100000/100000`, dedicated `10000/10000`, random-all `10000/10000`, and wasm-smith `9956/10000` compared with zero mismatches and `44` separately classified Binaryen/tool failures. No compare normalizers were needed.
- The 2026-04-25 port-readiness bridge and 2026-05-18 current-main refresh found no teaching-relevant Binaryen current-main drift; the 2026-05-16 through 2026-05-19 local implementation slices should be read as a partial port against that contract, not as full parity.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: phases, helper dependencies, scheduler placement, safety rules, and nested-rerun behavior.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner-file, helper, and lit-test map for the shared `SimplifyGlobals.cpp` family and the optimizing-specific nested-rerun wrapper.
- [`./linear-traces-read-only-to-write-and-reruns.md`](./linear-traces-read-only-to-write-and-reruns.md)
  Focused guide to the easiest parts of the pass to misunderstand: startup versus runtime propagation, the exact `read-only-to-write` matcher, actual-node versus effect-summary conservatism, and the optimizing rerun contract.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, negative, bailout, and interaction families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and remaining port map: active partial module-pass wiring, implemented constant/dead-set/touched-cleanup subset, open `SGO` backlog work, and the exact neighboring late-tail pass dossiers to compose with.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness bridge for a future port: minimum viable slice order, transformed-shape test plan, scheduler validation, Binaryen oracle comparison, and late-tail replay sequencing.

## Current maintenance rule

- Treat this folder as the canonical home for `simplify-globals-optimizing` research, implementation notes, and port planning.
- Keep it marked **audit-complete for the current v130/v0.1.0 scope** while preserving explicit reopening criteria for new semantic mismatches, validation failures, measured size/performance regressions, or upstream behavior drift. Plain `simplify-globals` remains a separate boundary-only contract.
- New `simplify-globals-optimizing` findings should update the strategy page, the linear-trace / read-only-to-write page, and the port-readiness page together so the global algorithm story, scheduler story, and Starshine validation plan stay aligned.

## Sources

- [`../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md`](../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md)
- [`../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md`](../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md)
- [`../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`](../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`](../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md) preserves the saved generated-artifact `-O4z` skipped-slot, summary, and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-dominance.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-nested.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-non-init.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-offsets.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-prefer_earlier.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-read_only_to_write.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-single_use.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals_func-effects.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>

## 2026-07-06 local-set compare update

The active read-only-to-write FlowScanner subset now includes independent constant `local.set` compare operands inside block conditions, in addition to the earlier independent `local.tee` select/compare and block-prefix local-write families. This remains a narrow source-backed subset, not a claim of generic Binaryen `FlowScanner` equivalence.

## 2026-07-06 global-set compare update

The active read-only-to-write FlowScanner subset now includes independent constant `global.set` result-block compare operands for guarded-write and if-return tails. The independent write must target a different global and store a constant; guarded-value-to-global-write flow remains excluded. This extends the earlier block-prefix independent global-write condition subset but remains narrower than generic Binaryen `FlowScanner` equivalence.

## 2026-07-06 memory-store compare update

The active read-only-to-write FlowScanner subset now includes independent memory-store result-block compare operands for guarded-write and if-return tails. The store address and value may be independent constants or `local.get`s; guarded-value-to-store address/value flow remains excluded. This extends the earlier independent memory-op compare and block-prefix memory-op subsets but remains narrower than generic Binaryen `FlowScanner` equivalence, and it does not claim arbitrary non-constant side-effect operands.

## 2026-07-06 local-fed local-write compare update

The active read-only-to-write FlowScanner subset now includes independent direct `local.tee` and block-condition `local.set` compare operands whose stored value is a constant or `local.get`. The guarded global may supply the other compare operand for guarded-write and function-level if-return tails, while guarded-value-to-local-write flow remains excluded. This remains narrower than generic Binaryen `FlowScanner` equivalence.

## 2026-07-06 local-fed memory-grow compare/select update

The active read-only-to-write FlowScanner subset now includes independent `memory.grow` compare and select operands whose delta is a constant or `local.get`. The guarded global may supply the other compare operand or the select condition for guarded-write and function-level if-return tails, while guarded-value-to-`memory.grow` delta flow remains excluded. This remains narrower than generic Binaryen `FlowScanner` equivalence.


## 2026-07-06 local-fed table-grow select update

The active read-only-to-write FlowScanner subset now includes independent `table.grow` select operands whose ref and delta operands are constants or `local.get`s. The guarded global may supply the other select value/condition for guarded-write and function-level if-return tails, while guarded-value-to-`table.grow` delta flow remains excluded. This remains narrower than generic Binaryen `FlowScanner` equivalence.

## 2026-07-07 independent call `i32.add` update

The active read-only-to-write FlowScanner subset now includes independent zero-parameter/result calls used as the sibling operand of the guarded global under a pure `i32.add`, in either operand order and for guarded-write plus function-level if-return tails. The call remains observable as `call; drop`; guarded-value-to-call-argument flow, arbitrary side-effect parents, non-`i32.add` effectful sibling parents, and generic Binaryen `FlowScanner` equivalence remain open.


## 2026-07-07 independent call nontrapping `i32` binary update

The active read-only-to-write FlowScanner subset now extends the independent-call sibling family beyond `i32.add` to nontrapping pure `i32` binary operators accepted by local Binaryen `version_130`: add/sub/mul, bitwise ops, shifts, and rotates. The call must still be independent, zero-parameter/one-result, and merely supply the sibling operand while the guarded global flows through the pure operator to a same-global guarded write or function-level `if return; set` tail. Trapping div/rem operators, guarded-value-to-call-argument flow, arbitrary side-effect parents, extra guarded reads, and generic Binaryen `FlowScanner` equivalence remain open.

## 2026-07-07 independent call binary `i32.eqz` suffix update

The active read-only-to-write FlowScanner subset now includes a narrow pure suffix after independent zero-parameter/one-result call sibling operands under nontrapping pure `i32` binary parents: the binary result may flow through `i32.eqz` before a same-global guarded write or function-level `if return; set` tail. The call remains observable as `call; drop`; trapping div/rem parents with `i32.eqz`, guarded-value-to-call-argument flow, arbitrary pure suffix chains, arbitrary side-effect parents, extra guarded reads, and generic Binaryen `FlowScanner` equivalence remain open.

The active read-only-to-write FlowScanner subset now extends the independent zero-parameter/one-result call sibling family through one additional source-backed pure suffix family above the nontrapping `i32` binary parent: `i32.clz`, `i32.ctz`, or `i32.popcnt` may consume the binary result before the same-global guarded write or function-level `if return; set` tail. Trapping div/rem parents plus unary suffix remain excluded, and generic Binaryen `FlowScanner` equivalence remains open.

The next source-backed parent is also implemented: one `i32.const` may be compared with that nontrapping binary result using `i32.eq` / `i32.ne` in either operand order before a guarded-write or function-level if-return tail. The independent call is preserved as `call; drop`; trapping binary parents, relational comparisons, multiple suffixes, arbitrary side-effect parents, extra reads, and generic FlowScanner equivalence remain open.

## 2026-07-07 independent `i64` call binary suffix update

The same narrow independent-call parent-chain model now covers `i64`: a zero-parameter/one-result call and guarded `i64` global may feed one nontrapping pure `i64` binary parent, followed by exactly one `i64.eqz` or constant-fed `i64.eq` / `i64.ne`, before the same-global guarded write or function-level `if return; set` tail. Direct/reverse operands and constant-first equality are covered; cleanup preserves `call; drop`. Trapping `i64.div_*` / `i64.rem_*`, relational comparisons, deeper chains, call-argument flow, arbitrary side-effect parents, extra reads, and generic FlowScanner equivalence remain open.

## 2026-07-07 independent float call binary-comparison update

The narrow typed parent-chain model now also covers `f32` / `f64`: an independent zero-parameter/one-result call and guarded same-typed float global may feed one IEEE float binary parent (`add`, `sub`, `mul`, `div`, `min`, `max`, or `copysign`), followed by exactly one same-typed constant-fed float comparison, before the guarded-write or function-level if-return tail. Direct/reverse binary operands, both comparison constant orders, NaN-sensitive shapes, and float divide are covered; cleanup preserves `call; drop`. Flow into call arguments, extra guarded reads, deeper chains, arbitrary effectful parents, and generic `FlowScanner` equivalence remain open.

## 2026-07-07 generic scalar parent-chain update

The independent-call family now uses a reusable scalar-kind parser instead of separate one-suffix ceilings. After the guarded global and an independent zero-parameter/one-result scalar call meet at a nontrapping scalar binary/comparison parent, the dependent value may continue through arbitrary result-first nontrapping scalar unary/conversion and constant-fed binary/comparison parents until the final `i32` guard. A same-type unary chain on the global-first call result is also accepted before the first parent. This covers deep integer unary chains, integer relational comparisons, float unary parents, and `f32`-to-`f64` promotion while preserving the call as `call; drop`.

The implementation is still a straight-line scalar subset, not complete Binaryen `FlowScanner` equivalence. Later slices added contiguous LIFO constant-first operands at arbitrary supported parent depth and effect-aware reverse pre-parent cleanup: removable same-type/type-changing unary fragments become `call; drop`, while trapping float-to-int truncations replay as `call; trunc; drop`. Generic non-constant independent producers, structured parents, general independent-effect sibling reconstruction, complete source/lit classification, and fresh final four-lane evidence remain open. Latest focused/full tests pass `3/3`, `291/291`, `4440/4440`, and `7879/7879`; regular/dedicated reverse-fragment smokes normalize `1000/1000`; representative timing remains `<=1x` with `0.977x` worst ratio.

## 2026-07-07 generic independent scalar producer update

After rebasing onto local `main` `c24acc74a`, the shared scalar fragment record now covers zero-parameter scalar calls, removable `memory.size`, and replay-required constant-address scalar loads. Producer-local unary/conversion chains are typed in both first-parent operand orders; trap-capable conversions and loads replay only after the full guard shell matches. Direct/reverse memory-size and independent-load probes match Binaryen v130 exactly, while a guarded value used as the load address remains mutable. Three positives failed red before implementation; focused pre-parent tests pass `6/6`, full SGO passes `295/295`, regular/dedicated `1000/1000` lanes are normalized-green, and representative timing remains `<=1x` with narrow `0.981x` read-only-select and `0.997x` startup margins.

## 2026-07-07 bounded structured producer update

Single-result numeric `block` and result-`if` envelopes are now classified separately from the flat grammar. Pure block/if producers disappear; a block-contained load replays as load/drop, and a call-conditioned result-`if` replays as call/drop. The guarded global remains unsafe when it is itself the result-`if` condition selecting an observable arm. Three positives were red before implementation; full SGO is `300/300`, pass tests are `5091/5091`, regular/dedicated structured smokes normalize `1000/1000`, and timing remains `<=1x` with a `0.990x` worst ratio. Broader independent grows/writes, branchful/type-index/multivalue structured producers, complete source/lit classification, and fresh final four-lane evidence remain open.

## 2026-07-07 structured memory-grow producer update

Bounded single-result blocks may now execute an independent `memory.grow` over a constant/local delta or the probed pure-add delta before yielding their scalar result. Binaryen/Starshine both preserve the grow as `memory.grow; drop`, while guarded-global-to-grow-delta flow remains negative. Two positives failed red before implementation; full SGO/pass/repo tests pass `303/303`, `5094/5094`, and `8537/8537`; regular/dedicated structured-grow smokes normalize `1000/1000`; and direct timing remains `<=1x` with a `0.961x` worst ratio.

## 2026-07-07 structured local-write and table-grow producer update

The same bounded result-block record now covers independent constant/local-fed `local.set` and `local.tee; drop` prefixes plus independent `table.grow; drop` prefixes. Observable one-use local writes are replayed as `local.tee; drop` and then folded with the following `local.get`, matching Binaryen's constant/parameter result while preserving guarded-global-to-local-write and guarded-global-to-table-grow-delta negatives. Direct/reverse local-set, local-tee, parameter-fed local-set, and table-grow probes match Binaryen instruction behavior; Starshine still retains an unused local declaration where Binaryen removes it. Red-first positives failed before implementation; full SGO/pass/repo tests pass `309/309`, `5100/5100`, and `8543/8543`; regular/dedicated `.tmp/pass-fuzz-sgo-structured-local-table-{genvalid,dedicated}-1000` lanes normalize `1000/1000`; and the 31-repeat timing rerun remains `<=1x`, worst `0.993x`.

## 2026-07-07 repeated-local and structured-control update

Constant local writes followed by exactly two reads and `i32.add` now fold to the result constant and delete the dead assignment. This is a measured Starshine win over Binaryen's retained assignment: `47` versus `51` stripped pass-local bytes, with identical `37`-byte downstream `-Oz` output. Independent scalar loops and branchful result blocks are replayed conservatively when their bodies contain no globals. V130 probes classify single-result type-index blocks and effectful-independent-arm result `if`s as positive/already covered, true multivalue blocks as negative. Full SGO/pass/repo tests pass `312/312`, `5103/5103`, and `8546/8546`; regular/dedicated structured-control smokes normalize `1000/1000`; timing remains `<=1x`, worst `0.966x`.

## 2026-07-07 guarded structured flow update

Exact scalar result loops containing the guarded read and the probed branchful result-block value path now participate in read-only-to-write analysis through the existing pure suffix, guarded-write, and if-return tails. Positive tests failed red `0/2`; full SGO/pass/repo tests now pass `315/315`, `5106/5106`, and `8549/8549`. Regular/dedicated `.tmp/pass-fuzz-sgo-guarded-structured-{genvalid,dedicated}-1000` lanes normalize `1000/1000` with zero failures/mismatches, and the accepted 51-repeat timing run remains `<=1x`, worst `0.977x`.

The effectful result-if residual is now closed: an `i32` result `if` followed by the empty guarded-write shell becomes `result-if; drop`, preserving all effects/traps and matching Binaryen at `63` stripped bytes. The focused test was red before implementation; full SGO/pass tests pass `316/316` and `5107/5107`, and regular/dedicated post-change smokes normalize `1000/1000` each. One-use local declarations remain a measured parity gap at `46` versus Binaryen `44` stripped bytes; the metadata-unsafe declaration deletion experiment remains reverted.

At this intermediate slice, the explicit v130 inventory classified every top-level `SimplifyGlobals.cpp` engine family while the semantic `FlowScanner` parent/child contract, strict timing, and final matrix were still open. The later structured-parent, exact-handler review, timing-recovery, metadata-safe local cleanup, and final-matrix sections below supersede that temporary status.

## 2026-07-07 pure structured-parent and timing recovery update

The guarded scalar flow model now recursively admits pure single-result carrier chains across `block`, `loop`, and `try_table`; earlier result-`if` slices cover the fourth structured value carrier. Inside the admitted chain, the guarded value may pass through typed nontrapping scalar unary and constant-fed binary/comparison parents. Red-first tests cover a pure result loop, nested block-in-loop flow, and a result `try_table`; the observable nested-`if` condition guardrail remains mutable, and true multivalue remains Binaryen-negative. This substantially closes the generic structured-parent classification while leaving type-index/exact independent-effect handlers subject to one final source/probe review before closeout.

The strict timing blocker is closed. An exact pre-recursion cleanup for the common post-SGO constant-address-load/select/dead-if whole-function shell preserves `i32.load; drop` and avoids the broad cleanup matcher roster. A rejected broader precheck regressed read-only-select to `1.106x`; the accepted exact path measures `0.430x` on the fresh unpinned 51-repeat/10-warmup run. All representative ratios are green: `0.438x`, `0.327x`, `0.430x`, `0.444x`, and `0.915x`. Focused SGO tests pass `319/319`, pass tests `5110/5110`, full repo tests `8553/8553`, and final regular/dedicated development smokes normalize `1000/1000` each with zero failures/mismatches.

The final structured review confirms that single-result type-index `block`, `loop`, and result-`if` carriers are Binaryen-positive and already covered by Starshine's exact type-index/effect/control handlers; no generic recursive widening is needed. The documented independent-effect structured handlers cover the source-probed call, memory/table, local/global write, store, and table mutation families, while true multivalue, dangerous nested conditions, and guarded values entering effect operands remain explicit negatives. The one-use local declaration gap is also closed: SGO now runs the existing metadata-aware `reorder-locals` remapper when a touched function has declarations even after its last local instruction disappears, preserving valid local-name mappings and matching Binaryen's stripped `44`-byte output.

Fresh focused/full validation remains green (`319/319`, `5110/5110`, `8553/8553`), regular/dedicated post-fix smokes normalize `1000/1000`, and the latest 51-repeat timing ratios are `0.474x`, `0.328x`, `0.429x`, `0.430x`, and `0.879x`. The final fresh matrix is also complete without normalizers: regular `100000/100000`, dedicated `10000/10000`, random-all `10000/10000`, and wasm-smith `9956/10000` compared with zero mismatches plus 44 classified Binaryen/tool failures. The v130/v0.1.0 audit is closed.
