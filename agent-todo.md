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
- `redundant-set-elimination` / `[RSE]002`: accepted on 2026-05-10 for v0.1.0 direct-pass signoff after the CFG/value-flow slice added branch/default identities, raw/HOT label-exit coverage, branch-free loop fallthrough facts, strict-subtype refined `local.get` retargeting, GC wrapper and aggregate-accessor refinalization fixtures, raw `string.const` / `any.convert_extern` identities, conservative `try_table` fact barriers, and a narrow safe loop-backedge subset that removes default loop writes only when the written local is otherwise loop-invariant. Direct fuzz at `.tmp/pass-fuzz-rse-rse002-final-signoff` reported `6759/10000` compared, `0` mismatches, and `20` Binaryen/tool command failures; `--redundant-set-elimination --vacuum` at `.tmp/rse002-rse-vacuum-final-signoff3` stayed pass-local faster than Binaryen and returned to the classified inherited direct-`vacuum` first diff at `defined=208 abs=225`.
- `dae-optimizing` / `[DAE]001`: accepted on 2026-05-12 for the call-graph pruning and touched-function tracking slice after the case-000690 escaped self-call operand parameter fix and local-declaration frontier classification. The active module pass covers private direct-call dead scalar parameter removal, adjacent self-recursive forwarded-parameter pruning, dropped/uncalled no-param result removal, dead-suffix local-use suppression after root `unreachable`, removed-actual side-effect preservation including value-producing `if` operands, export / `ref.func` escape bailouts, unused simple function type pruning, and narrow Binaryen-observed self-call operand preservation families. Direct fuzz at `.tmp/pass-fuzz-dae-690-final2-1000` reported `998/1000` compared, `985` normalized matches, `13` mismatches, `0` validation failures, and `2` Binaryen/tool command failures; the follow-up classification in `docs/wiki/raw/research/0558-2026-05-12-dae-local-declaration-frontier.md` found all 13 `gen-valid` mismatches are local-declaration-only diffs, while the two command failures are unchanged `binaryen-rec-group-zero` parser/tool failures. Remaining meaningful DAE work moves to `[DAE]002` for artifact parity and the touched-function-filtered nested cleanup scheduler.

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

- No active v0.1.0 direct `redundant-set-elimination` blocker. Future work should target new semantic/validity mismatches, a proven need for full Binaryen-style loop fixed-point convergence beyond the landed safe loop-invariant default-write subset, broader official `rse-gc.wast` families not already covered by wrapper and aggregate-accessor fixtures, or separate late-tail preset scheduling. The `rse -> vacuum` exact replay remains red at the inherited direct-`vacuum` `defined=208 abs=225` representation frontier, not an RSE-specific blocker.

#### DAE - Dead Argument Elimination Optimizing

- [DAE]002 - Nested Post-Inlining Cleanup and Artifact Compare
  - Status: active. A narrow scheduler slice now runs `dead-code-elimination -> optimize-instructions -> local-cse -> pick-load-signs -> heap-store-optimization -> heap2local -> optimize-casts -> code-pushing -> simplify-locals -> code-folding -> precompute -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks -> reorder-locals -> vacuum` only on DAE-touched functions for small modules and keeps untouched functions unchanged; `local-cse` and `reorder-locals` use function-filtered raw/module adapters in this nested lane while direct public `local-cse` and `reorder-locals` remain module-shaped, the local-CSE adapter now emits `pass[local-cse]:func/start/done` trace lines so focused regressions can pin its place before `simplify-locals`, and the DAE scheduler itself now emits `pass[dae-optimizing]:nested-pass name=...` lines so tests can lock the guarded nested pass order without depending on incidental skip/start noise; `optimize-instructions` / `pick-load-signs` / `heap-store-optimization` / `heap2local` / `optimize-casts` / `code-pushing` / direct `precompute` / `code-folding` / `merge-blocks` / `remove-unused-brs` / `remove-unused-names` use the existing hot touched-function runner. The lane still only traces the upstream `precompute-propagate` prefix and is not the full Binaryen `optimizeAfterInlining` lane. Broad/large modules remain guarded because the earlier whole-module cleanup rewrote untouched functions and the current artifact lane is not yet performant enough for full nested replay. The post-scheduler artifact timeout was attributed to repeated DAE core call/dead-suffix scans before the nested marker and partly fixed with a single original call summary plus suffix-target aggregation; traced artifact replay now reaches the guarded nested cleanup skip, but artifact compare `.tmp/dae002-call-summary-artifact-final3` remains red at `defined=11 abs=28` and Starshine pass-local time is still slower than Binaryen (`6945.212ms` vs `927.876ms` in that replay, with local timing variance). A post-reorder-locals trace still skips the debug artifact nested lane at `touched=12`.
  - Deliverables remaining: implement the real `precompute-propagate` sibling or faithful nested prefix; replace the guarded small-module cleanup subset with a performant touched-function default pipeline, including more function-local equivalents for currently module-shaped local passes; compare `--dae-optimizing` output on the debug artifact after the runtime discrepancy is attributed; keep direct-pass semantic regressions visible if a broader fuzz run discovers a new non-local-declaration mismatch.
  - Current DAE002 evidence: `moon test src/passes` passes with the touched-only scheduler regressions; `.tmp/dae002-reorder-locals-200` reported `199/200` compared, `198` normalized matches, `1` mismatch, `0` validation failures, and `1` Binaryen/tool command failure; `.tmp/dae002-reorder-locals-1000` reported `998/1000` compared, `985` normalized matches, `13` mismatches, `0` validation failures, and `2` Binaryen/tool command failures, preserving the prior local-declaration-only frontier shape; a post-reorder-locals debug-artifact trace still skips nested cleanup at `touched=12`.
  - Deferred DAE families to consider during artifact work, but not to force from the saved direct 1000-case local-decl frontier alone: constant actual materialization, non-adjacent/localized forwarding and recursive cycles, GC param/result refinement, full call operand localization, and complete result-removal scheduling with dead internal call filtering.

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
