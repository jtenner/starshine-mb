# Agent Tasks

## Scope
- Keep only active unreleased work.
- Group work by release target.
- Use explicit slice ids so future agents can execute in dependency order.
- Move completed work and historical evidence to the relevant docs/wiki page, release notes, or git history.

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
- `bun scripts/pass-fuzz-compare.ts --pass <pass> --count 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-<pass>`; for DAE / `dae-optimizing` mixed-generator lanes, add `--normalize drop-consts --normalize unreachable-control-debris` and report `cleanupNormalizedMatchCount` separately from exact `normalizedMatchCount`.
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
- `inlining-optimizing` direct current-supported surface / `[INL]001`: accepted on 2026-05-13 for v0.1.0 direct-pass signoff on the currently implemented direct-call surface after the standard seed lane `.tmp/pass-fuzz-inlining-seed-0x5eed-after-four-func-frontier` reached `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, and `25` ignored Binaryen/tool failures, and the broadened seed lane `.tmp/pass-fuzz-inlining-seed-0x1eed-after-four-func-frontier2` reached `9978/10000` compared, `9978` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `22` ignored Binaryen/tool `binaryen-rec-group-zero` parse failures. Deferred unsupported direct-inliner breadth is split into dedicated `[INL]005` and `[INL]006` follow-up slices after `[INL]004` acceptance.
- `inlining-optimizing` nested useful-passes replay and artifact parity / `[INL]002`: accepted on 2026-05-16 for v0.1.0 after direct `--inlining-optimizing` stopped aborting on `tests/node/dist/starshine-debug-wasi.wasm`, the output validated, and the remaining canonical artifact mismatch was classified as representation/factoring drift rather than correctness or validation risk. The direct closeout compare `.tmp/pass-fuzz-inlining-optimizing-inl002-closeout-10000-keep` reported `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, and `25` ignored Binaryen/tool command failures. Latest artifact replay `.tmp/inl002-puresuffix-only-20260516-002821` exits `0`, validates with `wasm-tools`, produces about `1.7M` wasm versus Binaryen's about `2.2M`, and prints about `35M` WAT versus Binaryen's about `134M`; `wasm-tools objdump` reports Starshine's code section at `1,560,895` bytes versus Binaryen's `2,106,285`, and `wasm-opt --all-features --metrics` reports `762,965` total Starshine nodes versus `977,216` Binaryen nodes. Alignment still differs (`star_skips 119`, `skip_bytes 585064`, top Starshine-larger aligned delta about `25K`), but a targeted correctness triage found no validation error, no exported/start/table/ref.func semantic discrepancy, and no meaning-changing evidence: the top Starshine-larger examples are local/control representation drift, the large Binaryen-larger examples are Binaryen expansion/factoring drift, the 119 skipped Starshine helpers are mostly referenced helper factoring with 12 unreferenced cleanup candidates, and the 200-case smoke `.tmp/pass-fuzz-inlining-optimizing-inl002-puresuffix-200` preserved the known local-declaration/frontier mismatch shape with `0` validation failures. Exact Binaryen byte/WAT parity is not required for this slice; future partial-inlining and multi-result/tail-call/name repair breadth belongs under `[INL]005` and `[INL]006`, and wall-time work belongs under `[WALL]001` unless a pass-local correctness issue appears.
- plain `inlining` direct current-supported surface / `[INL]007`: accepted on 2026-05-13 for v0.1.0 direct-pass signoff after the plain path stopped borrowing optimizing-only helper-retention and cleanup branches. The standard seed lane `.tmp/pass-fuzz-inlining-seed-0x5eed-plain-moonrun-10k-full-after-plain-no-retain-prune` reached `9975/10000` compared, `9169` normalized matches, `806` locals-only representation mismatches, `0` structural mismatches after local-declaration stripping, `0` validation failures, and `25` ignored Binaryen/tool parse failures. The broadened seed lane `.tmp/pass-fuzz-inlining-seed-0x1eed-plain-moonrun-10k-full-after-plain-no-retain-prune` reached `9978/10000` compared, `9208` normalized matches, `770` locals-only representation mismatches, `0` structural mismatches after local-declaration stripping, `0` validation failures, and `22` ignored Binaryen/tool parse failures. The residual local-declaration/allocation drift is accepted as representation-only for direct signoff; heuristic reopen work requires a new semantic mismatch, while partial-inlining and repair breadth remain under `[INL]005` and `[INL]006`.
- `inlining` / `inlining-optimizing` heuristic policy / `[INL]003`: accepted on 2026-05-14 for the current supported direct inliner heuristic/action-filtering surface after the final repeated-work slice matched Binaryen's per-function iteration cap on `.tmp/inl003-b-recursive-cap10.wat`. Source/test audit covered `TrivialInstruction::{Shrinks,MayNotShrink}`, direct-call-only flexible `hasCalls`, combined-size filtering, deterministic same-wave race guards, and the `MaxIterationsForFunc = 5` repeated-work cap. Current signoff lanes after the cap fix: plain `.tmp/pass-fuzz-inlining-inl003-after-repeated-cap-plain-10000` reached `9975/10000` compared, `9169` normalized matches, `806` local-declaration-only mismatches, `0` structural mismatches after local-declaration stripping, `0` validation failures, and `25` ignored Binaryen/tool command failures; optimizing `.tmp/pass-fuzz-inlining-optimizing-inl003-after-repeated-cap-10000` reached `9975/10000` compared, `9975` matches, `0` mismatches, `0` validation failures, and `25` ignored Binaryen/tool command failures. Remaining broad inliner gaps stay under `[INL]005` partial splitting or `[INL]006` repair/tail-call/multivalue/name behavior; unsupported atomic-wrapper text/parser breadth is not an active `[INL]003` blocker without a Starshine-supported repro.
- no-inline policy controls and clone-survival helper / `[INL]004`: accepted on 2026-05-13 for the current no-inline policy surface. Starshine registers `no-inline`, `no-full-inline`, and `no-partial-inline`, parses CLI wildcard arguments such as `--no-inline=*maybe*`, lowers WAT defined/imported function identifiers into structured function names, stores matched policy as internal function annotations, honors full-inline suppression in the direct inliner, keeps function-level `@metadata.code.inline` distinct from no-inline policy, deduplicates repeated policy markers, leaves no-match policy passes unchanged, remaps policy annotations and function names across inlining helper compaction, drops stale function-scoped local/label names after body rewrites, and exposes `no_inline_copy_policy_annotations(...)` for future clone/copy helpers. Partial-inlining-specific no-inline behavior moves with `[INL]005`; no active `[INL]004` blocker remains.

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

Current checkpoints
- Direct semantic baseline: `[DAE]001` is accepted. Keep it closed unless a new semantic mismatch, validation failure, or escaped-call correctness issue is reproduced.
- `[DAE]005` raw debug-artifact frontier policy is closed as of 2026-05-26: the default helper still first-diffs at `defined=336 abs=353` from raw type-section/type-index representation drift (`type $10/$2` versus `type $9/$1`), but that drift is now a documented diagnostic boundary rather than active DAE body work. Keep default raw behavior and raw artifacts unchanged; use both-canonical diagnostics when body-frontier classification is needed.
- Both-canonical diagnostic helper: `scripts/self-optimize-compare.ts --canonicalize-binaryen-output --dae-optimizing` still first-diffs at `defined=509 abs=526`; the latest successful replay `.tmp/dae006-outer-block-suffix2-20260526` kept that frontier. Research notes `0576` through `0584` reduce the saved Func505 body from unknown/risky output-shape drift to representation-only control/local-carrier, branch-polarity, temp-local, and dropped-debris drift; `0585` adds a diagnostic-only canonical-function normalizer for that inspected Func505 parser-loop family; `0586` records the successor Func509 frontier as a semantic-safe, size-losing dead-return-suffix cleanup gap; `0588` adds a focused outer-block reduction/helper but does not close the artifact because the final cleanup hook still does not hit Func509; `0589` proves the printed `--print-func 526` post-return wrapper shape is already covered by the existing helper; `0590` proves the exact function-level value-block suffix cannot be stripped at the DAE final hook without invalid output; `0591` closes `[DAE]006` by documenting the remaining Func509 diff as a lowerer/diagnostic boundary rather than a DAE final-hook blocker.
- `[DAE]011` performance stabilization is closed as of 2026-05-26 for the current debug-artifact pass-local target. Earlier timing-only replay `.tmp/dae011-timing-only-20260526` reported an over-target `2785.602ms` Starshine pass versus `836.627ms` Binaryen pass; notes `0595` through `0600` attributed the hotspot to repeated selected dropped-result helper calls, dominated by whole-module dropped-call rewriting, whole-module `call; drop` cleanup, and undropped-call scans. Research note `0601` landed caller-filtered selected dropped-result rewriting using precomputed `direct_callers[callee]`; repeated timing-only replays now report `.tmp/dae011-caller-filtered-timing-20260526` at `1461.100ms` Starshine pass versus `864.852ms` Binaryen pass and `.tmp/dae011-caller-filtered-timing-repeat-20260526` at `1577.403ms` versus `851.431ms`, both inside the `Starshine <= 2x Binaryen` target. Both Starshine outputs validate with `wasm-opt --all-features` with only the existing large-local-count VM warning. The 10k compare refresh at `.tmp/pass-fuzz-dae011-caller-filtered-20260526-full` reproduced the accepted `[DAE]010` counts (`9975/10000` compared, `6078` normalized matches, `3897` known gen-valid raw-cleanup mismatches, `0` validation failures, `25` Binaryen/tool command failures). Reopen DAE performance work only for a new measured DAE-owned regression, fuzz/runtime cliff, or preset-integration timing need.
- `[DAE]002` touched nested cleanup scheduler completion is closed as of 2026-05-26 by research note `0602` for the current v0.1.0 scheduler boundary. The guarded touched-only lane has order and touched-function coverage, keeps the `precompute-propagate` prefix intent through the private `precompute-propagate-prefix` helper, and uses documented function-filtered adapters for module-shaped cleanup passes. Later evidence moved the leading both-canonical artifact diff to the closed `[DAE]006` Func509 lowerer/diagnostic boundary rather than a scheduler miss, while `[DAE]011` restored pass-local artifact timing to the `Starshine <= 2x Binaryen` target. This does not claim full Binaryen default-function-pipeline byte/shape parity or a public upstream `precompute-propagate` port; reopen scheduler work only with a new artifact/fuzz mismatch or preset-integration need attributed to nested cleanup itself.
- `[DAE]013` preset / ordered-neighborhood integration is closed as of 2026-05-26 by research note `0603`: `dae-optimizing` remains direct-pass-only for v0.1.0 under `dae-optimizing` and `dead-argument-elimination-optimizing`, and public `optimize` / `shrink` presets intentionally skip it until new ordered-prefix or artifact evidence proves default-preset safety and runtime.
- `[DAE]003` constant-actual and unread-parameter generalization is closed as of 2026-05-26 by research note `0661` for the current v0.1.0 surface. Research notes `0627`, `0636`, `0638` through `0660`, and `0661` cover the supported exact-literal, unread-param, non-adjacent local carrier, wrapper-chain, conservative recursive/self/escaped, structured-carrier, immutable-global, and starvation surfaces. The DAE003 closeout replay `.tmp/pass-fuzz-dae003i-closeout-20260526` reported `45/10000` compared, `26` normalized matches, `19` accepted raw-cleanup mismatches, `0` validation failures, and `1` Binaryen/tool command failure; the debug-artifact timing/validation replay `.tmp/dae003i-artifact-timing-20260526` stayed within the pass-local target (`1721.182ms` Starshine versus `902.489ms` Binaryen) and validated with only the existing large-local-count VM warning. No known current frontier is attributed to missed safe constant/unread materialization; remaining DAE work is `[DAE]004` dropped-result scheduling/fallback closure.
- `[DAE]004` wider mid-size fact-driven dropped-result batching advanced on 2026-05-26 by research notes `0604` through `0637`: the bounded fact-driven candidate queue now runs ascending for modules up to `4096` defined functions before the handpicked selected-def fallback, still using current direct-call facts and the caller-filtered result-removal helper. The large-module descending lane stays capped at eight productive candidates on the debug artifact, while the narrow `4096 < defined <= 4608` regression band reaches fourteen productive attempts. Research note `0628` closes `[DAE004-A]` by tracing the current artifact fallback inventory: the handpicked list still changes `298`, `299`, `427`, `445`, `459`, `472`, `476`, `3566`, `3732`, `3814`, `3834`, `4106`, `4229`, `4232`, `503`, `4240`, `4241`, `4242`, and `4249`; `3799` was the only listed dropped-result fallback entry not observed as productive in that trace, note `0662` retires it with a white-box guard, note `0663` syncs the black-box selected mid-prefix fixture list so it no longer advertises `3799` as active selected fallback coverage, and note `0671` removes `503` after validating it no longer needs handpicked fallback coverage. Research note `0629` closes `[DAE004-B]` by classifying those still-productive entries as blocked first by descending large-module ordering plus the eight-productive-attempt cap, not by stale facts, mixed dropped/undropped calls, dead-suffix repair, signature repair, or type-liveness in the latest trace. Research notes `0664` and `0665` close `[DAE004-D1]` and `[DAE004-D2]`: selected fallback trace metadata is available, and the remaining productive entries are grouped into one-call singleton, tiny multi-caller, mid-prefix dense, high-index bridge, and late-cluster families. Research notes `0666` and `0667` remove singleton `445` from the selected fallback and validate the debug-artifact output/timing/direct-compare refresh; note `0668` removes singleton `3834` and validates it with artifact timing, wasm validation, and a direct compare refresh; note `0669` removes singleton `4106` and validates it with artifact timing, wasm validation, direct compare refresh, and commit-ready Moon validation. Research note `0670` removes singleton `4249` and validates it with artifact timing, wasm validation, and a direct compare refresh. Research note `0671` removes `503` as the first non-singleton fallback retirement with artifact timing, wasm validation, and a direct compare refresh. Research note `0672` removes `4229` after proving the ordinary fact/core path already covers the broad-large fixture shape, with artifact timing, wasm validation, and direct compare refresh. Research note `0674` removes `298` with the same broad-large fixture/fact-core proof, artifact timing, wasm validation, and direct compare refresh. Research note `0675` removes `427` under the same broad-large fixture/fact-core proof with artifact timing, wasm validation, and direct compare refresh. Research note `0676` removes `299` from the selected fallback loop/list after a test-first fallback guard, artifact timing, wasm validation, and a direct compare refresh. Research note `0677` removes `459` from the selected fallback loop/list after a test-first fallback guard and direct compare refresh. Research note `0678` removes `472` from the selected fallback loop/list after a test-first fallback guard and direct compare refresh. Research note `0679` removes `476` from the selected fallback loop/list after a test-first fallback guard and direct compare refresh. Research note `0680` removes `3566` from the selected fallback loop/list after a test-first fallback guard and 1000-case direct compare refresh. Research note `0681` removes `3732` from the selected fallback list after a test-first fallback guard and 1000-case direct compare refresh. Research note `0682` removes `3814` from the selected fallback list after a test-first fallback guard and 1000-case direct compare refresh. Research notes `0683`, `0684`, `0685`, and `0686` remove `4232`, `4240`, `4241`, and final late-cluster fallback `4242`; note `0687` closes `[DAE004-H]`/`[DAE004-I]` and marks DAE004 complete for the current v0.1.0 surface. Research note `0630` adds a focused large-module regression guard proving the current implementation still removes a lower-index fact-discovered dropped-result target when eight higher targets also consume the large descending budget. Research note `0631` closes `[DAE004-C]` as a design slice; note `0632` adds a white-box bucketed broad-large attempt-order contract, but keeps the active broad-large descending scheduler unchanged because a trial active switch exceeded the DAE011 `Starshine <= 2x Binaryen` pass-local target. Research notes `0633` and `0634` close `[DAE004-E]`: live mixed dropped/undropped callers preserve the result, while root-unreachable suffix calls are classified as dead observations that intentionally do not block result removal. Research note `0635` closes `[DAE004-F]` with refreshed live-prefix dead-suffix `call; drop` repair coverage after result removal. Research note `0637` closes `[DAE004-G]` with type-liveness coverage for table/global refs plus typed element, local, and ref-op references affected by simple function type pruning. The handpicked selected-def fallback list is now empty for the current DAE004 surface after note `0686`; research note `0687` closes `[DAE004-H]`, `[DAE004-I]`, and `[DAE]004` with artifact tracing, validation, timing, 10k direct compare, and mismatch classification proving no remaining dropped-result scheduling/fallback gap is known.
- Latest docs/backlog closure validation for `[DAE]006` on 2026-05-26: `git diff --check`, `moon info`, `moon fmt`, and `moon test` passed; `moon info` still reports existing unused DAE helper warnings. Latest pass-behavior validation before commit `0196531d` remains the script compare tests, `wasm-opt --all-features .tmp/dae-func447-normalized-artifact/starshine.wasm`, `moon info`, `moon fmt`, and `moon test`.
- `[DAE]007` compare-tool normalization hygiene is closed for the current diagnostic helper: the canonical-function fallback now uses an explicit ordered normalizer list instead of a deeply nested call chain, with a diagnostic-only comment at the artifact-family cleanup point and unchanged fixture coverage.
- `[DAE]010` direct fuzz refresh is closed for the latest pass logic as of 2026-05-25: `.tmp/pass-fuzz-dae-optimizing-dae010-20260525-full2` compared `9975/10000`, with `6078` normalized matches, `3897` normalized mismatches, `0` validation failures, and `25` Binaryen/tool command failures (`22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, `1` `binaryen-invalid-tag-index`). Agent classification: all mismatches are `gen-valid` size-winning semantic-safe raw-cleanup drift from Starshine stripping the generator's leading dropped pure/nontrapping constant debris while Binaryen preserves it; all `wasm-smith` cases that Binaryen accepted matched.
- `[DAE]008` Func237 historical frontier closure is closed as of 2026-05-25: the strategy now records landed Func237 selected local/control slices through `.tmp/dae-func237-common-branch-final-artifact`, the known reverted/deferred probes from research note `0570`, and the superseding direct debug-artifact frontiers (`defined=242`, then later `defined=505` in both-canonical diagnostics). Func237 is no longer an active leading blocker; reopen only with a new current-frontier Func237 repro.
- `[DAE]014` latest source/index sync is closed as of 2026-05-26: `docs/wiki/binaryen/passes/dae-optimizing/index.md` and `starshine-strategy.md` now link research notes `0576` through `0591` and record the current Func509 diagnostic frontier as a lowerer/diagnostic boundary rather than a DAE final-hook blocker. The wiki catalogs and `starshine-port-readiness-and-validation.md` were also refreshed so future agents no longer see stale pre-port/boundary-only wording for active `dae-optimizing`.
- `[DAE]012` local-subtyping / refinalization follow-up is closed as of 2026-05-26 for the current validated surface: focused regressions already cover write-site, tee-driven, optimize-casts-adjacent, `ref.as_non_null(local.get ...)`, loop-carried, block-wrapped `try_table`, lib-constructed `call_ref`, and dominated/undominated sibling-join ref-local families; the `--dae-optimizing --local-subtyping` 1000-case combo reproduced only the known DAE local-declaration mismatch set with `0` validation failures. Reopen only for a new validated DAE/local-subtyping semantic or validation repro.
- `[DAE]009` raw cleanup policy is closed as of 2026-05-26 as a docs/backlog recovery slice. The strategy now states the active policy explicitly: correctness first; useful pure/nontrapping cleanup is allowed and preferred when semantically proved; Binaryen-shape debris is preserved only for documented diagnostic/frontier needs; possibly trapping/effectful operand stacks stay live; future raw-cleanup behavior changes need focused tests plus size/mismatch evidence.
- Important classification: Func408/abs425 raw body is closed. With both sides passed through the same strip-debug writer, Func408 matches after type-id stripping; prior Func408 drift was compare-layer representation, not a DAE raw rewrite target.

Execution rules for all DAE slices
- Use pass-targeted commands first: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing` and/or `--canonicalize-binaryen-output`.
- For Starshine pass logic changes, write or update a focused Moon test first where practical, confirm failure, then implement.
- For compare-tool-only changes, add a focused script fixture first and confirm failure.
- Every artifact output must validate with `wasm-opt --all-features` unless the command failed before producing wasm.
- Do not classify fuzz mismatches as semantic-safe without inspected transform contract, replay evidence, or diff-family analysis.
- Keep pass-local performance visible; target `Starshine pass <= 2x Binaryen pass`.
- Keep `docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md`, `docs/wiki/log.md`, and this backlog current when a frontier, classification, or acceptance state changes.

- `[DAE]002` touched nested cleanup scheduler completion is closed as of 2026-05-26. Future scheduler work should reopen only with a new artifact/fuzz mismatch or preset-integration need attributed to nested cleanup itself, and should keep the existing trace-order, touched-only, artifact validation, and pass-local timing evidence requirements.

- [DAE]003 - Constant-Actual and Unread-Parameter Generalization
  - Status: closed as of 2026-05-26 for the current v0.1.0 surface by research note `0661`.
  - Goal: broaden the safe exact-literal/unread-parameter machinery beyond the current selected artifact lanes.
  - Why: current coverage includes private direct callees where every caller passes the same exact literal, selected scalar memory-load siblings, typed single-result block wrappers, immutable `global.get` for selected Func330/def313, selected Func3736/Func4117/Func4134/Func4303/Func4320, and many selected debug-artifact defs; broader candidate discovery remains incomplete.
  - Deliverables:
    - [x] Generalize the low-forwarded-const exact-literal revisit beyond the old first-`64` boundary for mid-size modules (`defined <= 4096`), covered by `dae-optimizing materializes high fact-discovered exact literal outside selected list` on 2026-05-26; note `0606` records the test-first failure, quick signoff, and 10k direct compare refresh.
    - [x] `[DAE003-A]` Inventory the currently supported constant-actual/unread-parameter shapes, mapping each family to source helpers, focused tests, and research notes so future work does not duplicate closed selected lanes; note `0627` records the generic exact-literal/unread helpers, selected artifact lanes, focused test/trace map, and remaining DAE003 gaps.
    - [x] `[DAE003-B]` Reproduce and classify the current artifact/frontier misses attributable to constant-actual or unread-parameter materialization; note `0636` closes this as a classification slice: current leading misses are raw type-section/type-index diagnostic drift, the closed Func509 lowerer/diagnostic boundary, `[DAE]004` dropped-result scheduling/fallback gaps, or accepted raw-cleanup drift, not missed safe constant/unread materialization.
    - [x] `[DAE003-C]` Generalize non-adjacent forwarding where a constant or unread value flows through locals/wrappers before reaching the target parameter; add positive and negative focused tests. Research note `0639` covers the first positive high-module caller-local shape `i32.const 77; local.set 0; local.get 0; call $target` with a test-first failure and a narrow same-local carrier recognizer accepting one prior constant-producing `local.set` with no earlier same-local read, tee, or multiple write before the call actual. Research note `0640` adds negative guards proving `local.tee` prefixes and multiple same-local writes preserve the target parameter. Research note `0641` adds the explicit earlier same-local read / multiple-get negative guard (`const; local.set; local.get; drop; local.get; call`), which already passes on current code and confirms the recognizer preserves the target parameter. Research note `0642` adds trapping and effectful producer guards (`i32.div_s; local.set; local.get; call` and `call $effect; local.set; local.get; call`), both preserving the target parameter after fixture-index correction. Research note `0643` closes the self/escaped-cycle policy for the current conservative local-carrier subset by preserving params for non-adjacent self-recursive local-carrier cycles and `ref.func` escaped callees. Research note `0645` closes the current conservative non-structured local-carrier surface with focused pass-suite validation plus direct-DAE compare evidence; structured carriers continue under `[DAE003-F]`. Research note `0648` closes `[DAE003-G]` by extending immutable-global materialization to bounded mid-size fact-discovered callees outside the old selected Func313 lane while preserving mutable globals.
    - [x] `[DAE003-D]` Generalize localized forwarding chains such as `A -> B -> C`, including starvation cases where a later candidate appears only after earlier productive rewrites; note `0638` closes this for the current direct private parameter-local `local.get` wrapper-chain surface using the existing trace-pinned `dae-optimizing can chase a later exact-literal forwarding-wrapper chain` regression.
    - [x] `[DAE003-E]` Define and test the safe subset for recursive/self-recursive constant or unread-parameter cycles, preserving escaped-call and case-000690-style self-call operand guards; note `0643` closes this for the current conservative non-adjacent local-carrier surface by preserving parameters for self-recursive local-carrier cycles and `ref.func` escaped callees, while leaving broader recursive-cycle materialization as a future behavior-widening slice.
    - [x] `[DAE003-F]` Support more structured carriers for constants/unread params: block, loop, if, try/try_table, and typed wrapper shapes, with trap/effect/control negative tests. Research note `0644` covers the first typed single-instruction `block` carrier positive and the original `loop` negative guard; note `0646` adds conservative multi-instruction block and equal-arm `if` carrier negative guards; note `0647` accepts the narrow equal-arm `if` carrier when both arms contain the same single materializable constant; note `0649` accepts the narrow branch-free single-leaf `loop` carrier; note `0650` accepts the narrow pure dropped-prefix multi-instruction block carrier (`materializable const; drop; ...; materializable leaf`) while keeping computed multi-instruction blocks conservative; note `0651` accepts a narrow typed outer-block plus single-leaf `try_table` carrier; note `0652` accepts equal-arm `if` carriers whose arms have only dropped materializable constants before the same final materializable leaf; note `0653` accepts a narrow `try_table` body with only dropped materializable constants before the final materializable leaf; note `0654` adds a throwing-prefix `try_table` negative guard that preserves the target parameter when control transfer means the trailing constant is not the guaranteed call actual; note `0655` accepts equal-arm `if` carriers whose arms resolve through the existing structured-carrier recognizer to the same nested single-leaf typed block constant; note `0656` accepts branch-free `loop` carriers with dropped materializable constant prefixes before the final materializable leaf; note `0657` accepts the narrow branch-free `loop` carrier whose single body instruction is itself a typed block carrier; note `0658` accepts dropped-prefix `block` carriers whose dropped prefix and final leaf are themselves recognized structured materializable constant carriers, sharing that recursive resolver with multi-instruction `loop` and `try_table` dropped-prefix carriers while preserving computed/trapping/effectful/control-sensitive guards. Research note `0659` closes `[DAE003-F]` for the v0.1.0 surface by treating branchy/computed multi-instruction positives, broader throwing/control-sensitive try/try_table positives, broader unequal/control-sensitive `if` policy, and additional structured-carrier breadth as deferred unless a new artifact/fuzz frontier or semantic/validation repro attributes a miss to those families.
    - [x] `[DAE003-G]` Broaden safe immutable global/materialized-constant support beyond the selected lanes, including tests for referenced globals and type/liveness guardrails. Research note `0648` closes this for the current v0.1.0 surface by adding a bounded `defined <= 4096` immutable-global revisit outside the selected Func313 lane plus a mutable-global negative guard; large-artifact timing-sensitive paths stay on the existing selected policy unless new evidence attributes a frontier to immutable global materialization.
    - [x] `[DAE003-H]` Revisit the fixed core-iteration budget/starvation problem from research note `0563` and later exact-literal starvation regressions; note `0660` closes this as a regression-guard/evidence slice by proving a mid-size module with 73 earlier productive exact-literal rewrites still reaches a later target under the existing bounded low-revisit lane, without raising the core fixed-loop budget or broadening large-artifact scheduling.
    - [x] `[DAE003-I]` Close out DAE003 with artifact replay and direct fuzz evidence showing no known frontier is attributable to missed safe constant/unread-parameter materialization; note `0661` records direct fuzz `.tmp/pass-fuzz-dae003i-closeout-20260526` (`45/10000` compared, `26` normalized matches, `19` accepted raw-cleanup mismatches, `0` validation failures, `1` Binaryen/tool command failure), artifact timing/validation `.tmp/dae003i-artifact-timing-20260526` (`1721.182ms` Starshine pass versus `902.489ms` Binaryen pass, valid output), and classifies remaining known frontiers as `[DAE]005` diagnostic type drift, `[DAE]006` lowerer/diagnostic drift, or `[DAE]004` dropped-result scheduling/fallback work.
  - Suggested tests:
    - Reduced starvation cases where the candidate appears after more than eight productive core rewrites.
    - Same-caller multi-call and forwarded-wrapper-chain regressions.
    - Artifact census/replay for `moonbit.check_range`-style literal carriers.
    - Positive/negative structured-carrier, recursive/self-recursive, immutable-global, and escape/ref.func/table/global/local type-reference cases.
  - Exit criteria: no known artifact frontier is attributable to missed safe constant/unread-parameter materialization, and direct fuzz has no new semantic or validation regression.

- [DAE]004 - Selected Result-Removal Broadening
  - Status: closed as of 2026-05-27 by research note `0687` for the current v0.1.0 surface.
  - Goal: convert the selected dropped-result lane into a principled, broader result-removal scheduler.
  - Why: selected defs now include artifact families such as `3566`, `3732`, `3814`, `4232`, `4240`, `4241`, and `4242`; Func445 and Func459/3732/472/476/4106 proved the both-canonical frontier can still expose real result/signature gaps before several entries were retired.
  - Deliverables:
    - [x] Add a bounded small-module fact-driven candidate queue for private direct callees whose current direct calls all drop the single result, outside the artifact handpicked selected-def list; covered by `dae-optimizing removes fact-discovered dropped callee result outside selected list` on 2026-05-26. Direct 10k compare `.tmp/pass-fuzz-dae004-fact-dropped-20260526-full` reproduced the accepted DAE010/DAE011 counts with `0` validation failures.
    - [x] Batch mid-size modules (`defined <= 2048`) through the bounded fact-driven candidate queue before the handpicked selected-def fallback, covered by `dae-optimizing removes high fact-discovered dropped callee result outside selected list` on 2026-05-26; note `0604` records the test-first failure, rejected unguarded artifact experiment, focused pass-suite validation, and 10k compare refresh.
    - [x] Widen the same guarded fact-driven queue to `defined <= 4096`, covered by moving `dae-optimizing removes high fact-discovered dropped callee result outside selected list` to target defined function `3000` on 2026-05-26; note `0605` records the test-first failure, quick signoff, and 10k direct compare refresh.
    - [x] Add a candidate-ordering regression for large modules with many low dropped-result candidates and one high dropped-result callee, then implement the first deterministic ordered large-module scheduler step; note `0608` covers `dae-optimizing reaches high dropped-result callee after low candidate budget`, the one-attempt descending lane for `4096 < defined <= 8192`, debug-artifact validation/timing, and the 10k direct compare refresh.
    - [x] Add a second large-module candidate-ordering regression with two high dropped-result callees after many low candidates, then raise the bounded descending scheduler to two productive attempts; note `0609` covers `dae-optimizing reaches two high dropped-result callees after low candidate budget`, debug-artifact validation/timing, and the 10k direct compare refresh.
    - [x] Add a third large-module candidate-ordering regression with three high dropped-result callees after many low candidates, then raise the bounded descending scheduler to three productive attempts; note `0610` covers `dae-optimizing reaches three high dropped-result callees after low candidate budget` and the test-first failure where the third high callee still reported one result.
    - [x] Add a fourth large-module candidate-ordering regression with four high dropped-result callees after many low candidates, then raise the bounded descending scheduler to four productive attempts; note `0611` covers `dae-optimizing reaches four high dropped-result callees after low candidate budget`, the test-first failure where the fourth high callee still reported one result, debug-artifact validation/timing, and the 10k direct compare refresh.
    - [x] Add a fifth large-module candidate-ordering regression with five high dropped-result callees after many low candidates, then raise the bounded descending scheduler to five productive attempts; note `0612` covers `dae-optimizing reaches five high dropped-result callees after low candidate budget`, the test-first failure where the fifth high callee still reported one result, debug-artifact validation/timing, and the 10k direct compare refresh.
    - [x] Add a sixth large-module candidate-ordering regression with six high dropped-result callees after many low candidates, then raise the bounded descending scheduler to six productive attempts; note `0613` covers `dae-optimizing reaches six high dropped-result callees after low candidate budget`, the test-first failure where the sixth high callee still reported one result, repeat debug-artifact validation/timing, and the 10k direct compare refresh.
    - [x] Add a seventh large-module candidate-ordering regression with seven high dropped-result callees after many low candidates, then raise the bounded descending scheduler to seven productive attempts; note `0614` covers `dae-optimizing reaches seven high dropped-result callees after low candidate budget` and the test-first failure where the seventh high callee still reported one result.
    - [x] Add an eighth large-module candidate-ordering regression with eight high dropped-result callees after many low candidates, then raise the bounded descending scheduler to eight productive attempts; note `0615` covers `dae-optimizing reaches eight high dropped-result callees after low candidate budget` and the test-first failure where the eighth high callee still reported one result.
    - [x] Retry the ninth candidate scheduler change after unblocking the native pass-suite crash; note `0621` covers the guarded `4096 < defined <= 4608` ninth-candidate band, the test-first failure where the ninth high callee still reported one result, native pass-suite validation, debug-artifact timing within the `<= 2x` pass-local target, and the 10k direct compare refresh with accepted DAE010/DAE011 counts.
    - [x] Advance the same guarded `4096 < defined <= 4608` scheduler band to ten, eleven, twelve, thirteen, and fourteen productive descending attempts; notes `0622`, `0623`, `0624`, `0625`, and `0626` cover the focused test-first failures where the tenth through fourteenth high callees still reported one result, while larger artifact modules remain capped at `8`.
    - [x] `[DAE004-A]` Inventory the current large-artifact handpicked selected-def fallback list and record which entries still produce changes on the latest artifact; note `0628` records the source list, latest trace, and `3799` as the only currently unobserved selected dropped-result entry. Retire stale entries only with artifact validation.
    - [x] `[DAE004-B]` For every still-productive fallback entry, classify why the fact-driven scheduler did not cover it: note `0629` records the latest trace where the large-module fact lane spent its eight productive descending attempts on `4651..4644`, then the still-productive fallback entries `298`, `299`, `427`, `445`, `459`, `472`, `476`, `3566`, `3732`, `3814`, `3834`, `4106`, `4229`, `4232`, `503`, `4240`, `4241`, `4242`, and `4249` remained blocked first by ordering plus iteration cap rather than stale facts, mixed dropped/undropped calls, dead-suffix handling, signature repair, or type-liveness in that trace.
    - [x] `[DAE004-C]` Design a runtime-neutral batching/worklist approach for large modules before raising broad artifact caps; note `0631` specifies a bucketed, caller-filtered, fact-refreshing worklist that preserves high-candidate reach, selected-fallback-neighborhood coverage, and low-candidate guards without raising the broad `4608 < defined <= 8192` productive cap. Do not repeat the rejected naive `defined <= 8192` ascending-queue widening from research note `0607`.
    - [x] `[DAE004-D]` Incrementally remove or replace selected fallback entries by family.
      - Context: note `0632` added a bucketed broad-large attempt-order collector and a white-box ordering regression, but the active broad-large switch was reverted after timing-only artifact replays exceeded the DAE011 pass-local target (`1871.393ms` vs `892.572ms`, repeat `1818.466ms` vs `875.108ms`). Note `0662` removes stale unobserved fallback entry `3799` with a white-box guard; note `0663` syncs the black-box fixture inventory.
      - [x] `[DAE004-D1]` Add trace metadata for selected fallback productivity: note `0664` adds `pass[dae-optimizing]:selected-dropped-result-candidate ...` trace lines before each handpicked selected dropped-result fallback attempt, recording callee def/absolute index, caller defs, current direct/dropped/live call facts, dead-suffix placeholder, fact source, bucket membership, and fact-attempt placeholder without changing optimizer behavior.
      - [x] `[DAE004-D2]` Group remaining productive entries into removable families before behavior changes. Note `0665` uses fresh selected-fallback trace metadata from the debug artifact to classify the remaining productive entries into one-call singleton, tiny multi-caller, mid-prefix dense, high-index bridge, and late-cluster families. Every traced candidate still had `direct == dropped` and `live=0`; grouping is therefore about scheduler reach/order and family shape, not mixed live callers.
      - [x] `[DAE004-D3]` Pick one smallest family and write a focused failing regression that proves the result-removal path should cover it without the handpicked fallback entry. Note `0666` starts with singleton `445`; the broad-large fixture initially failed because `445` still appeared in selected-fallback trace metadata even though the ordinary core had already removed the result.
      - [x] `[DAE004-D4]` Implement the first narrow family-specific removal behind existing safety guards: note `0666` removes only `445` from the selected dropped-result fallback list, without raising the broad-large cap or enabling the rejected broad bucketed switch. More singleton/family removals remain under `[DAE004-D7]`.
      - [x] `[DAE004-D5]` Validate that family removal on the debug artifact: note `0667` records `.tmp/dae004-d5-singleton445-validation-20260526` (`1575.557ms` Starshine pass versus `850.194ms` Binaryen pass, within `Starshine <= 2x Binaryen`), `wasm-opt --all-features` output validation with only the existing large-local-count VM warning, and direct compare refresh `.tmp/pass-fuzz-dae004-d5-singleton445-20260526` (`45/10000` compared before the known max-failure threshold, `26` normalized matches, `19` accepted raw-cleanup mismatches, `0` validation failures, `1` Binaryen/tool command failure: `binaryen-rec-group-zero`).
      - [x] `[DAE004-D6]` Delete or gate the covered fallback entry/family only after `[DAE004-D5]` passes, then update the selected fallback inventory, fixtures, research note, wiki log, and this backlog. Singleton `445` was removed in note `0666`; note `0667` validates that removal and records the post-removal docs/backlog update.
      - [x] `[DAE004-D7]` Repeat `[DAE004-D3]` through `[DAE004-D6]` until no productive selected-only family remains or a documented blocker is promoted to `[DAE004-H]` / `[DAE004-I]` closeout evidence. Singleton `4106` was removed and validated by note `0669`; singleton `4249` was removed and validated by note `0670`; fallback `503` was removed and validated by note `0671`; fallback `4229` was removed and validated by note `0672`; fallback `298` was removed and validated by note `0674`; fallback `427` was removed and validated by note `0675`; fallback `299` was removed and validated by note `0676`; fallback `459` was removed by note `0677`; fallback `472` was removed by note `0678`; fallback `476` was removed by note `0679`; fallback `3566` was removed by note `0680`; fallback `3732` was removed by note `0681`; fallback `3814` was removed by note `0682`; fallback `4232` was removed by note `0683`; fallback `4240` was removed by note `0684`; fallback `4241` was removed by note `0685`; final late-cluster fallback `4242` was removed by note `0686`. Remaining work should proceed to `[DAE004-H]` fallback-removal evidence and `[DAE004-I]` closeout rather than more D7 fallback-entry removals.
    - [x] `[DAE004-E]` Add explicit mixed dropped/undropped call guard tests and classify dead-suffix policy. Live mixed dropped/undropped direct-call coverage was added on 2026-05-26 by research note `0633` (`dae-optimizing preserves fact-discovered results with mixed dropped and live callers`) and already passes without behavior changes. Research note `0634` closes the undropped-dead-suffix portion as a classification: root-unreachable suffix calls are dead observations under the accepted DAE cleanup policy and intentionally do not block result removal; changing that would be a new policy-changing behavior slice with focused tests plus artifact/fuzz evidence.
    - [x] `[DAE004-F]` Add and/or refresh dead-suffix `call; drop` repair coverage after a callee becomes void, including unreachable suffixes that are safe to rewrite; note `0635` adds a live-prefix regression proving DAE preserves the live side-effecting prefix while removing the dead-suffix `call; drop` after result removal.
    - [x] `[DAE004-G]` Add type-liveness coverage for simple function types referenced outside the function section, including table, global, element, local, and ref heap-type references affected by result/function type rewriting; note `0637` adds typed element, local-declaration, and `ref.null` coverage alongside the existing table/global regression, with input/output validation and no optimizer behavior change.
    - [x] `[DAE004-H]` Remove the large-artifact handpicked selected-def fallback only when artifact/fuzz evidence proves the fact-driven queue covers the remaining result-removal frontier without reopening the DAE011 pass-local runtime cliff. Closed by note `0687`.
      - [x] `[DAE004-H1]` Prove the implementation fallback list is empty or fully gated off for the debug artifact while focused formerly-selected fixtures still pass.
      - [x] `[DAE004-H2]` Run default and both-canonical debug-artifact DAE replays, validate Starshine output with `wasm-opt --all-features`, and record first-diff movement or unchanged accepted diagnostic boundaries.
      - [x] `[DAE004-H3]` Run repeated timing-only debug-artifact replays and require pass-local `Starshine <= 2x Binaryen`; if timing regresses, keep the fallback or gate the new path and file the measured blocker.
      - [x] `[DAE004-H4]` Run a direct compare refresh for `--dae-optimizing`; classify any mismatches by agent judgment and keep accepted raw-cleanup drift separate from true dropped-result scheduling gaps.
      - [x] `[DAE004-H5]` Remove obsolete fallback-specific tests or convert them to fact-driven/bucketed coverage, then update docs/wiki/log/backlog with the final fallback-removal evidence.
    - [x] `[DAE004-I]` Close out DAE004 with artifact replay, direct fuzz evidence, and mismatch classification proving no remaining artifact or fuzz mismatch is a true dropped-result scheduling gap. Closed by note `0687`.
      - [x] `[DAE004-I1]` Re-run direct `--dae-optimizing` artifact comparison with default raw output and both-canonical diagnostics; record first diff, validation, size, and pass-local timing.
      - [x] `[DAE004-I2]` Run standard 10k direct compare with the DAE compare normalizer: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae004-closeout`; report exact `normalizedMatchCount`, `cleanupNormalizedMatchCount`, remaining mismatches, and command-failure classes separately.
      - [x] `[DAE004-I3]` Replay any saved failure dirs or new mismatch samples and classify each family as semantic-safe/size-winning, representation-only, size-losing, unknown/risky, validation failure, tool/Binaryen failure, or true semantic mismatch with rationale.
      - [x] `[DAE004-I4]` Confirm no remaining mismatch or artifact frontier is attributable to dropped-result scheduling/fallback coverage; if one remains, reopen the appropriate `[DAE004-D*]` family slice instead of closing DAE004.
      - [x] `[DAE004-I5]` Update `docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md`, `docs/wiki/log.md`, research notes, and this backlog with closeout evidence, commands, counts, timing, and mismatch classifications.
      - [x] `[DAE004-I6]` Run commit-ready validation (`moon info`, `moon fmt`, `moon test`; prefer `bun validate` if time permits), commit the closeout, then re-check for remaining DAE backlog before disabling the DAE recovery cron.
  - Notes for DAE004 subtasks:
    - Post-`0608` trace showed the new descending lane removes high candidate `4651`, then the selected fallback still removes `298`, `299`, `427`, `445`, `459`, `472`, `476`, `3566`, `3732`, `3814`, `3834`, `4106`, `4229`, `4232`, `503`, `4240`, `4241`, `4242`, and `4249`; stale unobserved entry `3799` was removed by note `0662`; singleton `445` was removed by note `0666` then validated by note `0667`; singleton `3834` was removed and validated by note `0668`; singleton `4106` was removed and validated by note `0669`; singleton `4249` was removed and validated by note `0670`; fallback `503` was removed and validated by note `0671`; fallback `4229` was removed and validated by note `0672`; fallback `298` was removed and validated by note `0674`; fallback `427` was removed and validated by note `0675`; fallback `299` was removed and validated by note `0676`; fallback `459` was removed by note `0677`; fallback `472` was removed by note `0678`; fallback `476` was removed by note `0679`; fallback `3566` was removed by note `0680`; fallback `3732` was removed by note `0681`; fallback `3814` was removed by note `0682`; fallback `4232` was removed by note `0683`; fallback `4240` was removed by note `0684`; fallback `4241` was removed by note `0685`; final fallback `4242` was removed by note `0686`. The selected fallback list is now empty for the current DAE004 surface; note `0687` ran `[DAE004-H]`/`[DAE004-I]` artifact, timing, direct compare, and closeout validation without raising the broad large-module cap.
    - Research notes `0616` through `0626` explain why broad cap jumps are risky and why the current safe path only advances the narrow `4096 < defined <= 4608` band; next widening or fallback removal needs artifact validation, pass-local timing, and direct compare evidence.
    - Larger artifact modules currently remain capped at `8`; do not raise that full large-artifact cap without a runtime-neutral batching or fallback-removal proof.
  - Suggested tests:
    - Focused Func445-style dropped-result regression.
    - Callee with mixed dropped and undropped calls.
    - Dead-suffix `call; drop` rewrite coverage.
    - Type-liveness coverage for simple function types referenced outside the function section.
  - Exit criteria: closed by note `0687`; no remaining artifact or fuzz mismatch is classified as a true dropped-result scheduling gap for the current v0.1.0 surface.

- `[DAE]005` debug-artifact raw frontier/type-section drift is closed as of 2026-05-26. The raw `defined=336 abs=353` type-section/type-index mismatch is accepted as a documented diagnostic boundary for the default helper, not an active Func408/Func336 body rewrite task. Future raw parity work should reopen from a type-section/type-index construction need or a changed byte-reference contract, not from the current default first diff.

- `[DAE]006` both-canonical frontier advancement is closed as of 2026-05-26 by research note `0591`: the live Func509 `defined=509 abs=526` diff is a documented lowerer/diagnostic boundary, not a safe DAE final-hook matcher miss. Agent classification remains semantic-safe/size-losing: Starshine returns the same object as Binaryen, but leaves lowered post-return wrapper debris; the pre-encode DAE IR still needs the value-block suffix to consume the `block (result i64)` result, and the broad final-hook strip from note `0590` made functions `509` and `514` invalid. Future cleanup belongs to a separate post-lowering or writer-side dead-code cleanup investigation, not the active DAE final hook.

- `[DAE]009` raw cleanup policy is closed as of 2026-05-26. Future cleanup work should reopen a concrete implementation or measurement slice only when it changes behavior; keep the policy from `docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md`: correctness first, useful audited pure/nontrapping cleanup by default, documented Binaryen-shape preservation only for active diagnostics/frontiers, focused tests for each new stripped operation family, and size/mismatch evidence for any policy-changing 10k compare refresh.

- `[DAE]011` performance stabilization is closed as of 2026-05-26. Reopen only for a new measured DAE-owned regression, fuzz/runtime cliff, or preset-integration timing need.
  - Goal: keep DAE artifact and direct-pass runtime inside `Starshine <= 2x Binaryen`, preferably with headroom.
  - Why: recent both-canonical artifact timings were over the 2x threshold before caller-filtering the selected dropped-result helper; earlier selected scheduler experiments showed unstable timing even when byte-identical.
  - Deliverables:
    - [x] Add a lightweight timing/report mode for `scripts/self-optimize-compare.ts` so huge DAE artifacts can record timings without full normalized-WAT comparison (`--timing-only`, covered by `scripts/test/self-optimize-compare-command.ts`, research note `0593`).
    - [x] Repeat timing on the latest artifact with that mode: `.tmp/dae011-timing-only-20260526` reported `2785.602ms` Starshine pass versus `836.627ms` Binaryen pass, so Starshine is still over the 2x floor.
    - [x] Attribute whole-command wall-time separately from pass-local runtime unless the root cause is inside DAE; research note `0593` records whole-command timings (`3148.883ms` Starshine versus `1138.266ms` Binaryen) separately from pass-local timings (`2785.602ms` versus `836.627ms`), confirming the current blocker is DAE pass-local rather than compare-helper WAT printing.
    - [x] Profile the top-level DAE-owned portion before changing pass logic: research note `0595` added detail timers and traced the debug artifact to `detail:dae:core` dominance (`2748777us` core, `4us` skipped nested cleanup, `47855us` type pruning).
    - [x] Add deeper `detail:dae:core:*` timers around expensive setup/scanner families inside `dae_run_core` before choosing an optimization: research note `0596` added `setup`, `fixed-loop`, `selected-lanes`, and `raw-cleanup` core-family timers; `.tmp/dae011-core-detail-trace` attributes the current artifact hotspot to `detail:dae:core:selected-lanes` (`1917924us` of `2762312us` core total).
    - [x] Split `detail:dae:core:selected-lanes` into smaller rewrite-family timers before choosing the optimization target: research note `0597` added timers for reverse exact-literal, low-wrapper callees, early shapes, dropped results, literal/unread, late shapes, and post-raw selected lanes. `.tmp/dae011-selected-detail-trace/stderr.txt` attributes the latest hotspot to `detail:dae:core:selected-lanes:dropped-results` (`1654447us` of `1897993us` selected-lane aggregate; `detail:dae:core` total `2753535us`).
    - [x] Further micro-profile `detail:dae:core:selected-lanes:dropped-results`: research note `0598` added `call-facts`, `selected-defs`, and `func299-if` timers. `.tmp/dae011-dropped-result-detail-trace/stderr.txt` attributes the current hotspot to selected-def candidate checks (`1662875us` of `1677201us` dropped-results total), not shared call-fact collection (`14279us`) or Func299 cleanup (`25us`).
    - [x] Land the first selected-def-loop guard: `dae_try_remove_selected_defs_dropped_results_with_facts_once(...)` now threads shared `dropped_calls` facts into `dae_try_remove_dropped_results(...)` instead of treating every direct call as dropped; the new white-box regression failed before the fix and passes after it. Timing remains over target (`2807.905ms` Starshine versus `850.135ms` Binaryen in `.tmp/dae011-dropped-facts-timing-rebuilt-20260526`), so this is a contract/per-candidate skip improvement, not DAE011 closure.
    - [x] Micro-profile the selected-def helper itself: research note `0600` adds helper/subphase timers and `.tmp/dae011-helper-detail-trace/stderr.txt` attributes the helper cost mostly to repeated whole-module dropped-call rewriting, whole-module call-drop cleanup, and undropped-call scans, not type-index collection or section copying.
    - [x] Optimize the selected-def candidate loop with a caller-filtered dropped-result path using `DaeCurrentCallFacts.direct_callers[callee]` to avoid repeated whole-module scans while preserving self-call, dead-suffix, and fact-consistency guards; research note `0601` reports repeated timing-only artifact replays inside target.
    - [x] Avoid broad rescans, per-def bitmap churn, whole-module untouched cleanup, and selected-loop expansions that previously caused cliffs; the landed path preserves the old whole-module helper only for callers without facts and limits the selected helper to known direct callers.
  - Known useful runtime strategies:
    - Shared current-call facts.
    - Singleton/scratch bitmap reuse.
    - Empty skip bitmap reuse.
    - Lazy mutation buffers.
    - Touched-flag reuse.
    - Boundary queue precomputation and original suffix-target stamp tables.
  - Exit criteria: closed by research note `0601`; repeated artifact timings are stable within target after caller-filtering the selected dropped-result helper.


- `[DAE]013` preset / ordered-neighborhood integration is closed as of 2026-05-26. `dae-optimizing` remains explicitly direct-pass-only for v0.1.0; do not add it to public `optimize` / `shrink` presets without new ordered-prefix or artifact evidence that proves default-preset safety and runtime.


#### INL - Inlining Optimizing

- No active v0.1.0 INL implementation slice. `[INL]001`, `[INL]002`, `[INL]003`, `[INL]004`, and `[INL]007` are accepted for the current v0.1.0 surfaces. Do not pick up partial splitting, residual local/label name reconstruction, or other unsupported direct-inliner breadth after DAE unless new evidence shows a semantic mismatch, wasm validation failure, exported/start/table/ref.func discrepancy, or proven pass-local performance/code-size issue. Deferred INL follow-up lives in the v0.2.0 backlog below.

#### SGO - Simplify Globals Optimizing

- No active v0.1.0 SGO correctness or preset-scheduling blocker. `[SGO]001` and `[SGO]002` are signed off for the current Starshine v0.1.0 supported direct-pass / nested-runtime / late-tail scheduling surface. Direct `--simplify-globals-optimizing` replay at `.tmp/sgo-direct-debug-artifact-nested-pruned` validated, stayed smaller than Binaryen (`2,860,269` vs `2,861,435` bytes), and met the pass-local runtime floor (`153.143ms` vs `107.210ms`). The remaining direct first diff `defined=48 abs=69` is accepted representation-only local/default-init drift by user decision. Standard direct fuzz `.tmp/pass-fuzz-sgo-nested-pruned-10k` reported `9975/10000` compared, `9975` matches, `0` mismatches, `0` validation failures, and `25` Binaryen/tool command failures. The late-tail sequence `simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize` has 10k ordered-neighborhood parity and is now scheduled by public `optimize` / `shrink`. Signoff is recorded in `docs/wiki/raw/research/0573-2026-05-19-sgo-v010-signoff.md`.
- Future SGO work should require new evidence: a semantic mismatch, wasm validation failure, targeted artifact/code-size need, string/GC/refinalization breadth requirement, or measured SGO-specific wall-time owner. Broader Binaryen `SimplifyGlobals.cpp` families, exact default-function scheduler parity, nested `vacuum` wrapper overhead, and compare-harness normalization for explicit default local initialization are non-blocking follow-ups, not active v0.1.0 release blockers.

#### SG / RG / DIR late-tail scheduling

- No active v0.1.0 late-tail scheduling blocker. `[SG]002` is accepted for the direct ordered-neighborhood proof and public preset suffix scheduling. The accepted sequence is `simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize`; direct artifact and 10k ordered-neighborhood evidence live in `docs/wiki/raw/research/0571-2026-05-19-late-tail-five-pass-neighborhood-baseline.md`, and public `optimize` / `shrink` suffix scheduling evidence lives in `docs/wiki/raw/research/0572-2026-05-19-public-preset-late-tail-scheduling.md`. Future work should require a new semantic mismatch, a string-heavy binary showing that Binaryen reuse of existing canonical string globals is necessary, or explicit full-preset artifact signoff.

#### Whole-command wall-time budget

- [WALL]001 - Cross-Pass Runtime Budget And Attribution
  - Deliverables: own whole-command Starshine-vs-Binaryen wall-time measurement outside individual pass parity slices; separate pass-local runtime, harness/tool startup, parse/emit, validation, HOT lift/lower, analysis cache, and artifact representation costs; maintain a prioritized list of cross-cutting runtime fixes without blocking pass correctness signoff on aggregate wall time.
  - Current status: direct pass slices may record timing evidence when available, but unresolved whole-command wall-time gaps should be filed here unless the root cause is clearly inside one pass implementation. A 2026-05-19 full self-optimize attempt showed the current compare harness rejects preset flags (`--optimize`/`--shrink`), and an expanded optimize-preset compare/direct Starshine optimize attempt exceeded 30 minutes while still in `ssa-nomerge` near function `2977`; this is a full-preset runtime/attribution issue, not an SG decoder blocker. A follow-up direct `--ssa-nomerge` compare on the debug artifact timed out after 300s before producing artifacts, and a 120s traced direct replay again stopped inside Func 2977 after `analysis:ssa`, while Binaryen direct `--ssa-nomerge` completed in about 851ms wall / 385.935ms pass time. `--print-func 2977` identifies the body as the large branchy Wast opcode parser (`_M0MP37jtenner9starshine4wast10WastParser26parse__opcode__instruction`) with 394 locals and a 71,463-character raw body line, so the next `[WALL]001` slice should isolate or guard `ssa-nomerge` on that function shape before retrying full preset comparison. Follow-up non-pass slices now cover raw wasm no-op copies in `src/cmd/cmd.mbt`, remove standard-section/stringref whole-payload copies in `src/binary/decode.mbt`, and thread reachable escape-depth summaries through `src/validate/typecheck.mbt` so nested control validation no longer recursively rescans subtrees for merge-reaching branches; the remaining non-pass candidate is encoder size/backpatch or code-section buffering reduction.

## Deferred Until MoonBit Threading Support

- [HOT]002 - Native Parallel Hot-Batch Queue
  - Status: deferred; MoonBit does not currently support the threading model Starshine needs for a safe native worker queue.
  - Resume when: MoonBit native threading is stable enough to run per-function optimizer workers with deterministic, byte-stable output and explicit runtime gating.
  - Deliverables: add a native-only worker queue over eligible defined functions for the hot batch payload (`ssa-nomerge -> dead-code-elimination -> vacuum -> optimize-instructions -> simplify-locals`); keep final output byte-stable and deterministic; gate behind an explicit native-only option.
  - Dependencies: [HOT]001 replay hardening must stay green.

## v0.1.1 Backlog

### Optimizer Audit Follow-Ups

- [AUDIT]001 - Hot Pass Descriptor Metadata Truthfulness
  - Status: active follow-up from the 2026-05-31 optimizer audit.
  - Goal: make hot pass `requires` metadata describe every analysis a pass may request through `pass_require_*`, so the registry remains a truthful pass-author contract and future scheduling/perf tooling can trust descriptors.
  - Why: the audit found passes that lazily request analyses without listing them in `requires`; tests currently pass because the helper layer builds analyses on demand, but the metadata contract is stale.
  - Deliverables:
    - [ ] `[AUDIT001-A]` Add focused descriptor tests for `optimize-instructions` requiring `use_def` and `effects`; confirm failure before metadata changes.
    - [ ] `[AUDIT001-B]` Update `optimize-instructions` descriptor metadata to declare `use_def` and `effects`; rerun the focused descriptor test and `moon test src/passes`.
    - [ ] `[AUDIT001-C]` Add focused descriptor test for `remove-unused-brs` requiring `use_def`; confirm failure before metadata changes.
    - [ ] `[AUDIT001-D]` Update `remove-unused-brs` descriptor metadata to declare `use_def`; rerun the focused descriptor test and `moon test src/passes`.
    - [ ] `[AUDIT001-E]` Add a focused descriptor test proving `precompute-propagate-prefix` requires `ssa` and direct `precompute` does not, if direct `precompute` truly never reaches SSA helpers.
    - [ ] `[AUDIT001-F]` If `[AUDIT001-E]` proves direct `precompute` can reach SSA helpers, update direct `precompute` descriptor in its own test-first slice; otherwise leave it unchanged and document why.
    - [ ] `[AUDIT001-G]` Add a lightweight static/registry audit helper or test table for future `pass_require_*` additions so new metadata drift is caught near the implementing pass.
    - [ ] `[AUDIT001-H]` Refresh `docs/wiki/ir2/pass-porting-checklist.md` with the descriptor audit rule and cite the new tests.
  - Suggested tests: `moon test src/passes`, registry/descriptor focused tests, and one small trace/perf smoke proving analysis timers still appear under the expected pass.
  - Exit criteria: every hot descriptor is either mechanically covered by tests or explicitly documented as intentionally lazy; no pass silently depends on undeclared analysis metadata.

- [AUDIT]002 - Pass-Manager Raw Skip And Gate Boundary Coverage
  - Status: active follow-up from the 2026-05-31 optimizer audit.
  - Goal: protect large-function raw precleaner / skip heuristics from silent coverage holes and performance cliffs.
  - Why: `src/passes/pass_manager.mbt` contains many threshold-shaped gates for `remove-unused-brs`, `simplify-locals`, and related raw adapters. They are performance-motivated, but nearby shapes can miss cleanup or unexpectedly fall back to expensive HOT lowering.
  - Deliverables:
    - [ ] `[AUDIT002-A]` Inventory every `can_skip`, `unchecked`, `giant`, `large`, and threshold-based raw gate in `pass_manager.mbt`, grouping them by owning pass and intended artifact/function family.
    - [ ] `[AUDIT002-B]` Add white-box tests for `remove-unused-brs` large-result `br_table` dispatch ladder gates: exact match, locals/instruction lower-bound miss, block-depth miss, and HOT-only-candidate miss.
    - [ ] `[AUDIT002-C]` Add white-box tests for `remove-unused-brs` large value-if branch ladder gates: locals range, instruction range, call range, return/block range, and drop/select/br_if negatives.
    - [ ] `[AUDIT002-D]` Add white-box tests for `remove-unused-brs` drop-heavy / typed-`br_table` / void-if-return ladder gates, one predicate family per test so boundary failures identify the exact gate.
    - [ ] `[AUDIT002-E]` Add white-box tests for `remove-unused-brs` moderate and unchecked call-mesh gates, including ±1 thresholds around locals, instruction count, if count, and call count.
    - [ ] `[AUDIT002-F]` Add white-box tests for `simplify-locals` small structured call mesh gates: exact match, instruction lower/upper bounds, local-get/call ranges, and exact-tail negative.
    - [ ] `[AUDIT002-G]` Add white-box tests for `simplify-locals` giant validator and no-structure gates, with one fixture per threshold family rather than one mega-fixture.
    - [ ] `[AUDIT002-H]` For each broad skip family touched by `[AUDIT002-B]` through `[AUDIT002-G]`, add one public-pipeline fixture proving the intended cleanup either still runs or intentionally stays skipped with a trace reason.
    - [ ] `[AUDIT002-I]` Add trace strings for currently silent broad skip decisions where a future agent cannot tell whether a function was skipped for safety, performance, or shape mismatch.
    - [ ] `[AUDIT002-J]` Run a focused artifact timing replay for the debug artifact after adding trace/tests; document any gate that exists only to stay within `Starshine <= 2x Binaryen`.
  - Suggested tests: `moon test src/passes`, focused `pass_manager_wbtest`, and a timing-only `self-optimize-compare` replay only after asking if it will be long.
  - Exit criteria: every raw skip/gate family has boundary tests and a documented purpose; no threshold is an unexplained magic number.

- [AUDIT]003 - DAE Selected-Shape De-Artifacting And Genericization
  - Status: active v0.1.1 follow-up; not a v0.1.0 blocker because current DAE direct-pass surfaces are accepted.
  - Goal: convert remaining selected `FuncXXX` artifact lanes into generic, named, semantics-first shape recognizers where practical, while keeping accepted artifact evidence intact.
  - Why: the audit found many selected-function helpers in `dead_argument_elimination.mbt`. They are covered and historically justified, but they are hard to maintain and weak as a general optimizer surface.
  - Deliverables:
    - [ ] `[AUDIT003-A]` Inventory selected-function helpers and tests into a markdown table with columns: helper, selected def(s), fixture/test, transform family, safety guard, artifact reason, and current generic candidate.
    - [ ] `[AUDIT003-B]` Classify Func237 carrier/loop/local-map helpers only; decide which are genericizable and which are intentionally artifact-local.
    - [ ] `[AUDIT003-C]` Classify Func256/Func298 loop-carrier helpers only; decide which are genericizable and which are intentionally artifact-local.
    - [ ] `[AUDIT003-D]` Classify Func287/Func288 setup/switch-carrier helpers only; decide which are genericizable and which are intentionally artifact-local.
    - [ ] `[AUDIT003-E]` Classify Func299 inverted-if, Func311/Func313 terminal-call-arg, and Func408/Func505/Func521 literal/control helpers, one family at a time.
    - [ ] `[AUDIT003-F]` Pick the smallest safe classified family and add a reduced non-artifact fixture that fails without a generic recognizer and does not depend on absolute debug-artifact function indices.
    - [ ] `[AUDIT003-G]` Implement only that one family behind semantic guards, keep the selected artifact fixture as a regression, and remove only the corresponding selected-index gate if artifact/timing/fuzz evidence stays green.
    - [ ] `[AUDIT003-H]` Repeat `[AUDIT003-F]`/`[AUDIT003-G]` for the next smallest family; every repeat gets its own focused test-first commit-sized slice, not a broad DAE rewrite.
    - [ ] `[AUDIT003-I]` For families that remain selected-only, add comments in source and wiki explaining why they are intentionally artifact-local and what evidence would reopen them.
    - [ ] `[AUDIT003-J]` Refresh direct `--dae-optimizing` compare with DAE normalizers and classify any mismatch families by agent judgment, keeping accepted raw-cleanup drift separate from true semantic mismatches.
  - Suggested tests: focused DAE fixtures first, `moon test src/passes`, direct `bun scripts/pass-fuzz-compare.ts --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris`, and artifact timing when selected lanes move.
  - Exit criteria: selected-function lanes are either replaced by generic recognizers or explicitly documented as intentionally artifact-local with current evidence.

- [AUDIT]004 - Thin Module-Pass Shape Coverage Expansion
  - Status: active follow-up from the 2026-05-31 optimizer audit.
  - Goal: add small, public-pipeline tests for module passes whose current direct coverage is thin relative to their implementation breadth.
  - Why: the all-pass fuzz smoke found no validation failures, but several module passes have only a small number of focused tests and are likely places for missing shapes to hide.
  - Deliverables:
    - [ ] `[AUDIT004-A]` `global-struct-inference` packed fields: add separate signed 8-bit, unsigned 8-bit, signed 16-bit, and unsigned 16-bit field-read tests.
    - [ ] `[AUDIT004-B]` `global-struct-inference` constructors: add separate `struct.new_default`, `struct.new_desc`, and `struct.new_default_desc` tests.
    - [ ] `[AUDIT004-C]` `global-struct-inference` negatives: add separate mutable-field, imported global, exported global, non-global producer, and nullable-ref default guard tests.
    - [ ] `[AUDIT004-D]` `directize` table visibility negatives: add separate imported-table and exported-table tests proving indirect calls remain indirect.
    - [ ] `[AUDIT004-E]` `directize` element coverage: add passive element, declarative element, active nonconstant offset, active out-of-range hole, and type-mismatch-trap tests.
    - [ ] `[AUDIT004-F]` `directize` multi-table and tail-call coverage: add one multi-table partial optimization fixture, one `return_call_indirect` fixture, and one unsupported `call_ref`/reference-call non-interference fixture if WAT support exists.
    - [ ] `[AUDIT004-G]` `duplicate-import-elimination`: add separate tests for same module/name duplicate function imports, different module/name same-signature duplicates, nonfunction-import negatives, and different-signature negatives.
    - [ ] `[AUDIT004-H]` `duplicate-import-elimination` remapping: add separate call, `ref.func`, table element, export/start, and name/custom-section preservation tests.
    - [ ] `[AUDIT004-I]` `merge-locals`: add separate tests for multi-value functions, GC/ref locals with equal types, GC/ref locals with unequal types, dead-tail local traffic, write-interrupted copy chains, effect-interrupted copy chains, and local-name cleanup.
    - [ ] `[AUDIT004-J]` `local-cse` scalar/effect barriers: add separate tests for memory load/store barriers, global get/set barriers, table barriers, ordinary call barriers, and pure duplicate scalar positives.
    - [ ] `[AUDIT004-K]` `local-cse` advanced barriers: add separate tests for exceptions/`try_table`, GC heap operations, atomic operations, and SIMD operations where the current WAT authoring surface supports them; otherwise file the unsupported shape in the wiki.
    - [ ] `[AUDIT004-L]` `once-reduction`: add separate tests for table escape, global escape, `ref.func` escape, export escape, start-function behavior, imported function negative, exported function negative, and multi-use once-positive.
    - [ ] `[AUDIT004-M]` `global-refining`: add separate tests for nullable-to-non-null refinement, non-null-to-null negative, external visibility guard, subtype-chain refinement, incompatible subtype negative, descriptor surface, and stringref surface where supported.
    - [ ] `[AUDIT004-N]` After each pass-family test batch, run the pass-targeted compare smoke with `--count 1000` before moving to the next family; do not batch all behavior changes behind one signoff.
  - Suggested tests: adjacent `*_test.mbt` public-pipeline fixtures, `moon test src/passes`, and pass-targeted compare smoke for each touched pass.
  - Exit criteria: each listed module pass has positive and negative coverage for its most important module shapes, with no new validation failures or unexplained Binaryen mismatches.

- [AUDIT]005 - Standalone No-Inline Pass Contract Tests
  - Status: active follow-up from the 2026-05-31 optimizer audit.
  - Goal: give `no-inline`, `no-full-inline`, and `no-partial-inline` their own focused module-pass tests instead of relying only on inlining integration tests.
  - Why: `src/passes/no_inline.mbt` has meaningful standalone behavior but no adjacent `no_inline_test.mbt` file.
  - Deliverables:
    - [ ] `[AUDIT005-A]` Add `src/passes/no_inline_test.mbt` with a helper that runs a no-inline module pass and extracts function annotations.
    - [ ] `[AUDIT005-B]` Add wildcard positive coverage for a defined WAT function name.
    - [ ] `[AUDIT005-C]` Add no-match negative coverage proving no annotation section is created.
    - [ ] `[AUDIT005-D]` Add imported function name matching coverage.
    - [ ] `[AUDIT005-E]` Add WAT identifier lowering coverage for defined functions.
    - [ ] `[AUDIT005-F]` Add repeated marker deduplication coverage.
    - [ ] `[AUDIT005-G]` Add metadata-code-inline non-interaction coverage.
    - [ ] `[AUDIT005-H]` Add `no-full-inline` only marker coverage.
    - [ ] `[AUDIT005-I]` Add `no-partial-inline` only marker coverage.
    - [ ] `[AUDIT005-J]` Add combined policy coverage and retain one narrow inlining integration smoke as the end-to-end guard.
  - Suggested tests: `moon test src/passes`, plus a narrow inlining integration smoke after standalone tests are green.
  - Exit criteria: no-inline policy marker semantics are protected independently from the inliner.

- [AUDIT]006 - Function TypeIdx/RecIdx Invariant Documentation
  - Status: active documentation follow-up from user clarification on 2026-05-31.
  - Goal: document clearly that `func_sec` function type references are absolutely invariant as global `TypeIdx` entries, not local recursive `RecIdx` entries; optimizer code may treat `RecIdx` in function-section type-index positions as impossible after valid decode/validation.
  - Why: the audit initially flagged `RecIdx` aborts in locals passes as potential user-input risk. User clarified this shape is a 100% invariant. The issue is documentation clarity, not behavior change.
  - Deliverables:
    - [ ] `[AUDIT006-A]` Add or update a wiki page covering the function-section type-index invariant: module-level function declarations use global `TypeIdx`; `RecIdx` is only meaningful inside a rec-group-local type context.
    - [ ] `[AUDIT006-B]` Cite concrete source anchors in that page: `src/lib/types.mbt`, validation/type-section handling, and at least one optimizer module-pass function-signature cache.
    - [ ] `[AUDIT006-C]` Add inline comment near the `merge-locals` `RecIdx` abort explaining it is an unreachable invariant assertion for function-section type references.
    - [ ] `[AUDIT006-D]` Add inline comment near the `coalesce-locals` `RecIdx` abort explaining the same invariant.
    - [ ] `[AUDIT006-E]` Add inline comment near the `reorder-locals` `RecIdx` abort explaining the same invariant.
    - [ ] `[AUDIT006-F]` Add a pass/helper test or validation test, if practical, demonstrating that valid module-level function declarations resolve through global `TypeIdx`; if no practical test exists, document why the source/validation references are sufficient.
    - [ ] `[AUDIT006-G]` Update `docs/wiki/ir2/pass-porting-checklist.md` or a related architecture page with guidance: do not cargo-cult broad `RecIdx` support into module-pass function-signature caches unless the source is actually inside a rec-group-local type context.
    - [ ] `[AUDIT006-H]` Refresh `docs/wiki/index.md` and `docs/wiki/log.md` for the new/updated invariant documentation.
  - Suggested tests: docs-only changes should still run `moon test src/passes`; if a validation/helper test is added, run the specific package plus `moon test` when practical.
  - Exit criteria: future agents can see that function-section `RecIdx` handling is an invariant assertion and do not spend time trying to support an impossible module shape.

- [AUDIT]007 - Audit Compare Refresh And Mismatch Classification Hygiene
  - Status: active follow-up from the 2026-05-31 optimizer audit.
  - Goal: turn the ad hoc audit smoke into durable, reproducible evidence without treating accepted representation drift as a correctness failure.
  - Why: the 50-case all-pass smoke and 1000-case DAE refresh found no validation failures, but the evidence currently lives only in `.tmp/deep-audit-20260531` and this thread.
  - Deliverables:
    - [ ] `[AUDIT007-A]` File a numbered research note summarizing the exact 2026-05-31 all-pass smoke commands and environment, including `--starshine-bin`, `--jobs auto`, seed, and out dirs.
    - [ ] `[AUDIT007-B]` Add the per-pass count table to that note: compared count, normalized matches, compare-normalized matches, validation failures, command failures, and mismatch count.
    - [ ] `[AUDIT007-C]` Add a lightweight docs recipe for running an all-pass smoke compare with `--jobs auto` and a prebuilt `--starshine-bin`, explicitly not part of normal `moon test`.
    - [ ] `[AUDIT007-D]` Add or update script tests only if the docs recipe requires script behavior changes; keep recipe-only changes docs-only.
    - [ ] `[AUDIT007-E]` Refresh direct `--pass inlining` mismatch classification with a small replay set, explicitly separating local-declaration representation drift from semantic mismatch.
    - [ ] `[AUDIT007-F]` Refresh direct `--pass inlining-optimizing` mismatch classification with a small replay set, separately from plain `inlining`.
    - [ ] `[AUDIT007-G]` Refresh direct `--pass dae-optimizing` classification with documented normalizers and keep generated dropped-constant cleanup drift separate from validation or semantic failures.
    - [ ] `[AUDIT007-H]` Link the research note from the relevant pass wiki pages or the audit/log page so future agents do not rediscover the same smoke results.
  - Suggested tests: no implementation tests unless tooling changes; if tooling/docs recipe changes, run script tests and a small compare replay.
  - Exit criteria: the audit evidence is durable and indexed, with exact commands and agent-classified mismatch families.

### O4z Per-Pass Deep Audits

Use this checklist for every `[O4Z-AUDIT-*]` slice below:
- Start from the pass wiki page and owner source/test files; update docs if findings become durable.
- Run or refresh direct pass oracle evidence with `bun scripts/pass-fuzz-compare.ts --pass <name> --count 1000` first, then scale to 10000 only when changing behavior or closing the slice.
- Inspect tests for missing positive/negative shapes, add focused test-first fixtures for any bug or missed optimization, and keep validation failures separate from representation drift.
- Capture pass-local timing where available; file whole-command issues under `[WALL]001` unless the pass is clearly the owner.
- Replay the pass's `-O4z` slot/neighborhood when it has saved artifacts or documented generated-audit evidence.
- Close with an agent-classified findings note: bugs found/fixed, missing shapes added, performance owners, deferred risks, exact commands, counts, and artifact paths.

- [O4Z-AUDIT-DFE] - Deep audit `duplicate-function-elimination`
  - Status: active `-O4z` per-pass audit.
  - Scope: duplicate defined-function equivalence, ref.func/export/start/table/global remapping, local Starshine type-compaction extras, repeated-slot behavior, and pass-local runtime.
  - Deliverables: apply the common checklist; add focused fixtures for any missing function identity/remap/type/name shape; refresh direct compare and ordered `DFE` slot evidence; record whether local extra cleanup should stay bundled or be split.

- [O4Z-AUDIT-RUME] - Deep audit `remove-unused-module-elements`
  - Status: active `-O4z` per-pass audit.
  - Scope: function/table/global/memory/tag/elem/data liveness, export/start/ref.func/type-use roots, nonfunction-only sibling behavior, and module rewrite cost.
  - Deliverables: apply the common checklist; cover roots and remaps not already tested; refresh direct compare plus `DFE -> RUME` neighborhood evidence; classify any retained dead elements or over-removal risks.

- [O4Z-AUDIT-MP] - Deep audit `memory-packing`
  - Status: active `-O4z` per-pass audit.
  - Scope: active/passive data packing, offset arithmetic, overlap and trap preservation, data.drop/data.init remaps, imported/defined memory boundaries, and large-data performance.
  - Deliverables: apply the common checklist; add missing data-segment shape tests; refresh direct compare and `MP` slot evidence; record any size-winning but Binaryen-divergent packing choices.

- [O4Z-AUDIT-OR] - Deep audit `once-reduction`
  - Status: active `-O4z` per-pass audit.
  - Scope: once-called/private function reduction, escape roots, table/ref.func/export/start/import boundaries, callsite rewriting, and type/name repair.
  - Deliverables: apply the common checklist; add escape and multi-use tests; refresh direct compare and `OR` slot evidence; classify any missed once-only opportunities versus safety bailouts.

- [O4Z-AUDIT-GR] - Deep audit `global-refining`
  - Status: active `-O4z` per-pass audit.
  - Scope: global initializer/type LUB refinement, mutable/exported/imported guardrails, GC heap type precision, descriptor/stringref interactions, and validation/refinalization behavior.
  - Deliverables: apply the common checklist; add subtype and visibility fixtures; refresh direct compare and `GR` slot evidence; record any under-refinement or unsafe-boundary risks.

- [O4Z-AUDIT-GSI] - Deep audit `global-struct-inference`
  - Status: active `-O4z` per-pass audit.
  - Scope: closed-world struct field constants, packed fields, default/descriptor constructors, mutable/exported/imported global negatives, nullable refs, and code-size/runtime impact.
  - Deliverables: apply the common checklist; coordinate with `[AUDIT004-A]` through `[AUDIT004-C]`; refresh direct compare and `GSI` slot evidence; document supported and intentionally unsupported closed-world shapes.

- [O4Z-AUDIT-SSA] - Deep audit `ssa-nomerge`
  - Status: active `-O4z` per-pass audit.
  - Scope: HOT SSA construction/lowering without merges, phi copy placement, large branchy function runtime, local-name/type preservation, and Func2977-style wall-time ownership.
  - Deliverables: apply the common checklist; add reduced large-branch stress fixtures if needed; refresh direct compare and early `SSA` slot evidence; file pass-local runtime fixes here and whole-command residuals under `[WALL]001`.

- [O4Z-AUDIT-DCE] - Deep audit `dead-code-elimination`
  - Status: active `-O4z` per-pass audit.
  - Scope: unreachable tails, dropped-value safety, structured-control result repair, EH/try_table behavior, writeback guards, raw-skip paths, and repeated cleanup interactions.
  - Deliverables: apply the common checklist; add missing dead-tail/control/EH fixtures; refresh direct compare and `DCE` slot evidence; classify Binaryen-shape differences as semantic, representation, or size tradeoffs.

- [O4Z-AUDIT-RUN] - Deep audit `remove-unused-names`
  - Status: active `-O4z` per-pass audit.
  - Scope: label-use tracking, block merge/demotion, delegate/try behavior, repeated RUN slots, name-section expectations, and interaction with branch cleanup.
  - Deliverables: apply the common checklist; add label/delegate/repeated-slot fixtures; refresh direct compare and all `RUN` slot evidence; record any missed same-type wrapper collapses.

- [O4Z-AUDIT-RUB] - Deep audit `remove-unused-brs`
  - Status: active `-O4z` per-pass audit.
  - Scope: tail branch/return removal, branch-to-trap rewrite, value-if/select lowering, br_table labels, raw gate thresholds, and retired slot14/slot40 corruption families.
  - Deliverables: apply the common checklist; coordinate with `[AUDIT002-B]` through `[AUDIT002-E]`; refresh direct compare and all `RUB` slot evidence; measure pass-local impact of raw skip choices.

- [O4Z-AUDIT-OI] - Deep audit `optimize-instructions`
  - Status: active `-O4z` per-pass audit.
  - Scope: exact peepholes, shift/compare/boolean rewrites, effect-aware folds, use-def/effects metadata, raw O4z slot16/slot44 predecessors, and pass-local runtime.
  - Deliverables: apply the common checklist; coordinate descriptor work with `[AUDIT001-A]`/`[AUDIT001-B]`; refresh direct compare and all `OI` slot evidence; classify any missed Binaryen folds by safety/effect reason.

- [O4Z-AUDIT-HSO] - Deep audit `heap-store-optimization`
  - Status: active `-O4z` per-pass audit.
  - Scope: struct.new/struct.set folding, local escape analysis, effect ordering, GC descriptor/refinalization shapes, and allocation-heavy performance.
  - Deliverables: apply the common checklist; add missing GC/effect/escape fixtures; refresh direct compare and `HSO` slot evidence; record unsafe fold blockers separately from missed profitable folds.

- [O4Z-AUDIT-PLS] - Deep audit `pick-load-signs`
  - Status: active `-O4z` per-pass audit.
  - Scope: signed/unsigned load choice, extension-use recognition, local.tee and multi-use negatives, imported/defined memory coverage, and idempotence.
  - Deliverables: apply the common checklist; add missing extension and memory fixtures; refresh direct compare and `PLS` slot evidence; document tie-breaking and unsupported evidence shapes.

- [O4Z-AUDIT-PC] - Deep audit `precompute`
  - Status: active `-O4z` per-pass audit.
  - Scope: constant folding, trap/effect preservation, raw precleaner/writeback guards, precompute-propagate prefix distinction, GC/array atomic exclusions, and O4z slot19/slot43 history.
  - Deliverables: apply the common checklist; coordinate descriptor work with `[AUDIT001-E]`/`[AUDIT001-F]`; refresh direct compare and all `PC` slot evidence; record missed folds versus deliberate trap/effect bailouts.

- [O4Z-AUDIT-CP] - Deep audit `code-pushing`
  - Status: active `-O4z` per-pass audit.
  - Scope: safe local/global computation sinking, effect/trap boundaries, if/else arm use analysis, nested control, and tuple/local-cleanup neighborhood effects.
  - Deliverables: apply the common checklist; add missing push/bailout fixtures; refresh direct compare and `CP` slot evidence; classify downstream code-size wins and regressions.

- [O4Z-AUDIT-TO] - Deep audit `tuple-optimization`
  - Status: active `-O4z` per-pass audit.
  - Scope: multivalue spill/copy splitting, passthrough chains, branch-exit carriers, local compaction, interaction with SLNS/RL/RUB, and candidate-heavy function runtime.
  - Deliverables: apply the common checklist; add missing tuple carrier fixtures; refresh direct compare and `TO` exact-slot neighborhood evidence; record any host-lane/local-map invariants clearly.

- [O4Z-AUDIT-SLNS] - Deep audit `simplify-locals-nostructure`
  - Status: active `-O4z` per-pass audit.
  - Scope: no-structure local sinking, no-tee variant spelling, dead write cleanup, interaction with tuple/reorder/vacuum, and raw gate behavior.
  - Deliverables: apply the common checklist; add missing no-structure/no-tee fixtures; refresh direct compare and `SLNS` slot evidence; keep structure-producing rewrites out unless intentionally scheduled.

- [O4Z-AUDIT-VQ] - Deep audit `vacuum`
  - Status: active `-O4z` per-pass audit.
  - Scope: nop/drop cleanup, explicit unreachable preservation, nested value-expression debris, empty if/block rewrites, repeated VQ slots, and retired slot23/slot33 histories.
  - Deliverables: apply the common checklist; add missing pure/nontrapping and control cleanup fixtures; refresh direct compare and all `VQ` slot evidence; measure cleanup value versus HOT traversal cost.

- [O4Z-AUDIT-RL] - Deep audit `reorder-locals`
  - Status: active `-O4z` per-pass audit.
  - Scope: access-count sorting, zero-count truncation, parameter stability, local-name repair, multivalue scratch locals, TypeIdx invariant docs, and module-pass runtime.
  - Deliverables: apply the common checklist; coordinate invariant docs with `[AUDIT006-E]`; add missing reorder/name/multivalue fixtures; refresh direct compare and `RL` slot evidence.

- [O4Z-AUDIT-H2L] - Deep audit `heap2local`
  - Status: active `-O4z` per-pass audit.
  - Scope: non-escaping struct locals, scalar field locals, null comparisons, GC type/refinalization, primary artifact fixtures, and heap-heavy function runtime.
  - Deliverables: apply the common checklist; add missing escape/null/field fixtures; refresh direct compare and `H2L` slot evidence; record memory and code-size effects.

- [O4Z-AUDIT-OC] - Deep audit `optimize-casts`
  - Status: active `-O4z` per-pass audit.
  - Scope: ref.cast/ref.test/br_on_cast folding, descriptor casts, nullability trap preservation, local-subtyping neighborhood, and GC validation.
  - Deliverables: apply the common checklist; add missing cast/descriptor/nullability fixtures; refresh direct compare and `OC` slot evidence; classify any trap-mode-sensitive decisions.

- [O4Z-AUDIT-LS] - Deep audit `local-subtyping`
  - Status: active `-O4z` per-pass audit.
  - Scope: local type refinement, write-site and join behavior, GC refs, call_ref and try_table shapes, interaction with optimize-casts/DAE, and validation refinalization.
  - Deliverables: apply the common checklist; add missing local-refinement fixtures; refresh direct compare and `LS` slot evidence; document conservative join/bailout policy.

- [O4Z-AUDIT-CL] - Deep audit `coalesce-locals`
  - Status: active `-O4z` per-pass audit.
  - Scope: interference graph/coloring, local remap/name cleanup, TypeIdx invariant docs, copy-pair cleanup, and large-function coloring runtime.
  - Deliverables: apply the common checklist; coordinate invariant docs with `[AUDIT006-D]`; add missing interference/ref/name fixtures; refresh direct compare and `CL` slot evidence.

- [O4Z-AUDIT-LCSE] - Deep audit `local-cse`
  - Status: active `-O4z` per-pass audit.
  - Scope: local expression reuse, effect barriers, memory/table/global/call/EH/GC/SIMD shapes, module adapter behavior, and pass-local runtime.
  - Deliverables: apply the common checklist; coordinate shape tests with `[AUDIT004-J]`/`[AUDIT004-K]`; refresh direct compare and `LCSE` slot evidence; classify missed CSE opportunities by barrier type.

- [O4Z-AUDIT-SL] - Deep audit `simplify-locals`
  - Status: active `-O4z` per-pass audit.
  - Scope: local sinking, tee synthesis, structured result rewrites, dead writes, raw gate thresholds, value-carrier spills, and late cleanup interactions.
  - Deliverables: apply the common checklist; coordinate raw gate coverage with `[AUDIT002-F]`/`[AUDIT002-G]`; refresh direct compare and `SL` slot evidence; record shrink candidates separately from semantic fixes.

- [O4Z-AUDIT-CF] - Deep audit `code-folding`
  - Status: active `-O4z` per-pass audit.
  - Scope: shared tails, terminating returns/unreachable, branch poison, label/helper generation, late cleanup neighborhood, and downstream code-size impact.
  - Deliverables: apply the common checklist; add missing tail/branch/label fixtures; refresh direct compare and `CF` slot evidence; decide whether any remaining Binaryen tail-sharing is worth implementing.

- [O4Z-AUDIT-MB] - Deep audit `merge-blocks`
  - Status: active `-O4z` per-pass audit.
  - Scope: branch-free block flattening, loop-tail merging, drop(block) cleanup, O4z slot42 witness, label/branch safety, and interaction with RUB/RUN.
  - Deliverables: apply the common checklist; add missing merge/bailout fixtures; refresh direct compare and all `MB` slot evidence; measure any large nested-control runtime cost.

- [O4Z-AUDIT-RSE] - Deep audit `redundant-set-elimination`
  - Status: active `-O4z` per-pass audit.
  - Scope: same-value set/tee removal, branch/default facts, loop invariants, refined local.get retargeting, GC wrapper/accessor facts, and late-tail preset role.
  - Deliverables: apply the common checklist; add missing CFG/value-flow fixtures; refresh direct compare and `RSE` slot evidence; classify any full fixed-point loop convergence gap.

- [O4Z-AUDIT-DAE] - Deep audit `dae-optimizing`
  - Status: active `-O4z` per-pass audit.
  - Scope: dead argument/result removal, nested cleanup scheduler, selected-shape genericization, raw cleanup policy, type liveness, and pass-local runtime.
  - Deliverables: apply the common checklist; coordinate with `[AUDIT003-*]`; refresh DAE-normalized direct compare and late `DAE` slot evidence; keep accepted raw-cleanup drift separate from semantic mismatches.

- [O4Z-AUDIT-INL] - Deep audit `inlining-optimizing`
  - Status: active `-O4z` per-pass audit.
  - Scope: direct inlining heuristics, optimizing cleanup scheduler, no-inline policy interaction, helper compaction, tail-call/multivalue surfaces, and local-declaration drift.
  - Deliverables: apply the common checklist; refresh direct compare and `INL` slot evidence; classify residual local-declaration mismatches; file partial-inlining/name repair only if new evidence warrants reopening deferred slices.

- [O4Z-AUDIT-DIE] - Deep audit `duplicate-import-elimination`
  - Status: active `-O4z` per-pass audit.
  - Scope: duplicate import equivalence, import remapping, call/ref.func/table/export users, nonfunction and signature negatives, and metadata preservation.
  - Deliverables: apply the common checklist; coordinate tests with `[AUDIT004-G]`/`[AUDIT004-H]`; refresh direct compare and `DIE` slot evidence; record any ABI-visible import-order constraints.

- [O4Z-AUDIT-SGO] - Deep audit `simplify-globals-optimizing`
  - Status: active `-O4z` per-pass audit.
  - Scope: global value propagation, nested cleanup runtime, late-tail scheduling, closed/open-world boundaries, string/GC/refinalization breadth, and accepted default-local drift.
  - Deliverables: apply the common checklist; refresh direct compare and `SGO` tail evidence; coordinate with `[SGO]003` through `[SGO]005`; keep accepted v0.1.0 signoff separate from new improvement findings.

- [O4Z-AUDIT-SG] - Deep audit `string-gathering`
  - Status: active `-O4z` per-pass audit.
  - Scope: string.const gathering, canonical global reuse, data/name/export interactions, late-tail ordering, and string-heavy module code-size impact.
  - Deliverables: apply the common checklist; add missing stringref/global fixtures; refresh direct compare and `SG` tail evidence; document any Binaryen canonical-string reuse gap.

- [O4Z-AUDIT-RG] - Deep audit `reorder-globals`
  - Status: active `-O4z` per-pass audit.
  - Scope: dependency-preserving global order, global.get/set remaps, exports/imports/start/elem/data interactions, string global late tail, and names/metadata.
  - Deliverables: apply the common checklist; add missing dependency/remap fixtures; refresh direct compare and `RG` tail evidence; record any order-only representation drift separately from correctness.

- [O4Z-AUDIT-DIR] - Deep audit `directize`
  - Status: active `-O4z` per-pass audit.
  - Scope: immutable table facts, holes/traps, type matching/subtyping, select lowering, imported/exported/mutated table negatives, tail calls, and late-tail code-size impact.
  - Deliverables: apply the common checklist; coordinate tests with `[AUDIT004-D]` through `[AUDIT004-F]`; refresh direct compare and final `DIR` tail evidence; document any broader directization opportunities or safety bailouts.

### SGO - Follow-Up Improvements

- [SGO]003 - Optional Binaryen `SimplifyGlobals.cpp` Breadth
  - Status: deferred to v0.1.1; not a v0.1.0 blocker after `docs/wiki/raw/research/0573-2026-05-19-sgo-v010-signoff.md`.
  - Goal: broaden the signed-off SGO supported surface only when a targeted need appears, without reopening the accepted v0.1.0 direct/nested/late-tail signoff by default.
  - Resume when: a new semantic mismatch, wasm validation failure, targeted artifact/code-size need, or string/GC/refinalization requirement points at SGO breadth.
  - Candidate families: side-effecting-but-safe `read-only-to-write` value-flow positives, broader same-as-init expression matching beyond direct literal / `ref.null` / `ref.func`, broader runtime linear-trace propagation, and additional GC/refinalization-safe replacement surfaces.
  - Deliverables when resumed: add focused shape tests first, rerun direct `--pass simplify-globals-optimizing` oracle fuzz for the new family, and update the SGO wiki pages with the exact accepted subset.

- [SGO]004 - Nested Cleanup Runtime And Exact-Scheduler Experiment
  - Status: deferred to v0.1.1; not a v0.1.0 blocker because the accepted nested lane is valid, smaller than Binaryen on the direct artifact, and inside the direct pass-local runtime floor.
  - Goal: decide whether to optimize remaining nested cleanup wrapper overhead or intentionally restore more exact Binaryen default-function scheduler slots despite measured runtime cost.
  - Resume when: a measured SGO-specific wall-time owner appears, the nested `vacuum` wrapper overhead becomes a concrete runtime target, or an artifact/code-size case demonstrates value from omitted nested default-function slots.
  - Candidate work: reduce nested `vacuum` / lift-lower wrapper cost, add cheaper function-filtered adapters for currently module-shaped cleanup passes, or run a controlled exact-scheduler experiment with artifact and fuzz evidence.
  - Deliverables when resumed: trace before/after nested timers, preserve validation and direct 10k SGO fuzz parity, and document whether the accepted artifact-tuned lane changes.

- [SGO]005 - Default-Local Compare Normalization
  - Status: deferred to v0.1.1 tooling/cosmetic follow-up; not a v0.1.0 correctness blocker.
  - Goal: eliminate or normalize the accepted direct SGO `defined=48 abs=69` artifact diff where Binaryen preserves an explicit `local.set $0 (i32.const 0)` and Starshine relies on WebAssembly default local zero-initialization.
  - Resume when: exact artifact diffs need to become quieter for release QA or compare-harness work.
  - Deliverables when resumed: either teach the compare helper to ignore explicit default local initialization when semantically equivalent, or add a deliberate Starshine emission/canonicalization option if preserving the explicit set proves more useful.

## v0.2.0 Backlog

### INL - Deferred Inliner Breadth

- [INL]005 - Partial Inlining Splitter
  - Status: deferred to v0.2.0; not a v0.1.0 blocker and not the next task after DAE. Starshine intentionally does not implement Binaryen's Pattern A / Pattern B partial splitting today.
  - Resume only if a reduced Pattern A/B fixture demonstrates one of: semantic or validation correctness, a clear pass-local performance win, a downstream size/optimization win that offsets code growth, or a user-facing need for `no-partial-inline` splitter behavior.
  - Deliverables when resumed: implement or explicitly reject/scope out Pattern A and Pattern B splitting, add reduced splitter and helper-cleanup fixtures, define `no-partial-inline` behavior against the splitter, and compare direct `--pass inlining` / `--pass inlining-optimizing` on split-family repros.

- [INL]006 - Residual Name/Annotation Repair
  - Status: deferred to v0.2.0; not a v0.1.0 blocker and not a semantic parity prerequisite for the accepted direct surfaces. Tail-call and multi-result correctness subsets are already covered by focused tests; Starshine intentionally drops function-scoped local/label names after inlining body rewrites instead of preserving stale or collision-prone debug maps.
  - Resume only with a concrete user-facing debug-name requirement, annotation-collision requirement, semantic mismatch, wasm validation failure, or proven pass-local performance/code-size issue.
  - Deliverables when resumed: add focused repair tests first, then either implement deterministic Binaryen-like local/label name reconstruction and broader annotation collision repair or explicitly document the unsupported surface as rejected.

- [TOOL]001 - Self-Optimize Compare Normalization Symmetry
  - Goal: make the exact artifact helper stop reporting harmless raw/debug-only outer-block drift as a pass blocker.
  - Why deferred: the current `[TO]005` residual is not a Starshine optimizer bug and is not needed for v0.1.0.
  - Deliverables: either canonicalize Binaryen through the same strip-debug path before canonical-function comparison while preserving `binaryen.raw.wasm`, or teach the canonical-function fallback to ignore transparent unused-label void block wrappers.
  - Acceptance: the exact-slot artifact command no longer reports `defined=200 abs=217` solely because Binaryen raw `--debug` kept an outer block that symmetric normalization removes.

- [HOT]003 - Node-Package Worker Queue Port
  - Status: deferred behind [HOT]002 and future Node package rebuild work.
  - Deliverables: reuse the native hot-batch queue contract in the shipped Node package with `worker_threads`, one WasmGC module per worker, worker-local heap state, and stable-order serialized merge.
  - Dependencies: [HOT]002 native queue contract, worker-local function serialization hooks, and future Node package rebuild work.

### FUZ - Fuzzer Hardening and GenValid Widening

- [FUZ]1002 - Typed Stack-Aware GenValid Body Generator
  - Goal: add a typed expression/body generator that tracks operand stack, labels, reachability, locals, globals, funcs, tables, memories, tags, and type information while emitting instructions.
  - Why: the current body generation relies heavily on hand-picked drop-wrapped preludes and `append_value_instrs(...)`. It proves surfaces exist but does not generate enough structurally diverse valid programs.
  - Deliverables: add a new internal generator path such as `gen_expr(expected_results, env, fuel)`, `gen_stmt(env, stack, label_stack, fuel)`, and `gen_value(type, env, fuel)`; initially use it for a small subset of numeric/control/local instructions, then expand behind config flags.
  - Required APIs: `GenValidBodyEnv`, `Instruction`, `BlockType`, `ValType`, validator typechecking behavior in `src/validate/validate.mbt`.
  - Invariants: generated modules must validate without relying on retry as the normal path; use bounded fuel to avoid runaway recursion; keep deterministic generation for a seed.
  - Dependencies: [FUZ]1000 for diagnostics is strongly recommended.
  - Suggested Tests: focused tests for typed block result generation, typed `if`, branch payloads, local get/set/tee, unreachable stack-polymorphic regions, and validation of generated modules across several seeds.
  - Exit Criteria: at least one profile uses the typed generator for nontrivial bodies and records feature facts beyond the existing deterministic prelude.

- [FUZ]1003 - GenValid Module Topology And High-Index Generation
  - Goal: widen valid module shape beyond small mostly-low-index modules.
  - Why: many validator and optimizer bugs appear only with high index spaces, many functions, repeated imports/exports, nonzero table/memory indices, or odd custom-section placement.
  - Deliverables: generate many-function modules, high type/function/table/memory/global/tag/data/elem indices, multiple import modules, imported re-exports, repeated valid exports of the same index under distinct names, modules without `main`, modules without exports, and custom sections before/between/after standard sections where the binary model supports it.
  - Required APIs: `Module`, section builders in `src/lib`, binary encode/decode, `gen_valid_feature_facts(...)`, pass-fuzz batch emission.
  - Invariants: keep the current small profiles small; put high-index and many-function shapes behind explicit profile/config knobs; avoid producing modules that Binaryen cannot parse in the binary-oracle profile unless that profile explicitly opts into tool-failure exploration.
  - Dependencies: [FUZ]1001 profile taxonomy recommended.
  - Suggested Tests: feature-fact tests for high index/topology rows, encode/decode/validate roundtrips, a small `--generator gen-valid` pass-fuzz smoke on a topology-heavy profile.
  - Exit Criteria: a dedicated profile can reliably emit validated modules with nonzero index spaces and richer import/export/custom-section topology.

- [FUZ]1004 - GenValid Type, Subtyping, And GC Topology Widening
  - Goal: generate richer recursive types, subtype graphs, descriptors, structs, arrays, and exact-reference flows.
  - Why: current GC coverage is broad but still template-heavy. Optimizer and validator bugs often live in recursive type topology, descriptor pairing, defaultability, exact refs, and typed aggregate access.
  - Deliverables: add generation for rec groups of varied sizes, mutually recursive struct/array groups, deep chains, wide fanout, final/open subtype matrices, descriptor/describes pairs, descriptor edge cases that remain valid, packed and ref fields, mutable/immutable field mixes, arrays over packed/ref fields, and exact refs flowing through params/locals/globals/calls/blocks.
  - Required APIs: `RecType`, `SubType`, `CompType`, `FieldType`, `StorageType`, `TypeMetadata`, `RefType`, `HeapType`, GC instruction constructors, validation type environment.
  - Invariants: do not weaken subtype validation; keep official-vs-local caveats documented; ensure every generated exact non-null ref has a real construction path or safe fallback.
  - Dependencies: [FUZ]1002 helps produce diverse GC bodies but is not strictly required for type-section widening.
  - Suggested Tests: focused validation tests for each topology family, feature fact counters for exact-ref and descriptor flows, `moon test src/validate`, small pass-fuzz lanes against GC-sensitive passes.
  - Exit Criteria: natural or GC-heavy profiles organically produce multiple GC topology families without relying only on the coverage prelude.

- [FUZ]1005 - GenValid Control Flow, Multi-Value, And Branch Payloads
  - Goal: generate varied valid control-flow bodies with typed block/loop/if results and branch payloads.
  - Why: current branch-heavy coverage proves `br`, `br_if`, `br_table`, typed `select`, and wrappers exist, but not enough payload/result combinations are explored.
  - Deliverables: add generation for multi-value blocks, value-producing loops where valid, `br` with payloads, `br_if` with payload and fallthrough values, `br_table` with matching result arities, nested labels, unreachable stack-polymorphic tails, returns from nested control, and typed `select` over numeric/ref/v128 where valid.
  - Required APIs: typed body generator from [FUZ]1002, `BlockType`, `LabelIdx`, `Instruction::{Block,Loop,If,Br,BrIf,BrTable,Return,Select}`.
  - Invariants: label-depth and payload typing must be proven by validation tests; avoid unbounded recursion; preserve deterministic seeds.
  - Dependencies: [FUZ]1002.
  - Suggested Tests: one focused fixture per branch payload family, generated-module validation across seeds, pass-fuzz smoke for branch-sensitive passes such as `code-folding`, `remove-unused-brs`, and `simplify-locals`.
  - Exit Criteria: feature facts can distinguish simple branch-heavy coverage from payload-bearing multi-value control coverage.

- [FUZ]1006 - GenValid Call, Reference Call, Indirect Call, Recursion, And Tail-Call Widening
  - Goal: generate diverse valid call graphs and callable-reference flows.
  - Why: call-related optimizer bugs depend on direct calls, imported calls, recursion, call_indirect tables, call_ref values, and tail-call terminal placement. Current coverage is useful but too narrow.
  - Deliverables: generate recursive and mutually recursive functions, imported calls, multi-param/multi-result calls, calls with ref/v128 params/results, `call_indirect` through populated tables and nonzero table indices, `call_ref` from locals/globals/ref.func/block values, and direct/indirect/ref tail calls in deeper terminal positions.
  - Required APIs: function signature planning in `gen_valid_module_once_with_config`, table/elem generation, typed body generator, call and tail-call instruction constructors.
  - Invariants: every call target must have a matching signature; tail calls must appear only in valid terminal contexts; keep `ref.func` declaration requirements satisfied.
  - Dependencies: [FUZ]1002 and [FUZ]1007 for table-backed indirect-call diversity.
  - Suggested Tests: generated direct-call, recursive-call, call_indirect, call_ref, and return_call fixtures; pass-fuzz compare for `inlining`, `inlining-optimizing`, `dae-optimizing`, and `directize` on call-heavy profiles.
  - Exit Criteria: call-heavy generation exercises direct, indirect, ref, and tail-call surfaces in multiple structurally distinct ways.

- [FUZ]1007 - GenValid Memory, Table, Data, And Element Segment Widening
  - Goal: expand valid resource and segment generation beyond current first-memory/first-table-heavy shapes.
  - Why: memory/table/data/elem bugs often require nonzero indices, mixed active/passive/declarative segments, memory64/shared variants, typed tables, and bulk operations over varied targets.
  - Deliverables: generate nonzero memory/table operations, mixed memory32/memory64 modules, multiple shared memories, active data on different memories, passive data payload variety, `memory.copy` across different memories, `memory.init` over different data indices, multiple `data.drop`, table get/set/grow/size/fill/copy/init over nonzero tables, typed element expressions, nonzero active table targets, and table initializer expressions.
  - Required APIs: memory/table/data/elem section builders, `MemArg`, `MemType`, `TableType`, `Data`, `Elem`, bulk memory/table instructions.
  - Invariants: preserve Binaryen-oracle portability by gating memory64/shared/non-funcref table combinations; keep all offsets and payloads valid for validation even if runtime traps would occur.
  - Dependencies: [FUZ]1001 profiles recommended.
  - Suggested Tests: feature facts for nonzero memory/table/segment ranges, validation tests for memory64/shared/table typed variants, pass-fuzz compare for `memory-packing`, `remove-unused-module-elements`, `heap-store-optimization`, and table-sensitive passes.
  - Exit Criteria: memory-heavy and table-heavy profiles reliably produce validated modules with nonzero resource indices and mixed segment modes.

- [FUZ]1008 - GenValid Exception, Tag, Throw, ThrowRef, And TryTable Widening
  - Goal: generate a broader matrix of exception/tag and `try_table` shapes.
  - Why: current exception coverage proves mixed catch lists exist, but not enough tag payload, result type, nesting, and label-depth variation is exercised.
  - Deliverables: generate multiple imported/defined tags, tags with params, throws with nontrivial operands, `throw_ref` from catch-ref/local/block sources, void/numeric/ref result `try_table`, nested `try_table`, mixed catch/catch_all and catch_ref/catch_all_ref lists, multiple catch tags, and varied catch label depths.
  - Required APIs: `TagType`, `Catch`, `TryTable`, `Throw`, `ThrowRef`, typed body generator and label stack.
  - Invariants: generated catch targets must have valid payload arities; nullable `throw_ref` traps are runtime behavior, not validation failures; invalid nullability belongs in invalid lanes.
  - Dependencies: [FUZ]1002 and [FUZ]1005.
  - Suggested Tests: focused validation for each catch topology, feature facts for exact catch-list combinations, WAST mirror tests where parser support exists.
  - Exit Criteria: exception-heavy profiles produce more than the single deterministic matrix currently used by coverage-forced generation.

- [FUZ]1009 - GenValid Numeric Constants, Arithmetic, Conversion, And Trap-Safe Cleanup Surfaces
  - Goal: widen scalar numeric generation with safe boundary constants and operation combinations.
  - Why: optimizers need arithmetic, comparisons, conversions, reinterprets, saturation, NaNs, signedness, and boundary constants in realistic expression trees, not only isolated drop-wrapped operations.
  - Deliverables: generate full integer arithmetic and bit ops, shifts/rotates, comparisons, float unary/binary/comparison ops, reinterpret operations, sign-extension, saturating conversions, safe regular conversions, boundary constants (`0`, `1`, `-1`, min/max, powers of two), float `-0`, infinities, NaNs, and nontrivial expression trees.
  - Required APIs: numeric instruction constructors, typed body generator, feature scanner exact opcode counters from [FUZ]1013.
  - Invariants: valid generation must avoid compile-time invalidity; runtime-trapping operations may appear only if they are valid wasm and acceptable for the target lane; optimizer cleanup tests must preserve trap/effect ordering.
  - Dependencies: [FUZ]1002 and [FUZ]1013 recommended.
  - Suggested Tests: per-opcode coverage counters, validation of numeric-heavy modules, pass-fuzz compare for `precompute`, `optimize-instructions`, `pick-load-signs`, `dae-optimizing`.
  - Exit Criteria: numeric-heavy profiles prove exact opcode diversity and boundary literal coverage.

- [FUZ]1010 - GenValid SIMD Exact Opcode And Relaxed-SIMD Widening
  - Goal: extend SIMD generation from phase-level coverage to exact opcode and relaxed-SIMD coverage.
  - Why: the AST appears to represent relaxed SIMD, but current GenValid docs note relaxed SIMD is not emitted. Phase counters are too coarse to detect missing individual SIMD op families.
  - Deliverables: add exact SIMD opcode counters; emit relaxed SIMD behind an explicit toggle/profile; widen lane index coverage to min/max/middle legal lanes; thread v128 values through locals/params/results/select/block results where valid; add SIMD memory ops with varied memargs and nonzero memory indices where supported.
  - Required APIs: SIMD instruction constructors in `src/lib/types.mbt`, binary encoder/decoder, validator SIMD typing, `gen_valid_feature_facts(...)`.
  - Invariants: keep relaxed-SIMD disabled in Binaryen-oracle portable profiles unless tool support is proven; lane immediates in valid generation must stay in range.
  - Dependencies: [FUZ]1013 exact coverage ledger.
  - Suggested Tests: one validation fixture per relaxed SIMD subgroup, exact counter tests, pass-fuzz compare against `remove-relaxed-simd` once relevant, binary roundtrip for new opcodes.
  - Exit Criteria: SIMD coverage can report exact standard and relaxed opcode presence rather than only phase booleans.

- [FUZ]1011 - GenValid Atomic Instruction And Shared-Memory Matrix Widening
  - Goal: cover the full atomic operation matrix over valid shared memories.
  - Why: current coverage-forced atomics emit a curated subset. Atomic bugs depend on width, operation, alignment, shared-memory index, and ordinary-memory interactions.
  - Deliverables: generate every atomic load/store width, every RMW op and narrow width, cmpxchg widths, wait/notify/fence, nonzero shared memory indices, and mixed ordinary+atomic memory sequences.
  - Required APIs: atomic instruction constructors, `AtomicRmwOp`, `AtomicCmpxchgOp`, shared `MemType`, validator alignment/shared-memory rules, exact coverage counters.
  - Invariants: valid generation must use shared memories and valid alignments; invalid alignment/non-shared-memory cases belong in invalid AST/binary lanes.
  - Dependencies: [FUZ]1007 for memory widening and [FUZ]1013 for exact counters.
  - Suggested Tests: per-opcode atomic counter tests, validation fixtures for each op family, invalid-lane follow-ups for non-shared/invalid alignment, pass-fuzz compare on memory-heavy profiles.
  - Exit Criteria: atomic-heavy profiles can prove every represented atomic family is generated at least once over a bounded run.

- [FUZ]1012 - Randomized Coverage-Forced Templates
  - Goal: keep coverage-forced floors deterministic while varying the concrete templates used to satisfy them.
  - Why: today many forced surfaces are emitted by a predictable prelude. That is excellent for floors but can overfit optimizers and validators to one layout.
  - Deliverables: for each forced family, add several equivalent valid templates, randomize ordering and placement across functions/blocks, and record which template family was selected in feature facts or generation diagnostics.
  - Required APIs: coverage-forced prelude helpers in `src/validate/gen_valid.mbt`, feature facts, profile/config toggles.
  - Invariants: smoke must remain stable and fast; every required floor must still be satisfied deterministically for the same seed/config; template selection must not make Binaryen-oracle profile flaky.
  - Dependencies: [FUZ]1000 diagnostics and [FUZ]1013 exact coverage recommended.
  - Suggested Tests: deterministic seed tests, feature-floor tests across multiple seeds, generated-module validation, small pass-fuzz compare lanes for each randomized family.
  - Exit Criteria: coverage-forced mode no longer emits one fixed body shape for each major feature family, but still satisfies all configured floors.

- [FUZ]1014 - Coverage-Guided GenValid Selection
  - Goal: add a local coverage-guided generation loop that keeps modules which satisfy missing feature floors.
  - Why: hardcoded forced preludes do not scale to every future family. A generate-measure-select loop can target feature floors without hand-authoring every combination.
  - Deliverables: implement a helper like `generate_until_features(config, required_floors, max_attempts)`; support profile filters such as require/exclude feature; return selected modules plus coverage ledger and skipped-candidate stats.
  - Required APIs: generator diagnostics from [FUZ]1000, exact ledger from [FUZ]1013, `emit_gen_valid_batch_artifacts(...)`.
  - Invariants: deterministic for seed/config/filter; bounded attempts; clear failure message listing unmet floors.
  - Dependencies: [FUZ]1000 and [FUZ]1013.
  - Suggested Tests: synthetic floor selection tests, failure tests for impossible floors, batch emission using require/exclude filters, `moon test src/fuzz`.
  - Exit Criteria: agents can request “give me N modules with feature X and without feature Y” without manually tweaking generator internals.

- [FUZ]1015 - GenValid Batch Profiles, Feature Filters, And Input Manifests
  - Goal: make `--emit-gen-valid-batch` useful beyond the current Binaryen-oracle portable corpus.
  - Why: pass-fuzz compare and validator fuzzing need different valid-generator profiles, and every saved `.wasm` should carry its config and feature facts.
  - Deliverables: add `--gen-valid-profile`, `--require-feature`, `--exclude-feature`, and manifest emission for generated batches; write per-input records with file name, seed, index, config/profile, feature facts, and validation result.
  - Required APIs: `src/fuzz/main.mbt` parser, `scripts/lib/fuzz-task.ts` forwarding, feature ledger APIs, docs/tooling pages.
  - Invariants: default batch behavior and file names remain compatible; manifest emission should be opt-in or backward-compatible; invalid generated candidates must never be written as successful batch artifacts.
  - Dependencies: [FUZ]1001 and [FUZ]1013; [FUZ]1014 for filters if implemented first.
  - Suggested Tests: CLI parse tests, deterministic artifact/manifest tests, wrapper forwarding tests, `moon test src/fuzz`, script tests for `bun fuzz run --emit-gen-valid-batch`.
  - Exit Criteria: every generated batch can be replayed and understood from its manifest without regenerating feature facts.

- [FUZ]1016 - Pass-Fuzz Compare Generator Profiles, Replay Modes, And Failure Metadata
  - Goal: widen `bun fuzz compare-pass` so it can consume richer GenValid profiles and replay every failure status.
  - Why: compare-pass currently uses one gen-valid batch config and replays command failures only. Agents need profile selection, feature-aware inputs, and replay for mismatches/validation failures too.
  - Deliverables: add `--gen-valid-profile`, feature filters, manifest copying, replay by status (`mismatch`, `validation-failure`, `generator-failure`, `command-failure`, and optionally `match` by case index), and richer failure metadata with feature facts.
  - Required APIs: `scripts/lib/pass-fuzz-compare-task.ts`, `scripts/test/pass-fuzz-compare-command.ts`, batch manifest from [FUZ]1015.
  - Invariants: current `--generator both|wasm-smith|gen-valid` semantics remain; Binaryen/tool command failures must stay clearly classified as tool/generator issues, not semantic mismatches.
  - Dependencies: [FUZ]1015.
  - Suggested Tests: command parser tests, replay tests for non-command statuses using fake artifacts, result.json schema tests, smoke compare with a small gen-valid profile.
  - Exit Criteria: a saved pass-fuzz run is self-contained enough for another agent to replay any interesting case by status, class, feature, or case index.

- [FUZ]1017 - Command Harness Generator Profiles, Pass Profiles, And Idempotence Checks
  - Goal: turn `cmd-harness` into a stronger optimizer-pipeline fuzzer.
  - Why: `run_cmd_fuzz_harness(...)` currently uses natural GenValid and an optional pass list, but profiles do not exercise named generator configs, pass clusters, repeated passes, or idempotence by default.
  - Deliverables: add generator profile selection, pass-list profiles, each-pass and common-cluster modes, default-pipeline mode, optimize idempotence checks, encode/decode idempotence checks, pass minimization on failure, and richer persisted failure reports with config/feature facts.
  - Required APIs: `src/cmd/fuzz_harness.mbt`, `src/cmd/cmd.mbt`, `src/fuzz/main.mbt`, pass registry, `minimize_fuzz_passes(...)`, differential validators.
  - Invariants: smoke profile remains quick; failure callback stays backward-compatible; no destructive writes unless corpus/output dir is explicit.
  - Dependencies: [FUZ]1001, [FUZ]1013, [FUZ]1015 recommended.
  - Suggested Tests: profile parser tests, fake pass minimization tests, idempotence fixture tests, native differential-availability tests where supported.
  - Exit Criteria: `cmd-harness` can battle-test no-pass, single-pass, pass-cluster, and full-pipeline behavior over chosen generator profiles.

- [FUZ]1019 - Declarative Invalid Seed Prerequisites And Mixed Seed Profiles
  - Goal: make invalid strategy seed shaping data-driven and run invalid strategies over multiple base profiles.
  - Why: prerequisite widening is currently hardcoded in seed-config functions. As strategies grow, agents need a declarative way to request defined funcs, memories, passive data, names, refs, tags, tables, etc.
  - Deliverables: add prerequisite metadata to invalid strategy specs; derive `GenValidConfig` adjustments from prerequisites; run invalid fuzz profiles over minimal, repro, small-natural, small-coverage, natural, coverage-forced, and rich seed profiles as configured.
  - Required APIs: `src/validate/gen_invalid.mbt`, `src/fuzz/invalid_binary.mbt`, strategy registries, `GenValidConfig` profile constructors.
  - Invariants: existing default invalid fuzz behavior remains stable until profiles are explicitly widened; strategies must fail clearly when prerequisites are impossible.
  - Dependencies: [FUZ]1001 profiles; [FUZ]1018 variants recommended.
  - Suggested Tests: prerequisite-to-config tests, mixed seed profile stats tests, minimal/repro/natural seed generation tests for representative strategies.
  - Exit Criteria: adding a new invalid strategy no longer requires bespoke seed-config code unless the prerequisite is genuinely new.

- [FUZ]1020 - Invalid AST Strategy Expansion Across Validator Families
  - Goal: add deeper AST-invalid mutations for type, import, function, table, memory, tag, global, element, data, datacount, start, export, code, name, and function-body families.
  - Why: every family has at least one strategy, but many families need more per-rule coverage: subtype variance, descriptor cycles, branch payload mismatches, local/global/table/memory/tag indices, GC field errors, array errors, exception payloads, atomics, memory64 address typing, and body stack typing.
  - Deliverables: add a prioritized batch of AST variants with focused tests first; include repair checks where possible (`valid -> mutate -> reject`, then `repair -> accept`); update docs/wiki family summaries.
  - Required APIs: `src/validate/invalid_fuzzer.mbt`, `src/validate/gen_invalid.mbt`, validation diagnostics, exact strategy variants from [FUZ]1018.
  - Invariants: each mutation starts from a valid base unless explicitly testing structural section absence; expected family must be explicit; no strategy should count as coverage if mutation was not applicable.
  - Dependencies: [FUZ]1018 and [FUZ]1019 recommended.
  - Suggested Tests: one focused test per new strategy/variant, smoke required-strategy floor tests, invalid repro build/replay tests.
  - Exit Criteria: AST-invalid coverage includes multiple meaningful strategies in every validator family, not just one representative stable id.

- [FUZ]1021 - Invalid Binary Malformed-Byte Matrix
  - Status: IN PROGRESS (cron 23, 2026-05-20). Follow-up export descriptor index-LEB slice landed: `malformed-export-func-index-uleb`, `malformed-export-table-index-uleb`, `malformed-export-memory-index-uleb`, `malformed-export-global-index-uleb`, and `malformed-export-tag-index-uleb` are decode-rejected, non-smoke binary-invalid strategies that corrupt export descriptor index immediates with unterminated ULEBs across all represented export kinds, with registry entries, focused replay coverage, fuzz-hardening/LEB docs, and wiki log entry. TDD evidence: `moon test --package jtenner/starshine/fuzz --file invalid_binary_wbtest.mbt` failed before implementation on the missing export descriptor strategy registry/replay coverage, then passed after implementation. Earlier slices also landed the bulk-copy index-LEB strategies, `invalid-element-kind-byte` for passive/declarative function-index elemkind corruption, and `duplicate-function-section`, `duplicate-code-section`, `duplicate-element-section`, `duplicate-data-section`, and `duplicate-tag-section` for duplicate known-section decode rejection. Final validation for this slice ran `moon fmt`, `moon info` (pre-existing DAE unused warnings only), `moon test --package jtenner/starshine/fuzz --file invalid_binary_wbtest.mbt`, `moon test src/fuzz`, `moon test`, and `moon run src/fuzz -- validate-invalid-binary smoke --seed 0x5eed`. Remaining blocker: the task is intentionally broader than this slice; next run should continue with another malformed-byte family such as deeper section/vector count mismatches, malformed/overwide LEB carriers in more contexts, invalid lane immediates beyond the current SIMD lane cases, more UTF-8/name payload corruption, or additional section descriptor bytes without weakening stage-aware accounting.
  - Goal: turn binary-invalid fuzzing into a broad section/immediate-aware malformed-byte generator.
  - Why: current binary invalid coverage has a curated header/order/section core. Decoder hardening needs truncations, malformed LEBs, wrong counts, wrong payload lengths, invalid opcodes, bad prefixes, UTF-8 corruption, lane overflow, and memarg/alignment corruption across many contexts.
  - Deliverables: add corruptions for every section boundary, vector count mismatch, section size too small/large/off-by-one, duplicate/out-of-order known sections, malformed and overwide LEBs, invalid UTF-8 in names/imports/exports/custom sections, invalid opcode/prefix subopcode bytes, invalid heap/ref/blocktype encodings, invalid lane immediates, and invalid memargs.
  - Required APIs: byte mutation helpers in `src/fuzz/invalid_binary.mbt`, binary section scanner, LEB encode/decode helpers, invalid repro persistence.
  - Invariants: stage expectation must distinguish decode-rejected from decode-accepted validate-rejected; noncanonical-but-valid encodings should be tracked separately from true malformed bytes.
  - Dependencies: [FUZ]1018 variants recommended.
  - Suggested Tests: focused byte fixtures per corruption class, minimal repro builder tests, `run_validate_invalid_binary_fuzz("smoke", seed)`.
  - Exit Criteria: binary-invalid smoke/CI can prove coverage for many malformed byte classes rather than only the current curated set.

- [FUZ]1022 - Invalid Binary Validator-Rejected Encoded Modules
  - Goal: expand binary-invalid cases that decode successfully but fail validation for semantic reasons.
  - Why: encoded invalid AST modules currently cover several families, but body-level and proposal-heavy validation failures need more direct binary evidence.
  - Deliverables: add validator-rejected binary strategies for body stack mismatch, bad branch labels/payloads, bad local/global/table/memory/tag/type indices, invalid call_indirect/call_ref signatures, GC field/array errors, invalid exception payloads, atomic-on-non-shared memory, invalid memory64 address typing, invalid const expressions, and relaxed SIMD validation failures where represented.
  - Required APIs: AST invalid mutation helpers, direct binary builders where AST constructors cannot represent invalid states, `ValidateInvalidBinaryExpectedResult`.
  - Invariants: decode must succeed for these strategies; expected validation family and optional exact issue must be recorded.
  - Dependencies: [FUZ]1020 for AST mutations and [FUZ]1018 variants.
  - Suggested Tests: one decode-then-validate test per strategy, invalid binary fuzz stats tests, minimal repro artifact tests.
  - Exit Criteria: binary-invalid lane has a balanced split between malformed decode failures and validator-rejected decoded modules.

- [FUZ]1023 - Dynamic Invalid Text Mutation Lane
  - Goal: generate invalid WAT/WAST by mutating valid text instead of relying only on a static inline registry.
  - Why: `validate-invalid-text` is stable but mostly fixed. Parser/lowerer/validator bugs need token, syntax, index, type, opcode, string, memarg, lane, and module-field mutations over generated sources.
  - Deliverables: start from valid WAT/WAST generated by GenValid or WAST arbitrary; mutate one controlled surface; classify parse/lower rejected, validate rejected, valid-before-link, or unexpectedly accepted; record mutation kind and source feature facts.
  - Required APIs: `src/fuzz/invalid_text.mbt`, WAT/WAST printers/parsers, static assertion evaluator, GenValid text emission if available.
  - Invariants: keep existing static registry as smoke-stable; dynamic lane should be separate or stress/CI-gated; unexpected acceptance must persist repro artifacts.
  - Dependencies: [FUZ]1027 for better WAT/WAST reporting and [FUZ]1025 for artifact metadata recommended.
  - Suggested Tests: deterministic mutation tests for missing parens, bad opcode, bad type token, duplicate export, mutable global const init, bad lane, bad memarg; fuzz-runner suite tests.
  - Exit Criteria: text invalid fuzz can discover new parser/lowerer/validator failures from generated valid text, not just replay known inline strings.

- [FUZ]1025 - Invalid Repro Metadata, Variant Recording, And Actual Specimen Shrinking
  - Goal: make invalid repros record more context and shrink the actual generated failing specimen, not only the strategy's known minimal form.
  - Why: current repros are useful but reduction often jumps to a canned minimal artifact. Agents also need variant id, seed profile, generator config, feature facts, exact issue kind, and shrink lineage.
  - Deliverables: extend `InvalidFuzzFailureReport` metadata; record strategy variant, exact issue kind, generator config/profile, feature facts, and source artifact manifest; add delta-style shrinking for AST modules, binary bytes, text assertions, and spec-seed extracts while preserving expected stage/family/issue.
  - Required APIs: `src/fuzz/invalid_repro.mbt`, invalid strategy variants, feature ledger, binary/text/module persistence helpers.
  - Invariants: current metadata parser must remain backward-compatible or versioned; shrinkers must preserve the expected failure classification before replacing artifacts.
  - Dependencies: [FUZ]1018 variants and [FUZ]1013 feature facts recommended.
  - Suggested Tests: metadata roundtrip tests, backward compatibility tests, shrink-preserves-outcome tests for AST/binary/text/spec-seed reports.
  - Exit Criteria: a persisted invalid failure contains enough data to replay, understand, and minimize the actual failing specimen.

- [FUZ]1026 - Multi-Fault Invalid Stress Lane
  - Goal: add a separate stress-only invalid lane that combines multiple faults without requiring exact first-error stability.
  - Why: single-fault lanes are ideal for diagnostic oracles, but real malformed inputs often contain several independent problems. The validator should reject without crashing/hanging even when first-error family is not deterministic.
  - Deliverables: compose two or more AST/binary/text mutations; classify only broad outcome (`rejected`, `accepted`, crash/tool failure) unless a stable first family is intentionally tested; persist multi-fault repros with all mutation ids.
  - Required APIs: invalid AST/binary/text mutation helpers, fuzz runner suite registry, invalid repro metadata.
  - Invariants: do not mix multi-fault outcomes into single-fault expected-family floors; this lane should never weaken exact diagnostic tests.
  - Dependencies: [FUZ]1018 and [FUZ]1025 recommended.
  - Suggested Tests: deterministic two-fault examples, no-acceptance smoke tests, repro persistence tests.
  - Exit Criteria: stress fuzzing can exercise hostile multi-fault inputs while keeping diagnostic-stable lanes clean.

- [FUZ]1027 - WAT/WAST Roundtrip Reporting And GenValid Text Roundtrip Lanes
  - Goal: make WAT/WAST fuzzing report why cases fail and add lanes that roundtrip GenValid modules through text.
  - Why: current WAT/WAST roundtrip fuzz silently skips many failed generated cases and compares text by deleting all whitespace, which can hide useful parser/printer information.
  - Deliverables: count print failures, parse failures, roundtrip print failures, unstable text, script render failures, and no-module-command failures; add `GenValid -> WAT -> parse -> validate` and `GenValid -> WAST -> lower -> binary -> decode -> validate` lanes; improve normalization or compare parsed AST/module facts rather than raw whitespace-stripped text.
  - Required APIs: `src/wat/fuzz_tests.mbt`, `src/wast/fuzz_tests.mbt`, WAT/WAST parser/printer/lowerer, `gen_valid_module_with_config(...)`.
  - Invariants: existing smoke success thresholds remain reasonable; do not treat unsupported WAST text syntax as a validator failure.
  - Dependencies: [FUZ]1001 profiles and [FUZ]1000 diagnostics recommended.
  - Suggested Tests: stats tests for failure categories, stable normalization tests with strings/comments, GenValid text roundtrip validation tests.
  - Exit Criteria: WAT/WAST fuzz output tells agents which surface failed and can roundtrip typed GenValid modules through text when supported.

- [FUZ]1028 - WAST Arbitrary Parity Exact Coverage
  - Goal: align `src/wast/arbitrary.mbt` with the GenValid coverage vocabulary through exact counters and profile-specific WAST generation.
  - Why: WAST arbitrary intentionally does not call typed GenValid, but duplicated opcode pickers can drift from the FZG ledger.
  - Deliverables: add WAST arbitrary feature/opcode counters, floors for FZG mirror families, profiles for valid-only modules, parser-stress modules, static assertions, scripts, and module-only output; generate WAST assertion scripts where feasible.
  - Required APIs: `src/wast/arbitrary.mbt`, WAST printer/parser, `docs/wiki/fuzzing/wast-arbitrary-parity-plan.md`, feature ledger labels.
  - Invariants: do not claim WAST support for core instructions the local parser/printer cannot represent; keep unsupported text gaps documented.
  - Dependencies: [FUZ]1013 exact ledger and [FUZ]1027 reporting.
  - Suggested Tests: exact WAST opcode counter tests, parity floor tests, WAST parse-back tests for widened prelude, docs updates.
  - Exit Criteria: WAST arbitrary coverage can be compared against GenValid coverage by feature name and exact supported text shape.

- [FUZ]1029 - Binary Roundtrip Valid-Module, Byte-Fuzz, And Exact Coverage Lanes
  - Goal: supplement arbitrary value roundtrips with full valid-module binary roundtrips and decoder byte fuzzing.
  - Why: `run_binary_roundtrip_fuzz` roundtrips many arbitrary types, but agents also need full-module `GenValid -> encode -> decode -> validate -> encode` coverage and malformed byte decode stress.
  - Deliverables: add valid-module binary roundtrip suite, byte-fuzz suite with random and structured corruptions, exact instruction/section/immediate roundtrip counters, boundary corpus for LEBs, high indices, floats/NaNs, v128 lanes, and differential full-module decode with `wasm-tools` where available.
  - Required APIs: `src/binary/tests.mbt`, binary encode/decode, GenValid profiles, invalid binary corruption helpers, external validators for native lanes.
  - Invariants: arbitrary invalid modules from quickcheck should not be confused with valid-module generator failures; byte-fuzz decode failures are expected and should be classified.
  - Dependencies: [FUZ]1001 profiles and [FUZ]1021 byte matrix recommended.
  - Suggested Tests: focused roundtrip corpus tests, exact counter tests, byte-fuzz classification tests, native differential tests behind availability checks.
  - Exit Criteria: binary fuzzing covers full valid module roundtrips, arbitrary type roundtrips, and malformed bytes as separate measurable lanes.

- [FUZ]1031 - Standard Fuzz Output Directory And Corpus Workflow
  - Goal: standardize where fuzz runs store results, generated inputs, failures, manifests, and ledgers.
  - Why: pass-fuzz compare has useful artifact directories, while ordinary fuzz suites mostly print results or write specific repros. Agents need one predictable layout for long-running fuzz work.
  - Deliverables: add optional `--out-dir` for ordinary fuzz runs; write `result.json`, `cases.jsonl`, `generated/`, `failures/`, `feature-ledger.json`, `strategy-ledger.json`, and suite-specific manifests; document retention and replay behavior.
  - Required APIs: fuzz runner, invalid repro persistence, GenValid batch manifests, pass-fuzz metadata conventions.
  - Invariants: no output directory should be created unless explicitly requested or defaulted by a documented command; artifact paths must be repo-relative or clearly absolute in metadata.
  - Dependencies: [FUZ]1015 and [FUZ]1030 recommended.
  - Suggested Tests: output directory creation tests with fake IO where possible, metadata schema tests, docs updates in `docs/wiki/tooling/fuzz-runner.md`.
  - Exit Criteria: every fuzz suite can leave durable artifacts in a predictable directory when requested.

- [FUZ]1032 - External Differential Validation And Optional Semantic Execution
  - Goal: compare Starshine validation and optimized outputs against external validators/runtimes where available.
  - Why: internal validation plus Binaryen normalized text comparison is useful, but external validator and simple execution oracles can catch tool disagreements and semantic regressions earlier.
  - Deliverables: add optional native adapters for `wasm-tools validate`, Binaryen `wasm-validate`, and a runtime such as Wasmtime when available; instantiate modules with generated/stub imports; call exported functions with generated simple args; compare traps/results for Starshine-vs-Binaryen outputs in optional semantic mode.
  - Required APIs: `DifferentialAdapters`, command harness, pass-fuzz compare task, import stub generation, runtime command adapters.
  - Invariants: external tools must be optional and skipped clearly when unavailable; execution tests must not replace validation/parity tests; nondeterministic/runtime-trapping cases need conservative classification.
  - Dependencies: [FUZ]1017 command harness and [FUZ]1016 pass-fuzz metadata recommended.
  - Suggested Tests: fake adapter mismatch tests, unavailable-tool tests, simple executable fixture comparisons, docs updates.
  - Exit Criteria: native fuzz runs can opt into external validator/runtime evidence without making default smoke dependent on local tools.

- [FUZ]1033 - Optimizer Battle-Test Properties In Pass Fuzz
  - Goal: add property checks to pass-fuzz beyond one-shot Starshine-vs-Binaryen normalized output comparison.
  - Why: optimizer bugs often show up as non-idempotence, invalid output after repeated passes, or pass-order composition surprises even when a single direct comparison is green.
  - Deliverables: add optional modes for idempotence (`pass(pass(m)) == pass(m)` under normalization), repeated pass validation, selected pass composition checks, Starshine self-comparison of pass order where intended, and saved artifacts for property failures.
  - Required APIs: `scripts/lib/pass-fuzz-compare-task.ts`, pass flag parser, canonicalization/normalization helpers, result schema.
  - Invariants: do not confuse property failures with Binaryen semantic mismatches; classify and report them separately; keep direct pass signoff defaults unchanged.
  - Dependencies: [FUZ]1016 replay/metadata improvements recommended.
  - Suggested Tests: command parser tests for property flags, fake normalizer property tests, small real pass smoke with `--check-idempotent`.
  - Exit Criteria: agents can battle-test passes for repeatability and composition robustness using the same artifact/replay workflow as compare-pass.

- [FUZ]1034 - Deterministic PRNG Stream Split And Repro Audit
  - Goal: make every generator and harness consume randomness through named deterministic substreams.
  - Why: widening GenValid and invalid fuzzing will otherwise make old seeds drift whenever a new choice is inserted early in generation. Named streams let agents add one family without invalidating unrelated repros.
  - Deliverables: define stream labels for module topology, types, funcs, bodies, memories, tables, data, elems, invalid strategy choice, invalid mutation choice, text mutation choice, and harness shuffling; record stream labels and seed derivation in manifests.
  - Required APIs: generator random helpers in `src/validate/gen_valid.mbt`, invalid strategy runners, fuzz runner seed parsing, batch manifests.
  - Invariants: same root seed/profile must remain deterministic; old public seed behavior should either be preserved or migrated with an explicit manifest version.
  - Dependencies: [FUZ]1000 and [FUZ]1015 recommended for recording the stream map.
  - Suggested Tests: same-seed determinism tests, add-choice-does-not-change-unrelated-stream tests using a fake stream, manifest seed-derivation roundtrip tests.
  - Exit Criteria: a repro can identify which stream made the interesting choice, and adding new choices in one family does not churn unrelated generated modules.

- [FUZ]1035 - Generator Fuel, Size Budgets, And Pathological Shape Stress
  - Goal: add explicit size/fuel budgets and separate pathological-but-valid stress profiles.
  - Why: a typed generator needs recursion limits, but validators and optimizers also need safe exposure to deep nesting, large vectors, wide type graphs, and large local/function counts.
  - Deliverables: introduce budget knobs for instruction count, expression depth, block depth, rec-group depth, section counts, byte-size target, local count, name length, and segment payload size; add stress profiles that approach limits without becoming default smoke behavior.
  - Required APIs: `GenValidConfig`, typed body generator from [FUZ]1002, module topology generation, fuzz runner profile selection.
  - Invariants: every budget must be bounded; smoke/CI defaults must stay fast; pathological profiles must report when a candidate was skipped for size/fuel instead of silently retrying forever.
  - Dependencies: [FUZ]1000 diagnostics and [FUZ]1002 typed generation recommended.
  - Suggested Tests: budget cap tests, deterministic skip diagnostics, deep-nesting valid fixture, large-vector valid fixture, timeout-free fuzz smoke.
  - Exit Criteria: agents can intentionally request small, medium, large, or pathological valid modules and understand which budget stopped growth.

- [FUZ]1036 - Metamorphic Valid Module Transformer Suite
  - Goal: generate new valid test cases by applying semantics-preserving rewrites to already-valid modules.
  - Why: mutating valid modules in controlled ways exercises encoders, validators, and optimizers without requiring every shape to be born directly from GenValid.
  - Deliverables: add metamorphic transforms such as renaming locals/exports, inserting dead functions/globals, wrapping expressions in identity blocks, adding harmless drops, reordering independent custom sections, splitting/merging local declarations, duplicating equivalent types, and adding unused passive segments where valid.
  - Required APIs: module traversal/edit helpers, validator, binary/text printers, feature facts.
  - Invariants: each transform must validate the output before returning success; transforms that alter observable semantics must be excluded or explicitly marked semantic-risky.
  - Dependencies: [FUZ]1013 for recording transform facts; [FUZ]1033 for property-style checks recommended.
  - Suggested Tests: one fixture per transform, `valid -> transform -> validate`, encode/decode roundtrip after transform, pass-fuzz smoke using transformed cases.
  - Exit Criteria: fuzz harnesses can request N transformed variants per generated seed and classify failures by transform id.

- [FUZ]1037 - Const Expression And Initializer Expression Matrix
  - Goal: cover all valid constant-expression and initializer-expression contexts with a shared generator.
  - Why: globals, element offsets, data offsets, table initializers, GC descriptors, and future proposal features each have subtly different expression constraints. Bugs often live at the boundary between ordinary body expressions and const-only expressions.
  - Deliverables: implement a const-expression generator that knows allowed op families per context; cover numeric constants, `ref.null`, `ref.func`, `global.get` for imported immutable globals, GC initializer forms where valid, i31 refs, and boundary offsets for memory/table segments.
  - Required APIs: global/table/data/elem builders, validator const-expression rules, GenValid facts, invalid const-expression mutations.
  - Invariants: const-expression generation must not accidentally use ordinary body-only instructions; invalid const-expression cases belong in [FUZ]1020/[FUZ]1022.
  - Dependencies: [FUZ]1004 GC widening and [FUZ]1007 segment widening recommended.
  - Suggested Tests: valid fixture per initializer context, invalid fixture per disallowed instruction family, binary/text roundtrip for const expressions.
  - Exit Criteria: initializer expressions are generated from a common matrix and feature facts identify which contexts and op forms appeared.

- [FUZ]1038 - Import, Export, Name, String, And Custom Section Stress
  - Goal: widen non-code module metadata surfaces without mixing them into body-generation work.
  - Why: import/export names, custom sections, name sections, UTF-8 strings, duplicates, long strings, empty names, and unusual module names are common decoder/parser/optimizer edge cases.
  - Deliverables: generate empty and long valid names, Unicode names, repeated imported module names, many exports under distinct names, export aliases, name-section function/local/label names, unknown custom sections with varied placement, and payloads containing arbitrary bytes.
  - Required APIs: import/export/name/custom-section types, binary encoder/decoder, text printer/parser where names are represented.
  - Invariants: valid mode must keep export names unique where required; invalid duplicate/name/UTF-8 cases should be routed to invalid binary/text lanes.
  - Dependencies: [FUZ]1003 topology widening and [FUZ]1021 binary malformed-byte matrix recommended.
  - Suggested Tests: encode/decode/name preservation fixtures, duplicate-export invalid fixture, Unicode string text/binary roundtrip tests, custom-section placement tests.
  - Exit Criteria: metadata-heavy profiles produce measurable name/custom-section coverage without needing large function bodies.

- [FUZ]1039 - Start Function, Global Init, Element Init, And Data Init Interaction Profiles
  - Goal: exercise valid and invalid initialization-time interactions as a first-class fuzz surface.
  - Why: start functions, imported immutable globals, active element/data offsets, table initializers, passive segment drops, and memory/table counts interact across sections and are easy to under-test.
  - Deliverables: add profiles with and without start functions, start functions that call helpers, global initializers depending on imports, active data/elem offsets using imported globals, table initializers using `ref.func` and typed refs, and invalid counterparts for missing imports or wrong initializer types.
  - Required APIs: start/global/data/elem generation, const-expression generator from [FUZ]1037, import planning, invalid strategy prerequisites.
  - Invariants: valid start functions must have type `[] -> []`; initializer expressions must validate under official section-order rules.
  - Dependencies: [FUZ]1037 and [FUZ]1019 recommended.
  - Suggested Tests: valid start/global/segment fixtures, invalid wrong-start-type and wrong-offset-type fixtures, pass-fuzz smoke for passes that remove unused elements.
  - Exit Criteria: initialization-heavy modules can be generated reproducibly and invalid tests cover the common bad cross-section references.

- [FUZ]1040 - Effect And Trap Feature Facts For Optimizer Oracles
  - Goal: annotate generated modules with approximate effect/trap facts for safer mismatch classification.
  - Why: pass-fuzz mismatches cannot be judged solely by validation and size. Agents need to know whether a case contains calls, memory effects, table effects, globals, throws, atomics, traps, unreachable code, or floating NaNs before deciding if a transform is semantic-risky.
  - Deliverables: add feature facts for side effects, possible traps, memory/table/global mutation, imported calls, exceptions, atomics, nondeterministic host imports, NaN-sensitive float ops, and unreachable stack-polymorphic regions.
  - Required APIs: instruction scanner, feature ledger, pass-fuzz result schema, command harness reports.
  - Invariants: facts are conservative; `mayTrap=false` must only be used when confidently proven, otherwise default to `unknown/mayTrap`.
  - Dependencies: [FUZ]1013 exact coverage ledger and [FUZ]1016 pass-fuzz metadata.
  - Suggested Tests: scanner fixtures for each effect family, conservative unknown tests, result.json fact propagation tests.
  - Exit Criteria: mismatch reports include enough effect/trap context for agents to prioritize semantic review.

- [FUZ]1041 - Pass-Targeted GenValid Profiles From Pass Preconditions
  - Goal: create generator profiles tailored to the preconditions and sensitive surfaces of individual optimizer passes.
  - Why: one broad generator wastes time when signing off a pass. Each pass needs dense coverage of the shapes it is supposed to rewrite and the barriers it must not cross.
  - Deliverables: add profile recipes for `precompute`, `optimize-instructions`, `simplify-locals`, `vacuum`, `remove-unused-*`, `dae`, `inlining`, `code-folding`, `directize`, memory passes, GC passes, and tail-call/control passes; document each pass's required features, barriers, and known Binaryen portability constraints.
  - Required APIs: pass registry, GenValid profile taxonomy, feature filters, pass-fuzz compare task.
  - Invariants: targeted profiles are additive and do not change generic smoke defaults; profile names must be stable enough for docs and CI.
  - Dependencies: [FUZ]1001, [FUZ]1013, and [FUZ]1016.
  - Suggested Tests: profile lookup tests, feature-floor tests per pass profile, tiny compare-pass smoke for representative profiles.
  - Exit Criteria: pass signoff can request a named profile that densely exercises the pass's intended rewrite and no-rewrite cases.

- [FUZ]1042 - Corpus Promotion, Quarantine, And Regression Replay Workflow
  - Goal: define how interesting fuzz findings become durable regression inputs.
  - Why: without a promotion workflow, agents either lose valuable seeds or commit noisy unminimized corpora. A quarantine lane keeps known tool failures and accepted semantic-safe divergences from blocking unrelated work.
  - Deliverables: add corpus directories or docs for promoted-valid, promoted-invalid, pass-mismatch, tool-failure, accepted-divergence, and quarantine cases; store metadata with source run, seed, profile, feature facts, classification, and replay command; add a replay-all task.
  - Required APIs: fuzz output dirs from [FUZ]1031, invalid repro metadata, pass-fuzz result schema, docs/wiki corpus page.
  - Invariants: no large or private artifacts should be committed accidentally; every promoted case must have a human-readable reason and replay command.
  - Dependencies: [FUZ]1031 and [FUZ]1016 recommended.
  - Suggested Tests: metadata schema tests, replay command parser tests, small promoted fixture replay in CI.
  - Exit Criteria: agents know whether to promote, quarantine, or discard a fuzz artifact and can replay all promoted cases deterministically.

- [FUZ]1043 - Cross-Harness Failure Minimizer And Case Reducer
  - Goal: share shrinking/minimization logic across GenValid, invalid fuzzing, command harness, and pass-fuzz compare.
  - Why: every harness currently risks inventing its own minimizer. Shared reduction makes failures smaller and more comparable across validator, parser, binary, and optimizer lanes.
  - Deliverables: implement a common reduction interface with predicates for validation failure, parse failure, pass mismatch, command crash, and property failure; support module-level deletion, function deletion, section deletion where legal, instruction subtree replacement, byte-slice deletion, and text token deletion.
  - Required APIs: invalid shrinking from [FUZ]1025, pass-fuzz artifacts, module traversal/edit helpers, binary/text persistence helpers.
  - Invariants: minimization must never replace the original artifact unless the predicate still reproduces; store original and reduced artifacts separately.
  - Dependencies: [FUZ]1025 and [FUZ]1031.
  - Suggested Tests: fake predicate reducer tests, known fixture reductions, original-vs-reduced metadata roundtrip tests.
  - Exit Criteria: any fuzz harness can hand a failure to one reducer and get a smaller reproducible artifact plus shrink log.

- [FUZ]1044 - N-Way Binary Parser And Validator Differential
  - Goal: compare Starshine binary decode/validate results against multiple external tools when available.
  - Why: Binaryen alone is not a complete oracle. WABT, wasm-tools, and Starshine may disagree on proposal support, malformed encodings, canonical LEB policy, and diagnostic staging.
  - Deliverables: add optional adapters for `wasm-tools validate`, WABT `wasm-validate`, and Binaryen `wasm-validate`; classify agree-valid, agree-invalid, proposal-gap, decoder-stage disagreement, validator-stage disagreement, tool-failure, and unsupported-feature.
  - Required APIs: external adapter layer from [FUZ]1032, invalid binary lane, valid-module binary roundtrip lane, result schema.
  - Invariants: external tool absence must skip cleanly; proposal support differences must be reported, not auto-labeled as Starshine bugs.
  - Dependencies: [FUZ]1029 and [FUZ]1032.
  - Suggested Tests: fake adapter classification tests, unavailable-tool tests, known malformed binary disagreements, docs for supported tool versions.
  - Exit Criteria: binary fuzz runs can provide n-way evidence for decode/validation behavior without hard-requiring every external tool.

- [FUZ]1045 - N-Way Text Printer, Parser, And Lowering Differential
  - Goal: compare WAT/WAST parsing, printing, and lowering against external text tools when available.
  - Why: local text support can drift from WABT or wasm-tools in syntax, abbreviation handling, name resolution, blocktype/typeuse forms, and assertion scripts.
  - Deliverables: add optional adapters for WABT `wat2wasm`/`wasm2wat` and wasm-tools text commands; classify parse disagreement, print disagreement, lower disagreement, unsupported syntax, and semantic validation disagreement; store both text and binary artifacts.
  - Required APIs: WAT/WAST fuzzing from [FUZ]1027, external adapters, text artifact persistence.
  - Invariants: whitespace-only differences are not failures; unsupported local syntax must be separated from validation failures.
  - Dependencies: [FUZ]1027 and [FUZ]1032.
  - Suggested Tests: fake text adapter tests, abbreviation fixtures, name-resolution fixtures, unavailable-tool skip tests.
  - Exit Criteria: text fuzzing can explain whether a failure is local parser/printer behavior, external tool disagreement, or true validation divergence.

- [FUZ]1046 - Proposal Feature Gate Positive And Negative Matrix
  - Goal: test every proposal/feature toggle with both accepted and rejected examples.
  - Why: GenValid enables many modern wasm features, but validators must also reject proposal instructions/types when disabled and accept them when enabled.
  - Deliverables: define a feature-gate matrix for GC, function references, tail calls, exceptions, SIMD, relaxed SIMD, atomics, bulk memory, multi-memory, memory64, extended const, reference types, and any local proposal flags; generate one positive and one negative fixture per gate.
  - Required APIs: feature toggles, validator feature checks, invalid AST/binary strategies, docs/wiki coverage ledger.
  - Invariants: negative tests must fail because of the disabled feature, not because the module is otherwise malformed; positive tests must validate under the matching feature set.
  - Dependencies: [FUZ]1013 exact ledger and [FUZ]1020 invalid AST expansion.
  - Suggested Tests: per-feature enabled/disabled fixtures, exact issue-kind expectations where available, CLI profile tests for feature toggles.
  - Exit Criteria: adding or changing a feature gate requires updating one obvious matrix and its positive/negative tests.

- [FUZ]1047 - Normalization And Canonicalization Oracle Audit
  - Goal: audit the normalization layers used by pass-fuzz compare so they do not hide real semantic differences or report known harmless representation noise.
  - Why: normalized text, raw wasm, canonical text, debug stripping, NaN formatting, default locals, block wrappers, and name sections can all affect mismatch classification.
  - Deliverables: document each normalization step; add fixtures for debug-only differences, default-local initialization, NaN payload/printing, equivalent block wrappers, local/name stripping, custom sections, and order-stable section printing; report which normalizer decided equality.
  - Required APIs: compare-pass canonicalization helpers, Binaryen output capture, Starshine text/binary printers, docs/tooling pages.
  - Invariants: do not expand normalization to semantic-risky rewrites without proof; preserve raw artifacts for human review.
  - Dependencies: [FUZ]1016 pass-fuzz failure metadata and [FUZ]1040 effect/trap facts.
  - Suggested Tests: one equality/inequality fixture per normalization rule, result schema tests showing raw and normalized hashes.
  - Exit Criteria: agents can tell whether a mismatch disappeared due to a documented harmless normalization rule or a potentially risky oracle choice.

- [FUZ]1048 - Fuzz Result Trend Reports And Coverage Deltas
  - Goal: compare fuzz coverage and outcomes across commits, seeds, and profiles.
  - Why: broad generator work can accidentally remove surfaces while all tests still pass. Trend reports make coverage regressions visible.
  - Deliverables: write summary JSON for feature/opcode counters, strategy counters, pass statuses, failure classes, timings, and artifact counts; add a diff tool that compares two reports and highlights lost required/optional coverage.
  - Required APIs: fuzz JSON reports from [FUZ]1030, exact ledger from [FUZ]1013, pass-fuzz result schema, docs/wiki tooling.
  - Invariants: report comparison must tolerate newly added optional counters; required counter drops should fail only when a profile declares that floor.
  - Dependencies: [FUZ]1013 and [FUZ]1030.
  - Suggested Tests: report diff tests, optional-counter compatibility tests, fake coverage regression tests.
  - Exit Criteria: CI or agents can show “what coverage changed?” after a generator edit.

- [FUZ]1049 - Parallel Long-Run Fuzz Queue And Stable Merge
  - Goal: support long fuzz runs that execute shards in parallel and merge results deterministically.
  - Why: seed sweeps and wide profiles will outgrow single-process interactive runs. Agents need parallelism without nondeterministic result ordering.
  - Deliverables: add a work queue for suites/seeds/profiles; run shards independently; merge `result.json`, `cases.jsonl`, ledgers, minimized failures, and manifests in stable seed/profile/suite order; include resume behavior for completed cases.
  - Required APIs: fuzz runner sharding from [FUZ]1030, output directory workflow from [FUZ]1031, Bun task wrappers.
  - Invariants: no two workers should write the same artifact path; merged outputs must be deterministic independent of completion order.
  - Dependencies: [FUZ]1030 and [FUZ]1031.
  - Suggested Tests: fake queue merge tests, deterministic order tests, interrupted-run resume tests.
  - Exit Criteria: a long fuzz run can be split across workers and later inspected as one stable report.

- [FUZ]1050 - Corpus Deduplication, Interestingness Hashes, And Case Index
  - Goal: prevent fuzz artifact directories and promoted corpora from filling with duplicate or equivalent cases.
  - Why: wide generation will produce many modules that are byte-distinct but structurally or semantically redundant. Dedup keeps review and CI costs manageable.
  - Deliverables: compute hashes for raw bytes/text, decoded module shape, feature facts, normalized canonical form, failure predicate, and reduced artifact; maintain an index mapping hash to source seeds and profiles; define an interestingness score for rare features or new failure classes.
  - Required APIs: feature ledger, normalizers, output directory manifests, corpus workflow.
  - Invariants: never delete the only artifact for an unreduced failure; dedup decisions must be recorded and reversible for debugging.
  - Dependencies: [FUZ]1031, [FUZ]1042, and [FUZ]1047.
  - Suggested Tests: duplicate artifact fixtures, structurally-same/raw-different fixtures, index roundtrip tests.
  - Exit Criteria: repeated fuzz runs can skip or compress duplicate artifacts while preserving reproduction metadata.

- [FUZ]1051 - Checked-In Fuzz Recipes And Config Schema
  - Goal: move complex fuzz command combinations into versioned recipes.
  - Why: long CLI invocations for GenValid profiles, pass filters, feature floors, seed sweeps, external tools, and output dirs are easy to mistype and hard to reproduce.
  - Deliverables: define a JSON or TOML recipe schema for suite, seeds, profiles, filters, harness options, external adapters, budgets, and artifact policy; add checked-in recipes for smoke, CI, nightly, pass-signoff, validator-stress, parser-stress, and Binaryen-oracle runs.
  - Required APIs: fuzz runner CLI, Bun task wrappers, profile taxonomy, docs/tooling pages.
  - Invariants: explicit CLI flags should override recipe fields predictably; recipes must record schema version.
  - Dependencies: [FUZ]1001, [FUZ]1030, and [FUZ]1031.
  - Suggested Tests: recipe parse tests, override precedence tests, invalid recipe diagnostics, docs examples.
  - Exit Criteria: agents can launch standard fuzz scenarios by recipe name and get reproducible settings.

- [FUZ]1052 - Runtime Import Stub Generator And Export Invocation Matrix
  - Goal: enable optional execution oracles by generating host stubs and calls for exported functions.
  - Why: validation and text/binary parity cannot prove semantic equivalence for optimizer outputs. Simple execution across generated inputs catches many wrong-code bugs when runtime tooling is available.
  - Deliverables: generate deterministic imports for numeric/ref/global/table/memory functions where feasible; choose simple argument vectors for exported functions; execute Starshine and Binaryen outputs under the same runtime; classify equal result, equal trap, runtime unsupported, nondeterministic import, and semantic mismatch.
  - Required APIs: external runtime adapter from [FUZ]1032, import planning, effect/trap facts from [FUZ]1040, pass-fuzz result schema.
  - Invariants: execution remains opt-in; imports with host side effects or nondeterminism must be stubbed conservatively or skipped.
  - Dependencies: [FUZ]1032 and [FUZ]1040.
  - Suggested Tests: simple add/export execution fixture, equal-trap fixture, unsupported-import skip test, fake runtime mismatch test.
  - Exit Criteria: selected pass-fuzz runs can produce semantic execution evidence for simple generated modules.

- [FUZ]1053 - Resource-Limit, Timeout, And Nontermination Hardening
  - Goal: make every fuzz harness classify timeouts and resource exhaustion safely.
  - Why: deep generated modules, malformed binaries, parser corner cases, and external tools can hang or consume excessive memory. Fuzzing should find and report those cases without wedging CI.
  - Deliverables: add per-case time budgets, total run budgets, memory/byte-size limits where available, cancellation paths, timeout classifications, and minimized timeout repro artifacts.
  - Required APIs: fuzz runner, pass-fuzz task runner, external adapter subprocess wrappers, output report schema.
  - Invariants: timeout must be reported separately from semantic mismatch, validation failure, or crash; default smoke budgets must be conservative.
  - Dependencies: [FUZ]1030 and [FUZ]1031.
  - Suggested Tests: fake hanging adapter test, timeout report schema test, partial artifact cleanup test.
  - Exit Criteria: a hanging parser/validator/tool case produces a clear timeout artifact instead of blocking the full fuzz run.

- [FUZ]1054 - Local Declaration, Param/Result, And Body Layout Widening
  - Goal: stress function-body layout details that are distinct from instruction semantics.
  - Why: local declaration grouping, many locals, zero locals, mixed param/result arities, unused locals, shadowed names, and locals of every supported type can reveal encoder, decoder, validator, and optimizer bugs.
  - Deliverables: generate varied local-declaration groups, high local indices, mixed value types including refs/v128, unused and write-only locals, multi-result functions, empty bodies where valid, unreachable bodies with declared results, and text name-section local names.
  - Required APIs: function builder, local index planning, typed body generator, binary encoder/decoder, name-section support.
  - Invariants: body expressions must still satisfy declared result arity; high local profiles must remain budget-gated.
  - Dependencies: [FUZ]1002 typed body generation and [FUZ]1035 budgets.
  - Suggested Tests: local grouping binary roundtrip tests, high-local validation fixtures, optimizer smoke for `simplify-locals` and `vacuum`.
  - Exit Criteria: local/body-layout coverage is measurable separately from opcode coverage.

- [FUZ]1055 - Multi-Module WAST, Linking, Unlinkable, And Instantiation Lanes
  - Goal: treat multi-module scripts and link-time behavior as a distinct fuzz target.
  - Why: validation accepts individual modules, but WAST assertions and real tooling also care about imports, exports, duplicate module names, register commands, instantiation, and unlinkable modules.
  - Deliverables: generate WAST scripts with multiple modules, module names, register commands, import/export wiring, `assert_unlinkable`, valid linked pairs, and intentionally missing or type-mismatched imports.
  - Required APIs: WAST arbitrary generator, static assertion evaluator, text parser/lowerer, import/export planning.
  - Invariants: unlinkable cases must be classified separately from invalid modules; unsupported WAST script commands should be skipped with explicit counters.
  - Dependencies: landed dynamic spec-seed scanner/CI floors and [FUZ]1027 WAST reporting.
  - Suggested Tests: two-module valid link fixture, missing-import unlinkable fixture, type-mismatch unlinkable fixture, register command fixture.
  - Exit Criteria: WAST fuzzing can exercise link-time behavior without conflating it with validation failures.

- [FUZ]1056 - Parser Recovery, Error Span, And Diagnostic Location Fuzzing
  - Goal: verify that parser and decoder errors include stable, useful locations when possible.
  - Why: invalid fuzzing currently emphasizes accept/reject and diagnostic family. Developer productivity also depends on error spans, byte offsets, section ids, line/column info, and stable first-error behavior.
  - Deliverables: add optional expected byte offset/section/line/column checks for curated invalid binary/text cases; fuzz malformed inputs near boundaries; persist diagnostic location metadata in repros.
  - Required APIs: binary decoder diagnostics, WAT/WAST parser diagnostics, invalid text/binary strategy specs, repro metadata.
  - Invariants: location assertions should be exact only for curated stable cases; randomized lanes may record locations without requiring exact match.
  - Dependencies: [FUZ]1018 exact diagnostic expectations and [FUZ]1025 repro metadata.
  - Suggested Tests: malformed section offset fixture, bad text token line/column fixture, diagnostic metadata roundtrip tests.
  - Exit Criteria: diagnostic regressions in locations can be caught for stable invalid fixtures while fuzz artifacts still record best-effort positions.

- [FUZ]1057 - Binary Canonical Versus Noncanonical Encoding Policy
  - Goal: decide and test how the binary decoder handles noncanonical-but-well-formed encodings.
  - Why: malformed byte fuzzing needs to distinguish truly invalid encodings from encodings that some tools accept but canonical encoders do not emit, especially overwide LEBs, section lengths, blocktypes, and immediates.
  - Deliverables: document canonicality policy; add fixtures for canonical LEBs, overwide LEBs, signed LEB boundary forms, section size encodings, NaN payload preservation, and custom-section byte preservation; classify external tool disagreements as canonicality-policy differences when appropriate.
  - Required APIs: binary decoder/encoder, invalid binary strategy specs, external binary differential from [FUZ]1044.
  - Invariants: encoder should keep emitting canonical encodings unless explicitly configured otherwise; decoder acceptance/rejection must be consistent and documented.
  - Dependencies: [FUZ]1021 malformed-byte matrix and [FUZ]1044 n-way binary differential.
  - Suggested Tests: LEB canonicality fixtures, roundtrip canonicalization tests, external disagreement classification tests.
  - Exit Criteria: fuzz reports stop treating canonicality policy decisions as ambiguous decoder bugs.

- [FUZ]1058 - Fuzzer Self-Tests, Golden Seeds, And Deterministic Example Catalog
  - Goal: maintain a small catalog of seeds/examples that prove each major fuzz surface still works.
  - Why: large random runs are poor smoke tests. Future agents need fast deterministic examples for GenValid profiles, invalid variants, text mutation, binary corruption, pass-fuzz metadata, and minimization.
  - Deliverables: add golden seeds for each profile/family, expected feature/strategy counters, expected artifact names, and a docs page explaining what each seed is meant to cover.
  - Required APIs: GenValid profiles, invalid strategy ledgers, fuzz runner reports, batch manifests.
  - Invariants: golden seeds should be few and intentionally maintained; broad coverage remains the job of CI/stress fuzz, not the catalog.
  - Dependencies: [FUZ]1013 exact ledger and [FUZ]1030 detailed reports.
  - Suggested Tests: golden seed smoke suite, expected counter snapshots with controlled update process, docs sync test if available.
  - Exit Criteria: a quick deterministic suite tells agents whether the fuzzer infrastructure itself regressed before they launch long runs.
