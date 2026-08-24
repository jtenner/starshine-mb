---
kind: concept
status: supported
last_reviewed: 2026-08-02
sources:
  - ../binaryen/passes/reorder-locals/index.md
  - ./registry-map.md
  - ../../../src/ir/README.md
  - ../../../src/passes/optimize.mbt
  - ../../../src/passes/registry_test.mbt
  - ../../../src/passes/optimize_test.mbt
related:
  - ./architecture-rules.md
  - ./local-ssa-policy.md
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

There are 28 active hot entries. The full list, including `precompute-propagate`, every supported SimplifyLocals policy spelling, and hot `merge-locals`, is maintained in [`./registry-map.md`](./registry-map.md) from the live registry.

### Module passes

There are 30 active module entries. They include the plain and optimizing DAE spellings, `inline-main`, `global-struct-inference-desc-cast`, and the module-shaped local/global/index adapters listed in [`./registry-map.md`](./registry-map.md).

### Presets

`optimize` and `shrink` use measured wall-time-first rosters outside O4z. O1/O2/default optimize run DFE plus final debug stripping; O3/O4/Os/Oz/default shrink add only Vacuum and ReorderLocals. Expensive direct passes remain available but are not paid automatically by those public presets.

O4z remains the locked full compatibility point: Binaryen v131's 56 slots, followed by Starshine-only `strip-debug` at slot 57. Its early module order is `global-refining -> remove-unused-module-elements -> global-struct-inference`; its function phase contains the aggressive `ssa-nomerge -> flatten -> simplify-locals-notee-nostructure -> local-cse` prelude, both propagating-precompute slots, and the three-slot RUB placement; its post phase ends with the accepted global/string/reorder/directize tail. Starshine's additional 18-pass local-convergence suffix remains enabled below 2,000 defined functions. At artifact scale the scheduler skips that exact suffix as one unit while preserving later explicit user passes: an August 22 production A/B measured the suffix at +60.285 seconds and +25,152 bytes, so retaining it there was both slower and larger.

Nested optimizing owners use the same function scheduler with the parent levels and module features. DAE and optimizing inlining prepend their required `precompute-propagate`; SGO does not. All three retain touched-function application, and SGO no longer suppresses the required roster solely because a touched function exceeds 192 locals or 1,000 instructions.

Production runtime smoke also defines an explicit fail-closed boundary for large typed-loop modules. Plain DAE and DAE optimizing now use one bounded safe batch instead of the unrestricted shared core: parameter changes require the callee and every direct caller to be parameterized-loop-disjoint, while dropped-result convergence remains atomic and independently available. Caller-side typed-loop parameter rewriting is still closed after an August 22 literal-only experiment passed `wasm-tools` validation but failed Binaryen-v131 roundtrip with a block-value underflow. Optimizing inlining falls back to plain inlining, SGO returns the original module, and the scheduled `flatten` / `merge-locals` owners trace a no-op. These are correctness boundaries discovered by runtime or independent-tool execution after local validation succeeded; they must not be removed from size-only or validation-only evidence.

## Current Migration Gaps

The old Batch 1/2/3 labels are no longer the live implementation frontier. Many former batch items are active now. Current removed names are the real hot/local gaps:

- `const-hoisting`
- `dataflow-optimization`
- `loop-invariant-code-motion`
- `re-reloop`
- `optimize-added-constants`
- `optimize-added-constants-propagate`
- `de-nan`
- `simplify-locals-no-tee-no-structure`

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

- Reorder-locals preset-scheduling reconciliation: [research note 0709](../binaryen/passes/reorder-locals/index.md)
- Numbered handoff doc: research note 0065
- Registry map: [research note 0063](./registry-map.md)
- Package-local ownership summary: [`../../../src/ir/README.md`](../../../src/ir/README.md)
- Live registry: [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt)
- Registry and preset coverage: [`../../../src/passes/registry_test.mbt`](../../../src/passes/registry_test.mbt), [`../../../src/passes/optimize_test.mbt`](../../../src/passes/optimize_test.mbt)
