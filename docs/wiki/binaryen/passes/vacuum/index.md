---
kind: entity
status: supported
last_reviewed: 2026-07-21
sources:
  - ../../../raw/research/1649-2026-07-18-vacuum-shared-dag-admission-and-public-hso-attribution.md
  - ../../../raw/binaryen/2026-04-22-vacuum-primary-sources.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./effect-pruning-and-traps-never-happen.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../remove-unused-brs/index.md
  - ../simplify-locals/index.md
---

# `vacuum`

## Role

- `vacuum` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, `vacuum` is a function-parallel cleanup pass whose public summary is `removes obviously unneeded code`.
- The real job is broader than the current in-tree Starshine implementation and narrower than a full DCE pass.

A good beginner summary is:

- if some code computes a value nobody will use,
- and removing the wrapper does not lose observable effects or break types,
- Binaryen tries to throw away the wrapper and keep only the parts that still matter.

That includes more than `nop` removal, but less than full dead-code elimination.

## Why this pass matters

- The tracker's earlier saved-audit `none` queue is now clear, so implemented folders still missing immutable primary-source captures or exact Starshine code-map coverage remain good follow-up targets.
- This folder now has both of those additions too, so future threads should not come back to `vacuum` for the same provenance-and-navigation gap.
- The canonical no-DWARF `-O` / `-Os` scheduler uses `vacuum` **four times** in the default function pipeline.
- The saved generated-artifact `-O4z` audit also saw `vacuum` at four real top-level Binaryen slots:
  - slot `23`
  - slot `33`
  - slot `37`
  - slot `47`
- The saved Binaryen debug log contains `72` `running pass: vacuum` lines in total, so nested reruns make it far more common than the four visible top-level slots suggest.
- The provenance and checked ordered-neighborhood audit is recorded, and both 2026-07-21 three-family direct slices are closed. Fresh native Binaryen-v131 signoff is exact at regular GenValid `100000/100000` and pass-owned aggregate `10000/10000`; wasm-smith and broad random-all leave only measured six-byte Starshine wins, with no size-losing, unknown/risky, validation, or true-semantic residual.

## Most important durable takeaways

- Binaryen `vacuum` is **not** just a `nop` sweeper.
- Binaryen `vacuum` is **not** a CFG or liveness pass.
- The pass is built around one generic unused-result optimization helper plus special visitors for:
  - `block`
  - `if`
  - `loop`
  - `drop`
  - `try`
  - `try_table`
  - the function body itself
- The pass depends heavily on effect analysis, helper-based dropped-child rebuilding, and post-rewrite refinalization.
- The canonical no-DWARF scheduler uses it as repeated cleanup glue between other local and late cleanup passes, not as a one-shot finalizer.
- Current Starshine still implements a focused subset of upstream behavior, but that subset is now audit-complete for the current direct pass and checked `-O4z` neighborhood evidence. It covers:
  - recursive `nop` region-entry trimming
  - dropped pure scalar result pruning for nontrapping numeric/ref/tuple shapes
  - removing empty void blocks
  - unwrapping blocks whose only payload is `unreachable`
  - flipping empty-then/live-else void `if`s to Binaryen's one-armed double-`eqz` form
  - raw large-function precleaning for cheap pure `const`/`drop` and `nop` debris inside lowered structured bodies
  - dropped constant `i32`/`i64` div/rem pruning when constant operands prove the operation cannot trap, while preserving zero-divisor and signed-minimum/`-1` traps
  - `drop(local.tee value)` rewriting to `local.set value` in direct and nested lowered regions, preserving the value computation exactly once
  - Binaryen-style single-`nop` canonicalization for proven local-only void bodies even when they contain no `local.tee`; result-producing bodies, calls, external writes, traps, and loops with a branch to their own label remain ineligible
  - empty void `if` removal: removable pure conditions disappear, while call/load/trapping conditions are preserved as `drop(condition)`
  - finite local-only loop cleanup when no branch targets the loop label, while self/back-branching loops remain intact
  - exact unread `struct.new_default` allocation cleanup when the reference is stored only to otherwise removable local traffic; observed allocations remain intact
  - dropped fresh-GC observations: pure `ref.eq` / `ref.test` disappear, and unused nonnull `struct.get*` wrappers disappear while a trapping `ref.as_non_null` operand is retained as a drop
  - dropped `struct.atomic.get*` from concrete nonnull receivers when the declared struct is unshared, or shared with an immutable field; nullable receivers and shared mutable fields remain
  - loop-local `drop(local.get)` cleanup inside branchy structured functions without removing the loop or its self/back branch
  - Binaryen-style single-`nop` function-body canonicalization when `vacuum` rewrites or re-lowers an otherwise empty function body
- Research note [`1649`](../../../raw/research/1649-2026-07-18-vacuum-shared-dag-admission-and-public-hso-attribution.md) closed a newly proven current-artifact wall-time owner. The 2026-07-21 parity slice moved that memoization to the complete local-only-body proof, so removing the old tee-presence gate does not reintroduce exponential traversal on shared HOT DAGs.
- A fresh 2026-04-20 source check corrected an earlier repo-local note:
  - the 2026-02-27 explicit-`unreachable` preservation change belongs to Chromium commit `f284d54...`, not `9ee4a25...`
  - that change is already present in Binaryen `version_129`
  - current GitHub `main` still matches `version_129` `Vacuum.cpp` in substance

So explicit `unreachable` preservation is part of the tagged `version_129` oracle here, not a newer trunk-only drift note.

## Beginner warning: what the name hides

The easy wrong mental model is:

- `vacuum` just cleans stray junk after other passes

The safer mental model is:

- `vacuum` is Binaryen's effect-aware cleanup crew for unused results and trivial residue,
- with special logic for block fallthroughs, `if` simplification, drop-of-tee cleanup, EH no-throw shapes, TNH trap-path cleanup, and function-level no-oping.

That difference matters a lot if Starshine ever wants real Binaryen parity.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation, helper dependencies, scheduler placement, visitor phases, and the corrected freshness story.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Compact source-confirmed owner/test-map page for `Vacuum.cpp`, the direct helper dependencies, public pass registration, nested rerun context, and the shipped `vacuum-*` lit family.
- [`./effect-pruning-and-traps-never-happen.md`](./effect-pruning-and-traps-never-happen.md)
  - Focused guide to the easiest part of the pass to misunderstand: unused-result pruning, `removableIfUnused`, dummy-zero replacement values, TNH cleanup, and explicit-`unreachable` preservation.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering positive, negative, bailout, EH, GC, string, and TNH-specific rewrite families.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current in-tree Starshine strategy with the exact MoonBit registry, dispatch, helper, validation-guard, trace, perf, and CLI replay code map, plus the major Binaryen behaviors the repo still does not model.

## Current maintenance rule

- Treat this folder as the canonical home for future `vacuum` parity and scheduler research.
- Treat the `[VACUUM-PARITY]003` explicit-v131 results in [`./fuzzing.md`](./fuzzing.md) as current direct evidence: all `289` prior residuals were replayed, the three former size-losing families are exact, regular `100000` and aggregate `10000` are exact, and the wasm-smith/random-all residuals are only measured six-byte Starshine wins. `[VACUUM-PARITY]002` remains the discovery baseline.
- Treat the raw primary-source manifest plus the refreshed Starshine code-map page as the compact answer for provenance and local navigation; future edits should keep them aligned with the broader strategy and WAT-shape pages.
- Treat the corrected 2026-04-20 freshness note as the current durable answer:
  - `version_129` already contains the explicit-`unreachable` preservation safeguard
  - the previously cited `9ee4...` commit is actually a `RemoveUnusedBrs` change
- Keep the Binaryen strategy page and the Starshine strategy page in sync whenever the in-tree implementation grows beyond the current `nop`, empty-void-block, dropped-pure-result, proven-nontrapping constant div/rem, dropped-tee-to-set, empty-`if`, finite no-backedge loop, exact unread default-struct allocation, fresh-GC observation pruning, guarded GC atomic-get pruning, branchy-loop dropped-local cleanup, local-only void-body, block-only-`unreachable`, empty-then/live-else `if` inversion, large lowered-function precleaning, and empty-function single-`nop` canonicalization slice.

## Sources

- research note 0130
- research note 0210
- research note 0249
- research note 0520
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../tracker.md`](../tracker.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [research note 0093](../late-pipeline-dispatch.md) preserves the saved generated-artifact `-O4z` audit root and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Vacuum.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-hints.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/drop.h>
- Representative Binaryen `version_129` tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-func.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-eh.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-strings.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-tnh.wast>
- Freshness / correction sources:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Vacuum.cpp>
  - <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/f284d54ef60a5b6e6c33b4c1f4d4b423f7a6b1c3%5E%21/>
  - <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/9ee4a25ee15ab53e796cb0b3f320cafa2622c407%5E%21/>
