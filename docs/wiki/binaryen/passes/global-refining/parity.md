---
kind: comparison
status: supported
last_reviewed: 2026-05-07
sources:
  - ../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md
  - ../../../raw/research/0236-2026-04-21-global-refining-starshine-strategy-followup.md
related:
  - ./starshine-hot-ir-strategy.md
  - ../../../../../src/passes/global_refining.mbt
  - ../../../../../src/passes/global_refining_test.mbt
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
  - current official `version_129` closed-world behavior still skips all exported globals
- The current Starshine implementation now matches the broad exported-boundary split on the direct parity lane: mutable exports stay untouched, immutable exports can refine, and private globals still tighten from initializer-plus-write LUBs.
- Remaining local gaps are now the explicit public-type and closed-world distinctions from official Binaryen, not the earlier mutable-vs-immutable export split.

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

The focused local tests currently cover five main families:

- private global narrowed from declared supertype to a child write type
- exported immutable global refined from an abstract `ref.null` initializer
- exported mutable global kept at its declared boundary type
- abstract `ref.null` initializers tightened to Binaryen's bottom reference types
- sibling writes joined at a shared declared supertype

That is a much better local floor for the active mismatch family, but it still does not cover the full Binaryen public-type and closed-world matrix.

## Main remaining divergences from official Binaryen

## 1. Export handling is still incomplete locally

Current local behavior:

- skip exported mutable globals
- allow exported immutable globals to refine from the same initializer-plus-write facts as private globals
- do not thread a closed-world mode into the pass

Official Binaryen `version_129` behavior:

- skip exported mutable globals in open world
- allow exported immutable globals in open world when the refined type is public
- skip all exported globals in closed world

So the remaining local export gap is now:

- **public-type validation plus the closed-world exported-global distinction**

## 2. `closed_world` is not threaded into the local pass

`pass_manager.mbt` passes `options.closed_world` to `global-struct-inference`, but not to `global-refining`.

That means the local pass still cannot express the official distinction between:

- open-world immutable exports that may refine when public
- closed-world exported globals that official Binaryen currently skips

## 3. There is no local `PublicTypeValidator` equivalent on this path

Binaryen uses `PublicTypeValidator` so an immutable exported global can refine only to a still-public type.

The local pass still has no equivalent hook today, so the new immutable-export support is only oracle-proven for the current fuzz and artifact lanes, not guarded by an explicit local public-type validator.

## 4. The local implementation strategy is different

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

## 5. The local pass lacks Binaryen's explicit GC gate

Official Binaryen returns immediately when GC is not enabled.
The current local pass has no equivalent top-level GC feature guard.

That may often be a practical no-op difference, but it is still a semantic difference from the official implementation.

## 6. Binaryen-style `global.get` retagging is representation-specific locally

Official Binaryen must explicitly repair cached `global.get` result types after changing global declarations.

The local boundary IR does not cache expression result types in the same way, so there is no direct local equivalent today.

That is likely fine for the current representation, but future typed caches in boundary IR or HOT IR would need an equivalent repair contract.

## Why the saved audit can still be exactly green

The updated most plausible explanation is:

- the saved artifact and fresh fuzz lane hit the earlier nullability/type-tightening drift and now agree with Binaryen there
- but they still do not prove every exported public-type or closed-world corner case from the full upstream contract

That is an inference from the green audit plus the visible local-vs-upstream source differences, not a direct quoted upstream statement.

## Practical rule for future work

- Keep the current local mutable-export boundary and bottom-null handling unless new compare evidence says they are wrong.
- If future parity work targets the full Binaryen contract, the next missing surfaces to implement are:
  - immutable exported refinement guarded by a public-type check
  - closed-world exported-global conservatism when/if Starshine starts threading that option into `global-refining`
- If the local IR ever starts caching expression result types more aggressively, preserve the Binaryen rule that declaration refinement must be paired with `global.get` retagging and refinalization.

## Sources

- Archived research docs:
  - [`../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md`](../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md)
  - [`../../../raw/research/0236-2026-04-21-global-refining-starshine-strategy-followup.md`](../../../raw/research/0236-2026-04-21-global-refining-starshine-strategy-followup.md)
- Local strategy page: [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
- Implementation: [`../../../../../src/passes/global_refining.mbt`](../../../../../src/passes/global_refining.mbt)
- Focused tests: [`../../../../../src/passes/global_refining_test.mbt`](../../../../../src/passes/global_refining_test.mbt)
- Dispatch/options surface: [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- Registry/preset surface: [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- Registry tests: [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
