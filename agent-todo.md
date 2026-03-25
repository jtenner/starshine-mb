# Agent Tasks

## Scope
- Keep only unreleased work.
- Group work by release target.
- Use explicit slice ids so future agents can execute in dependency order.
- Keep each slice actionable enough to implement directly without re-deriving the architecture.
- Move completed work to `CHANGELOG.md`.

## v0.1.0 Active Slice

### Binaryen no-DWARF default optimize pathway parity (`wasm-opt version 125`, `-O` / `-Os`)

Goal
- Rebuild the full Binaryen no-DWARF default optimize path used by `tests/node/dist/starshine-debug-wasi.wasm`, including the nested rerun shape inside optimizing global passes.

Why
- The current public Starshine optimize preset is materially smaller than Binaryen's real no-DWARF path for the MoonBit debug artifact. Without an explicit per-pass backlog, pass work can land out of order and still miss preset parity.

Deliverables
- Keep [0066 top-level path](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L40) as the canonical no-DWARF order document until dedicated per-pass docs exist.
- Land every unique pass in the observed pathway and replay repeated cleanup slots where Binaryen repeats them.
- Add edge-case and regression coverage beside each implementing file and parity checks against Binaryen's MoonBit debug artifact output.

Required APIs
- Public `src/passes` registry and preset expansion.
- `src/cmd/cmd.mbt` dispatcher coverage for new pass flags or preset behavior.
- `scripts/self-optimize-compare.ts` for debug-artifact parity checks.
- `tests/node/dist/starshine-debug-wasi.wasm` as the canonical compare input.

Invariants
- Preserve the pre/function/post phase split from [0066#L40](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L40).
- Preserve nested reruns from [0066#L97](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L97).
- Preserve GC, multivalue, and string feature gates for this artifact.
- Do not collapse repeated cleanup slots into one occurrence unless the divergence is documented first.

Dependencies
- [0066 scope and current behavior](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L1)
- [0066 source anchors](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L23)

Exit Criteria
- Every unique pass below has research, implementation slices, edge/regression coverage, and MoonBit debug-artifact parity evidence.
- The public optimize preset can replay the top-level no-DWARF order for the MoonBit debug artifact.
- Nested reruns inside `dae-optimizing`, `inlining-optimizing`, and `simplify-globals-optimizing` are modeled or left as explicit blockers.

Suggested Tests
- `wasm-opt tests/node/dist/starshine-debug-wasi.wasm -O --all-features --debug`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>`
- `moon test`
- `moon info && moon fmt`

Observed unique-pass order
- `DFE -> RUME -> MP -> OR -> GR -> GSI -> SSA -> DCE -> RUN -> RUB -> OI -> HSO -> PLS -> PC -> CP -> TO -> SLNS -> VQ -> RL -> H2L -> OC -> LS -> CL -> LCSE -> SL -> CF -> MB -> RSE -> DAE -> INL -> DIE -> SGO -> SG -> RG -> DIR`
- Canonical ordered path and nested-shape notes live at [0066#L42](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L42) and [0066#L97](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L97).

#### RUME - Remove Unused Module Elements
1. Remaining follow-up.
   - [RUME]003 - Ordered Replay and Runtime Budget Audit - The direct module pass, CLI flag, registry wiring, focused section/index rewrite coverage, explicit memarg-index rewrites, and canonical compare-harness artifact parity are landed; the remaining work is replaying the pass in the exact no-DWARF slots once the preset path can host the module-pass order and closing the runtime budget gap.
     - Deliverables: replay `remove-unused-module-elements` on `tests/node/dist/starshine-debug-wasi.wasm`; wire the pass into the documented repeated top-level slots when the public preset expansion is ready; keep canonical compare parity green while reducing Starshine runtime and pass time toward the Binaryen budget, with likely attention on imported/trapping instantiation roots if ordered replay exposes new semantic drift.
     - Current blocker: the ordered `DFE -> RUME -> MP -> OR -> GR -> GSI` prefix still sits just under the `>= 50% as fast as Binaryen` wall-time target on the MoonBit debug artifact even though `global-struct-inference` itself is effectively free, so the remaining budget work stays upstream of `SSA`.
     - Doc: [0066#L148](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L148)
2. Do work.
   - Keep the landed direct pass stable while tightening Binaryen parity; do not widen the public preset order until the exact replay slots are available.
3. Test against binaryen.
   - Keep `moon test src/passes` and `moon test src/cmd` green while replaying the compare harness.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --remove-unused-module-elements` and any required ordered-prefix replay.

#### DCE - Dead Code Elimination
0. Shared blocker on canonical artifact parity.
   - [HOT]001 - Binaryen Multivalue Block Lowering - Canonical single-pass artifact replay now survives hot lift, DCE, final module validation, and Binaryen's `ref.null` parse path, and hot lowering now drops dead non-final multivalue roots while preserving valid trailing region-result roots, but Binaryen still rejects hot-pipeline output during canonicalization with `non-final block elements returning a value must be dropped`; the same failure reproduces under `--vacuum`, so later hot-pass compare signoff is blocked on a still-live multivalue block/tuple lowering shape rather than DCE alone. Two new synthetic regressions now prove that simpler typed block and typed loop bridge shapes survive region-root mutation, which narrows the remaining artifact failure to a more specific post-mutation lowering case than those direct patterns.
     - Deliverables: isolate the remaining artifact-local lowered multivalue block shape that Binaryen rejects after mutation; add hot-lower or binary-facing regression coverage for that exact live emitted shape; keep `--vacuum` and `--dead-code-elimination` artifact outputs Binaryen-parseable and Binaryen-valid.
     - Doc: [0066#L124](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L124)
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L178](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L178)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [DCE]001 - Binaryen-Shape Cleanup Hardening - Close the remaining parity gaps in the existing DCE pass so it matches Binaryen's structured dead-result and unreachable cleanup rules.
     - Deliverables: audit current Starshine behavior against the documented Binaryen shape; fix any trap, type, or structured-region mismatches; keep mutation invalidation honest.
     - Doc: [0066#L178](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L178)
   - [DCE]002 - Prefix Regression and Artifact Replay - Lock the corrected DCE behavior into focused tests and rerun the MoonBit debug-artifact compare harness.
     - Deliverables: add red/green regressions for dead results, unreachable tails, and imported calls; replay `--dce` parity on the artifact; document any intentional remaining divergence.
     - Status: focused DCE regressions plus follow-up hot-lift/effects fixes landed; replay now gets past the earlier `func[80]` / `func[106]` hot-lift aborts, the typed-loop lowering bug that broke canonical `--vacuum` replay at `func[81]` is fixed, the dead-result wrapper failures at `func[67]` and `func[190]` are closed by keeping typed wrappers concrete when DCE would otherwise retag dead `block` results, and Binaryen-facing `ref.null` encoding now roundtrips with heap-type immediates. Canonical compare parity is still blocked later by the shared hot-pipeline multivalue block-lowering issue above, which reproduces under both `--vacuum` and `--dead-code-elimination`.
     - Doc: [0066#L178](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L178)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### RUN - Remove Unused Names
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L183](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L183)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [RUN]001 - Name and Label Liveness Rules - Define the exact name, label, and debug-visible identifier cleanup Binaryen performs after DCE and branch reduction.
     - Deliverables: identify removable labels and names after each cleanup stage; preserve externally required names; expose the repeated-slot contract.
     - Doc: [0066#L183](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L183)
   - [RUN]002 - Triple-Slot Replay and Parity - Implement the pass and prove all three top-level RUN slots line up with Binaryen's repeated cleanup opportunities.
     - Deliverables: wire the pass into each required slot; add regressions around stale labels after `remove-unused-brs` and `merge-blocks`; compare pass output on the debug artifact.
     - Doc: [0066#L183](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L183)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### RUB - Remove Unused Brs
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L188](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L188)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [RUB]001 - Branch Liveness and Structured Repair - Port the branch-pruning logic that removes dead branch traffic while preserving valid structured control flow.
     - Deliverables: compute dead target edges and forwarding opportunities; repair block signatures and branch values; preserve trap and effect ordering.
     - Doc: [0066#L188](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L188)
   - [RUB]002 - Multi-Slot Cleanup and Artifact Compare - Replay the pass in each Binaryen slot and confirm later `merge-blocks` opportunities match the reference output.
     - Deliverables: add early, mid, and late slot coverage; write regressions for branch-value and typed-block cases; compare the pass on the MoonBit debug artifact.
     - Doc: [0066#L188](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L188)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### OI - Optimize Instructions
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L193](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L193)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [OI]001 - Peephole Parity Audit - Audit the existing optimize-instructions pass against Binaryen's early and late peephole expectations for the MoonBit artifact.
     - Deliverables: diff current Starshine patterns vs Binaryen's observed reductions; add missing peepholes or safety guards; preserve effect and trap semantics.
     - Doc: [0066#L193](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L193)
   - [OI]002 - Dual-Slot Replay and Regression Lock - Verify both OI slots remain correct after surrounding pipeline work and lock the behavior in focused tests.
     - Deliverables: add repeated-slot pipeline coverage; regress edge cases around typed ops and tuple users; rerun the debug-artifact compare harness for `--optimize-instructions`.
     - Doc: [0066#L193](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L193)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### HSO - Heap Store Optimization
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L198](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L198)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [HSO]001 - GC Heap Store Eligibility - Build the GC-aware store analysis that identifies removable or foldable heap stores without changing field semantics.
     - Deliverables: model object allocation, store, and read interactions; preserve aliasing and escaping refs; expose the pass's invalidation needs.
     - Doc: [0066#L198](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L198)
   - [HSO]002 - Early/Late Slot Validation - Implement the rewrite and prove it behaves the same in both HSO slots on focused GC fixtures and the debug artifact.
     - Deliverables: wire the pass into both Binaryen positions; add regressions for overwritten fields and escaping objects; compare Starshine vs Binaryen output for the pass.
     - Doc: [0066#L198](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L198)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### PLS - Pick Load Signs
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L203](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L203)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [PLS]001 - Signedness Selection Rules - Port the integer-load signedness heuristics Binaryen uses when it can encode the same semantics more compactly.
     - Deliverables: map eligible load/extend patterns; preserve observable integer results; reject patterns where traps or later folds could diverge.
     - Doc: [0066#L203](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L203)
   - [PLS]002 - Rewrite Matrix and Artifact Compare - Add the rewrite, cover signed/unsigned boundary cases, and compare single-pass output against Binaryen on the debug artifact.
     - Deliverables: add focused load-sign regressions; test interactions with `precompute` and `optimize-instructions`; replay Binaryen parity for `--pick-load-signs`.
     - Doc: [0066#L203](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L203)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### PC - Precompute
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L208](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L208)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [PC]001 - Constant Folding Surface - Audit the exact constant, tuple, and local-evaluable fragments Binaryen folds in the top-level `precompute` slots for `-O` / `-Os`.
     - Deliverables: map foldable op families; preserve trap behavior and feature typing; note the difference between top-level `precompute` and nested `precompute-propagate`.
     - Doc: [0066#L208](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L208)
   - [PC]002 - Early/Late Slot Regression and Artifact Parity - Harden the pass for both top-level slots and compare the resulting folds against Binaryen on the debug artifact.
     - Deliverables: add regressions for early and late folding opportunities; verify interaction with surrounding cleanup passes; replay `--precompute` parity on the artifact.
     - Doc: [0066#L208](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L208)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### CP - Code Pushing
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L213](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L213)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [CP]001 - Motion Safety Rules - Port Binaryen's code-motion rules for pushing work deeper into control flow without duplicating invalid side effects.
     - Deliverables: encode effect and trap guards for movable expressions; preserve control dependence and size heuristics; define the bailout cases clearly.
     - Doc: [0066#L213](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L213)
   - [CP]002 - Rewrite Coverage and Artifact Validation - Implement the move and test it against branchy, trap-sensitive fixtures plus the MoonBit debug artifact.
     - Deliverables: add regressions for duplicated work, traps, and branch-local constants; wire the pass into the early slot; compare Starshine and Binaryen pass output.
     - Doc: [0066#L213](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L213)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### TO - Tuple Optimization
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L218](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L218)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [TO]001 - Multivalue Tuple Rewrite Rules - Port the tuple construction and extraction simplifications Binaryen performs before heavy local cleanup.
     - Deliverables: cover tuple.make and tuple.extract style patterns; preserve multivalue typing and ordering; reject cases that still need surrounding locals intact.
     - Doc: [0066#L218](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L218)
   - [TO]002 - Feature-Gated Validation and Artifact Compare - Add multivalue regressions and confirm the pass only appears when the artifact feature set matches Binaryen's gate.
     - Deliverables: add tests for tuple users before `simplify-locals-nostructure`; cover feature-off scheduler behavior; compare `--tuple-optimization` output against Binaryen.
     - Doc: [0066#L218](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L218)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### SLNS - Simplify Locals No-Structure
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L223](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L223)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [SLNS]001 - Early Local Simplification Core - Port the local-traffic reductions Binaryen runs before it is willing to reshape structure.
     - Deliverables: simplify sets, gets, and dead locals without creating new structured returns; preserve later coalescing opportunities; integrate with current local analyses.
     - Doc: [0066#L223](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L223)
   - [SLNS]002 - Early-Slot Regression and Artifact Proof - Lock the no-structure contract into tests and compare the early local-cleanup prefix against Binaryen.
     - Deliverables: add regressions for tee-like traffic and tuple scratch locals; confirm structure is intentionally preserved; replay parity for the pass on the debug artifact.
     - Doc: [0066#L223](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L223)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### VQ - Vacuum
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L228](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L228)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [VQ]001 - Cleanup Semantics Audit - Audit the existing vacuum pass against Binaryen's repeated garbage-collection role after earlier rewrites.
     - Deliverables: confirm which empty blocks, nops, and detached residue Binaryen drops; preserve typed block correctness; tighten any mismatches in the current pass.
     - Doc: [0066#L228](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L228)
   - [VQ]002 - Repeated-Slot Regression Matrix - Add pipeline coverage that proves all four vacuum slots remain valid as surrounding passes land.
     - Deliverables: write regressions around empty structures and detached nodes; verify slot ordering in the public preset; replay pass parity against Binaryen on the artifact.
     - Doc: [0066#L228](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L228)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### RL - Reorder Locals
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L233](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L233)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [RL]001 - Local Cost Model and Reindex Plan - Port Binaryen's local reordering goal and compute a safe remap plan after simplification and coalescing.
     - Deliverables: define the local cost or frequency model; preserve parameter and externally visible ordering constraints; prepare a reusable local-index remapper.
     - Doc: [0066#L233](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L233)
   - [RL]002 - Triple-Slot Rewrite and Artifact Compare - Apply the remap in each required slot and verify surrounding passes still see Binaryen-aligned local order.
     - Deliverables: add regressions for repeated reorder/coalesce interactions; confirm index rewrites in code and metadata; compare the pass output against Binaryen on the artifact.
     - Doc: [0066#L233](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L233)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### H2L - Heap2Local
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L238](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L238)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [H2L]001 - Escape and Alias Eligibility - Build the GC-localization analysis that proves heap traffic can be rewritten into locals without alias leaks.
     - Deliverables: track allocation lifetimes, reads, writes, and escaping refs; preserve aliasing correctness; document unsupported object shapes explicitly.
     - Doc: [0066#L238](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L238)
   - [H2L]002 - Localization Rewrite and Artifact Validation - Rewrite eligible heap accesses to locals and validate the result on focused GC fixtures and the debug artifact.
     - Deliverables: add regressions for escaping objects and partial field coverage; prove the pass only runs in the GC mid-function slot; compare against Binaryen output.
     - Doc: [0066#L238](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L238)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### OC - Optimize Casts
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L243](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L243)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [OC]001 - Cast Tightening Rules - Port the GC cast simplifications Binaryen runs after `heap2local` when subtype facts are strongest.
     - Deliverables: encode ref.cast, ref.test, nullability, and subtype simplifications; preserve trap and exact-type semantics; integrate with current type helpers.
     - Doc: [0066#L243](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L243)
   - [OC]002 - GC Regression Matrix and Artifact Compare - Add focused GC cast regressions and verify the pass output matches Binaryen on the MoonBit artifact.
     - Deliverables: cover exact refs, nullability, and escaping values; confirm the pass stays after `heap2local`; run `--optimize-casts` parity against Binaryen.
     - Doc: [0066#L243](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L243)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### LS - Local Subtyping
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L248](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L248)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [LS]001 - Local Type Narrowing Core - Port the local-subtyping rewrite that narrows GC local types before coalescing widens them again.
     - Deliverables: compute safe narrower local types from uses and defs; preserve multivalue and tuple-local behavior; keep later coalescing constraints explicit.
     - Doc: [0066#L248](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L248)
   - [LS]002 - Ordering Tests and Artifact Proof - Lock the required `optimize-casts -> local-subtyping -> coalesce-locals` order into tests and compare the pass against Binaryen.
     - Deliverables: add regressions for local narrowing before coalescing; verify scheduler order; replay `--local-subtyping` parity on the MoonBit artifact.
     - Doc: [0066#L248](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L248)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### CL - Coalesce Locals
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L253](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L253)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [CL]001 - Compatibility and Lifetime Analysis - Port Binaryen's local-coalescing compatibility test so only safe local lifetimes are merged.
     - Deliverables: compute live-range overlap and type compatibility; preserve tuple scratch and GC subtype constraints; define which locals are never coalesced.
     - Doc: [0066#L253](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L253)
   - [CL]002 - Dual-Slot Rewrite, Reorder Interaction, and Artifact Parity - Implement the merge, keep `reorder-locals` interactions stable, and compare the pass output against Binaryen.
     - Deliverables: add regressions for double-slot coalescing and reordered indices; validate with surrounding `simplify-locals` and `reorder-locals`; replay parity on the debug artifact.
     - Doc: [0066#L253](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L253)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### LCSE - Local CSE
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L258](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L258)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [LCSE]001 - Local Expression Equivalence - Port the expression-equivalence rules Binaryen uses to reuse local computations after coalescing has simplified traffic.
     - Deliverables: define effect-safe equivalence classes for local computations; preserve trap ordering and GC side effects; integrate with current effects analysis.
     - Doc: [0066#L258](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L258)
   - [LCSE]002 - Mid-Pipeline Regression and Artifact Compare - Add focused CSE regressions and confirm the pass output matches Binaryen on the MoonBit artifact.
     - Deliverables: cover repeated loads, locals, and effect barriers; verify the pass stays in the mid-function slot; replay `--local-cse` parity against Binaryen.
     - Doc: [0066#L258](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L258)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### SL - Simplify Locals
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L263](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L263)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [SL]001 - Full Local Simplification Audit - Harden the existing simplify-locals pass so the late local cleanup exactly matches Binaryen's post-coalescing behavior.
     - Deliverables: diff the current Starshine pass against Binaryen's late slot semantics; close any remaining copy, tee, or dead-local gaps; preserve typed structure and tuple locals.
     - Doc: [0066#L263](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L263)
   - [SL]002 - Slot Validation and Artifact Replay - Lock the corrected pass into scheduler tests and replay the MoonBit debug-artifact compare harness.
     - Deliverables: add focused regressions for late-slot local cleanup; verify surrounding `vacuum` and `reorder-locals` behavior; run `--simplify-locals` parity against Binaryen.
     - Doc: [0066#L263](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L263)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### CF - Code Folding
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L268](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L268)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [CF]001 - Region Equivalence and Fold Safety - Port the region-merging rules Binaryen uses to fold duplicate code late in the function pipeline.
     - Deliverables: define structural equality for candidate code regions; preserve labels, branch targets, and tuple typing; reject folds that would disturb later cleanup.
     - Doc: [0066#L268](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L268)
   - [CF]002 - Late-Slot Regression and Artifact Compare - Add duplicate-region regressions and confirm the folded output matches Binaryen on the MoonBit artifact.
     - Deliverables: cover repeated blocks, typed values, and branchy regions; verify the pass remains late in the pipeline; replay `--code-folding` parity against Binaryen.
     - Doc: [0066#L268](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L268)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### MB - Merge Blocks
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L273](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L273)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [MB]001 - Typed Block Merge Rules - Port Binaryen's block-flattening rules that merge nested blocks without breaking branch or result typing.
     - Deliverables: encode which block nesting patterns can collapse; preserve branch values and typed block signatures; keep the pass compatible with repeated late cleanup.
     - Doc: [0066#L273](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L273)
   - [MB]002 - Dual-Slot Replay and Artifact Validation - Run the pass in both Binaryen slots and validate the resulting branch-cleanup opportunities against the reference output.
     - Deliverables: add regressions for typed block merging and repeated-slot cleanup; verify order with `remove-unused-brs`; replay `--merge-blocks` parity on the debug artifact.
     - Doc: [0066#L273](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L273)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### RSE - Redundant Set Elimination
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L278](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L278)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [RSE]001 - Redundant Write Detection - Port the late-pipeline write-elimination logic that removes provably redundant sets after coalescing and peephole cleanup.
     - Deliverables: identify overwritten sets with no intervening observable read; preserve traps and side effects; integrate with current liveness and effects helpers.
     - Doc: [0066#L278](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L278)
   - [RSE]002 - Final-Cleanup Regression and Artifact Proof - Add focused set-elimination regressions and confirm the pass output matches Binaryen before the final `vacuum`.
     - Deliverables: cover locals, globals, and GC field writes where applicable; verify scheduler order with the final cleanup slot; compare `--rse` output against Binaryen on the artifact.
     - Doc: [0066#L278](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L278)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### DAE - Dead Argument Elimination Optimizing
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L283](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L283)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [DAE]001 - Call-Graph Pruning and Touched-Function Tracking - Port Binaryen's optimizing dead-argument elimination and record exactly which functions need nested cleanup reruns.
     - Deliverables: remove dead call parameters safely across direct users; localize call targets where Binaryen does; track the touched-function set for the nested rerun helper.
     - Doc: [0066#L283](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L283)
   - [DAE]002 - Nested Post-Inlining Cleanup and Artifact Compare - Recreate the `optimizeAfterInlining` subpipeline and validate both the top-level and nested output against Binaryen.
     - Deliverables: prepend `precompute-propagate` before rerunning the default function pipeline on touched functions; add nested-run scheduler tests; compare `--dae-optimizing` output on the debug artifact.
     - Doc: [0066#L283](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L283)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### INL - Inlining Optimizing
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L288](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L288)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [INL]001 - Heuristics, Rewrite, and Touched-Function Set - Port Binaryen's optimizing inliner and keep the touched-function filter that drives nested cleanup reruns.
     - Deliverables: implement Binaryen-like inlining heuristics for `-O` / `-Os`; rewrite callsites and remove now-dead functions; capture the exact set of mutated functions for the nested runner.
     - Doc: [0066#L288](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L288)
   - [INL]002 - Nested Useful-Passes Replay and Artifact Parity - Recreate `addUsefulPassesAfterInlining` and prove both the inline rewrite and nested cleanup match Binaryen on the debug artifact.
     - Deliverables: prepend `precompute-propagate`, rerun the default function pipeline on touched functions, and add nested-run tests; compare `--inlining-optimizing` output against Binaryen.
     - Doc: [0066#L288](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L288)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### DIE - Duplicate Import Elimination
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L293](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L293)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [DIE]001 - Import Identity and Merge Safety - Define the exact module/name/type identity checks required before duplicate imports can be merged.
     - Deliverables: compare import module, field, and external type exactly; preserve externally observable ordering where required; build a replacement map for merged import indices.
     - Doc: [0066#L293](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L293)
   - [DIE]002 - Index Rewrite and Artifact Validation - Rewrite all users of merged imports and validate the late post-pass cleanup result against Binaryen.
     - Deliverables: patch function/table/global/memory import users consistently; add regressions for import-boundary corner cases; compare `--duplicate-import-elimination` output on the artifact.
     - Doc: [0066#L293](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L293)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### SGO - Simplify Globals Optimizing
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L298](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L298)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [SGO]001 - Constant-Global Rewrite and Mutation Tracking - Port the constant-global replacement and dead `global.set` removal flow while tracking every mutated function.
     - Deliverables: replace constant global reads safely; remove dead writes without violating ordering; maintain the exact touched-function set for nested reruns.
     - Doc: [0066#L298](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L298)
   - [SGO]002 - Nested Default-Function Rerun and Artifact Compare - Recreate the per-function rerun of `addDefaultFunctionOptimizationPasses()` and validate the result against Binaryen.
     - Deliverables: rerun the default function pipeline without the `precompute-propagate` prefix; add nested-run scheduler tests; compare `--simplify-globals-optimizing` output on the debug artifact.
     - Doc: [0066#L298](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L298)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### SG - String Gathering
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L303](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L303)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [SG]001 - String Collection and Canonicalization Rules - Port the string-gathering transformation that runs immediately before `reorder-globals` on string-enabled modules.
     - Deliverables: collect the string data Binaryen hoists or canonicalizes; preserve string feature semantics and global users; define unsupported string layouts explicitly.
     - Doc: [0066#L303](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L303)
   - [SG]002 - Feature Gate, Global Order, and Artifact Parity - Validate the pass only runs when strings are enabled and confirm the resulting global layout matches Binaryen.
     - Deliverables: add feature-gated scheduler tests and focused string regressions; verify interaction with `reorder-globals`; compare `--string-gathering` output on the debug artifact.
     - Doc: [0066#L303](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L303)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### RG - Reorder Globals
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L308](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L308)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [RG]001 - Global Cost Model and Reindexing - Port Binaryen's global reordering criteria and compute a safe remap after late global cleanup and string gathering.
     - Deliverables: define the reordering cost model; preserve externally visible boundaries and section invariants; prepare a reusable global-index remapper.
     - Doc: [0066#L308](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L308)
   - [RG]002 - Late-Postpass Validation and Artifact Compare - Apply the global reorder, lock the resulting section rewrites into tests, and compare the output against Binaryen.
     - Deliverables: add regressions for reordered globals with string users and exports; verify the pass stays after `string-gathering`; replay `--reorder-globals` parity on the artifact.
     - Doc: [0066#L308](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L308)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### DIR - Directize
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L313](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L313)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [DIR]001 - Indirect-to-Direct Eligibility - Port Binaryen's final-pass logic for converting eligible indirect calls into direct calls without violating table behavior.
     - Deliverables: identify call targets that are uniquely resolvable; preserve table semantics, imports, and dynamic behavior; document the bailout cases that remain indirect.
     - Doc: [0066#L313](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L313)
   - [DIR]002 - Call Rewrite, Boundary Regressions, and Artifact Proof - Rewrite eligible callsites, test boundary cases, and confirm the final pass output matches Binaryen on the debug artifact.
     - Deliverables: patch call instructions and dependent signatures safely; add regressions for mixed direct/indirect call tables; compare `--directize` output on the artifact.
     - Doc: [0066#L313](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L313)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.
## v0.2.0 Backlog

- No active backlog slices. Add the next IR2 slice id here before new implementation work starts.
