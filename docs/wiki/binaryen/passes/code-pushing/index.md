---
kind: entity
status: strong
last_reviewed: 2026-07-26
sources:
  - ../../release-horizon-and-oracles.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./segment-selection-and-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../late-pipeline-dispatch.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
supersedes:
---

# `code-pushing`

## Binaryen v131 renewal status

The 2026-07-26 renewal is complete for the represented surface. Binaryen v130, v131, and current-main `CodePushing.cpp` are byte-identical at SHA-256 `ed4ce60cc1cc0ae836fddb83b6e8c58dec36e196e74e5a514dd3f5b34f4f401c`; the reviewed v131 and current-main lit fixtures are also identical. The only v130-to-v131 fixture drift found was the TNH expected form changing one `local.tee` to `local.set`, which Starshine now matches.

The executable audit found and repaired four Starshine gaps: the global O4z bypass that silently skipped the pass, legacy `try`/`catch_all` movement through a fully caught throw, an unused local-copy set incorrectly moved past a final `if`, and ordered consecutive sets consumed by different `if` arms. Return-in-condition coverage was also added during the investigation; the final implementation retains the established fixed-point scanner while preserving all new behavior. Official v131 fixture replay is exact for legacy EH, GC, and TNH. Remaining modern-EH, ordinary-into-`if`, and IIT text differences are bounded `nop`/empty-arm, unreachable/dead-tail, or structural-lowering drift; applying the same Binaryen-v131 `-O` cleanup to both outputs produces byte-identical wasm for all three fixtures. The official ordered-atomics fixture remains outside the represented surface because Starshine rejects its ordered atomic memarg before `code-pushing` runs (`memarg alignment too large for access width`).

The earlier explicit-v131 `random-all-profiles` discovery lane on 2026-07-22 also found one narrow behavior family: Binaryen delays a pure single-first-assignment `local.set` even when the destination has zero reads, while Starshine previously required a suffix use. Starshine matches the three reduced destinations proven by direct oracle probes: ordinary void `if`, dropped value `if`, and no-payload `br_if` to a void block label. The path requires exactly one write, zero reads, an existing movable-value/effect proof, a non-final push point, and no unsafe crossed root; loop labels and broader branch forms remain outside this repair.

That zero-read closeout used native SHA-256 `05bda3d8275dc5fa2174acdbe443c5892f04abbb92ca0b0842d8d34e15908fc1`. Focused HOT, white-box, command-adapter, and GenValid suites passed `141/141`, `11/11`, `1/1`, and `161/161`; full Moon passed `9766/9766`. Its matrix was regular GenValid `100000/100000` exact, random all-profiles `10000/10000` exact, pass-owned aggregate `10000/10000` with `4493` normalized plus `5507` documented local-cleanup-normalized matches, and wasm-smith `9956/9956` exact comparable cases plus `44` classified Binaryen/tool failures, with zero Starshine validation, generator, property, command, raw mismatch, unknown/risky, or true-semantic failures.

## Role

`code-pushing` is an upstream Binaryen function pass and an active explicit HOT pass in Starshine.

Its purpose is to move single-assignment local writes later when doing so preserves behavior and makes the write execute closer to the control-flow path that consumes it.

The current source-backed Binaryen mental model is:

- analyze locals for single-first-assignment (SFA) behavior;
- scan structured block root segments with `Pusher`;
- admit only pushable `local.set` roots whose value effects are safe;
- push toward `if`, `switch`, conditional `br`, or dropped push-point wrappers;
- sink into the one `if` arm that reads the local, with an important unreachable-arm post-use allowance;
- rely on later optimizer cycles for deeper recursive opportunities.

The current Starshine implementation is closed for the user-directed CP audit under Starshine's pass-wide completion criteria. `[O4Z-AUDIT-CP]` closed in `0892`, the replacement-oriented follow-up `[O4Z-AUDIT-CP-BINREP]` closed in `0901`, and `0910` is the explicit closeout marker after the reopened IIT, intrinsic, refinalization, and preset blockers were closed:

- a distinct Binaryen-compatible `--ignore-implicit-traps` / `-iit` option wired through CLI/config/command options/hot-pass context, with lit-derived memory-load `br_if` movement that remains separate from TNH;
- safe movable-value `local.set` sinking into the single `if` arm that contains all reads of that local;
- a first ordinary-void-`if` segment movement slice that moves one SFA set after the `if` when all reads are same-region suffix reads;
- a narrow zero-read slice that moves an exactly-once pure set after an ordinary void `if`, dropped value `if`, or no-payload void-block-target `br_if` when another root follows the push point;
- a dropped value-`if` segment movement slice that moves one SFA set after the dropped wrapper when all reads are same-region suffix reads;
- narrow conditional-branch segment movement slices that move one SFA set after a void-block-target or void-loop-target `br_if`, a dropped void-label `br_on_null`, a one-result-block `br_on_non_null`, a dropped one-result-block `br_on_cast`, a dropped one-result-block `br_on_cast_fail`, and a branch-value slice for value-block-target `br_if`, when the branch/guard/payload does not read the local and all reads are same-block / same-loop-body suffix reads;
- ordered multi-set movement slices that move adjacent local-independent SFA sets after an ordinary void `if`, dropped value-`if`, narrow void-block-target / void-loop-target `br_if`, dropped void-label `br_on_null`, one-result-block `br_on_non_null`, dropped one-result-block `br_on_cast`, dropped one-result-block `br_on_cast_fail`, or value-block-target `br_if` while preserving source order;
- an ordered direct local-copy multi-set slice that preserves source order across the same three push-point families when copied source locals are not rewritten by the crossed push point;
- ordered separator-window multi-set slices that preserve source order across the same three push-point families when only `nop`, `drop(const)`, or `drop(local.get)` roots separate local-independent SFA sets, plus a bounded `drop(global.get)` separator slice for ordinary void `if` and dropped value-`if` push points only;
- a dedicated `code-pushing-all` GenValid profile covering the currently aggregate-safe `if`-arm, after-`if`, dropped-`if`, no-branch-value `br_if`, value-block-target `br_if`, dropped `br_on_null`, one-result-block `br_on_non_null`, two-result block-label `br_on_non_null` prefix-payload, dropped one-result-block `br_on_cast`, dropped one-result-block `br_on_cast_fail`, ordinary-`if` multi-set, dropped-`if` multi-set, no-branch-value `br_if` multi-set, local-copy multi-set, `nop`-window multi-set, loop-target `br_if`, `drop(const)`-window multi-set, `drop(local.get)`-window multi-set, and `drop(global.get)`-window ordinary-/dropped-`if` positive families;
- guarded movement of selected `global.get`, local-copy setup shapes, and a narrow non-null `struct.get` heap-read shape across safe intervening roots, with pure SFA values now covered moving across intervening `global.set`, `table.set`, `memory.store`, dropped `memory.grow`, dropped `memory.size`, dropped `table.size`, dropped `table.grow`, `table.copy`, `table.fill`, `memory.copy`, `memory.fill`, `memory.init`, `data.drop`, `table.init`, and `elem.drop` roots before a later `br_if`; `global.get` candidate values remain stationary before matching `global.set` mutation but can cross a direct `global.set` to a different global and a nested block containing such disjoint writes plus trivial `nop` / dead `drop(const)` roots, while direct or nested disjoint global writes whose value contains a call remain stationary; `memory.size` / `table.size` candidate values remain stationary before matching growth, and memory/table-reading candidates remain stationary before matching, reduced unrelated, and the first multitable `table.get T0` / `table.set T1` writes; call, no-payload and payload-bearing tag-based `throw`, rethrow-containing HOT regions, and `try_table` roots including reference-carrying `catch_all_ref`, tag-payload `catch`, payload-plus-reference `catch_ref`, and reduced multi-catch probes preserved as segment-order barriers before later push points; a source-backed pure-value `throw_ref` / later-`br_if` movement refinement; and a legacy no-rethrow `try`/`catch` WAT fixture that currently observes Binaryen-positive movement through Starshine's try-lowered HOT block path;
- a first atomics/GC slice matching Binaryen `code-pushing-atomics.wast`: the non-null `struct.get` may cross atomic loads but not atomic stores, both for into-`if` and segment movement;
- a lit-derived `ref-into-if` slice matching Binaryen `code-pushing_into_if.wast` by sinking a direct `local.get` ref set into the reachable `if` arm and weakening the moved non-null body-local ref type to nullable so the output validates after dominance changes;
- one Starshine-local typed/dead-block flattening helper near unreachable context.

Acceptance does **not** require raw wasm/text or transform-for-transform parity. The direct pass is complete when it preserves Binaryen semantics, produces valid wasm, and stays at least 50% as fast as Binaryen on comparable pass-local measurements.

## 2026-04-26 correction

This folder previously contained a 2026-04-25 correction that removed `Pusher`, segment selection, and local profitability-style movement from the upstream teaching. That correction was itself stale/wrong after a fresh official-source recheck.

The preferred source manifest is now:

- [`../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- research note 0807
- research note 0454

The 2026-06-20 `version_130` refresh is the current local-oracle source bridge. It keeps the same owner and scheduler surfaces, adds `code-pushing-atomics.wast` as an audit-relevant lit family, and records the `version_130` effect-ordering drift from `invalidates(...)` to `effects.orderedBefore(cumulativeEffects)`. Keep the useful part of the 2026-04-25 warning: do not teach arbitrary two-live-arm duplication as the baseline. But restore the correct upstream owner concepts: `LocalAnalyzer`, `Pusher`, segment windows, `isPushable`, `isPushPoint`, and `optimizeSegment`.

## Why it matters

- Binaryen schedules `code-pushing` in the canonical no-DWARF function pipeline between `precompute` and the tuple/local-cleanup neighborhood.
- The saved generated-artifact `-O4z` audit recorded it as top-level skipped slot `20` before Starshine grew the current direct subset.
- Starshine's `tuple-optimization` exact-slot story depends on this pass and `simplify-locals-nostructure` being represented honestly in the scheduler and preset replay; `0907` records that the public `optimize` / `shrink` presets now have focused proof for `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure`.
- The pass is easy to over-broaden. Correctness depends on SFA local proofs, effect ordering/invalidation, trap policy, GC/reference behavior, atomics, EH, and post-if read rules.

## Inputs and outputs

### Upstream Binaryen input shape

- Function-local structured expression trees.
- Block root lists containing `local.set` temporaries and later push points.
- Local get/set information and effect properties.
- Optimization options that affect implicit traps and traps-never-happen behavior.

### Upstream Binaryen output shape

- Some pushable `local.set` roots move later within the same block segment, including after supported `if`, dropped-`if`, narrow no-branch-value `br_if`, dropped void-label `br_on_null`, one-result-block `br_on_non_null`, dropped one-result-block `br_on_cast`, dropped one-result-block `br_on_cast_fail`, and bounded branch-value `br_if` push points. 2026-06-25 reduced probes show a pure constant SFA set also moves across intervening `global.set`, `table.set`, `memory.store`, dropped `memory.grow`, dropped `memory.size`, dropped `table.size`, dropped `table.grow`, `table.copy`, `table.fill`, `memory.copy`, `memory.fill`, `memory.init`, `data.drop`, `table.init`, and `elem.drop` roots before a later `br_if`; `global.get G0` also moves across a direct disjoint `global.set G1` when `G0 != G1` and across a nested block containing only such disjoint writes, while a disjoint global write whose value contains a call remains stationary. This does not permit values that read global/table/memory state, including the source-backed `global.get`-candidate / matching-`global.set` boundary, `memory.size` / `table.size` candidate growth boundaries, and `i32.load` / `table.get` read-before-write boundaries, to cross matching mutation or the reduced unrelated memory/table writes covered by `0880` and the multitable `table.get T0` / `table.set T1` boundary covered by `0882`.
- Some sets move into the only `if` arm that reads their local.
- Under `--ignore-implicit-traps` / `-iit`, a memory-load-backed SFA set can move after an eligible `br_if` when no intervening memory write, call, or ordered effect can change the loaded value or observability; the same shape remains stationary by default.
- Moved sets keep order and should execute on the same or fewer paths as allowed by the proof.
- Unproven shapes stay unchanged; local Binaryen v130 kept a pure SFA set before an intervening call and later `br_if`, now mirrored by Starshine as a call segment barrier in `0850`, `0855` narrows the EH distinction by moving the same pure set after a later `br_if` when the intervening root is non-fallthrough `throw_ref`, `0857` records that no-payload tag-based `throw` remains stationary, `0860` records that payload-bearing tag-based `throw` remains stationary, `0858` records that `try_table` remains stationary, `0859` records that a reduced no-rethrow legacy `try`/`catch` probe moves after the later `br_if` in Binaryen while Starshine currently covers the observable movement through a try-lowered HOT block fixture, `0861` records that a rethrow-containing legacy try/catch stays stationary and is now guarded through direct HOT rethrow coverage, `0863` extends the `try_table` stationary boundary to tag-payload `catch` and payload-plus-reference `catch_ref` handlers, and `0864` records the same stationary behavior for a reduced multi-catch `try_table`.

### Current Starshine input shape

- HOT functions lifted into `HotFunc`.
- Region roots containing local writes, structured `if`s, blocks, and unreachable roots.

### Current Starshine output shape

- Narrow single-consuming-arm local-set sinks become `nop` at the original root plus a cloned `local.set` inside the target arm.
- The first segment movement slices can replace original SFA sets with `nop` and insert cloned sets immediately after an ordinary void `if`, after a dropped value-`if` wrapper, after a narrow void-block-target / void-loop-target `br_if`, after a dropped void-label `br_on_null`, or after a value-block-target `br_if` with one branch payload when all uses are later suffix reads. Multi-set movement is currently limited to adjacent local-independent sets before ordinary void `if`, dropped value-`if`, narrow no-branch-value void-block-target / void-loop-target `br_if`, dropped void-label `br_on_null`, and value-block-target `br_if` push points, plus direct local-copy, `nop`-separated, `drop(const)`-separated, `drop(local.get)`-separated, and bounded ordinary-/dropped-`if` `drop(global.get)`-separated subcases with explicit source-local/order boundaries. Simple no-branch-value `br_table` block-exit windows, the first value-carrying result-block `br_table` probe, and one multi-label nested-block `br_table` probe are currently protected no-mutation boundaries, not a mutating switch implementation.
- Narrow non-null `struct.get` values sourced from `local.get` may move across atomic loads under the same local-use proof, but atomic stores remain a movement boundary, mirroring the shared-struct `version_130` atomics lit family through HOT fixtures until Starshine grows a shared-GC WAT surface.
- Some typed/dead block roots near unreachable context are spliced into the parent region.
- Unmatched shapes stay unchanged.

## Invariants and correctness constraints

- Do not move non-SFA locals without a stronger local-use proof.
- Do not move values across effects that can invalidate or must be ordered after the delayed computation.
- Do not change trap timing unless the active trap policy explicitly permits that behavior; Starshine now carries `traps_never_happen` into hot passes and uses it for the reduced exact integer div/rem into-if family, and `ignore_implicit_traps` separately covers the lit-derived memory-load `br_if` movement from `0902`. The old `--ignore-implicit-traps` boundary in `0897` is historical evidence only; do not treat IIT as a TNH alias.
- Do not strand post-if uses unless the non-consuming arm cannot fall through or another proof preserves the value.
- Do not treat two-live-arm duplication as a default `code-pushing` behavior.
- Preserve order among multiple pushed sets, including consecutive multi-set windows sunk into a sole consuming `if` arm.
- Preserve function validity after structural mutation.
- Keep Starshine-local dead-block flattening documented separately from upstream Binaryen behavior.
- Public preset CP placement is claimed only for the focused Binaryen-shaped neighborhood validated in `0907`; broader preset parity still follows the repo's normal preset-audit rules.
- Do not treat raw wasm/text drift as a blocker when normalized/canonical semantic comparison is green.

## Notable edge cases

- One `if` arm consumes the local and the other does not.
- Post-if reads where the non-consuming arm is unreachable.
- `switch` and conditional `br` push points, including the current simple, value-carrying, and multi-label `br_table` no-mutation boundaries closed for the current replacement follow-up by `0898`, the bounded Binaryen-positive one-result-block `br_on_non_null`, dropped one-result-block `br_on_cast`, and dropped one-result-block `br_on_cast_fail` families, and the current Binaryen-stationary prefix-payload `br_on_null` / `br_on_cast` / `br_on_cast_fail` boundaries.
- Trap-capable expressions under default, Binaryen `--ignore-implicit-traps` / `-iit`, and TNH options, with default trap semantics, IIT memory-load relaxation, and TNH exact-div/rem relaxation kept distinct.
- GC/reference operations such as `ref.func`, casts, null checks, the `version_130` atomics/GC ordering family, and the implemented `ref-into-if` local-refinalization slice documented in `0906`, with broader official shared-GC fixture support still separate.
- Call and EH control where movement can change observability, including Binaryen's `binaryen-intrinsics/call.without.effects` no-effects call surface: `0899` records the old missing-import-metadata blocker, `0904` lands the exact HOT module-context import identity prerequisite, and `0905` implements only the exact imported intrinsic with pure/nontrapping arguments. Ordinary imports and defined calls remain barriers. The current `throw_ref` positive movement, no-payload and payload-bearing tag-based `throw` / `try_table` stationary split including the `catch_all_ref` try-table boundary, no-rethrow legacy `try`/`catch` try-lowered movement characterization, and rethrow-containing HOT stationary boundary remain separate.
- Starshine dead-block flattening, which is local cleanup rather than upstream `CodePushing.cpp` behavior.

## Validation

The 2026-07-26 Binaryen-v131 renewal used explicit `wasm-opt version 131 (version_131)` SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c` and rebuilt native Starshine SHA-256 `e1ec8c88737f5a1ac88df5d3ce71eada3a0c155d6bba8989bab9acdd94161c15`. `moon info`, `moon fmt`, `src/passes` tests (`6450/6450`), and full `moon test` (`9938/9938`) were green. The aggregate `bun validate full --profile ci --target wasm-gc` wrapper reproduced the repository's documented intermittent no-return-code failure at its initial `moon info`; the same `moon info` and Moon tests succeeded directly. Final direct evidence was:

- dedicated `code-pushing-all`: `10000/10000`, `4769` direct normalized plus `5231` `local-cleanup-debris` normalized, zero mismatches or failures;
- ordinary `binaryen-oracle-portable`: `10000/10000` exact normalized, zero failures;
- broad `pass-fuzz-stress`: `10000/10000` exact normalized, zero failures;
- explicit wasm-smith: all `9956` comparable cases exact normalized, zero Starshine/validation/property failures and `44` classified Binaryen-v131 parser/tool failures (`39` empty rec groups, one invalid tag index, one table index out of range, and three bad section sizes).

The bounded 100-function synthetic pass-local probe stayed under the repository's absolute target at a Starshine median of about `0.359s`; its rejection-heavy C++ comparison was about `0.00349s`, so it is not evidence for the relative `<=2x` floor. Relative performance acceptance therefore remains grounded in the comparable 2026-05-09 artifact measurement below, while the new v131 behavior is bounded by the current direct lanes and the pass's existing large-function guards.

The older direct `--pass code-pushing` lane was accepted under the previous v0.1.0 direct-pass standard. The later `[O4Z-AUDIT-CP]` behavior-parity audit and user-directed reopenings are now closed by `0892`, `0901`, `0902`, `0905`, `0906`, `0907`, and explicit marker `0910`. The 2026-05-09 comparable-artifact evidence remains useful for the relative performance criterion:

- `moon info`, `moon fmt`, and `moon test` green;
- `.tmp/pass-fuzz-code-pushing` compared 6759/10000 cases with 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures;
- direct debug-artifact replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1687067` reported `Normalized WAT equal: yes` and `Canonical function compare equal: yes`;
- pass-local timing was about 1658ms for Starshine versus about 1311ms for Binaryen, which is above the required 50%-of-Binaryen speed floor.

Raw canonical wasm/text still differs, but that is accepted representation drift rather than active `code-pushing` work.

For docs maintenance:

- prefer the 2026-06-20 `version_130` source/lit refresh over the older 2026-05-05, 2026-04-26, and 2026-04-25 corrections;
- search for stale “no `Pusher`,” “no segment selection,” or “no local profitability” wording in this folder;
- keep the no-two-live-arm-duplication warning, but do not erase Binaryen's real `Pusher` model.

The current post-`0884`/post-`0887` final matrix and stop condition are recorded in research note 0892. The matrix has four fresh final-lane results: research note 0888 refreshed the dedicated `code-pushing-all` lane at `10000/10000` compared with `4769` normalized, `5231` cleanup-normalized, no raw mismatches/failures, and all 19 aggregate leaves sampled; research note 0889 refreshed explicit wasm-smith at `9956/10000` compared, all normalized, no raw mismatches, and `44` cached Binaryen/tool command failures; research note 0890 refreshed regular GenValid at `100000/100000` compared, all normalized, and no failures; research note 0891 refreshed broad named `pass-fuzz-stress` at `10000/10000` compared, all normalized, and no failures. The older post-call-barrier regular `0854`, wasm-smith `0852`, dedicated `0851`, and broad named `0853` lanes are superseded for final-current evidence by later behavior changes and refreshes. `[O4Z-AUDIT-CP]` is closed for the v0.1.0 direct-pass release gate, and `0910` confirms no active useful user-directed CP gap remains known. Reopen only for a new source-backed CP behavior gap, a generated mismatch classified as a real CP behavior/validity issue, a CP validation failure, a shared-GC fixture requirement for an actual CP behavior surface, or preset-neighborhood drift.

For future source-backed `code-pushing` widening after the closed `[O4Z-AUDIT-CP]` release-gating audit:

1. add focused tests in `src/passes/code_pushing_test.mbt` before mutating behavior and whitebox tests in `src/passes/code_pushing_wbtest.mbt` for analyzer-only surfaces;
2. build on the analyzer/segment-discovery slice from research note 0808, the ordinary-`if` movement slice from research note 0809, the dropped-`if` movement slice from research note 0811, the narrow `br_if` movement slice from research note 0812, the ordinary-`if` ordered multi-set slice from research note 0813, the dropped-`if` ordered multi-set slice from research note 0814, and the `br_if` ordered multi-set slice from research note 0815, before broad mutation;
3. include the loop-target `br_if` widening slice from research note 0818 when reasoning about conditional-branch movement, the `drop(const)` window slice from research note 0819 plus `drop(local.get)` window slice from research note 0820 when reasoning about non-set separators, the `br_table` boundary slice from research note 0822 before attempting switch mutation, and the atomics/GC slice from research note 0823 before widening reference or memory-order movement;
4. validate direct pass execution through registry and command surfaces;
5. compare reduced WAT against Binaryen `wasm-opt --code-pushing` for each widened family;
6. include the dedicated `code-pushing-all` GenValid lane, currently with `--normalize local-cleanup-debris` for bounded Starshine `nop`/empty-else cleanup drift;
7. then run pass-fuzz / artifact comparisons under the standard pass signoff criteria;
8. if a future widening changes direct behavior or the local-cleanup neighborhood, refresh the public preset proof from `0907`.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Current source-backed Binaryen strategy: `LocalAnalyzer`, `Pusher`, segment scanning, push points, effects, and `if` arm sinking.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Upstream owner-file and lit-test map for the corrected strategy.
- [`./segment-selection-and-barriers.md`](./segment-selection-and-barriers.md)
  - Movement-safety guide centered on SFA locals, effect barriers, push points, `if` arm rules, and Starshine-local dead-block flattening.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly before/after and bailout shape catalog, including current Starshine positive and negative families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Exact local code map and current subset.
- [`./fuzzing.md`](./fuzzing.md)
  - Dedicated `code-pushing-all` GenValid profile and compare lanes.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  - First-slice and validation plan for future broader parity work.

## Sources

- [`../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- research note 0845
- research note 0844
- research note 0829
- research note 0828
- research note 0827
- research note 0826
- research note 0825
- research note 0824
- research note 0822
- research note 0821
- research note 0820
- research note 0819
- research note 0816
- research note 0815
- research note 0814
- research note 0813
- research note 0812
- research note 0811
- research note 0810
- research note 0809
- research note 0808
- research note 0807
- research note 0806
- research note 0527
- research note 0454
- research note 0413
- [`../../../../../src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt)
- [`../../../../../src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- Binaryen `version_130` `CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/CodePushing.cpp>
- Binaryen current-main `CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodePushing.cpp>
