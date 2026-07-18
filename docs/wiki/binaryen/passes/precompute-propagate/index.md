---
kind: entity
status: supported
last_reviewed: 2026-07-18
sources:
  - ../../../raw/research/1573-2026-07-18-precompute-returned-values-arrays-and-effect-retention.md
  - ../../../raw/research/1572-2026-07-17-precompute-propagate-port-and-signoff.md
  - ../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md
  - ../../../raw/research/0375-2026-04-25-precompute-propagate-current-main-code-map.md
  - ../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0167-2026-04-21-precompute-propagate-binaryen-research.md
  - ../../../raw/research/0198-2026-04-21-precompute-propagate-worklist-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../precompute/index.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-worklist-fallthrough-and-merge-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../precompute/index.md
  - ../dae-optimizing/index.md
  - ../inlining-optimizing/index.md
  - ../simplify-globals-optimizing/index.md
  - ../tracker.md
---

# `precompute-propagate`

## Role

- `precompute-propagate` is an active Starshine **hot/function pass** matching Binaryen's second public precompute spelling.
- It shares its evaluator and cleanup base with [`../precompute/index.md`](../precompute/index.md), then adds one SSA-backed local-consensus solve and one bounded evaluator rerun.
- The exact public name is registered, dispatched, accepted by the compare harness, and covered by focused tests plus the `precompute-propagate-local-facts` GenValid profile.
- Starshine's two aggressive top-level PC slots now use `precompute-propagate`; ordinary plain-`precompute` remains a separately requestable direct pass.
- DAE and inlining nested optimization now use the same public implementation instead of the removed private `precompute-propagate-prefix` semantic fork.
- The shared Binaryen-v131 evaluator contract is closed: strings, general constant control `Flow`, immutable nested heaps and exact identities, ordered multi-effect retention, emitability, deterministic SIMD, descriptor/reference behavior, and exact cast refinalization are covered. Conservative legacy-EH and stack-switching preservation remains intentional. Propagation itself stays bounded to one SSA local-consensus solve and one evaluator rerun.

## Why this pass matters

- The public family gap had a dedicated `[O4Z-PCP]001` backlog slice; the implementation and propagation-specific signoff are now complete.
- The public-port closeout is [`../../../raw/research/1572-2026-07-17-precompute-propagate-port-and-signoff.md`](../../../raw/research/1572-2026-07-17-precompute-propagate-port-and-signoff.md); the shared-evaluator refresh is [`../../../raw/research/1573-2026-07-18-precompute-returned-values-arrays-and-effect-retention.md`](../../../raw/research/1573-2026-07-18-precompute-returned-values-arrays-and-effect-retention.md).
- The pass is already important in neighboring docs:
  - `dae-optimizing` and `inlining-optimizing` both depend on the `precompute-propagate` nested-rerun rule.
  - `simplify-globals-optimizing` is easier to teach once the contrast is explicit: it reruns the default function pipeline **without** prepending `precompute-propagate`.
- The earlier worklist follow-up closed the dossier's biggest algorithm teaching gap with a dedicated page for the exact `propagateLocals(...)` contract.
- The 2026-04-24 follow-up closed the original provenance and local-follow-along gap with an immutable raw primary-source manifest and a dedicated Starshine status / port-strategy page.
- The 2026-05-04 refresh adds a current-main no-drift manifest and a dedicated Starshine port-readiness bridge, so this folder should be treated as a deep dossier rather than only a landing dossier.

## Beginner summary

A good beginner mental model is:

- Binaryen tries to **execute** some expressions at compile time,
- keeps the rewrite only when the result can be emitted honestly,
- preserves child writes when erasing them would be wrong,
- and in `precompute-propagate` mode it also solves a small local get/set consensus problem to unlock one extra evaluator walk.

So the pass is best taught as:

- **semantic precomputation plus a narrow local worklist**,
- not just “constant folding through locals.”

## Most important durable takeaways

- `precompute-propagate` is a real public pass name in Binaryen `version_131`, not just an internal mode nickname, and Starshine exposes that exact public name.
- It shares the same `Precompute.cpp` core as plain `precompute`, but the propagate variant adds a real extra phase.
- That extra phase uses `LazyLocalGraph` to learn concrete values for some `local.get`s and then reruns the main precompute walk once.
- The propagation step is stricter than the name alone suggests:
  - sets are analyzed through their **fallthrough values**
  - propagated set values must still subtype the original set-value expression type
  - a `local.get` becomes constant only when **all** reaching sets agree on one concrete literal tuple
  - defaultable vars can contribute function-entry zero/default literals, but params and suspicious nondefaultable-local entry reads bail out
- Starshine keeps plain `precompute` available directly while its modeled aggressive optimize/shrink rosters use `precompute-propagate` in both PC slots.
- DAE and inlining nested prefixes use the same public propagating pass; simplify-globals-optimizing remains the contrast path without that extra prefix.
- The pass still depends on the same hard safety boundaries as plain `precompute`:
  - emitability of computed values
  - preservation of child local/global writes
  - bounded loop/depth exploration
  - GC identity and heap-value rules

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation, scheduler placement, helper dependencies, and the propagate-specific extra phase.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./local-worklist-fallthrough-and-merge-boundaries.md`](./local-worklist-fallthrough-and-merge-boundaries.md)
  Focused guide to the exact `propagateLocals(...)` contract: `LazyLocalGraph` worklist edges, fallthrough-value analysis, get-merge consensus, defaultable-versus-param entry behavior, nondefaultable-local bailout, and the one-extra-rerun stopping rule.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, bailout, and easy-to-misread `precompute-propagate` families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine implementation map: public descriptor/registry/dispatcher surfaces, SSA-backed consensus, result-`if` phi/direct-condition handling, guarded raw propagation, evaluator breadth, aggressive preset slots, nested-prefix reuse, and signoff evidence.

## Current maintenance rule

- Treat this folder as the canonical home for maintained `precompute-propagate` implementation and parity evidence.
- Keep it marked active while the public descriptor, registry, dispatcher, dedicated profile, and scheduler wiring remain present.
- Keep the relationship to plain `precompute` explicit:
  - shared implementation core
  - different public pass name
  - different scheduler usage
  - different reachable fixed points because of the extra propagation phase
- Treat the retained 2026-04-24 follow-up research [`../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md`](../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md) and direct tagged URLs as the source provenance anchor, and its retained research mirror [`../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md`](../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md) as the current-main freshness anchor.
- Keep the exact local-worklist contract explicit too:
  - not generic SCCP
  - not an unbounded fixed-point loop
  - not a bypass around emitability or GC-identity rules
- Keep the exact Starshine status explicit too:
  - active public descriptor and registry entry today
  - one solve plus one evaluator rerun, not generic unbounded SCCP
  - both aggressive top-level PC slots use the propagating member
  - DAE/inlining nested prefixes reuse the public pass
  - the closed v131 string/Flow/heap-identity/emitability/refinalization contract and conservative EH/stack-switching boundaries remain visible

## Sources

- [`../../../raw/research/1574-2026-07-18-precompute-binaryen-v131-parity-reopen.md`](../../../raw/research/1574-2026-07-18-precompute-binaryen-v131-parity-reopen.md)
- [`../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md`](../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md)
- [`../../../raw/research/0375-2026-04-25-precompute-propagate-current-main-code-map.md`](../../../raw/research/0375-2026-04-25-precompute-propagate-current-main-code-map.md)
- [`../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md`](../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0167-2026-04-21-precompute-propagate-binaryen-research.md`](../../../raw/research/0167-2026-04-21-precompute-propagate-binaryen-research.md)
- [`../../../raw/research/0198-2026-04-21-precompute-propagate-worklist-followup.md`](../../../raw/research/0198-2026-04-21-precompute-propagate-worklist-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../precompute/index.md`](../precompute/index.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-interpreter.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate-partial.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate_all-features.wast>
