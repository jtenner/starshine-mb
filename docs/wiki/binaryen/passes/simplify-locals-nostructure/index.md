---
kind: entity
status: supported
starshine_status: active
last_reviewed: 2026-08-10
sources:
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./parity.md
  - ./variant-surface.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-locals/index.md
  - ../tuple-optimization/index.md
  - ../reorder-locals/index.md
  - ../coalesce-locals/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `simplify-locals-nostructure`

## Binaryen-v131 renewal

Closed on 2026-07-27. The refreshed aggregate completed `10000/10000`: `7115` exact matches and `2885` strictly smaller Starshine outputs (`-12..-8` bytes), with zero failures. The new differences are intentional stronger cleanup of pure dropped local reads and the writes made dead by removing those observations. Idempotence is `1000/1000`.

## Role

- `simplify-locals-nostructure` is an upstream Binaryen early locals-cleanup pass.
- It is now an active direct hot pass in Starshine, implemented in [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt) and registered in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- The upstream Binaryen name is `simplify-locals-nostructure`, while Starshine also accepts compatibility spelling `simplify-locals-no-structure` as an alias.
- Despite the name, Binaryen `version_131` does **not** use this pass for “flat locals only” or “no tee.” The real contract is narrower: run the shared simplify-locals engine with teeing still enabled and structure-building rewrites disabled.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` function pipeline runs `simplify-locals-nostructure` after `code-pushing` plus `tuple-optimization` and before `vacuum` plus the first `reorder-locals`.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - top-level slot `22`
- The repo backlog previously tracked the remaining ordered-slot follow-up under `SLNS`; that exact `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals` replay is now proven and the standalone slice is closed.
- The current Starshine tuple-slot gate still sees the no-structure pass as active, and the public presets still stay conservative, but the remaining caution now belongs to neighboring tuple/local-cluster slices rather than this pass's own ordered-slot proof.
- The current local oracle is official Binaryen `version_131` (`wasm-opt version 131 (version_131)`). The 2026-07-27 renewal confirmed that the dedicated no-structure tests, `SimplifyLocals.cpp`, and reviewed locals helpers are unchanged from v130; shared pass/global-effect drift was probed directly. The refreshed aggregate and idempotence evidence below supersedes the earlier v130 profile.

## Beginner summary

A safe beginner mental model is:

- count how many times each local is still read,
- sink easy `local.set` values forward into the real use sites,
- create a tee later if the first use still needs the value to stay live,
- delete dead or overwritten local traffic,
- but **do not** create new block / `if` / loop return values yet.

That is narrower than “full simplify-locals.”

## Current durable takeaways

- Binaryen implements this pass as `SimplifyLocals<true, false, true>`.
- So `simplify-locals-nostructure` still allows:
  - tee creation
  - nesting into existing expression positions
  - late equivalent-get canonicalization
  - final dead-set cleanup
- The disabled feature is specifically the structure-building family:
  - loop return lifting
  - block return lifting
  - `if` / `if-else` return lifting
  - one-armed `if` speculative else-side `local.get` insertion
- The first fixpoint cycle is still stricter than later ones: it only sinks easy single-use locals.
- The main analysis is deliberately linear-trace based and uses directional effect invalidation instead of whole-function CFG reasoning.
- Current Starshine has a direct transform for this pass: it reuses the existing local-sink/dead-cleanup cycles from full `simplify-locals` while disabling structure-result rewrites. Historical 2026-05 evidence and the early 2026-06-30 residual paragraphs are baseline only; the active source of truth is the [`./parity.md`](./parity.md) checklist plus [`./fuzzing.md`](./fuzzing.md).
- Current `version_131` evidence includes the refreshed dedicated aggregate: `10000/10000` compared, `7115` exact and `2885` strictly smaller Starshine outputs, with zero validation, property, generator, or command failures. The variant is also `1000/1000` idempotent. The new structural differences come from stronger pure dropped-read and dead-carrier cleanup; they are measured `8–12` byte wins, not annotation-only drift.
- The v131 behavior, validity, idempotence, and canonical-size renewal is closed. Historical 100-largest timing tails remain a broader `[WALL]001` performance caveat; they were not refreshed here and do not reopen this shared-helper-sensitive parity spot check.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_131` implementation: template identity, first-cycle versus later-cycle behavior, linear-trace sink state, effect barriers, late equivalent-get canonicalization, final dead-set cleanup, and scheduler placement.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner/helper/test map for the no-structure variant, including the current-main no-drift bridge, `pass.h` nondefaultable-local fixup postcondition, and exact Starshine registry / slot-blocker / dispatcher line ranges.
- [`./parity.md`](./parity.md)
  Current `version_131` parity checklist: template identity, get counting, first-cycle sinks, later teeing, dropped-tee cleanup, effect/EH barriers, refinalization, late equivalent-get cleanup, final dead-set cleanup, disabled structure synthesis, dedicated-profile evidence, and performance evidence.
- [`./variant-surface.md`](./variant-surface.md)
  Focused guide to the easiest part of the pass to misunderstand: what “no structure” actually toggles, what it surprisingly leaves on, and how it differs from `simplify-locals`, `simplify-locals-notee-nostructure`, and `simplify-locals-nonesting`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status: active hot pass plus alias, implementation shape, direct parity evidence, canonical no-DWARF slot, and conservative preset-neighborhood follow-up.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness bridge: first slice, negative tests, scheduler honesty, and Binaryen oracle lanes.
- [`./fuzzing.md`](./fuzzing.md)
  Dedicated `simplify-locals-nostructure-all` GenValid aggregate profile, leaf surfaces, manifest metadata, current smoke result, and profile-specific reopening criteria.

## 2026-08-10 self-opt ownership hardening

Exact self-optimized spec execution exposed release-order corruption in both no-structure and full SimplifyLocals. Direct argument consumers must remain before one or more release calls, and call results used late in long argument lists must not be released before the consumer. Later native-vs-Wasm optimizer-output isolation found the distinct conditional-release form in defined functions `3863` and `3866`: a two-local consumer was moved after separate conditional calls that released each argument through different targets. Red structural regressions now cover direct, long-argument, shared structured-release, and distinct structured-release families across `simplify-locals-nostructure` and `simplify-locals`; the focused combined suite is `118/118`. These are conservative ownership boundaries, not claims that arbitrary call/release conventions are inferred.

## Current maintenance rule

- Treat this folder as the canonical home for `simplify-locals-nostructure` research, direct-pass validation, and preset-neighborhood planning.
- Keep direct-pass evidence and broader preset status separate: the pass and its `simplify-locals-no-structure` alias are active, revalidated, and now exact-slot replay-proven, but public `optimize` / `shrink` placement still depends on neighboring tuple/local-cluster work.
- New `simplify-locals-nostructure` findings should update the strategy, implementation/test-map, variant-surface, and Starshine pages together so the upstream algorithm, source proof surface, variant boundary, and local port story stay aligned.

## Sources

- research note 1399
- research note 0543
- research note 0368
- research note 0263
- research note 0117
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_131` pass source: <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/SimplifyLocals.cpp>
- Binaryen `version_131` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp>
- Binaryen `version_131` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/opt-utils.h>
- Binaryen `version_131` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/local-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/equivalent_sets.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/properties.h>
- Binaryen `version_131` dedicated tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_131/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/test/passes/simplify-locals-nostructure.txt>
