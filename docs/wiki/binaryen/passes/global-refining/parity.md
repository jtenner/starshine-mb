---
kind: comparison
status: supported
last_reviewed: 2026-06-18
sources:
  - ../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md
  - ../../../raw/research/0236-2026-04-21-global-refining-starshine-strategy-followup.md
related:
  - ./starshine-hot-ir-strategy.md
  - ../../../../../src/passes/global_refining.mbt
  - ../../../../../src/passes/global_refining_test.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
---

# `global-refining` Binaryen parity

## Durable conclusions

- Binaryen's `global-refining` is a small module pass that tightens global declaration types from the initializer plus all observed `global.set` value types, then repairs `global.get` cached types.
- The real correctness story is mostly about **boundary legality**:
  - imported globals stay untouched
  - exported mutable globals stay untouched in open world
  - exported immutable globals may refine in open world only when the new type is public
  - current official `version_130` closed-world behavior still skips all exported globals
- The current Starshine implementation now matches the broad exported-boundary split on the direct parity lane: mutable exports stay untouched, immutable exports can refine only when the refined type remains public, closed-world exports stay untouched, and private globals still tighten from initializer-plus-write LUBs.
- The 2026-06-03 O4z audit restored the direct `global-refining` slot under `-O4z` options and added initializer coverage for `ref.func`, `ref.i31`, `string.const`, and exact GC constructor results.
- The 2026-06-18 `[GR-002]` slice aligned Starshine's function-reference LUB behavior with Binaryen `version_130`: `ref.func` facts are exact, nullable function bottom plus exact `ref.func` joins to nullable exact, and all-non-null `ref.func` families refine to non-null exact function refs.
- The 2026-06-18 `[GR-003]` slice replaced the syntax-limited initializer classifier with local expression typechecking for global initializers, while preserving Binaryen-style bottom typing for direct `ref.null` initializers. This closed the direct `ref.i31` and `extern.convert_any` initializer mismatch family from `.tmp/pass-fuzz-global-refining-gr002-10000`; the follow-up direct 10000-case lane `.tmp/pass-fuzz-global-refining-gr003-10000` had `0` mismatches.
- The 2026-06-18 `[GR-004]` slice aligned open-world immutable exported globals with the local all-features/custom-descriptors feature model used by the Binaryen oracle lane: exact refs and types whose bodies mention exact refs are public for this pass locally, matching Binaryen `--all-features` `PublicTypeValidator` behavior.
- The 2026-06-18 `[GR-005]` proof closed Binaryen-style `global.get` retagging as representation-specific locally: Starshine does not cache `global.get` result types in boundary IR, so fresh validation/typechecking sees refined declarations directly.
- The 2026-06-18 `[GR-006]` final direct closeout found no true `global-refining` semantic mismatches. The only residual raw mismatches in the 100000-case lane are pass-independent unreachable-debris canonicalization on no-global modules.

## Current in-tree status

- The implementation lives in [`../../../../../src/passes/global_refining.mbt`](../../../../../src/passes/global_refining.mbt).
- The focused suite lives in [`../../../../../src/passes/global_refining_test.mbt`](../../../../../src/passes/global_refining_test.mbt).
- Registry and preset coverage live in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt), and module-pass dispatch in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt).
- The pass is active in-tree and is scheduled in the early module cluster before `global-struct-inference`.

## Saved generated-artifact evidence

The saved generated-artifact `-O4z` audit shows slot `5` (`global-refining`) as:

- exact wasm equal: `yes`
- normalized WAT equal: `yes`
- Starshine wall/runtime: `403.297 ms`
- Binaryen wall/runtime: `198.980 ms`
- Starshine in-pass time: `0.611 ms`
- Binaryen in-pass time: `2.100 ms`
- both outputs valid: `yes`

That is strong evidence that the current local pass behaves compatibly on the saved artifact.

## Current local coverage

The focused local tests currently cover these main families:

- private global narrowed from declared supertype to a child write type
- exported immutable global refined from an abstract `ref.null` initializer
- exported mutable global kept at its declared boundary type
- abstract `ref.null` initializers tightened to Binaryen's bottom reference types
- private `ref.func` initializer refinement to exact function heap types, including nullable-bottom joins and subtype targets
- `ref.i31` initializer refinement through full expression typing, including nested numeric constant expressions and mutable `eqref` / `i31ref` declarations tightening to non-null `(ref i31)`
- conversion initializer refinement for non-null `extern.convert_any` and `any.convert_extern` results
- private exact GC constructor initializer refinement, including exact struct and array constructor result typing
- exported immutable exact/private initializer refinement under the local all-features/custom-descriptors feature model
- closed-world exported-global bailout
- dependent `global.get` initializers staying valid after source global refinement
- function-body `global.get` users seeing refined declarations through fresh validation/typechecking
- sibling writes joined at a shared declared supertype
- direct `-O4z` option slot execution for `global-refining`

That closes the known `[GR-003]` initializer-typing mismatch family, `[GR-004]` custom-descriptor public-type family, and `[GR-005]` retagging/refinalization representation proof. The direct audit is closed with the `[GR-006]` evidence below.

## Recently closed watchpoints

### `[GR-002]` exact `ref.func` LUB behavior

Starshine now treats `ref.func` instruction typing plus initializer-side and direct-write `ref.func` facts as exact function references, matching Binaryen's `ref.func` expression typing in the dedicated `global-refining.wast` surface. The local join also preserves exactness when the other observed value is the nullable function bottom (`nofunc`), so `ref.null func` plus one exact function family refines to `(ref null (exact $f_t))` instead of widening to non-exact `funcref`.

Focused coverage in [`../../../../../src/passes/global_refining_test.mbt`](../../../../../src/passes/global_refining_test.mbt) locks init-only exact refs, null-plus-exact writes, exact-plus-null writes, all-non-null writes, and a function subtype `$sub` initializer refining through a `$super` declaration. Validation on 2026-06-18 passed `moon info`, `moon fmt`, focused `global_refining_test.mbt`, focused `typecheck.mbt`, `moon test src/passes`, `moon test src/validate`, full `moon test`, native `src/cmd` build, and `git diff --check`. Direct compare `.tmp/pass-fuzz-global-refining-gr002-10000` compared `4651/10000` before max-failures, with `4640` normalized matches, `11` mismatches, and `9` Binaryen/tool command failures; sampled mismatches are existing `[GR-003]` initializer-typing gaps (`ref.i31` and `extern.convert_any`), not `[GR-002]` function-ref exactness drift.

### `[GR-003]` initializer expression typing

Starshine now seeds initializer facts by typechecking the full initializer expression in the local validator/type model instead of recognizing only a hard-coded reference-producing syntax subset. Direct `ref.null` initializers remain a deliberate special case so abstract and concrete nulls continue to contribute Binaryen-style bottom reference facts (`none`, `nofunc`, `noextern`, `noexn`) instead of simply reusing the surface nullable heap type.

Focused coverage locks the mismatch families found by the GR-002 compare lane: nested `ref.i31` arithmetic constant expressions refine broad `anyref`, mutable `eqref`, and mutable `i31ref` declarations to non-null `(ref i31)`; exported `extern.convert_any(ref.i31)` refines `externref` to non-null `(ref extern)`; and nested `any.convert_extern(extern.convert_any(...))` refines broad `anyref` to non-null `(ref any)`. The validator's conversion instruction typing now preserves operand nullability, which is what exposes those non-null conversion initializer result types to the pass.

Validation on 2026-06-18 passed focused `global_refining_test.mbt` (`20/20`), focused `typecheck.mbt` (`540/540`), `moon test src/passes` (`2535/2535`), `moon test src/validate` (`1610/1610`), full `moon test` (`5846/5846`), and native `src/cmd` build. Direct compare `.tmp/pass-fuzz-global-refining-gr003-10000` requested `10000`, compared `7602`, normalized `7602`, found `0` mismatches, `0` validation/property/generator failures, and `20` Binaryen/tool command failures (`19` rec-group-zero, `1` bad-section-size).

### `[GR-004]` exported immutable public-type guard

Binaryen's `PublicTypeValidator` accepts every type when custom descriptors are enabled. The direct Starshine-vs-Binaryen pass-fuzz oracle runs Binaryen with `--all-features`, and Starshine has no pass-local feature-disabled mode for custom descriptors. Therefore the local `global-refining` public-type guard now treats custom descriptors as enabled and accepts exported immutable refinements to exact refs and to heap types whose bodies mention exact refs.

Focused coverage locks two previously blocked open-world immutable export cases: an `anyref` export initialized with `struct.new_default $s` now refines to `(ref (exact $s))`, and an `anyref` export initialized from a dependent `(global.get $src)` can refine to `(ref null $wrapper)` even when `$wrapper` contains a field `(ref null (exact $private))`. These cases match local `wasm-opt --all-features --global-refining` behavior; running the same exact-ref export under only `--enable-reference-types --enable-gc` keeps the broad public type in Binaryen, which is outside Starshine's current direct-pass feature model.

Validation on 2026-06-18 passed focused `global_refining_test.mbt` (`21/21`), `moon test src/passes` (`2536/2536`), full `moon test` (`5847/5847`), and native `src/cmd` build. Direct compare `.tmp/pass-fuzz-global-refining-gr004-10000` requested `10000`, compared `7603`, normalized `7603`, found `0` mismatches, `0` validation/property/generator failures, and `20` Binaryen/tool command failures (`19` rec-group-zero, `1` bad-section-size).

### `[GR-005]` `global.get` retagging/refinalization proof

Binaryen must run `GetUpdater` and `ReFinalize` because its AST nodes cache expression result types, including `global.get`. Starshine's boundary IR `GlobalGet` carries only the global index; result types are read from the current validation environment. Focused tests now cover both module-code and function-code users: a dependent global initializer remains valid after its source global is refined, and a fresh typecheck of a function-body `global.get` sees the refined exact heap type.

The first 100000-case closeout probe also exposed that replacing the syntax whitelist with expression typechecking made array constructor exactness depend on validator instruction typing. `array.new`, `array.new_default`, `array.new_fixed`, `array.new_data`, and `array.new_elem` now produce exact non-null array refs, matching Binaryen initializer result types and clearing 14 exact-array mismatches from `.tmp/pass-fuzz-global-refining-final-100000`.

### `[GR-006]` direct closeout evidence

After the retagging proof and array-constructor exactness fix, validation on 2026-06-18 passed `moon info`, `moon fmt`, focused `global_refining_test.mbt` (`23/23`), focused `typecheck.mbt` (`540/540`), `moon test src/validate` (`1610/1610`), `moon test src/passes` (`2538/2538`), full `moon test` (`5849/5849`), native `src/cmd` build, and `git diff --check`.

Ordinary direct compare `.tmp/pass-fuzz-global-refining-gr005-10000` requested `10000`, compared `7609`, normalized `7609`, found `0` mismatches, `0` validation/property/generator failures, and `20` Binaryen/tool command failures.

Final direct compare `.tmp/pass-fuzz-global-refining-final2-100000` requested `100000`, compared `99751`, normalized `99748`, found `3` raw mismatches, `0` validation/property/generator failures, and `249` command failures. Agent classification: zero true `global-refining` semantic mismatches. All 3 raw mismatches are wasm-smith modules with no globals, so Starshine's no-candidate path returns the module unchanged while Binaryen's command output strips `drop(unreachable)` / nested unreachable debris. A targeted normalizer probe `.tmp/pass-fuzz-global-refining-final2-100000-unreach-normalized` classified 2 of the 3 as `unreachable-control-debris`; the remaining nested `drop(drop(unreachable))` sample is the same pass-independent debris family. The 249 command failures are Binaryen/tool-only boundaries: `219` rec-group-zero, `12` bad-section-size, `11` binaryen-command-failed, `6` table-index-out-of-range, and `1` invalid-tag-index.

## Main remaining divergences from official Binaryen

## 1. The local implementation strategy is different

Official Binaryen:

- `ParallelFunctionAnalysis`
- `FindAll<GlobalSet>`
- `LUBFinder`
- declaration rewrite
- `GetUpdater` + `ReFinalize`

Current local pass:

- cheap boundary scan for candidate-set presence
- HOT lifting only for functions that set candidate globals
- validator-environment subtype matching and join helpers
- declaration rewrite only at the boundary IR level
- no Binaryen-style `GetUpdater` / `runOnModuleCode(...)` repair phase because the local representation does not need the same cached expression-type retagging on this path today

That difference is not automatically wrong, but it is a real architectural divergence.

## 2. Binaryen's explicit GC gate is unobservable in Starshine's feature model

Official Binaryen returns immediately when GC is not enabled and schedules the default prepass only under `wasm->features.hasGC() && optimizeLevel >= 2`.
Starshine does not carry a Binaryen-style per-module no-GC feature bit into direct pass execution. For this repo's Wasm 3.0 / `wasm-gc` target, GC is enabled for direct-pass and preset execution, so there is no local execution mode in which `global-refining` should observe `hasGC() == false` and bail out.

That closes the prior GC-gate watchpoint as a feature-model proof, not an implementation change. Reopen it if Starshine later supports feature-disabled direct-pass execution or compares against Binaryen without GC enabled.

## 3. Binaryen-style `global.get` retagging is representation-specific locally and covered

Official Binaryen must explicitly repair cached `global.get` result types after changing global declarations.

The local boundary IR does not cache expression result types in the same way, so there is no direct local equivalent today.

That is likely fine for the current representation, but future typed caches in boundary IR or HOT IR would need an equivalent repair contract.

## Practical rule for future work

- Keep the current local mutable-export boundary, closed-world exported-global bailout, all-features/custom-descriptor public-type model, expression-typed initializer facts, exact `ref.func` / array-constructor typing, and bottom-null handling unless new compare evidence says they are wrong.
- If Starshine later adds feature-disabled direct-pass execution, revisit both the Binaryen GC gate and the non-custom-descriptor public-type scan.
- If the local IR ever starts caching expression result types more aggressively, preserve the Binaryen rule that declaration refinement must be paired with `global.get` retagging and refinalization.

## Sources

- Archived research docs:
  - [`../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md`](../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md)
  - [`../../../raw/research/0236-2026-04-21-global-refining-starshine-strategy-followup.md`](../../../raw/research/0236-2026-04-21-global-refining-starshine-strategy-followup.md)
- Local strategy page: [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
- Implementation: [`../../../../../src/passes/global_refining.mbt`](../../../../../src/passes/global_refining.mbt)
- Focused tests: [`../../../../../src/passes/global_refining_test.mbt`](../../../../../src/passes/global_refining_test.mbt)
- Ref.func instruction typing: [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
- Dispatch/options surface: [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- Registry/preset surface: [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- Registry tests: [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
