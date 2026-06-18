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
- The 2026-06-03 O4z audit also restored the direct `global-refining` slot under `-O4z` options and added initializer coverage for `ref.func`, `ref.i31`, `string.const`, and exact GC constructor results.
- The 2026-06-18 `[GR-002]` slice aligned Starshine's function-reference LUB behavior with Binaryen `version_130`: `ref.func` facts are exact, nullable function bottom plus exact `ref.func` joins to nullable exact, and all-non-null `ref.func` families refine to non-null exact function refs. Moon validation passed. The direct 10000-case compare stopped on existing `[GR-003]` initializer-typing mismatches (`ref.i31` and `extern.convert_any`), not function-ref exactness drift.

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
- private `ref.i31` initializer refinement
- private exact GC constructor initializer refinement, currently represented with `struct.new_default`
- exported immutable exact/private initializer bailout through the local public-type filter
- closed-world exported-global bailout
- sibling writes joined at a shared declared supertype
- direct `-O4z` option slot execution for `global-refining`

That is a much better local floor for the active mismatch family, but broader descriptor-bearing public-type bodies and additional stringref expression surfaces remain useful follow-up fixtures.

## Recently closed watchpoints

### `[GR-002]` exact `ref.func` LUB behavior

Starshine now treats `ref.func` instruction typing plus initializer-side and direct-write `ref.func` facts as exact function references, matching Binaryen's `ref.func` expression typing in the dedicated `global-refining.wast` surface. The local join also preserves exactness when the other observed value is the nullable function bottom (`nofunc`), so `ref.null func` plus one exact function family refines to `(ref null (exact $f_t))` instead of widening to non-exact `funcref`.

Focused coverage in [`../../../../../src/passes/global_refining_test.mbt`](../../../../../src/passes/global_refining_test.mbt) locks init-only exact refs, null-plus-exact writes, exact-plus-null writes, all-non-null writes, and a function subtype `$sub` initializer refining through a `$super` declaration. Validation on 2026-06-18 passed `moon info`, `moon fmt`, focused `global_refining_test.mbt`, focused `typecheck.mbt`, `moon test src/passes`, `moon test src/validate`, full `moon test`, native `src/cmd` build, and `git diff --check`. Direct compare `.tmp/pass-fuzz-global-refining-gr002-10000` compared `4651/10000` before max-failures, with `4640` normalized matches, `11` mismatches, and `9` Binaryen/tool command failures; sampled mismatches are existing `[GR-003]` initializer-typing gaps (`ref.i31` and `extern.convert_any`), not `[GR-002]` function-ref exactness drift.

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

## 3. Binaryen-style `global.get` retagging is representation-specific locally

Official Binaryen must explicitly repair cached `global.get` result types after changing global declarations.

The local boundary IR does not cache expression result types in the same way, so there is no direct local equivalent today.

That is likely fine for the current representation, but future typed caches in boundary IR or HOT IR would need an equivalent repair contract.

## Why the saved audit can still be exactly green

The updated most plausible explanation is:

- the saved artifact and fresh fuzz lanes hit the earlier nullability/type-tightening drift and now agree with Binaryen there
- the 2026-06-03 focused fixtures prove the previously documented open-world public-type and closed-world exported-global cases locally
- but they still do not prove every descriptor-bearing public type or every future representation-specific retagging corner case

That is an inference from the green audit plus the visible local-vs-upstream source differences, not a direct quoted upstream statement.

## Practical rule for future work

- Keep the current local mutable-export boundary, closed-world exported-global bailout, public-type filter, and bottom-null handling unless new compare evidence says they are wrong.
- Future parity work should focus on broader Binaryen initializer expression typing, descriptor-bearing public type bodies, dependent `global.get` retagging evidence, and any local IR change that starts caching expression result types.
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
