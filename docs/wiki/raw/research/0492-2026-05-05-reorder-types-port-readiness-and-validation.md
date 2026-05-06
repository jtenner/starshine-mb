# Reorder-types port-readiness and validation bridge

## Question

What should Starshine prove first if `reorder-types` ever moves from boundary-only status to a real module pass?

## Findings

The upstream contract is already clear:

- GC required
- `--closed-world` required
- private heap types only
- public types frozen
- predecessor constraints from private supertypes and private described types
- 21-factor successor-weight search
- module-wide remap through `GlobalTypeRewriter`

That means a Starshine port should not start as a HOT peephole.
It should start as a module-level type-layout rewrite with explicit validation around the type section and every type-bearing surface that can be left stale.

## Recommended first slice

1. keep registry honesty: boundary-only rejection stays explicit until a real pass exists
2. add a tiny closed-world/GC analyzer that can prove the candidate set and the freeze set
3. implement one private-only reorder on a small fixture
4. rewrite all type-bearing surfaces in one pass
5. compare against Binaryen `reorder-types`
6. keep the hidden testing sibling in mind only as an oracle aid, not as a local API promise

## Validation order

- no-GC rejection
- no-closed-world rejection
- public-type freeze negative
- private-only reorder positive
- type-index remap across function / local / table / export / descriptor surfaces
- binary roundtrip after rewrite
- Binaryen parity compare on the supported subset

## Open questions

- whether Starshine should add a local `GlobalTypeRewriter` equivalent before the first mutating slice
- whether the pass should mirror Binaryen's 21-factor search or expose a simpler internal search first
- whether a future port should ship a testing-only sibling spelling for easier local comparison

## Sources

- `../binaryen/2026-05-05-reorder-types-current-main-recheck.md`
- `../binaryen/2026-04-24-reorder-types-primary-sources.md`
- `../../binaryen/passes/reorder-types/binaryen-strategy.md`
- `../../binaryen/passes/reorder-types/starshine-strategy.md`
- official Binaryen sources for `src/passes/ReorderTypes.cpp`, `src/passes/pass.cpp`, and `test/lit/passes/reorder-types.wast`
- https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderTypes.cpp
- https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
- https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-types.wast
