# Agent Tasks

## Scope
- Keep only active unreleased work.
- Group work by release target.
- Use explicit slice ids so future agents can execute in dependency order.
- Move completed work and historical evidence to `CHANGELOG.md` or the relevant docs/wiki page.

## Current Parity Focus
- Keep the Binaryen no-DWARF default optimize path as the v0.1.0 parity target.
- Canonical order and nested-shape notes live in `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` and `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`.
- Prefer direct-pass semantic parity first, then ordered-neighborhood replay, then preset scheduling.
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

Completed direct-pass slices
- `code-pushing` / `[CP]002`: accepted on 2026-05-09 under the pass-wide criteria of Binaryen semantic parity, valid wasm output, and pass-local speed at least 50% of Binaryen. Raw wasm/text drift is representation-only and not an active blocker; public preset scheduling remains part of the ordered-neighborhood / tuple-slot work, not a code-pushing direct-pass blocker.
- `tuple-optimization` exact slot / `[TO]005`: accepted on 2026-05-09 for v0.1.0 after `code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs` fixed the real `defined=29`, `defined=31`, `defined=33`, and `defined=200` optimizer shape drifts. The remaining `.tmp/to-exact-slot-artifact` red at `defined=200 abs=217` is a compare-normalization artifact: Starshine raw output and Binaryen strip-debug output both elide/preserve the harmless outer block consistently when normalized the same way, but the helper currently compares strip-debug-normalized Starshine against Binaryen's raw `--debug` output. This is not a v0.1.0 blocker.
- `simplify-locals` / `[SL]004`: accepted on 2026-05-09 for v0.1.0 under the direct-pass criteria of Binaryen semantic parity, Binaryen-accepted wasm output, and pass-local speed at least 50% of Binaryen. The exact debug-artifact helper remains red at `defined=208 abs=225`, but the inspected diff is representation-only stackification/carrier drift: Binaryen keeps an inline value-producing block/extra wrappers and Starshine spills that value to a local before reusing it. No semantic mismatch or validation failure is currently attributed to `simplify-locals`; future exact-helper normalization belongs with `[TOOL]001` or a new cosmetic parity task, not the v0.1.0 gate.
- `code-folding` / `[CF]002`: accepted on 2026-05-10 for v0.1.0 direct-pass signoff under the same criteria. Direct fuzz at `.tmp/pass-fuzz-code-folding-cf002-terminal-if` reported `6759/10000` compared, `0` mismatches, and only `20` Binaryen/tool command failures; direct debug-artifact replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1680352` stayed inside the pass-local speed floor (`334.711ms` Starshine vs `176.295ms` Binaryen). The remaining direct `defined=220 abs=237` diff is classified helper-wrapper representation drift, and the focused late cleanup replay `code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names` at `.tmp/cf002-late-cleanup-artifact` had the same first diff and byte-identical focused diff files as the no-CF cleanup baseline at `.tmp/cf002-late-cleanup-without-cf-artifact`, so it is not a code-folding blocker.

#### Ordered-prefix / hot-pipeline blockers

- No active threading work for v0.1.0. Parallel hot-batch execution is deferred until MoonBit exposes threading support that is suitable for Starshine's native runtime.

#### TO - Tuple Optimization

- No active v0.1.0 tuple exact-slot blocker. Future tuple work should target new semantic/validity mismatches, feature-gated preset coverage if Starshine gains explicit feature options, or runtime reductions such as candidate-heavy functions including `Func 1673`; do not preserve cosmetic raw/debug blocks solely for byte-shape parity.

#### SL - Simplify Locals

- No active v0.1.0 direct `simplify-locals` blocker. Future work should target new semantic or validity mismatches, pass-local runtime regressions proven inside `simplify-locals`, or narrow shrink/code-quality improvements for real value-carrier spills; do not preserve debug-only wrappers solely for byte/shape parity.
- The 2026-05-09 value-carrier shrink pass retired the focused `$913` typed-control tee and `$42` block-result spill/reload families in `defined=208 abs=225`, but exact artifact compare remains red. The next real shrink candidate is broader and riskier: a call-result carrier where Starshine still materializes `call $292 (block ...)` into a local before `call $281`, while Binaryen keeps it inline. Only pursue it with strict branch-depth/effect-order guards.

#### CF - Code Folding

- No active v0.1.0 direct `code-folding` blocker. Future code-folding work should target new semantic/validity mismatches, a proven downstream code-size blocker, or explicit preset-scheduling work after the surrounding late cleanup path is representable; do not implement broad Binaryen function-ending helper-label sharing solely to erase the already-classified `defined=220 abs=237` helper-wrapper representation drift.

#### RSE - Redundant Set Elimination

- [RSE]002 - CFG Value Flow And Refined Local Gets
  - Current status: 2026-05-10 added branch-disagreement merge identities for self-set folding, body-local default identities for redundant default writes, raw strict-subtype equivalent-local `local.get` retargeting, raw preservation of fallthrough facts after one-armed terminating `if`s, paired vacuum cleanup for nested pure `drop` / `nop` debris, vacuum empty-then/live-else inversion, raw structured block/if label-exit merge tracking with unreachable-tail skipping so `br_if` block exits no longer misfold final const sets, GC conditional branch-exit recording for `br_on_null` / `br_on_non_null` / `br_on_cast` / `br_on_cast_fail`, HOT block/if label-exit merge tracking with reachable fallthrough sources so agreeing exits still fold while bypassing exits keep final sets alive, identity-preserving refinement wrappers for raw `ref.as_non_null` / `ref.cast` / `ref.cast_desc_eq` so concrete-heap refined gets now retarget through straight-line and branch-merge shapes, programmatic lowered-instruction coverage for `ref.cast` / `ref.cast_desc_eq`, and an explicit conservative loop-exit skip regression where a post-loop const set survives an outer loop exit. Direct compare-pass stayed semantic-green at `.tmp/pass-fuzz-rse-rse002-hot-label-exits` (`6759/10000`, `0` mismatches, `20` Binaryen/tool command failures).
  - Remaining deliverables: replace the documented conservative loop-exit skips with fixed-point convergence where parity needs it, extend the same structured label start/end identities through the remaining HOT/control families beyond block/if and the raw GC conditional-branch lanes, and broaden `rse-gc.wast`-style type-refinement coverage beyond the reduced abs-heap plus concrete-heap `ref.as_non_null` / `ref.cast` / `ref.cast_desc_eq` wrapper fixtures.
  - Cleanup-slot classification: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/rse002-rse-vacuum-final --redundant-set-elimination --vacuum` remains exact-red at `defined=208 abs=225`, but the former `defined=0 abs=17` nested drop/nop debris and `defined=29 abs=46` empty-then/double-`eqz` control-shape gap are fixed. The current first diff is inherited from direct `--vacuum`: `.tmp/rse002-vacuum-baseline` has the same first differing function, and the focused Starshine `func-defined208-abs225` WAT/pretty files are byte-identical with and without RSE.
  - Tests: branch-join positives/negatives, raw block/GC-branch/loop-exit negatives plus HOT block/if label-exit safety and agreement coverage, broader `rse-gc.wast`-style type-refinement tests, direct compare-pass parity, and eventual late-tail preset replay.

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

#### Whole-command wall-time budget

- [WALL]001 - Cross-Pass Runtime Budget And Attribution
  - Deliverables: own whole-command Starshine-vs-Binaryen wall-time measurement outside individual pass parity slices; separate pass-local runtime, harness/tool startup, parse/emit, validation, HOT lift/lower, analysis cache, and artifact representation costs; maintain a prioritized list of cross-cutting runtime fixes without blocking pass correctness signoff on aggregate wall time.
  - Current status: direct pass slices may record timing evidence when available, but unresolved whole-command wall-time gaps should be filed here unless the root cause is clearly inside one pass implementation.

## Deferred Until MoonBit Threading Support

- [HOT]002 - Native Parallel Hot-Batch Queue
  - Status: deferred; MoonBit does not currently support the threading model Starshine needs for a safe native worker queue.
  - Resume when: MoonBit native threading is stable enough to run per-function optimizer workers with deterministic, byte-stable output and explicit runtime gating.
  - Deliverables: add a native-only worker queue over eligible defined functions for the hot batch payload (`ssa-nomerge -> dead-code-elimination -> vacuum -> optimize-instructions -> simplify-locals`); keep final output byte-stable and deterministic; gate behind an explicit native-only option.
  - Dependencies: [HOT]001 replay hardening must stay green.

## v0.2.0 Backlog

- [TOOL]001 - Self-Optimize Compare Normalization Symmetry
  - Goal: make the exact artifact helper stop reporting harmless raw/debug-only outer-block drift as a pass blocker.
  - Why deferred: the current `[TO]005` residual is not a Starshine optimizer bug and is not needed for v0.1.0.
  - Deliverables: either canonicalize Binaryen through the same strip-debug path before canonical-function comparison while preserving `binaryen.raw.wasm`, or teach the canonical-function fallback to ignore transparent unused-label void block wrappers.
  - Acceptance: the exact-slot artifact command no longer reports `defined=200 abs=217` solely because Binaryen raw `--debug` kept an outer block that symmetric normalization removes.

- [HOT]003 - Node-Package Worker Queue Port
  - Status: deferred behind [HOT]002 and future Node package rebuild work.
  - Deliverables: reuse the native hot-batch queue contract in the shipped Node package with `worker_threads`, one WasmGC module per worker, worker-local heap state, and stable-order serialized merge.
  - Dependencies: [HOT]002 native queue contract, worker-local function serialization hooks, and future Node package rebuild work.
