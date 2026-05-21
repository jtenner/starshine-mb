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
- Latest diagnostic timing is over the 2x target for the current Func509 artifact: `2791.086ms` Starshine pass versus `843.419ms` Binaryen pass for `.tmp/dae006-outer-block-suffix2-20260526`. Per user direction, keep prioritizing correctness/frontier classification over pass time for now.
- Latest docs/backlog closure validation for `[DAE]006` on 2026-05-26: `git diff --check`, `moon info`, `moon fmt`, and `moon test` passed; `moon info` still reports existing unused DAE helper warnings. Latest pass-behavior validation before commit `0196531d` remains the script compare tests, `wasm-opt --all-features .tmp/dae-func447-normalized-artifact/starshine.wasm`, `moon info`, `moon fmt`, and `moon test`.
- `[DAE]007` compare-tool normalization hygiene is closed for the current diagnostic helper: the canonical-function fallback now uses an explicit ordered normalizer list instead of a deeply nested call chain, with a diagnostic-only comment at the artifact-family cleanup point and unchanged fixture coverage.
- `[DAE]010` direct fuzz refresh is closed for the latest pass logic as of 2026-05-25: `.tmp/pass-fuzz-dae-optimizing-dae010-20260525-full2` compared `9975/10000`, with `6078` normalized matches, `3897` normalized mismatches, `0` validation failures, and `25` Binaryen/tool command failures (`22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, `1` `binaryen-invalid-tag-index`). Agent classification: all mismatches are `gen-valid` size-winning semantic-safe raw-cleanup drift from Starshine stripping the generator's leading dropped pure/nontrapping constant debris while Binaryen preserves it; all `wasm-smith` cases that Binaryen accepted matched.
- `[DAE]008` Func237 historical frontier closure is closed as of 2026-05-25: the strategy now records landed Func237 selected local/control slices through `.tmp/dae-func237-common-branch-final-artifact`, the known reverted/deferred probes from research note `0570`, and the superseding direct debug-artifact frontiers (`defined=242`, then later `defined=505` in both-canonical diagnostics). Func237 is no longer an active leading blocker; reopen only with a new current-frontier Func237 repro.
- `[DAE]014` latest source/index sync is closed as of 2026-05-26: `docs/wiki/binaryen/passes/dae-optimizing/index.md` and `starshine-strategy.md` now link research notes `0576` through `0591` and record the current Func509 diagnostic frontier as a lowerer/diagnostic boundary rather than a DAE final-hook blocker. The wiki catalogs and `starshine-port-readiness-and-validation.md` were also refreshed so future agents no longer see stale pre-port/boundary-only wording for active `dae-optimizing`.
- `[DAE]012` local-subtyping / refinalization follow-up is closed as of 2026-05-26 for the current validated surface: focused regressions already cover write-site, tee-driven, optimize-casts-adjacent, `ref.as_non_null(local.get ...)`, loop-carried, block-wrapped `try_table`, lib-constructed `call_ref`, and dominated/undominated sibling-join ref-local families; the `--dae-optimizing --local-subtyping` 1000-case combo reproduced only the known DAE local-declaration mismatch set with `0` validation failures. Reopen only for a new validated DAE/local-subtyping semantic or validation repro.
- Important classification: Func408/abs425 raw body is closed. With both sides passed through the same strip-debug writer, Func408 matches after type-id stripping; prior Func408 drift was compare-layer representation, not a DAE raw rewrite target.

Execution rules for all DAE slices
- Use pass-targeted commands first: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing` and/or `--canonicalize-binaryen-output`.
- For Starshine pass logic changes, write or update a focused Moon test first where practical, confirm failure, then implement.
- For compare-tool-only changes, add a focused script fixture first and confirm failure.
- Every artifact output must validate with `wasm-opt --all-features` unless the command failed before producing wasm.
- Do not classify fuzz mismatches as semantic-safe without inspected transform contract, replay evidence, or diff-family analysis.
- Keep pass-local performance visible; target `Starshine pass <= 2x Binaryen pass`.
- Keep `docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md`, `docs/wiki/log.md`, and this backlog current when a frontier, classification, or acceptance state changes.

- [DAE]002 - Touched Nested Cleanup Scheduler Completion
  - Goal: replace the current narrow guarded `optimizeAfterInlining` approximation with a performant touched-function replay that is close enough to Binaryen for the debug artifact and direct pass signoff.
  - Why: the current lane runs a private subset (`precompute-propagate-prefix -> DCE -> OI -> LCSE -> PLS -> HSO -> H2L -> OC -> CP -> SL -> CF -> precompute -> MB -> RUB -> RUN -> MB -> CL -> RL -> VQ`) on selected functions, but it is still not Binaryen's full nested useful-passes replay and remains guarded for broad/large modules.
  - Deliverables:
    - Decide whether to land a real public `precompute-propagate` sibling or keep widening the private `precompute-propagate-prefix` helper.
    - Replace module-shaped nested adapters (`local-cse`, `coalesce-locals`, `reorder-locals`) with true function-filtered equivalents where needed, or document why the adapter remains safe.
    - Preserve touched-only behavior for artifact-sized modules unless a whole-module replay is proven safe, useful, and within the 2x target.
    - Preserve nested pass trace coverage (`pass[dae-optimizing]:nested-pass name=...`) and focused scheduler-order tests.
  - Required tests/evidence:
    - Existing scheduler order and touched-only Moon tests.
    - Artifact replay with and without `--canonicalize-binaryen-output`.
    - A timing repeat showing the nested lane stays within the 2x target.
  - Exit criteria: nested cleanup no longer explains the leading artifact frontier, or remaining gaps are explicitly classified as representation-only/deferred.

- [DAE]003 - Constant-Actual and Unread-Parameter Generalization
  - Goal: broaden the safe exact-literal/unread-parameter machinery beyond the current selected artifact lanes.
  - Why: current coverage includes private direct callees where every caller passes the same exact literal, selected scalar memory-load siblings, typed single-result block wrappers, immutable `global.get` for selected Func330/def313, selected Func3736/Func4117/Func4134/Func4303/Func4320, and many selected debug-artifact defs; broader candidate discovery remains incomplete.
  - Deliverables:
    - Generalize beyond fixed selected defs without reopening the earlier runtime cliffs.
    - Support more carrier shapes: non-adjacent forwarding, localized forwarding chains, recursive/self-recursive cycles, block/loop/if/try carriers, and safe immutable global/materialized constants.
    - Preserve all existing escape guards: exports, `ref.func`, table/element/global/local type refs, undropped dead-suffix calls, and self-call operand preservation such as case-000690.
    - Revisit the fixed core-iteration budget/starvation problem from research notes `0563` and later exact-literal starvation regressions.
  - Suggested tests:
    - Reduced starvation cases where the candidate appears after more than eight productive core rewrites.
    - Same-caller multi-call and forwarded-wrapper-chain regressions.
    - Artifact census/replay for `moonbit.check_range`-style literal carriers.
  - Exit criteria: no known artifact frontier is attributable to missed safe constant/unread-parameter materialization, and direct fuzz has no new semantic or validation regression.

- [DAE]004 - Selected Result-Removal Broadening
  - Goal: convert the selected dropped-result lane into a principled, broader result-removal scheduler.
  - Why: selected defs now include artifact families such as `298`, `299`, `427`, `445`, `459`, `472`, `476`, `3566`, `3732`, `3814`, `3834`, `4106`, and `4229`; Func445 and Func459/3732/472/476/4106 proved the both-canonical frontier can still expose real result/signature gaps.
  - Deliverables:
    - Replace the handpicked selected-def list with a fact-driven candidate queue when safe.
    - Preserve signatures when any live/undropped call result still exists, including undropped dead-suffix calls.
    - Repair `call; drop` sites after a callee becomes void.
    - Keep table/global/element/local/ref heap type references live when result/function type rewriting changes type ownership.
  - Suggested tests:
    - Focused Func445-style dropped-result regression.
    - Callee with mixed dropped and undropped calls.
    - Dead-suffix `call; drop` rewrite coverage.
    - Type-liveness coverage for simple function types referenced outside the function section.
  - Exit criteria: no remaining artifact or fuzz mismatch is a true dropped-result scheduling gap.

- `[DAE]005` debug-artifact raw frontier/type-section drift is closed as of 2026-05-26. The raw `defined=336 abs=353` type-section/type-index mismatch is accepted as a documented diagnostic boundary for the default helper, not an active Func408/Func336 body rewrite task. Future raw parity work should reopen from a type-section/type-index construction need or a changed byte-reference contract, not from the current default first diff.

- `[DAE]006` both-canonical frontier advancement is closed as of 2026-05-26 by research note `0591`: the live Func509 `defined=509 abs=526` diff is a documented lowerer/diagnostic boundary, not a safe DAE final-hook matcher miss. Agent classification remains semantic-safe/size-losing: Starshine returns the same object as Binaryen, but leaves lowered post-return wrapper debris; the pre-encode DAE IR still needs the value-block suffix to consume the `block (result i64)` result, and the broad final-hook strip from note `0590` made functions `509` and `514` invalid. Future cleanup belongs to a separate post-lowering or writer-side dead-code cleanup investigation, not the active DAE final hook.

- [DAE]009 - Raw Cleanup Policy and Size/Shape Tradeoff
  - Goal: maintain a clear policy for useful raw cleanup versus Binaryen-shape debris preservation.
  - Why: DAE has alternated between useful cleanup (smaller Starshine output) and Binaryen-shape debris preservation for artifact parity. Some broad cleanup improved size and fuzz shape, while some parity-preserving choices kept `nop`, dropped constants, and local-read debris.
  - Deliverables:
    - Keep the current policy explicit: correctness and usefulness first; raw byte parity only when it supports a documented frontier.
    - Separate module-wide useful cleanup from selected strict-debris cleanup used for inspected artifact functions.
    - Preserve possibly trapping/effectful operand stacks; only strip audited pure/nontrapping debris.
    - Track size and mismatch counts for 10k compare runs when raw cleanup policy changes.
  - Suggested evidence:
    - 10k compare-pass run with mismatch counts and Starshine/Binaryen size deltas.
    - Focused tests for each newly stripped operation family.
  - Exit criteria: no open DAE task depends on unclear debris policy, and new cleanup work is either usefulness-signable or explicitly shape-parity-scoped.

- [DAE]011 - Performance Stabilization
  - Goal: keep DAE artifact and direct-pass runtime inside `Starshine <= 2x Binaryen`, preferably with headroom.
  - Why: recent both-canonical artifact timings are often close to the 2x threshold; earlier selected scheduler experiments showed unstable timing even when byte-identical.
  - Deliverables:
    - Repeat timing for `.tmp/dae-func469-literal-artifact` or the latest artifact before claiming signoff.
    - Attribute whole-command wall-time separately from pass-local runtime unless the root cause is inside DAE.
    - Avoid broad rescans, per-def bitmap churn, whole-module untouched cleanup, and selected-loop expansions that previously caused cliffs.
  - Known useful runtime strategies:
    - Shared current-call facts.
    - Singleton/scratch bitmap reuse.
    - Empty skip bitmap reuse.
    - Lazy mutation buffers.
    - Touched-flag reuse.
    - Boundary queue precomputation and original suffix-target stamp tables.
  - Exit criteria: repeated artifact timings are stable within target after the current slice, or a performance blocker is opened with a concrete profile/repro.


- [DAE]013 - Preset / Ordered-Neighborhood Integration
  - Goal: only widen public `optimize`/`shrink` preset behavior after direct DAE evidence is strong enough and the surrounding ordered neighborhood is representable.
  - Dependencies:
    - `[DAE]002` nested cleanup scheduler state.
    - `[DAE]010` fresh direct fuzz signoff.
    - Current no-DWARF default optimize path ordering docs.
  - Deliverables:
    - Prove direct `dae-optimizing` first, then ordered-prefix/preset replay.
    - Keep repeated Binaryen cleanup slots explicit; do not collapse them just because Starshine has a simpler pass sequence.
    - Update `src/cmd/cmd.mbt` only if public flags or preset expansion changes.
  - Exit criteria: DAE participates in the preset path with documented parity/performance evidence or remains explicitly direct-pass-only for v0.1.0.


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

### SGO - Follow-Up Improvements

- [SGO]003 - Binaryen `SimplifyGlobals.cpp` Breadth
  - Status: active again for v0.1.1 because the product goal changed toward broad Binaryen coverage; not a v0.1.0 blocker and not a rejection of the supported-surface signoff in `docs/wiki/raw/research/0573-2026-05-19-sgo-v010-signoff.md`.
  - Goal: broaden SGO toward full Binaryen `SimplifyGlobals.cpp` rewrite-family coverage while preserving the accepted v0.1.0 direct/nested/late-tail surface as a scoped signoff, not a full-parity claim.
  - Current matrix: `docs/wiki/binaryen/passes/simplify-globals-optimizing/parity-matrix.md` distinguishes implemented, partial, missing, intentionally conservative, and unknown families.
  - Landed first slices: source-backed `read-only-to-write` value-flow positives through pure const/`select` self-guards and side-effecting-but-safe official-style `local.tee` / `i32.load` / `global.get + const` / `select` / `i32.eqz`, where the actual `global.get` only flows to the outer branch decision, including three select positions; the current conservative stack/value-flow scanner now also admits extra non-trapping pure ops between the actual `global.get` and final branch, plus nested-`if (result i32)` arm-flow positives when the nested condition is built from independent calls (including clean operands), pure ops, local tees, or loads, when independent arm-local calls, clean arm-local `local.tee` / `i32.load` effects, transparent arm value blocks, and post-if `select` value uses do not consume the global-derived value dangerously, when the nested-if result flows through a supported pure/ref/numeric post-if consumer such as `i32.eqz`, `ref.is_null`, `ref.eq`, `ref.i31`, `extern.convert_any`, `any.convert_extern`, nontrapping int-to-float conversions, float demote/promote, saturating float-to-int truncations, or float div before the outer branch, when nested transparent result blocks wrap the supported nested-if pure/select/post-conversion forms before the outer branch, when a clean value-producing `if` wrapper yields another supported nested-if arm result through supported pure/select post-consumers, and when reference-typed or numeric nested-if arm results flow through the covered nontrapping reference/numeric operators with or without a transparent result-block wrapper before the outer branch; the recursive no-else nested-pattern carveout now covers the two-layer and three-layer Binaryen lit shapes. Focused negatives preserve trapping global-derived loads, global-derived `local.tee`, multiple same-global reads in one condition, nested conditions steered by the global, post-if call operands or trapping post-if loads that consume the global-derived value, block-wrapped post-if loads that consume the global-derived value, nested arm blocks where the global feeds a trapping load, clean if-wrapper results feeding trapping loads, candidate reads steering inner if-wrapper branches, nontrapping reference-test/numeric-conversion results feeding post-consumer calls, nullable `i31.get_s`/`i31.get_u`, trapping regular float-to-int truncations, nested patterns with `else`, and extra dropped same-global reads.
  - Remaining candidate families: broader safe-side-effect `read-only-to-write` positives beyond the local stack scanner (broader control wrappers, broader nested `if` arms, calls/effects whose independence needs stack proof, broader loads/tables, and recursive nested-pattern variants beyond the no-else direct/eqz lit subset), broader same-as-init expression matching beyond direct literal / `ref.null` / `ref.func`, broader runtime linear-trace propagation, shared plain `simplify-globals` / `propagate-globals-globally` engine exposure, and additional GC/refinalization-safe replacement surfaces. The current nested-pattern slice also records an SGO wrapper guard that filters value-block/control touched functions out of nested cleanup until the HOT cleanup verifier frontier is fixed.
  - Deliverables for each next slice: add focused shape tests first, confirm the expected failure, implement a minimal safe subset, rerun direct `--pass simplify-globals-optimizing` oracle fuzz when nontrivial, and update the SGO wiki pages with the exact accepted subset.

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
