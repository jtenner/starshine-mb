# 0065 - IR2 Execution Plan

## Scope

- Keep one canonical handoff document for the rebuilt IR2 optimizer leg.
- Point future agents at the architecture, CFG, SSA, pass-porting, registry, and test-matrix docs that govern continued work.
- Record the current live pass surface, preset expansion, and minimum validation expected for future IR2 changes.

## Canonical References

- Architecture rules: [`wiki/ir2/architecture-rules.md`](../../ir2/architecture-rules.md), with original March note archived at [`wiki/raw/research/0059-2026-03-24-ir2-architecture-rules.md`](./0059-2026-03-24-ir2-architecture-rules.md)
- CFG contract ADR: [`wiki/ir2/cfg-contract.md`](../../ir2/cfg-contract.md), with original March note archived at [`wiki/raw/research/0060-2026-03-24-cfg-contract-and-block-boundary-rules.md`](./0060-2026-03-24-cfg-contract-and-block-boundary-rules.md)
- SSA policy ADR: [`wiki/ir2/local-ssa-policy.md`](../../ir2/local-ssa-policy.md), with original March note archived at [`wiki/raw/research/0061-2026-03-24-local-ssa-policy.md`](./0061-2026-03-24-local-ssa-policy.md)
- Pass-porting checklist: [`wiki/ir2/pass-porting-checklist.md`](../../ir2/pass-porting-checklist.md), with original March note archived at [`wiki/raw/research/0062-2026-03-24-pass-porting-checklist.md`](./0062-2026-03-24-pass-porting-checklist.md)
- Registry and batch map: [`0063-2026-03-24-pass-port-batches-and-registry-map.md`](./0063-2026-03-24-pass-port-batches-and-registry-map.md)
- Shared IR2 test matrix: [`0064-2026-03-24-ir2-test-matrix.md`](./0064-2026-03-24-ir2-test-matrix.md)

## Current State

- `HotFunc` is the only owned optimizer body representation.
- CFG, traversal orders, dominance, post-dominance, loop info, use-def, liveness, effects, and local SSA exist as revision-keyed overlays instead of replacing `HotFunc`.
- The public optimizer path is:
  `requested pass/preset names -> registry expansion -> module-pass or hot-pass dispatch -> final validation`.
- The hot-function leg remains:
  `lift -> verify -> analyze -> mutate -> verify -> lower`.
- Boundary-only and removed names stay visible to the registry for explicit diagnostics, but are rejected rather than accepted as no-ops.

## Current Active Surface

### Hot passes

`ssa-nomerge`, `vacuum`, `dead-code-elimination`, `remove-unused-names`, `remove-unused-brs`, `optimize-instructions`, `heap-store-optimization`, `heap2local`, `optimize-casts`, `pick-load-signs`, `precompute`, `code-pushing`, `code-folding`, `tuple-optimization`, `simplify-locals`, `simplify-locals-nostructure`, `simplify-locals-no-structure`, `simplify-locals-notee-nostructure`, `merge-blocks`, and `redundant-set-elimination`.

### Module passes

`local-cse`, `merge-locals`, `avoid-reinterprets`, `untee`, `duplicate-function-elimination`, `remove-unused-module-elements`, `remove-unused-nonfunction-module-elements`, `memory-packing`, `once-reduction`, `global-refining`, `global-struct-inference`, `reorder-locals`, `local-subtyping`, `coalesce-locals`, `duplicate-import-elimination`, `dae-optimizing`, `dead-argument-elimination-optimizing`, `string-gathering`, `reorder-globals`, and `directize`.

### Presets

`optimize` and `shrink` currently expand to the same implemented mixed sequence:

```text
memory-packing -> once-reduction -> global-refining -> global-struct-inference ->
ssa-nomerge -> dead-code-elimination -> remove-unused-names -> remove-unused-brs ->
remove-unused-names -> vacuum -> remove-unused-brs -> optimize-instructions ->
heap-store-optimization -> pick-load-signs -> precompute -> code-pushing ->
tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals ->
remove-unused-brs -> heap2local -> optimize-casts -> local-subtyping ->
coalesce-locals -> local-cse -> simplify-locals -> merge-blocks ->
remove-unused-brs -> remove-unused-names -> merge-blocks -> precompute ->
optimize-instructions -> heap-store-optimization -> simplify-globals-optimizing ->
remove-unused-module-elements -> string-gathering -> reorder-globals -> directize
```

Slot caveats:

- `simplify-locals-notee-nostructure` is runnable explicitly but kept out of presets until the exact `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood is ready.
- `reorder-locals` is scheduled once inside the tuple/no-structure cleanup lane.
- `optimize` and `shrink` should stay identical until a tested size-specific divergence lands.
- The current shared late tail is `simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize`; this is registry- and slot-tested and should not be shortened in docs when summarizing the live preset.

## Current Migration Gaps

The old Batch 1/2/3 labels are no longer the live implementation frontier. Many former batch items are active now. Current removed names are the real hot/local gaps:

- `const-hoisting`
- `dataflow-optimization`
- `loop-invariant-code-motion`
- `flatten`
- `re-reloop`
- `optimize-added-constants`
- `optimize-added-constants-propagate`
- `precompute-propagate`
- `de-nan`
- `simplify-locals-no-tee`
- `simplify-locals-no-tee-no-structure`
- `simplify-locals-no-nesting`

Boundary-only families, such as closed-world type/signature passes, ABI/lowering passes, and function/type ordering passes, need a module/type/ABI rewrite contract before they can become active implementation slices.

## Future Slice Order

1. Start from live registry evidence and the affected pass folder, not from stale batch memory.
2. If the pass needs a new IR invariant or analysis overlay, update the contract/ADR first.
3. Land the smallest explicit-pass slice before preset scheduling.
4. Add slot-level preset tests only after the Binaryen-adjacent neighborhood is source-confirmed.
5. Keep one atomic slice per coherent dependency step.

## Practical Rule

- If a future pass needs a new IR rule or overlay contract, land the docs and contract first, then the pass slice.
- Keep public docs and help text conservative: describe only the passes and registry entries that are real today.
- Extend the shared helper and golden layer in [`./test-matrix.md`](./test-matrix.md) instead of inventing ad hoc IR2 harnesses.
- Keep `agent-todo.md` active-only: add a slice before behavior work and remove it when complete.

## Sources

- Numbered handoff doc: [`../../../0065-2026-03-24-ir2-execution-plan.md`](../../../0065-2026-03-24-ir2-execution-plan.md)
- Registry map: [`../../../0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../0063-2026-03-24-pass-port-batches-and-registry-map.md)
- Package-local ownership summary: [`src/ir/README.md`](../../../../src/ir/README.md)
- Live registry: [`src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt)
- Registry and preset coverage: [`src/passes/registry_test.mbt`](../../../../src/passes/registry_test.mbt), [`src/passes/optimize_test.mbt`](../../../../src/passes/optimize_test.mbt)
