# 0076 - Tuple Optimization Binaryen Port Plan

## Scope

- Record the exact `version_125` Binaryen `tuple-optimization` behavior from source, not from observed output alone.
- Map that behavior onto Starshine's current HOT IR shape and pass pipeline.
- Define the implementation strategy for this worktree before code changes start.

## Primary Sources

- Binaryen `version_125` tuple pass:
  `src/passes/TupleOptimization.cpp:17-373` at commit `6ec7b5f9c615d3b224c67ae221d6812c8f8e1a96`.
- Binaryen default function-pass scheduler slot:
  `src/passes/pass.cpp:651-683`.
- Binaryen earlier tuple peephole in `optimize-instructions`:
  `src/passes/OptimizeInstructions.cpp:2710-2726`.
- Binaryen tuple type/finalization semantics:
  `src/wasm/wasm.cpp:963-983`.
- Binaryen tuple validation rules:
  `src/wasm/wasm-validator.cpp:2798-2845`.
- Starshine HOT IR ownership and pass contract:
  [`src/ir/README.md`](../src/ir/README.md).
- Starshine current pass-registry state:
  [`src/passes/optimize.mbt`](../src/passes/optimize.mbt).
- Starshine current multivalue lift shape:
  [`src/ir/hot_lift_test.mbt`](../src/ir/hot_lift_test.mbt).
- Starshine tuple op surface in HOT core/builders:
  [`src/ir/hot_core.mbt`](../src/ir/hot_core.mbt),
  [`src/ir/hot_builders.mbt`](../src/ir/hot_builders.mbt).
- Starshine current lift/lower opcode families:
  [`src/ir/hot_lift.mbt`](../src/ir/hot_lift.mbt),
  [`src/ir/hot_lower.mbt`](../src/ir/hot_lower.mbt).

## Binaryen Exact Behavior

### Scheduler and Gate

- Binaryen runs `tuple-optimization` only when multivalue is enabled.
- In the default `-O` / `-Os` function pipeline it sits after `code-pushing` and before `simplify-locals-nostructure`.
- The scheduler comment is explicit about intent: run after at least `optimize-instructions`, because that earlier pass can already remove some tuple traffic.

### What Binaryen Is Actually Optimizing

- The pass is not a general multivalue simplifier.
- It is specifically a tuple-local lowering pass for Binaryen's internal tuple IR.
- The motivating shape is:
  - a tuple local written from `tuple.make`
  - later consumed only through `tuple.extract`
  - or copied through other tuple locals that obey the same restrictions
- The pass intentionally does not try to lower every multivalue block, branch, or return shape.
- The source comment is explicit that this is limited to cases that are "definitely worth lowering."

### Analysis Phase

Binaryen scans the function once and builds three per-local structures:

- `uses`
  Counts tuple-local uses.
  `local.get` counts as one use.
  `local.set` counts as one use.
  `local.tee` counts as two uses because it both writes and reads.
- `validUses`
  Counts only uses that are safe for tuple lowering.
- `copiedIndexes`
  A symmetric copy graph between tuple locals.
  If tuple local `x` copies from tuple local `y`, then `x <-> y` is recorded so "badness" can propagate both ways.

Binaryen marks a tuple-local use as valid only in these cases:

- A tuple local is written from `tuple.make`.
- A tuple local is written from another tuple local through `local.get`.
- A tuple local is written from another tuple local through a reachable `local.tee`.
- A `tuple.extract` reads from a tuple local through `local.get`.
- A `tuple.extract` reads from a tuple local through a reachable `local.tee`.

Binaryen intentionally rejects or ignores:

- unreachable tee chains
- any tuple local that escapes to another consumer kind
- any tuple local written from a non-`tuple.make`, non-tuple-copy source
- any tuple local read in a way other than tuple extraction or tuple-local copying

That means the pass is conservative by construction:
if `uses > validUses`, the tuple local is treated as bad.

### Badness Propagation

- Binaryen first seeds the worklist with tuple locals that have at least one invalid use.
- It then propagates "bad" across the symmetric copy graph.
- If `x` copies to `y` and either side has an escaping or otherwise invalid use, both become ineligible.

This is important: the pass optimizes connected components of tuple-local copies, not isolated locals.

### Rewrite Phase

After analysis, Binaryen rewrites only tuple locals that:

- have at least one use
- are not marked bad

For each such tuple local, Binaryen allocates one fresh scalar local per tuple lane and records a contiguous base index.

It then rewrites:

- `local.set` / `local.tee` of a good tuple local from `tuple.make`
  Into a block of scalar `local.set`s, one per lane.
- `local.set` / `local.tee` of a good tuple local from another good tuple local
  Into a block of scalar `local.set`s reading from the source lane locals.
- `tuple.extract` of a good tuple local
  Into a scalar `local.get` of the matching split lane local.

Two details matter:

- Binaryen preserves tee side effects/order by remembering which rewritten block came from a tee and, when needed, emitting a `sequence(block-of-sets, local.get lane)`.
- When rewriting tuple-local copies, it uses the source tuple lane types, not blindly the target lane types.
  That preserves subtype relationships across copies as long as tuple arity matches.

### What The Pass Does Not Do

- It does not directly remove dead locals, dead sets, or dead tuple lanes.
- It does not touch general multivalue block/branch/return structure.
- It does not fold `tuple.extract(tuple.make(...))` itself in this pass.
  That fold happens earlier in Binaryen's `optimize-instructions`.

So the intended effect is:

1. lower safe tuple locals into scalar locals
2. let the later local-cleanup passes realize the actual dead-code and copy-propagation wins

## Current Starshine State

### Pipeline and Registry

- HOT IR is the only owned optimizer representation.
- The pass contract is `lift -> verify -> analyze -> mutate -> verify -> lower`.
- `tuple-optimization` is still categorized as a removed pass in the current registry surface.
- The default Starshine `optimize` / `shrink` presets therefore do not currently include the Binaryen tuple slot yet.

### HOT IR Already Models Multivalue Differently

- HOT IR supports arbitrary multi-result node types directly.
- HOT core and builders also define explicit `TupleMake` / `TupleExtract` pseudo-ops.
- But the normal HOT lift/lower pipeline does not currently treat tuple pseudo-ops as part of the active roundtrip surface.
  The current direct/exact lift families do not include tuple instructions, and the current lowering opcode switch has no `TupleMake` / `TupleExtract` lowering arm.

That means a first Starshine port must not assume Binaryen's explicit tuple AST is the same thing as Starshine's current multivalue representation.

### What Lift Produces Today

The important project-specific fact is in the HOT lift tests:

- explicit multivalue spill bridges are already lifted as one shared multi-result producer plus several scalar `LocalSet` / `LocalTee` users
- the producer is typically a normal HOT node such as a `Block` with `result_arity > 1`
- later scalar consumers read individual locals, not tuple pseudo-ops

Examples already locked in tests:

- explicit triple-result spill bridges
- branchy triple-result spill bridges
- triple-result bridges ending in `local.tee`

In other words, many raw-wasm shapes that Binaryen would represent using tuple locals are already much closer to Binaryen's post-`tuple-optimization` normal form once they are inside HOT.

## Porting Implications

### The Main Conclusion

The correct Starshine port is not "copy `TupleOptimization.cpp` literally."

The direct Binaryen algorithm is exact and useful as an oracle, but Starshine's current HOT IR changes where the equivalent work lives:

- Binaryen starts from explicit tuple locals.
- HOT lift usually starts from shared multi-result producers and scalar spill locals already.

So the implementation target for Starshine should be:

- preserve Binaryen's conservative escape policy
- preserve the scheduler slot and multivalue gate
- preserve the tee-ordering guarantees
- adapt the rewrite to current HOT multivalue bridge shapes instead of forcing explicit tuple nodes into the pipeline

## Planned Implementation Strategy

### Phase 1: Keep The First Port HOT-Native

- Implement a new hot pass module for `tuple-optimization`.
- Do not make the first version depend on explicit HOT `TupleMake` / `TupleExtract` roundtripping.
- Treat explicit tuple pseudo-ops as optional support, not the main path.

The pass should primarily recognize HOT-native equivalents of Binaryen's "good tuple-local component":

- one multi-result producer
- scalar spill locals that act as lanes of that producer
- later scalar lane reads / tees / copy traffic
- no escaping whole-value use outside the allowed shapes

### Phase 2: Recreate Binaryen's Conservatism In HOT Terms

The HOT pass should keep the same conservative rules Binaryen uses:

- If a multi-result lane group escapes to an unsupported consumer, reject the whole connected component.
- If copy traffic links two groups, flow badness across the whole component.
- If tee ordering cannot be preserved with local region edits, reject the case.
- If a case already looks like the fully split scalar form HOT local cleanup can consume, avoid widening it into tuple pseudo-ops.

### Phase 3: Keep `optimize-instructions` Responsibility Separate

- Binaryen's direct `tuple.extract(tuple.make(...))` fold is not part of tuple-optimization.
- If Starshine later starts materializing explicit HOT tuple nodes during some optimization, the direct fold should land in `optimize-instructions`, not be folded into the tuple pass.
- That keeps the phase split aligned with Binaryen and avoids overloading the tuple pass with pure peepholes.

### Phase 4: Wire The Real Scheduler Slot

Once the pass exists and has artifact proof:

- move `tuple-optimization` from `removed` to a real hot pass in the registry
- schedule it only when multivalue is enabled
- place it between `code-pushing` and `simplify-locals-nostructure`
- add dispatcher / CLI coverage where the active pass surface expects it

Current status (`2026-04-03`):

- The HOT-native tuple rewrite is now active on the explicit hot-pass surface: the registry, pass manager dispatch, and CLI flag all accept `tuple-optimization`.
- The default `optimize` / `shrink` preset order is intentionally unchanged in this tree for now; do not approximate the Binaryen slot with a nearby local ordering.
- Scalar-only explicit-pass coverage is now locked too: running `tuple-optimization` directly on a no-multivalue function stays a no-op on the public pass-manager surface.
- Initial Binaryen proof is green on the clean lane: `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 10000 --min-compared 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-10000` reached `10000/10000` normalized matches with no mismatches or command failures; the earlier clean runs `.tmp/pass-fuzz-tuple-optimization-genvalid-2000` and `.tmp/pass-fuzz-tuple-optimization-genvalid-500` were also `2000/2000` and `500/500`.
- The `wasm-smith` lane also remains mismatch-free so far: `.tmp/pass-fuzz-tuple-optimization-smith-200` reached `165/165` normalized matches before hitting only Binaryen parser failures (`invalid type index`, `Recursion groups of size zero not supported`, and `invalid wasm type: -64`).
- The focused debug-artifact compare is still the remaining proof step, and it has now been rerun against the latest kept tree again. The newest saved evidence is `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-507423`: canonical wasm and normalized WAT still differ, Starshine remains over budget (`5459.653 ms` wall, `904.985 ms` pass) versus Binaryen (`336.953 ms` wall, `2.957 ms` pass), and full Binaryen parity is still not proven. The narrowed no-host root-carrier parity bugs are fixed, the overlap-aware exact-copy copyback family is fixed in reduced form, the non-canonical copy-root-carrier family is fixed at the tuple-pass rewrite layer, the reduced nested branch-exit source-root family now stages through dedicated split locals plus a typed multivalue carrier instead of the older direct root block shortcut, a reduced root-local.set exact-copy family now also routes through a typed carrier whenever its payload source lanes are scrambled, and the reduced source-host-copy passthrough family now keeps the old non-host lanes materialized while host-only tail-live0 exact-copy groups stop adding a redundant second carrier. New focused `cmd`, native-cmd, and white-box regressions lock both the compare-shaped source-remat case and the tail-live0 lane-remat case in-source. A focused `hot_lower` roundtrip regression still proves that explicit branch-exit temp copy chains already survive lift/lower unchanged, so that family remains outside the current blocker. This reduced fix still did not move the current leading artifact family, though: the earlier `func $440` hunk is still gone, but the first surviving normalized-WAT drift remains later in canonical `func $1930` (`binary.decode_section_payload`). The passthrough-lane and tail-live0 fixes did not change that head hunk either. The current narrowed conclusion is therefore more specific: the remaining head family no longer looks like the repaired source-lane correctness hole, but a later tuple-temp / local-allocation policy difference that still falls out of the current HOT-native rewrite.
- Two reduced pipeline regressions now rule out the obvious simpler carriers: a nested scalar-result direct spill bridge and a host-`local.tee` imported-call bridge both lower cleanly through the current pass surface.
- The reduced standalone repros have become more specific too. The earlier imported-call host-tee bug is fixed: the rewrite follows the actual `LocalTee` lane instead of assuming the host spill is always last, and the encoded output preserves `local.tee 0` into the later call instead of directly reading the fresh split local. The direct scalar-forward seed bridge family is now locked too at the pass-analysis layer, including the raw decoded one-hop shape that exposed the next drift boundary. The newer source-host-copy passthrough fix now also rematerializes the old non-host lanes in the staged init root, and a narrowed host-only tail-live0 guard suppresses the redundant second exact-copy carrier in the reduced chained repro. New native lowered-output checks prove the compare-shape and tail-live0 cases keep the old source lanes live again. The large artifact rerun shows that these were still not sufficient by themselves: the surviving `func $1930` head hunk did not move, and the remaining drift still looks like a later mixed scalar-forward / local-allocation policy family rather than the repaired source-lane bug.
- The remaining scheduler work is therefore the exact Binaryen slot and multivalue gate, plus the narrower artifact-only parity gap above, not generic pass activation anymore.

## Concrete First Slice Plan

1. Add the doc-backed pass skeleton and tests first.
2. Add HOT-native fixtures for:
   - multi-result producer spilled into several locals where only one lane survives
   - tuple-like copy chains across spill locals
   - `local.tee`-based bridge traffic that still requires ordered side-effect preservation
   - feature-off scheduling
   - if explicit HOT tuple pseudo-op coverage becomes necessary, add it as HOT-builder/unit coverage rather than WAT fixtures
3. Implement the analysis as one cheap walk plus component propagation, mirroring Binaryen's `uses` / `validUses` / copy-graph structure as closely as HOT shape allows.
4. Rewrite only good components.
   Prefer direct scalar-local forwarding and dead bridge cleanup through public HOT mutation helpers.
5. Only after the HOT-native form is stable, decide whether explicit HOT tuple pseudo-op support is still necessary.

## Expected Helper / Analysis Needs

- Minimum expected descriptor requirement:
  `use_def`.
- Likely sufficient mutation helpers:
  `pass_replace_node(...)`,
  `pass_splice_region(...)`,
  `pass_delete_detached_nodes(...)`,
  `pass_mark_mutated(...)`.
- Likely no need for CFG or SSA in the first slice if the pass stays as local-shape rewriting, as Binaryen's own pass is also a simple local walk plus copy-component propagation.

## Correctness Constraints

- Preserve Binaryen's multivalue feature gate exactly.
- Preserve tee ordering and side effects exactly.
- Do not introduce explicit HOT tuple nodes into the normal pipeline unless lift/lower/verify support is added first.
- Keep the first pass conservative.
  Reject ambiguous multivalue shapes instead of guessing.
- Keep the pass cheap enough to run in Binaryen's early local-cleanup slot.

## Validation Plan

- Unit / regression tests beside the implementing pass file.
- Scheduler and registry tests beside the active optimize/dispatcher surface.
- HOT roundtrip checks when new helper behavior touches multivalue lowering.
- Focused package runs while iterating:
  - `moon test src/passes`
  - `moon test src/ir`
- Before commit:
  - `moon info`
  - `moon fmt`
  - `bun validate readme-api-sync`
  - `moon test`
- Binaryen parity checks for signoff:
  - `bun fuzz compare-pass --pass tuple-optimization ...` or
    `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization ...`
  - target `10000` comparisons
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --tuple-optimization`

## Performance Impact

- Binaryen's own pass is intentionally lightweight: one walk, a small propagation worklist, then a rewrite walk.
- Starshine should keep that spirit.
- The first HOT port should add a fast no-op screen for functions with no relevant multi-result spill/copy bridge shape so the early slot stays cheap on the debug artifact.

## Open Questions

- Whether the HOT-native multivalue spill shape already subsumes most of Binaryen's tuple pass on real artifacts, making the eventual port intentionally narrow.
- Whether explicit HOT `TupleMake` / `TupleExtract` support is worth extending through lift/lower, or whether those nodes should remain builder-only until a later pass truly needs them.
- Whether the first useful Starshine slice should be a semantics-preserving cleanup of HOT multivalue spill bridges rather than a literal tuple-node pass.
