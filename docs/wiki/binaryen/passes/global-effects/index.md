---
kind: entity
status: supported
last_reviewed: 2026-09-24
sources:
  - ../../../../../src/passes/global_effects.mbt
  - ../../../../../src/passes/global_effects_target_summary_wbtest.mbt
  - ../../../../../src/passes/global_effects_noop_perf_wbtest.mbt
  - ../../../../../src/passes_perf_long/global_effects_target_summary_perf_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../../../src/ir/effects.mbt
  - ../../../../../src/ir/analysis_cache.mbt
  - ../../../../../src/passes/pass_common.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../simplify-locals/index.md
  - ../vacuum/index.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./metadata-naming-and-consumers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ./fuzzing.md
  - ../discard-global-effects/index.md
  - ../simplify-locals/index.md
  - ../vacuum/index.md
  - ../tracker.md
---

# `global-effects` / upstream `generate-global-effects`

## Current repository note — September 24, 2026

The current Starshine registry dispatches `global-effects` to
`src/passes/global_effects.mbt`, a direct module rewrite that replaces fresh
resumes of non-suspending continuations with calls. It does **not** implement
the historical Binaryen `generate-global-effects` metadata producer described
in this dossier's older source review. The current rewrite caches each defined
target's suspension summary for one invocation. A native direct-pass benchmark
with 128 repeated resumes improved from 26.42 to 15.83 µs (`1.67×`), and 256
resumes improved from 71.40 to 28.30 µs (`2.52×`). The benchmark constructs
and validates its continuation module outside timing; it is synthetic
Starshine pass-local evidence, not a Binaryen oracle comparison.

The no-resume fast path now scans for a `resume` in the instruction forms this rewrite traverses before allocating rewritten function and body arrays. A native direct-pass benchmark with 64 `nop`s under one block per function improved from `102.83 → 11.66 µs` for 256 functions (8.82×) and `217.21 → 24.61 µs` for 512 (8.83×). On the historical v133 encoded fresh-resume fixture, used only as a local timing control, direct-pass time changed from `2.51 → 2.56 µs` (about 2% slower); this is not new Binaryen parity evidence. The nested guard test, target-summary test, and two encoded continuation tests pass. Full-pipeline impact and allocation counts remain unmeasured.

## Role

- `global-effects` is the local Starshine registry name historically assigned to the upstream Binaryen pass published as `generate-global-effects`; its current implementation has a different direct resume-rewrite contract as noted above.
- The upstream metadata producer remains **unimplemented** in Starshine.
- It is a real public upstream pass in Binaryen `version_129`, but it is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` default top-level path.
- Its job is to compute per-function global-effect summaries that later passes can consult across calls.
- The retained current-main source bridges record the propagation refactor and make the stale upstream comment-vs-implementation wording explicit: the implementation writes per-function `Function.effects`, even though an owner-file header phrase still says `PassOptions`.
- The 2026-05-06 current-main recheck confirms the same teaching contract on the reviewed surfaces, and the 2026-05-05 line-anchor refresh still keeps the SCC-shaped current-main implementation note explicit while tightening the exact local code-map anchors used by the living dossier.
- The 2026-04-25 follow-up gives the cleanup sibling [`../discard-global-effects/index.md`](../discard-global-effects/index.md) its own canonical home, so this page can focus on producing summaries while the sibling page covers clearing stale summaries.
- The 2026-04-27 port-readiness bridge adds the missing local implementation ladder: analyzer-only first slice, per-function summary storage, SCC/fixed-point propagation choice, consumer sequencing, and paired Binaryen validation lanes.
- The repo-wide Binaryen release horizon now reaches `version_130`; this page keeps the detailed contract anchored to the reviewed `version_129` / current-main surfaces because the teaching-relevant behavior did not drift on the 2026-05-06 recheck.

## Why this pass matters

- The main parity queue and first expansion queue are already dossier-covered, so this folder is an explicit source-backed tracker expansion for another real local registry entry.
- `agent-todo.md` currently has **no dedicated `global-effects` slice**.
- The pass already matters in neighboring living docs:
  - `simplify-locals` uses generated global-effect summaries to distinguish call readers from call writers.
  - `vacuum` can remove more unused calls after those summaries exist.
- The pass is easy to underestimate because it does not rewrite WAT directly, but downstream optimizer behavior can still change materially when the metadata is present or absent.

## Beginner summary

A good beginner mental model is:

- Binaryen first asks “what globals does each function itself read or write?”
- then it keeps propagating that information backward through call chains
- and finally later passes use those stored summaries when deciding whether calls are barriers or removable

So the pass is best taught as:

- **metadata-producing interprocedural global-effect analysis**
- not as a direct code-rewriting optimizer

## Most important durable takeaways

- The official upstream public name is `generate-global-effects`.
- The local Starshine registry currently shortens that to `global-effects`.
- Binaryen `version_129` does **not** schedule this in the default optimize pipeline.
- In `version_129`, the pass computes shallow per-function summaries first, records direct callees plus unknown-call effects, propagates static callees, marks recursive chains as trapping, merges callee summaries, and writes each function's summary.
- Current Binaryen `main` keeps the same source-backed contract but refactors propagation through explicit SCC component aggregation.
- The result is stored in `Function.effects` metadata.
- Later `EffectAnalyzer` queries on `Call` can consult those stored summaries.
- The pass therefore changes later optimizer precision without directly rewriting the current function's WAT.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation, scheduler placement, helper dependencies, and fixed-point algorithm.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./metadata-naming-and-consumers.md`](./metadata-naming-and-consumers.md)
  Focused guide to the easy-to-misread part: local-vs-upstream naming, metadata-only behavior, invalidation, and downstream consumers.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing which call/global patterns gain precision, which stay conservative, and why the WAT often stays textually unchanged.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future-port map: boundary-only registry entry, CLI parse coverage, local HOT effect-mask ingredients, missing module-level summary storage, and the reason a faithful port must be a module/call-graph metadata pass rather than a HOT peephole.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Concrete future implementation ladder: no-rewrite analyzer, summary model, solver choice, registry/dispatcher sequencing, consumer sequencing, Binaryen oracle lanes, and first-port definition of done.
- [`./fuzzing.md`](./fuzzing.md)
  Current planned-only harness status and future metadata-first signoff: standalone WAT is not an oracle for this producer, so paired consumer and cleanup composition evidence is required.

## Current maintenance rule

- Treat this folder as the canonical home for future `global-effects` / `generate-global-effects` research and port planning.
- Keep the historical upstream metadata producer explicitly marked as **unimplemented** until Starshine grows a real module-level metadata pass for it; the current direct resume rewrite does not satisfy that contract.
- Keep the naming split explicit:
  - local registry: `global-effects`
  - upstream public pass: `generate-global-effects`
  - upstream cleanup sibling: [`discard-global-effects`](../discard-global-effects/index.md)
- Keep the scheduler fact explicit too: this is a real pass, but not part of the current no-DWARF default optimize path.

## Sources

- research note 0502
- research note 0480
- research note 0490
- research note 0417
- research note 0305
- research note 0168
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt)
- [`../../../../../src/ir/effects.mbt`](../../../../../src/ir/effects.mbt)
- [`../../../../../src/ir/analysis_cache.mbt`](../../../../../src/ir/analysis_cache.mbt)
- [`../../../../../src/passes/pass_common.mbt`](../../../../../src/passes/pass_common.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../simplify-locals/index.md`](../simplify-locals/index.md)
- [`../vacuum/index.md`](../vacuum/index.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` and current-main implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalEffects.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/wasm.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-global-effects.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/vacuum-global-effects.wast>
