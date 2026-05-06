# Agent Tasks

## Scope
- Keep only active unreleased work.
- Group work by release target.
- Use explicit slice ids so future agents can execute in dependency order.
- Move completed work and historical evidence to `CHANGELOG.md` or the relevant docs/wiki page.

## Current Parity Focus
- Keep the Binaryen no-DWARF default optimize path as the v0.1.0 parity target.
- Canonical order and nested-shape notes live in `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` and `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`.
- Prefer exact direct-pass parity first, then ordered-neighborhood replay, then preset scheduling.
- Do not widen public `optimize` / `shrink` slots until the surrounding Binaryen neighborhood is representable and oracle-proven.

## v0.1.0 Active Slices

### Binaryen no-DWARF default optimize pathway parity (`wasm-opt version 125`, `-O` / `-Os`)

Goal
- Rebuild the full Binaryen no-DWARF default optimize path used by `tests/node/dist/starshine-debug-wasi.wasm`, including nested reruns inside optimizing global passes.

Required APIs
- `src/passes` registry and preset expansion.
- `src/cmd/cmd.mbt` dispatcher coverage for new pass flags or preset behavior.
- `scripts/self-optimize-compare.ts` and `scripts/pass-fuzz-compare.ts` for oracle checks.
- `tests/node/dist/starshine-debug-wasi.wasm` as the canonical compare input.

Invariants
- Preserve the pre/function/post phase split from the canonical optimize-path docs.
- Preserve nested reruns inside `dae-optimizing`, `inlining-optimizing`, and `simplify-globals-optimizing` until modeled or explicitly blocked.
- Preserve GC, multivalue, and string feature gates for this artifact.
- Do not collapse repeated cleanup slots into one occurrence unless the divergence is documented first.

Suggested Tests
- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --pass <pass> --count 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-<pass>`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>`

Observed unique-pass order
- `DFE -> RUME -> MP -> OR -> GR -> GSI -> SSA -> DCE -> RUN -> RUB -> OI -> HSO -> PLS -> PC -> CP -> TO -> SLNS -> VQ -> RL -> H2L -> OC -> LS -> CL -> LCSE -> SL -> CF -> MB -> RSE -> DAE -> INL -> DIE -> SGO -> SG -> RG -> DIR`

#### Ordered-prefix / hot-pipeline blockers

- [HOT]002 - Native Parallel Hot-Batch Queue
  - Deliverables: add a native-only worker queue over eligible defined functions for the current hot batch payload (`ssa-nomerge -> dead-code-elimination -> vacuum -> optimize-instructions -> simplify-locals`); keep final output byte-stable and deterministic; gate behind an explicit native-only option.
  - Dependencies: [HOT]001 replay hardening must stay green.

- [BIN]001 - Iterative Expr Decoder
  - Goal: replace recursive binary expression decoding with an explicit worklist / stack machine so deeply nested valid wasm does not depend on native call-stack budget.
  - Deliverables: preserve exact decode errors and offsets; add large-depth regressions that exercise native `run_cmd` without stack-limit hacks.
  - Relevant code: `src/binary/decode.mbt`.

#### 2026-05-06 direct-pass audit follow-up

- [AUD]001 - Fresh Direct-Pass Mismatch Triage
  - Why: the 2026-05-06 full pass audit (`docs/wiki/raw/research/0513-2026-05-06-starshine-pass-audit.md`) reran the current `pass-fuzz-compare` harness after substantial fuzzer / harness changes and found fresh active-pass mismatches even on a 100-case smoke lane.
  - Passes with active problems: `global-refining`, `memory-packing`, `optimize-instructions`, `precompute`, `remove-unused-brs`, `ssa-nomerge`.
  - Deliverables: reduce and classify each fresh repro under `.tmp/pass-audit-20260506/`; promote durable failures into focused tests; fix the current mismatch families; rerun direct `--pass <name>` parity at `10000` cases before treating the pass as green again.
  - Current mismatch families from the audit: `global-refining` nullability/type-tightening drift, `memory-packing` data-segment normalization drift, `optimize-instructions` signed-vs-unsigned constant-fold canonicalization drift, `precompute` dead `block` / `br_table` cleanup drift, `remove-unused-brs` shared dead branch-wrapper cleanup drift, and `ssa-nomerge` temp-local shaping drift.

- [AUD]002 - Revalidate Smoke-Green Direct Passes After Fuzzer Changes
  - Why: the same 2026-05-06 audit only smoke checked many direct passes at `--count 100`, and older parity evidence is now stale because the fuzzer / compare-pass harness changed a lot.
  - Passes requiring full direct-pass revalidation: `code-folding`, `code-pushing`, `dead-code-elimination`, `directize`, `duplicate-function-elimination`, `duplicate-import-elimination`, `global-struct-inference`, `heap-store-optimization`, `heap2local`, `local-cse`, `local-subtyping`, `merge-locals`, `once-reduction`, `optimize-casts`, `pick-load-signs`, `redundant-set-elimination`, `remove-unused-module-elements`, `remove-unused-nonfunction-module-elements`, `reorder-globals`, `reorder-locals`, `simplify-locals`, `simplify-locals-no-structure`, `simplify-locals-nostructure`, `simplify-locals-notee-nostructure`, `string-gathering`, `tuple-optimization`, `untee`, `vacuum`.
  - Completed 2026-05-06: `avoid-reinterprets` direct revalidation in `.tmp/pass-fuzz-avoid-reinterprets` reached 6759/10000 compared cases with 6759 normalized matches, 0 mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures; see `docs/wiki/raw/research/0516-2026-05-06-avoid-reinterprets-direct-revalidation.md`.
  - Completed 2026-05-06: `remove-unused-names` direct revalidation in `.tmp/pass-fuzz-remove-unused-names` reached 6759/10000 compared cases with 6759 normalized matches, 0 mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures; see `docs/wiki/raw/research/0517-2026-05-06-remove-unused-names-direct-revalidation.md`.
  - Completed 2026-05-06: `coalesce-locals` direct revalidation in `.tmp/pass-fuzz-coalesce-locals` reached 6759/10000 compared cases with 6759 normalized matches, 0 mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures; see `docs/wiki/raw/research/0518-2026-05-06-coalesce-locals-direct-revalidation.md`.
  - Deliverables: rerun repo-standard direct signoff (`moon info`, `moon fmt`, `moon test`, then `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass <name> --out-dir .tmp/pass-fuzz-<name>`) for each listed pass; refresh any artifact lanes that were previously signed off before the recent fuzzer / harness churn; update the relevant wiki parity pages and this backlog as passes are re-proven.

#### DCE - Dead Code Elimination

- [DCE]003 - Runtime Budget and Oracle Refresh
  - Deliverables: rerun single-pass and ordered-prefix DCE parity on a valid baseline/oracle path; measure Starshine and Binaryen on the same artifact; reduce whole-command wall time and representation drift after the direct pass-time fixes.
  - Current status: direct DCE canonical-function parity is green and direct pass time is close to Binaryen. Remaining work is whole-command wall time, raw wasm/text-form drift, and valid ordered-prefix proof.

#### RUB - Remove Unused Brs

- [RUB]002 - Ordered-Neighborhood and Runtime Follow-up
  - Deliverables: keep the direct artifact lane canonically green while later ordered-prefix work lands; rerun a larger mixed-generator compare-pass lane before final preset proof; treat remaining work as ordered-neighborhood and end-to-end runtime work unless a fresh mutation-backed mismatch appears.

#### PC - Precompute

- [PC]001 - Runtime and Representation Drift
  - Deliverables: keep direct debug-artifact parity green; reduce the current runtime gap and canonical wasm/text-form drift; keep the fuzz parity gate green.

- [PC]002 - Early/Late Slot Regression and Artifact Parity
  - Deliverables: add regressions for early and late folding opportunities; verify interaction with surrounding cleanup passes; replay `--precompute` parity on the artifact after neighboring slots land.

#### CP - Code Pushing

- [CP]002 - Rewrite Coverage and Artifact Validation
  - Deliverables: continue profiling the optimized-artifact lane; decide whether to expand the Binaryen surface or keep the pass direct-only after performance is better understood; do not schedule publicly until performance and slot proof are acceptable.

#### TO - Tuple Optimization

- [TO]005 - Exact Slot Gate And Oracle Proof
  - Deliverables: place the pass after `code-pushing` and before `simplify-locals-nostructure` once that slot exists in-tree; add feature-off preset coverage; prove the landed HOT-native rewrite with `pass-fuzz` and debug-artifact compare.
  - Remaining TODOs: retire pre-lower carrier debt in chained host-copy `tail-live0`; rerun a fresh `10000`-case `gen-valid` compare on current head; keep full debug-artifact compare canonically green while reducing tuple runtime, especially candidate-heavy functions such as `Func 1673`.

#### SLNNS - Simplify Locals No-Tee No-Structure

- [SLNNS]003 - Preset Readiness Gate
  - Deliverables: keep the direct pass out of public `optimize` / `shrink` until the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood is representable and oracle-proven.

#### SLNS - Simplify Locals No-Structure

- [SLNS]003 - Ordered Slot Gate
  - Deliverables: keep the direct pass out of public `optimize` / `shrink` until ordered-neighborhood replay proves the exact `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals` slot; revisit placement with `coalesce-locals` and `local-cse`.

#### RL - Reorder Locals

- [RL]003 - Boundary Policy and Artifact Compare
  - Deliverables: decide whether Binaryen's multivalue call writeback/materialization layer is a broader compatibility target or explicitly out of scope for `reorder-locals`; keep preset slot wiring deferred until neighboring passes make the slot truthful.

#### H2L - Heap2Local

- [H2L]002 - Localization Follow-up and Neighborhood Parity
  - Deliverables: cover Binaryen's non-nullable-local / refinalization fixups and the wider missing-pass neighborhood (`optimize-casts` follow-ups, `coalesce-locals`, `local-cse`) needed for full no-DWARF parity.

#### OC - Optimize Casts Follow-up

- [OC]003 - Descriptor And Branch Cast Coverage
  - Deliverables: extend the direct hot pass beyond plain `ref.cast` / `ref.test` to cover safe `ref.cast_desc_eq`, `ref.test_desc`, `br_on_cast`, and `br_on_cast_fail` rewrites; preserve descriptor-pair invariants, branch arity/payload semantics, exact refs, and all trap-vs-branch behavior.
  - Tests: descriptor-cast GC regressions, branch-cast success/fail rewrites, nullable/exact negative cases, `moon test src/passes`, and direct `--optimize-casts` compare-pass replay.

- [OC]004 - Negative And Exact-Ref Tightening
  - Deliverables: add conservative guaranteed-false `ref.test` / cast-family folding where source and target heap hierarchies are provably disjoint; tighten exact-ref reasoning without invalidating subtype casts; keep impossible/null bottom cases validation-safe.
  - Tests: sibling hierarchy false tests, abstract heap disjointness cases, exact-vs-inexact refs, null-only families, and `10000`-case `--optimize-casts` parity.

- [OC]005 - Ordered Slot And Preset Readiness
  - Deliverables: keep direct `optimize-casts` parity green while proving the `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` neighborhood; do not add `optimize-casts` to public `optimize` / `shrink` presets until the ordered neighborhood and debug artifact are oracle-proven.
  - Tests: ordered-neighborhood replay after `local-subtyping`, `coalesce-locals`, and `local-cse` are active; debug artifact compare with `--optimize-casts` and the surrounding slot sequence.

#### CL - Coalesce Locals

- [CL]003 - Ordered-Slot Replay
  - Deliverables: keep direct pass parity green and replay the exact slots after `local-subtyping`, `reorder-locals`, and surrounding cleanup passes are available.

#### SL - Simplify Locals

- [SL]004 - Slot Validation and Artifact Replay
  - Deliverables: keep the late-slot regression suite green; reduce the remaining non-adjacent nested exact-expression drift and branchy internal-helper hotspot cluster; keep direct and ordered artifact compares canonically green while runtime work lands.

#### CF - Code Folding

- [CF]002 - Late-Slot Regression and Artifact Compare
  - Deliverables: expand beyond the landed branch-free identical void suffix slice; cover branchy tails, structured-control suffixes, and typed/value `if` folding; verify late-pipeline slot and replay `--code-folding` artifact parity.

#### RSE - Redundant Set Elimination

- [RSE]002 - CFG Value Flow And Refined Local Gets
  - Deliverables: implement full block start/end local value identities, predecessor agreement/disagreement merge handling, loop convergence or documented conservative skips, and strict-subtype equivalent-local `local.get` retargeting.
  - Tests: branch-join positives/negatives, loop convergence/skips, `rse-gc.wast`-style type-refinement tests, direct compare-pass parity, and final `rse -> vacuum` cleanup-slot replay.

#### DAE - Dead Argument Elimination Optimizing

- [DAE]001 - Call-Graph Pruning and Touched-Function Tracking
  - Deliverables: remove dead call parameters safely across direct users; localize call targets where Binaryen does; track the touched-function set for nested cleanup reruns.

- [DAE]002 - Nested Post-Inlining Cleanup and Artifact Compare
  - Deliverables: prepend `precompute-propagate` before rerunning the default function pipeline on touched functions; add nested-run scheduler tests; compare `--dae-optimizing` output on the debug artifact.

#### INL - Inlining Optimizing

- [INL]001 - Heuristics, Rewrite, and Touched-Function Set
  - Deliverables: implement Binaryen-like inlining heuristics for `-O` / `-Os`; rewrite callsites and remove now-dead functions; capture the exact set of mutated functions for nested reruns.

- [INL]002 - Nested Useful-Passes Replay and Artifact Parity
  - Deliverables: prepend `precompute-propagate`, rerun the default function pipeline on touched functions, add nested-run tests, and compare `--inlining-optimizing` output against Binaryen.

#### SGO - Simplify Globals Optimizing

- [SGO]001 - Constant-Global Rewrite and Mutation Tracking
  - Deliverables: replace constant global reads safely; remove dead writes without violating ordering; maintain the exact touched-function set for nested reruns.

- [SGO]002 - Nested Default-Function Rerun and Artifact Compare
  - Deliverables: rerun the default function pipeline without the `precompute-propagate` prefix; add nested-run scheduler tests; compare `--simplify-globals-optimizing` output on the debug artifact.

#### SG / RG / DIR late-tail scheduling

- [SG]002 - Late-Tail Preset Scheduling
  - Deliverables: keep `string-gathering` out of public presets until `simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize` can be replayed as an ordered neighborhood; decide whether Binaryen reuse of existing canonical string globals is needed for string-heavy binaries.

- [RG]002 - Late-Postpass Validation and Artifact Compare
  - Deliverables: add string-gathering/directize neighborhood regressions; verify the pass stays after `string-gathering`; replay ordered late-tail parity once neighboring passes exist.

- [DIR]002 - Late-Tail Slot Proof
  - Deliverables: keep `directize` preset scheduling deferred until the `string-gathering -> reorder-globals -> directize` slot can be replayed together; add `directize-initial-contents-immutable` support only if/when Starshine grows a pass-arg surface for it.

## v0.2.0 Backlog

- [HOT]003 - Node-Package Worker Queue Port
  - Deliverables: reuse the native hot-batch queue contract in the shipped Node package with `worker_threads`, one WasmGC module per worker, worker-local heap state, and stable-order serialized merge.
  - Dependencies: [HOT]002 native queue contract, worker-local function serialization hooks, and future Node package rebuild work.
