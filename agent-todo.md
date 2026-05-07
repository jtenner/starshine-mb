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

#### DCE - Dead Code Elimination

- [DCE]003 - Runtime Budget and Oracle Refresh
  - Deliverables: rerun single-pass and ordered-prefix DCE parity on a valid baseline/oracle path; measure Starshine and Binaryen on the same artifact; reduce whole-command wall time and representation drift after the direct pass-time fixes.
  - Current status: direct DCE canonical-function parity is green and direct pass time is close to Binaryen. Remaining work is whole-command wall time, raw wasm/text-form drift, and valid ordered-prefix proof.

#### PC - Precompute

- [PC]001 - Runtime And Representation Drift
  - Deliverables: keep direct debug-artifact parity green after the dead-root `nop` normalization fix; reduce the remaining runtime gap and canonical wasm/text-form drift.
  - Current status: saved `.tmp/recheck-precompute/` repros replay green (`100 / 100`, seed `0xa11d`, out dir `.tmp/recheck-precompute-after`); the raw stack-level shortcut now covers no-candidate functions, adjacent scalar folds, branch-free constant-`if` arm picks, immutable module-constant `global.get` folds, mutable/global no-candidate reads, dropped flat nontrapping scalar/global expressions, and preserved effectful/trapping dropped tails after safe raw folds are exhausted while skipping HOT lift/pass timers. The standard mixed 10k lane stays at `0` semantic mismatches before known Binaryen/tool command failures stop the run (`6759` compared, `.tmp/pass-fuzz-precompute-const-if-raw`); direct debug-artifact compare remains canonical-function green (`.tmp/pc-artifact-const-if-raw`, normalized WAT equal, canonical function compare equal) with measured Starshine pass time about `144ms` versus Binaryen about `151ms`, while raw canonical wasm/text drift and whole-command runtime gap remain.

#### CP - Code Pushing

- [CP]002 - Rewrite Coverage and Artifact Validation
  - Deliverables: continue profiling the optimized-artifact lane; decide whether to expand the Binaryen surface or keep the pass direct-only after performance is better understood; do not schedule publicly until performance and slot proof are acceptable.

#### TO - Tuple Optimization

- [TO]005 - Exact Slot Gate And Oracle Proof
  - Deliverables: place the pass after `code-pushing` and before `simplify-locals-nostructure` once that slot exists in-tree; add feature-off preset coverage; prove the landed HOT-native rewrite with `pass-fuzz` and debug-artifact compare.
  - Remaining TODOs: retire pre-lower carrier debt in chained host-copy `tail-live0`; keep full debug-artifact compare canonically green while reducing tuple runtime, especially candidate-heavy functions such as `Func 1673`.

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

## v0.2.0 Backlog

- [HOT]003 - Node-Package Worker Queue Port
  - Deliverables: reuse the native hot-batch queue contract in the shipped Node package with `worker_threads`, one WasmGC module per worker, worker-local heap state, and stable-order serialized merge.
  - Dependencies: [HOT]002 native queue contract, worker-local function serialization hooks, and future Node package rebuild work.
