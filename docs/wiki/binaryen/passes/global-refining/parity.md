---
kind: comparison
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md
related:
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
- The current Starshine implementation matches the broad idea for private globals, but it is narrower than official Binaryen at the exported-global boundary.

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

The focused local tests currently cover three main families:

- private global narrowed from declared supertype to a child write type
- exported global kept at its declared boundary type
- sibling writes joined at a shared declared supertype

That is a good local floor, but it does not yet cover the full Binaryen boundary matrix.

## Main remaining divergences from official Binaryen

## 1. Export handling is more conservative locally

Current local behavior:

- skip all exported globals

Official Binaryen `version_129` behavior:

- skip exported mutable globals in open world
- allow exported immutable globals in open world when the refined type is public
- skip all exported globals in closed world

So the most important local missing case is:

- **open-world immutable exported public refinement**

## 2. `closed_world` is not threaded into the local pass

`pass_manager.mbt` passes `options.closed_world` to `global-struct-inference`, but not to `global-refining`.

That means the local pass cannot currently express the official distinction between:

- open-world immutable exports
- closed-world exported globals

## 3. There is no local `PublicTypeValidator` equivalent on this path

Binaryen uses `PublicTypeValidator` so an immutable exported global can refine only to a still-public type.

The local pass has no equivalent hook today, which is one practical reason it currently bails on all exports instead.

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

The most plausible explanation is:

- the saved artifact does not hit the open-world immutable-export/public-type corner cases
- and the private-global cases it does hit are already modeled well enough by the local implementation

That is an inference from the green audit plus the visible local-vs-upstream source differences, not a direct quoted upstream statement.

## Practical rule for future work

- Keep the current local private-global behavior unless new compare evidence says it is wrong.
- If future parity work targets the full Binaryen contract, the next missing surface to implement is:
  - open-world immutable exported refinement guarded by a public-type check
- If the local IR ever starts caching expression result types more aggressively, preserve the Binaryen rule that declaration refinement must be paired with `global.get` retagging and refinalization.

## Sources

- Archived research doc: [`../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md`](../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md)
- Implementation: [`../../../../../src/passes/global_refining.mbt`](../../../../../src/passes/global_refining.mbt)
- Focused tests: [`../../../../../src/passes/global_refining_test.mbt`](../../../../../src/passes/global_refining_test.mbt)
- Dispatch/options surface: [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- Registry/preset surface: [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- Registry tests: [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
