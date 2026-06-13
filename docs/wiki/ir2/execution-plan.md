---
kind: concept
status: supported
last_reviewed: 2026-06-06
sources:
  - ../raw/research/0709-2026-06-04-reorder-locals-preset-scheduling-reconciliation.md
  - ../raw/research/0065-2026-03-24-ir2-execution-plan.md
  - ../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../src/ir/README.md
  - ../../../src/passes/optimize.mbt
  - ../../../src/passes/registry_test.mbt
  - ../../../src/passes/optimize_test.mbt
related:
  - ./architecture-rules.md
  - ./registry-map.md
  - ./pass-porting-checklist.md
  - ./test-matrix.md
  - ../../../src/passes/pass_manager.mbt
---

# IR2 Execution Plan

## Durable Conclusions

- `HotFunc` is the only owned optimizer body representation.
- CFG, traversal orders, dominance, post-dominance, loop info, use-def, liveness, effects, and local SSA exist as revision-keyed overlays instead of replacing `HotFunc`.
- The public optimizer path is:
  `requested pass/preset names -> registry expansion -> module-pass or hot-pass dispatch -> final validation`.
- The hot-function leg remains:
  `lift -> verify -> analyze -> mutate -> verify -> lower`.
- Boundary-only and removed names stay visible to the registry for explicit diagnostics, but are rejected rather than accepted as no-ops.

## Current Active Surface

### Hot passes

`ssa-nomerge`, `ssa`, `vacuum`, `dead-code-elimination`, `remove-unused-names`, `remove-unused-brs`, `optimize-instructions`, `heap-store-optimization`, `heap2local`, `optimize-casts`, `pick-load-signs`, `precompute`, `code-pushing`, `code-folding`, `tuple-optimization`, `simplify-locals`, `simplify-locals-nostructure`, `simplify-locals-no-structure`, `simplify-locals-notee-nostructure`, `merge-blocks`, and `redundant-set-elimination`.

### Module passes

`local-cse`, `merge-locals`, `avoid-reinterprets`, `untee`, `duplicate-function-elimination`, `remove-unused-module-elements`, `remove-unused-nonfunction-module-elements`, `memory-packing`, `once-reduction`, `global-refining`, `global-struct-inference`, `reorder-locals`, `local-subtyping`, `coalesce-locals`, `duplicate-import-elimination`, `strip-debug`, `simplify-globals-optimizing`, `dae-optimizing`, `dead-argument-elimination-optimizing`, `inlining`, `inlining-optimizing`, `no-inline`, `no-full-inline`, `no-partial-inline`, `string-gathering`, `reorder-globals`, and `directize`.

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
- `reorder-locals` is scheduled once inside the tuple/no-structure cleanup lane; [`../raw/research/0709-2026-06-04-reorder-locals-preset-scheduling-reconciliation.md`](../raw/research/0709-2026-06-04-reorder-locals-preset-scheduling-reconciliation.md) is the current reconciliation source for that one-slot public policy versus Binaryen's extra upstream placements.
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

## Runtime Artifact Correctness Notes

- 2026-06-06: the restored `examples/modules/medium.bench.incremental.simd.wasm` runtime smoke exposed a function-66 stack-order hazard that validation and direct inlining did not catch. `remove-unused-brs` and `precompute` now share a conservative raw shape gate for the SIMD parser br-table stack hazard; it skips that artifact-shaped function before HOT lowering can move stack-carried locals across side-effectful blocks. Covered by `src/passes/pass_manager_wbtest.mbt`; implemented in `src/passes/pass_manager.mbt`.
- Preset widening remains blocked on runtime smoke evidence, not validation alone. The same restored artifact now passes direct `--remove-unused-brs`, direct `--precompute`, direct `--inlining-optimizing --remove-unused-module-elements`, and full `--optimize` under Node in the current local evidence. The direct `remove-unused-brs` and `precompute` both-generator lanes have refreshed branch-heavy compare signoff with scoped semantic normalizers; use separate runtime smoke before widening presets.

## Compare-Pass Blocker Notes

- 2026-06-06: `remove-unused-brs` wasm-smith direct compare is clean with `--normalize drop-consts --normalize unreachable-control-debris` after the adjacent `(drop (unreachable))` debris normalizer: `.tmp/pass-fuzz-remove-unused-brs-simd-parser-guard-wasm-smith-norm2-10000` compared 9952/10000, normalized 9950, cleanup-normalized 2, mismatches 0, command failures 48. Agent classification: the normalized family is semantic-safe unreachable-control debris; command failures are Binaryen/tool decode classes already separated by the harness.
- 2026-06-06: `precompute` wasm-smith direct compare is clean with `--normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris` after broadening dropped pure numeric debris normalization: `.tmp/pass-fuzz-precompute-simd-parser-guard-wasm-smith-norm4-10000` compared 9952/10000, normalized 9947, cleanup-normalized 5, mismatches 0, command failures 48. Agent classification: the normalized family is semantic-safe dropped closed numeric debris and local/unreachable cleanup; command failures are Binaryen/tool decode classes already separated by the harness.
- 2026-06-06: `remove-unused-brs` both-generator direct compare is clean after folding constant `br_if`, dropping void self-branch blocks, and extending `unreachable-control-debris` for Binaryen's void branch/unreachable wrapper debris: `.tmp/pass-fuzz-remove-unused-brs-branch-heavy-fix2-10000` compared 6768/10000, normalized 3847, cleanup-normalized 2921, mismatches 0, command failures 20. Agent classification: the cleanup-normalized wrapper family is semantic-safe/size-winning for Starshine because `(block $b (block (br $b)) unreachable)` has no side effects and reaches the same continuation as an empty void block; command failures are Binaryen/tool decode classes separated by the harness.
- 2026-06-06: `precompute` both-generator direct compare is clean after raw constant `br_if` / void self-branch cleanup and a scoped `unreachable-control-debris` normalizer for semantic-safe constant self-branch blocks, constant false self-branch loops, empty void controls, and tails after infinite self-loops: `.tmp/pass-fuzz-precompute-branch-heavy-slice4-norm4-10000` compared 6769/10000, normalized 3375, cleanup-normalized 3394, mismatches 0, command failures 20. Agent classification: cleanup-normalized cases are representation-only or semantic-safe unreachable tail debris; command failures are Binaryen/tool decode classes separated by the harness.

## Practical Rule

- If a future pass needs a new IR rule or overlay contract, land the docs and contract first, then the pass slice.
- Keep public docs and help text conservative: describe only the passes and registry entries that are real today.
- Extend the shared helper and golden layer in [`./test-matrix.md`](./test-matrix.md) instead of inventing ad hoc IR2 harnesses.
- Keep `agent-todo.md` active-only: add a slice before behavior work and remove it when complete.

## Sources

- Reorder-locals preset-scheduling reconciliation: [`../raw/research/0709-2026-06-04-reorder-locals-preset-scheduling-reconciliation.md`](../raw/research/0709-2026-06-04-reorder-locals-preset-scheduling-reconciliation.md)
- Numbered handoff doc: [`../raw/research/0065-2026-03-24-ir2-execution-plan.md`](../raw/research/0065-2026-03-24-ir2-execution-plan.md)
- Registry map: [`../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- Package-local ownership summary: [`../../../src/ir/README.md`](../../../src/ir/README.md)
- Live registry: [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt)
- Registry and preset coverage: [`../../../src/passes/registry_test.mbt`](../../../src/passes/registry_test.mbt), [`../../../src/passes/optimize_test.mbt`](../../../src/passes/optimize_test.mbt)
