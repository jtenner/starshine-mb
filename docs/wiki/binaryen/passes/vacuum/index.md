---
kind: entity
status: supported
last_reviewed: 2026-09-01
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
  - generic unused-parent removal that preserves one or multiple effectful/trapping children as ordered drops when Binaryen's defaultability rule permits
  - constant result-`if` arm selection and dropped result-`if` drop sinking when exactly one arm is `unreachable`
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

## 2026-08-29 level-zero flatten/preclean composition

Level-zero raw Vacuum no longer returns immediately after flattening an unbranched result block. It now applies the existing effect/trap-aware raw precleaner to that flattened body first, removing large dropped pure scalar forests while preserving checked truncation traps and the live result. A saved Binaryen-v131 semantic-profile case fell from `21,501` to `1,697` Starshine raw bytes; canonical Starshine and Binaryen are both `1,145` bytes and differ only because Starshine removes 54 additional unused local declarations. The pinned 16-case semantic matrix is `16/16` cleanup-normalized and semantically green. Follow-up case 34 added nontrapping dropped `memory.size` to both HOT cleanup paths and became a one-byte Starshine win. Pure scalar result `if`s and pure self-branch result blocks now disappear through matching HOT/raw legality checks while standalone void branch scaffolds remain. The control slice left 15 multi-family residuals while reducing Starshine canonical total from `22,581` to `20,500` bytes. Follow-up `RefI31` admission closes case 12 through the existing local-only body proof, and exact `V128Const` admission closes case 62 through self-branch cleanup. Each yields a one-byte canonical Starshine win. Unconditional branch dead-tail cleanup closes case 10, and finalizer-only non-fallthrough proof closes nested outer-branch case 82. Each yields another one-byte canonical win. Nested pure outer-branch wrappers, post-child self-branch blocks, and pure result loops reduce the 100-case Starshine canonical aggregate below Binaryen. Exact removal of fully dropped pure multivalue blocks then leaves 11 intentional structural Starshine wins, zero size-losing or unknown sample gaps, and a 309-byte canonical aggregate win. Broader deterministic closeout remains open. In the current 1,000-case v131 sample, post-arm empty-`if` reevaluation converts eight size losses into Starshine wins, conservative legacy no-throw `try` flattening makes five more cases exact, and recursive cleanup of live legacy catch bodies makes one more exact. The final 10-case `try_table` family now closes through an owner-block-only proof requiring one void `try_table`, nonempty catches all targeting that owner, and a no-throw/nonbranching protected body. Top-level implicit-function-label catches remain preserved. The refreshed samples have zero canonically larger cases: `42/58/0` smaller/equal/larger at 100 cases and `395/605/0` at 1,000 cases.

## 2026-08-21 guarded-hazard-first scheduling

The raw preclean admission path now computes its already-required instruction and stack-effect facts before the specialized candidate chain. When a function has both local writes and stack-effect hazards, Vacuum immediately runs the same preclean, optional second-preclean, and finalization used previously, or returns the same unchanged guarded-hazard classification. This avoids repeatedly scanning large guarded Emscripten functions for nop, SIMD, owner-branch, dropped-tee, div/rem, and repeated-load candidates that do not admit them.

A controlled primes A/B reduces aggregate raw-preclean time 39.701 → 36.876 ms (-7.12%) and direct level-correct Vacuum 12.176 → 11.779 ms (-3.27%) with byte-identical direct output. Regular explicit-v131 smoke is 1,000/1,000 normalized. The pass-owned aggregate's 301 smaller residuals are byte-identical under isolated pre-change and final binaries, so this is an execution-order performance improvement rather than a direct behavior change.

## 2026-09-01 deep singleton-wrapper benchmark and exact raw flatten

The calibrated native-release suite now includes seven Vacuum lanes: flat guarded-hazard HOT lift, direct pass, lower, and raw registry dispatch; nested HOT lift at depth 512; and raw registry dispatch at depths 512 and 1024. The nested cases are fail-closed: the source is a chain of singleton void blocks ending in exactly `i32.const; local.set; call`, preflight requires the named raw reason, all leaf operations remain, and the optimized body must have block depth zero.

Generic raw preclean scaled superlinearly because every wrapper entered the complete artifact-shape matcher chain before recursive reconstruction. An allocation-free depth walk now admits only at least 64 singleton void blocks with that exact three-instruction leaf and returns the leaf directly. Nearby depth-63, extra-debris, and loop-wrapper shapes remain on the old path.

Five matched clean-`ef85aa1a8`/current native-release medians on AMD Ryzen 7 8845HS with MoonBit `0.1.20260713` are:

- depth 512 raw registry: `3.680ms -> 16.89us` (`217.880x`, `-99.541%`);
- depth 1024 raw registry: `12.150ms -> 21.71us` (`559.650x`, `-99.821%`);
- flat lift/pass/lower/raw lanes remain approximately neutral and prove the optimization is limited to the deep exact family.

On the exact 3,140-byte depth-1024 wasm fixture, 11-sample command medians move Starshine `10.800ms -> 1.660ms` (`6.506x`, `-84.630%`) versus Binaryen v131 `2.601ms`. Baseline Starshine retained all 1,024 wrappers. Current Starshine emits 66 raw bytes because it preserves the import name section; after `--strip-debug`, current and Binaryen are byte-identical at 48 bytes with SHA-256 `cc435f18e75f3b2e0730373100929101de3b5824cb18200496bc3dfe71e1de18`.

The canonical production debug-WASI Vacuum attribution reports **zero** `raw-vacuum-deep-singleton-call-leaf` hits. Therefore this closes one synthetic size-losing/parity family and removes its superlinear path, but does not close `[P0-WALL-VACUUM]`; production raw preprocessing and writeback remain the owners.

The existing `vacuum-structural-wrappers` GenValid leaf now includes the depth-64 defined-call fixture. Explicit-v131 targeted comparison is `10000/10000` normalized with equal raw/canonical totals. Regular GenValid is also `10000/10000` normalized. The refreshed aggregate is `7175` normalized plus `2825` pre-existing canonically smaller Starshine residuals and zero failures; all 20 persisted current/baseline residual artifacts are byte-identical, so no aggregate drift is attributed to this change.

## 2026-09-01 broad unused-result and result-control expansion

A direct Binaryen-v131 source audit exposed three represented-surface gaps beyond the prior structural/raw matcher work:

- `drop(i32.add(call, call))` retained the pure parent instead of preserving the calls as two ordered drops;
- constant scalar result `if`s retained both arms;
- `drop(if (result T) ... unreachable ... value)` retained the outer drop instead of converting the concrete arm to `drop(value)` and making the `if` void.

Vacuum now recursively removes ordinary removable unary/binary/compare/convert/SIMD/select/tuple/ref wrappers while preserving every nonremovable child in evaluation order. Multiple preserved children retain Binaryen's defaultable-result requirement; nondefaultable multi-effect parents remain unchanged. A region-wide rewrite batches generic dropped-parent replacements and one liveness-checked known-detached deletion instead of splicing and validating each root independently. A shared-DAG regression proves a parent still feeding an observable global write remains live after its redundant dropped use disappears. On the 4,096-parent native fixture, five matched pre-batch/current medians improve HOT pass `427.080ms -> 20.840ms` (`20.493x`, `-95.120%`) and registry pipeline `431.750ms -> 31.480ms` (`13.715x`, `-92.709%`); candidate-free raw admission remains neutral at `305.44us -> 303.39us`. The exact call/pure/trap probe is stripped-byte-identical to Binaryen at SHA-256 `ef61a5455d450e40b7de272d59b4fe4660e2c1ac4864c32900402e98fe1f70bf`.

Constant result `if` admission is recorded during the existing single instruction-summary traversal, avoiding another whole-function scan. Raw and HOT paths select the constant arm under existing branch-target guards. Scalar dropped result `if`s with one exact `unreachable` arm now keep the condition and unreachable arm while sinking the drop into the concrete arm. The previous conservative dropped-shuffle/observable-tee expectation was corrected to Binaryen's verified shape: remove the shuffle shell and preserve the tee assignment as `local.set`; direct outputs are byte-identical at SHA-256 `65e60e2d93117b59b12c2ccd78239d1e8e932d65c0f5afb0b5737f09177fafe1`.

The calibrated suite grows from 29 to 36 cases. Seven new lanes cover dropped-parent HOT lift/pass/lower/registry decomposition, candidate-free raw admission, 2,048-function constant result selection, and 2,048 unreachable-arm drop sinks. The pass-owned `vacuum` aggregate grows from six to eight leaves with seed-varying `vacuum-dropped-parent-effects` and `vacuum-constant-result-if` profiles. Explicit-v131 results are:

- dropped-parent leaf: `10000/10000` normalized, equal canonical totals `667176/667176`;
- result-control leaf: `10000/10000` normalized, equal canonical totals `900000/900000`;
- eight-leaf aggregate: `7830` normalized plus `2170` pre-existing smaller hazard/local-set residuals, zero larger outputs or failures;
- regular GenValid: `100000/100000` normalized, zero failures;
- random-all: `5696` normalized plus `4304` canonically smaller residuals and zero larger outputs; the repaired `merge-similar-functions-nested` constant-result family contributes `35/35` newly exact replays;
- wasm-smith: `9934/9956` normalized plus 22 pre-existing byte-identical clean/current Starshine wins and the same 44 Binaryen-v131 tool failures. Twenty-one wins serialize valid empty function bodies instead of Binaryen's one-byte `nop`; case 3694 remains the documented six-byte loop/local-carrier win.

Fresh canonical production attribution is intentionally neutral. Three clean/current no-trace medians are `1705.620/1706.197ms` versus paired Binaryen v131 `711.836ms`; raw preprocessing is `559.636/564.746ms`, batch writeback `237.698/235.353ms`, and every clean/current output is byte-identical at SHA-256 `519d36fcf0e88121774ad188ceafba81b2d25d376517fc63fa02f074462c07a0`. The current `<=2x` gate is `1423.672ms`, so `[P0-WALL-VACUUM]` remains open for the remaining raw/writeback and shared command envelope.

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

## 2026-08-25 oversized array trap repair

`wasmtime-core3/core/gc/big-array-overflow` proved that dropped GC allocation is not always removable: `i32.const -21; array.new_default; drop` must trap with an oversized-array error. Vacuum now rejects negative constant lengths in both raw peepholes and HOT constructor cleanup while retaining established dynamic/effectful and nonnegative-constant allocation cleanup. `tests/repros/vacuum-big-array-overflow.wasm` is the direct regression. Full O4z preserves the trap, and the direct 10,000-case Vacuum lane matches 10,000/10,000 with zero failures.

## Current maintenance rule

- Treat this folder as the canonical home for future `vacuum` parity and scheduler research.
- Treat the 2026-09-01 eight-leaf evidence in [`./fuzzing.md`](./fuzzing.md) as current direct evidence: both new seeded leaves are `10000/10000` exact, regular GenValid is `100000/100000` exact, the aggregate has only the established smaller hazard/local-set outputs, random-all has zero canonically larger outputs after 35 result-control repairs, and wasm-smith retains only the classified empty-body and case-3694 Starshine wins plus Binaryen tool failures. `[VACUUM-PARITY]003` remains the earlier six-leaf closeout baseline and `[VACUUM-PARITY]002` the discovery baseline.
- Treat the raw primary-source manifest plus the refreshed Starshine code-map page as the compact answer for provenance and local navigation; future edits should keep them aligned with the broader strategy and WAT-shape pages.
- Treat the corrected 2026-04-20 freshness note as the current durable answer:
  - `version_129` already contains the explicit-`unreachable` preservation safeguard
  - the previously cited `9ee4...` commit is actually a `RemoveUnusedBrs` change
- Keep the Binaryen strategy page and the Starshine strategy page in sync whenever the in-tree implementation grows beyond the current `nop`, empty-void-block, dropped-pure-result, generic ordered child-effect preservation, proven-nontrapping constant div/rem, dropped-tee-to-set, empty-`if`, constant result-`if`, one-unreachable-arm drop sinking, finite no-backedge loop, exact unread default-struct allocation, fresh-GC observation pruning, guarded GC atomic-get pruning, branchy-loop dropped-local cleanup, local-only void-body, block-only-`unreachable`, empty-then/live-else `if` inversion, large lowered-function precleaning, and empty-function canonicalization slice.

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
