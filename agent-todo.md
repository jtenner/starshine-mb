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

Goal
- Make `simplify-globals-optimizing` match Binaryen `SimplifyGlobals.cpp` behavior for the v0.1.0 no-DWARF default optimize path, then prove it with both direct 10k pass fuzz and self-optimization / artifact comparison.
- Treat the existing v0.1.0 supported-surface signoff as a baseline only. It is not full Binaryen feature parity.
- Preserve correctness first: every new rewrite must validate, preserve side effects and traps, and either match Binaryen semantics or document an explicitly approved divergence.

Required APIs
- `src/passes/simplify_globals_optimizing.mbt` for the SGO core, fact table, matchers, replacements, touched-function reporting, and tests.
- `src/passes/simplify_globals_optimizing_test.mbt` for focused WAT regressions and guardrails.
- `src/passes/pass_manager.mbt` for module-pass dispatch and nested cleanup scheduling.
- `src/passes/optimize.mbt` and `src/passes/registry_test.mbt` for pass classification, `optimize` / `shrink` preset ordering, and sibling pass exposure.
- `src/cmd/cmd.mbt` when public CLI behavior, help, or preset flags change.
- `scripts/pass-fuzz-compare.ts`, `bun fuzz compare-pass`, and `scripts/self-optimize-compare.ts` for oracle and artifact signoff.
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/*`, especially `parity-matrix.md`, `starshine-strategy.md`, and `starshine-port-readiness-and-validation.md`, for source-backed scope and status.

Invariants
- Direct pass semantic parity with Binaryen is required before claiming any slice complete.
- Standard direct signoff for behavior slices: `moon test src/passes`, then `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-<slice>`; classify Binaryen/tool command failures separately.
- Final full-parity signoff: `moon info`, `moon fmt`, `moon test`, direct SGO 10k fuzz, ordered late-tail 10k replay where applicable, and self-optimization comparison on `tests/node/dist/starshine-debug-wasi.wasm` through the v0.1.0 optimize path.
- Record pass-local Starshine/Binaryen timing for direct artifact and preset/self-optimize runs; keep Starshine within the 2x Binaryen pass-local floor unless the gap is attributed to `[WALL]001` or explicitly accepted.
- Do not collapse repeated Binaryen cleanup slots or widen `optimize` / `shrink` ordering without dedicated preset tests and artifact evidence.
- Preserve startup/global-initializer rewrites as module-only changes unless a function body is actually changed; touched-function nested cleanup must run only for touched functions.
- Keep `precompute-propagate` out of SGO nested cleanup unless Binaryen source evidence proves it belongs there for this pass.
- Prefer adding one Binaryen-positive shape plus paired negatives per child slice. Do not broaden by analogy across trapping, effectful, branchy, reference-typed, or object-identity-sensitive families.
- Update `docs/wiki/binaryen/passes/simplify-globals-optimizing/parity-matrix.md`, `docs/wiki/log.md`, and `agent-todo.md` whenever a slice lands or is reclassified.

Suggested tests
- Focused WAT tests in `src/passes/simplify_globals_optimizing_test.mbt` for every positive and guardrail negative.
- Registry/preset tests in `src/passes/registry_test.mbt` and `src/passes/optimize.mbt` tests when sibling passes or public preset behavior changes.
- CLI tests in `src/cmd` when public flags/help change.
- Reduced mismatch tests promoted from any `pass-fuzz-compare` failure dirs.
- Direct artifact replays with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --simplify-globals-optimizing --out-dir .tmp/sgo-<slice>-artifact` for slices that may affect the debug artifact.
- Final full optimize/self-optimize replay after direct pass and late-tail parity are green.

Active v0.1.0 slices for full Binaryen parity

- [SGO]003 - Full `SimplifyGlobals.cpp` Breadth Coordination
  - Status: active parent slice.
  - Goal: coordinate all remaining source-backed Binaryen SGO feature gaps until direct `simplify-globals-optimizing` 10k fuzz and v0.1.0 self-optimization/artifact comparison are green under the pass-signoff rules.
  - Why: the existing SGO implementation is accepted for a supported subset, but the parity matrix still marks full Binaryen breadth as partial or missing.
  - Deliverables:
    - keep a live checklist of child slices `[SGO]003A` through `[SGO]003H` and `[SGO]004` / `[SGO]005`;
    - after each child, update the parity matrix and close or narrow completed rows;
    - preserve latest direct 10k fuzz and artifact evidence paths;
    - maintain a current mismatch classification table if direct fuzz or self-optimize is red.
  - Exit criteria:
    - all child slices are complete or explicitly out-of-scope by user decision;
    - direct SGO 10k has zero Starshine validation failures and zero semantic mismatches;
    - v0.1.0 self-optimization comparison is green or every remaining diff is classified and accepted by the user.

- [SGO]003A - Binaryen Source Audit And Fact-Table Parity
  - Status: accepted on 2026-05-25. Source audit, fact-row refactor, focused tests, Moon validation, and direct SGO fuzz evidence live in `docs/wiki/raw/research/0675-2026-05-25-sgo-fact-table-source-audit.md`.
  - Goal: align Starshine's module-wide global fact table with Binaryen's `SimplifyGlobals.cpp` facts before adding more matcher breadth.
  - Why: the parity matrix says Binaryen's `nonInitWritten` and `readOnlyToWrite` are modeled locally by separate flag paths rather than one faithful source-shaped fact table; later slices should not pile more ad hoc flags onto that gap.
  - Tasks:
    - [x] re-read Binaryen `version_129` `SimplifyGlobals.cpp`, `pass.cpp`, and current-main SGO no-drift evidence for this run;
    - [x] map Binaryen's per-global facts and Starshine's source-specific fact needs in research note `0675`;
    - [x] add/adjust whitebox tests that expose current Starshine fact rows for imported/exported, data/elem offsets, typed element item expressions, and function-body reads/writes;
    - [x] refactor SGO collection so source-specific counters and existing same-init/read-only-to-write plan flags live in one coherent `SgoGlobalInfo` row;
    - [x] run direct SGO fuzz to confirm behavior parity after the fact-row refactor: `.tmp/pass-fuzz-sgo-fact-table-003a-10000` compared `6759/10000` before the configured 20 Binaryen/tool command-failure stop, with `0` mismatches and `0` Starshine validation failures.
  - Required guardrails:
    - imported initializer provenance must remain conservative;
    - exported mutable globals must not be made private by fact refactoring;
    - element item reference expressions must remain conservative until `[SGO]003F`.
  - Exit criteria:
    - focused fact-table tests pass (`moon test src/passes` passed `1610/1610` after the refactor);
    - no intended behavior broadening without tests;
    - direct SGO fuzz remains green under the configured command-failure stop (`0` mismatches, `0` validation failures).

- [SGO]003B - Same-As-Init Expression Equivalence Parity
  - Status: accepted / evidence-gated on 2026-05-25. Fresh arithmetic and `select` same-init probes were Binaryen negatives, and the existing block/result, alias one-shot, imported-provenance, changed-write, and object-identity guardrails remain the active boundary. Evidence lives in `docs/wiki/raw/research/0676-2026-05-25-sgo-same-init-expression-guardrails.md`, with prior closeout context in `0658`.
  - Goal: avoid broadening same-init write removal beyond the currently proven direct literal / `ref.null` / `ref.func` and exact repeated-run alias surfaces unless a future exact Binaryen-positive expression grammar appears.
  - Completed tasks:
    - [x] inventoried current official/generated evidence and prior closeouts for direct literals, canonicalized aliases, block/result wrappers, arithmetic expressions, `select` expressions, imported-provenance cases, changed-write cases, and repeated-run behavior;
    - [x] added focused guardrail tests for arithmetic and `select` expression-shaped same-init writes, both preserving the mutable global and later read;
    - [x] kept implementation unchanged because no new Binaryen-positive expression grammar was found.
  - Future reopen criteria:
    - a new exact Binaryen-positive fixture for a specific expression grammar;
    - paired negatives for provenance, trapping/effectful expressions, block/result wrappers, changed non-init writes, and object-identity-sensitive GC expressions;
    - direct SGO 10k fuzz for any behavior change.

- [SGO]003C - Full Read-Only-To-Write FlowScanner Parity
  - Status: accepted / evidence-gated for the currently evidenced v0.1.0 surface. Broad FlowScanner parity remains source-backed but future broadening now requires a fresh exact Binaryen-positive child slice with paired guardrails and direct SGO fuzz evidence.
  - Goal: replace the remaining syntactic and partial FlowScanner gaps with a source-faithful value/effect scanner for Binaryen read-only-to-write detection when fresh evidence identifies a concrete missing shape.
  - Why: `read-only-to-write` and side-effecting-but-safe condition value-flow remain partial; full Binaryen parity requires recognizing all safe candidate-read-to-branch/control shapes while preserving traps, side effects, and extra reads.
  - Subtasks:
    - `[SGO]003C1` condition/control inventory: enumerate Binaryen-positive direct, `i32.eqz`, normal/reverse compare, `select`, block, loop, if, `try_table`, and exact `if return; set` shapes not yet covered;
    - `[SGO]003C2` pure/nontrapping operator closure: audit remaining scalar, reference, GC, SIMD, and conversion operators that Binaryen accepts as nontrapping pure condition consumers; add one operator-family test set at a time;
    - `[SGO]003C3` side-effect-preserving prefixes: complete safe independent side-effect families including stores, table/memory bulk ops, grows, drops, local/global writes, and clean calls only when operands are independent of the candidate global;
    - `[SGO]003C4` nested-if and arm-flow completion: cover any remaining first-arm/second-arm/nested-arm placements, transparent wrappers, and post-if consumers;
    - `[SGO]003C5` loop-specific scanner: accepted / evidence-gated on 2026-05-25 in `docs/wiki/raw/research/0691-2026-05-25-sgo-loop-prefix-closeout.md`. Direct loop self-guards and simple pure adjacent consumers are covered, and the narrow independent `const; global.set <other>` value-loop prefix from 0638/0677, the Binaryen-positive independent `const; local.set` prefix from 0678, the constant-operand `i32.store` prefix from 0679, the matching constant-operand `i64.store` prefix from 0680, the integer subword store family (`i32.store8`, `i32.store16`, `i64.store8`, `i64.store16`, and `i64.store32`) from 0681, the float store family (`f32.store` and `f64.store`) from 0682, the clean `table.set` prefix from 0683, the three-constant `memory.fill` prefix from 0684, the three-constant `memory.copy` prefix from 0685, the three-constant `memory.init` prefix from 0686, the clean `table.fill` prefix from 0687, the three-constant `table.init` / `table.copy` prefixes from 0688, the independent `memory.grow` / `table.grow` plus dropped-result prefixes from 0689, and the operandless `elem.drop` / `data.drop` segment-drop prefixes from 0690 are now implemented without reusing the full block scanner. Do not continue the prefix micro-series implicitly; future loop broadening needs a new exact Binaryen-positive child slice plus branch/trap/effect guardrails;
    - `[SGO]003C6` `try_table` and exception-wrapper completion: accepted / evidence-gated on 2026-05-25 in `docs/wiki/raw/research/0692-2026-05-25-sgo-try-table-wrapper-closeout.md`. The no-catch wrapper surface from 0603 through 0632 covers direct, `i32.eqz`, compare/reverse-compare, select-position, supported pure-post-consumer, exact `if return; set`, and `ref.is_null` families; catch-bearing/delegate/control-transfer wrappers remain conservative until a future exact Binaryen-positive child slice supplies paired guardrails and direct SGO fuzz evidence;
    - `[SGO]003C7` branch/control guardrails: preserve negatives for branchy wrappers, returns, throws, `br_if`, extra same-global reads, wrong target globals, non-constant writes, tainted operands, trapping consumers, and post-join uses.
  - Exit criteria:
    - focused tests cover every implemented FlowScanner grammar plus paired negatives;
    - direct SGO 10k fuzz green;
    - no Starshine validation failures;
    - self-optimize read-only-to-write diffs are gone or explicitly classified.

- [SGO]003D - Call, Generated-Effects, And Function-Effect Parity
  - Status: accepted / evidence-gated on 2026-05-25. Evidence and closeout live in `docs/wiki/raw/research/0693-2026-05-25-sgo-call-effect-parity-closeout.md`, building on the direct-call read-summary implementation in `0671`, constant-argument guardrails in `0672`, and prior call-breadth closeout in `0673`.
  - Goal: keep the current fixed-point direct-call read/write summaries as the supported v0.1.0 call/effect surface, while requiring fresh exact Binaryen-positive evidence before broader call behavior is implemented.
  - Completed tasks:
    - [x] audited the existing `LinearExecutionWalker` / function-effect evidence and Starshine implementation state for ordinary direct calls, runtime fact preservation, and read-only-to-write call participation;
    - [x] confirmed focused tests already cover fixed-point per-global read/write summaries, zero-param one-result calls, clean constant-argument direct calls, wrong-global reads, candidate-reading callees, imported calls, and candidate-derived operands;
    - [x] kept imported calls, indirect calls, `call_ref`, return-call variants, generated-effects metadata, target-set modeling, and broader placements conservative without fresh positive evidence;
    - [x] recorded a spot direct `--simplify-globals-optimizing` probe showing a zero-result independent call before a later candidate read is not an immediate Starshine/Binaryen normalized-output gap.
  - Future reopen criteria:
    - an exact Binaryen-positive fixture for imported-call, indirect-call, `call_ref`, return-call, generated-effects, target-set, or broader placement behavior;
    - paired guardrails for candidate-derived call operands, candidate-reading callees, unknown/dynamic callees, table/element escapes, exported/open-world functions, recursive cycles, trapping/effectful operands, multi-read conditions, and non-branch consumers;
    - direct SGO 10k fuzz and validation evidence for any behavior change.

- [SGO]003E - Runtime ConstantGlobalApplier / Linear-Trace Parity
  - Status: accepted / evidence-gated on 2026-05-25. Evidence and closeout live in `docs/wiki/raw/research/0694-2026-05-25-sgo-runtime-linear-trace-closeout.md`, building on the 0598 through 0602 runtime slices and `[SGO]003D` call/effect summary closeout.
  - Goal: keep the current runtime linear-trace propagation surface as the supported v0.1.0 behavior while requiring fresh exact Binaryen-positive evidence before broader `ConstantGlobalApplier` adjacency is implemented.
  - Completed tasks:
    - [x] audited the landed runtime implementation and tests for straight-line, top-level-noise, plain-block, no-else, then-with-else, else-local, loop-local, `try_table`-local, imported/exported/reference fact, and direct-call-summary propagation;
    - [x] confirmed conservative guardrails remain for pre-`if` facts entering else arms, post-if joins, pre-loop facts entering loops, loop facts escaping/backedge reuse, post-`try_table` joins, imported/indirect/reference calls, dynamic return calls, branches, returns, throws, and non-constant writes;
    - [x] kept optimizer behavior unchanged because no active exact Binaryen-positive runtime-adjacency child fixture remains.
  - Future reopen criteria:
    - an exact Binaryen-positive fixture for a specific runtime propagation shape not already covered;
    - paired guardrails for joins/backedges, candidate-derived operands, unknown calls, branches, returns, throws, non-constant writes, and type/refinalization-sensitive replacements as relevant;
    - focused tests plus direct SGO 10k fuzz and validation evidence for any behavior change.

- [SGO]003F - Reference, GC, Type-Refinalization, And Element-Expression Parity
  - Status: accepted / evidence-gated on 2026-05-26. The ordinary `ref.cast` parser prerequisite and first validating `ref.func`-through-`ref.cast` SGO fixture landed on 2026-05-25 in `docs/wiki/raw/research/0695-2026-05-25-sgo-ref-cast-parser-and-fixture.md`; the narrow exact-type typed element item-expression subset landed on 2026-05-26 in `docs/wiki/raw/research/0696-2026-05-26-sgo-exact-typed-element-replacement.md`; and typed element broadening was closed as evidence-gated in `docs/wiki/raw/research/0697-2026-05-26-sgo-typed-element-guardrail-closeout.md` after adding refinalization-sensitive and object-identity-sensitive guardrails. Broader less-refined alias, descriptor, object-identity, and module-retagging-sensitive cases require a future exact Binaryen-positive fixture before reopening.
  - Goal: safely implement Binaryen's reference-typed replacement breadth, including typed element item expressions and GC/refinalization-sensitive cases.
  - Why: reference replacements are partial; typed element item expressions and broader type-changing replacements are intentionally conservative. The old ordinary `ref.cast` WAT blocker is removed, but full `[SGO]003F` parity still needs exact Binaryen-positive fixtures and paired guardrails.
  - Tasks:
    - [x] isolate parser/lowering support needed for normal `ref.cast` fixtures (`0695` adds WAST opcode/parser/lowering/rendering and roundtrip coverage);
    - [x] add a minimal validating fixture where SGO replacement changes reference precision and refinalization repairs the function (`0695` covers a typed `ref.func` global read feeding `ref.cast (ref $t)`);
    - [x] implement the narrow `ref.cast(ref.func-global)` path only after the fixture validates (existing SGO replacement is now covered by the parser-supported fixture);
    - [x] audit and implement the exact-type typed element item-expression subset: single `global.get` items whose global value type exactly equals the element segment `RefType`, including exact immutable aliases after startup constant rewriting (`0696`);
    - [x] audit broader typed element item-expression replacements and keep non-exact, nested, subtype/refinalization-sensitive, descriptor-sensitive, or object-identity-sensitive reference `global.get`s conservative without fresh exact Binaryen-positive evidence (`0697`);
    - [x] add guardrails for nullable/non-null refinalization-sensitive typed element expressions and object-identity-sensitive `struct.new_default` typed element globals; existing less-refined alias guardrails remain active (`0697`);
    - [x] run direct SGO 10k fuzz for the completed `[SGO]003F` behavior set after the remaining guardrails/deferrals are finalized: `.tmp/pass-fuzz-sgo-typed-element-guardrails-0697-10000` reported `6759/10000` compared, `0` mismatches, and `0` Starshine validation failures before the configured 20 Binaryen/tool command-failure stop.
  - Exit criteria:
    - reference/GC rows in the parity matrix are implemented or evidence-gated with focused guardrails;
    - `wasm-tools validate` and Binaryen validation accept outputs;
    - direct SGO 10k fuzz green for the completed behavior set.

- [SGO]003G - Startup Propagation, Single-Use, Copy-Chain, And Segment Parity
  - Status: accepted / evidence-gated on 2026-05-26. Evidence and closeout live in `docs/wiki/raw/research/0698-2026-05-26-sgo-startup-copy-chain-closeout.md`, building on the 0580 through 0589 startup/single-use/copy-chain lit regressions, `[SGO]003A` fact-table audit, and `[SGO]003F` typed element exactness/guardrail slices.
  - Goal: keep the current source-backed startup-only propagation, single-use initializer folding, exact-type immutable copy-chain canonicalization, and segment/table initializer behavior as the v0.1.0 supported surface while requiring fresh exact Binaryen-positive evidence before broader startup or copy-chain behavior is implemented.
  - Completed tasks:
    - [x] audited Binaryen-backed startup propagation into later globals, table initializer expressions, active data offsets, active element offsets, typed element item expressions, and nested GC initializer children against the current Starshine implementation and tests;
    - [x] confirmed existing focused positives cover supported startup constants, active segment offsets, nested GC initializers, single-use GC initializer folding, and prefer-earlier exact-type copy chains;
    - [x] preserved function-code second-use, imported source, second global use, passive-data, non-exact typed element item, object-identity, subtype/refinalization, descriptor-sensitive, exported/open-world, and startup-only nested-cleanup guardrails;
    - [x] kept optimizer behavior unchanged because no fresh exact Binaryen-positive startup/copy-chain fixture remained in the active evidence set.
  - Future reopen criteria:
    - an exact Binaryen-positive fixture for a specific startup/copy-chain/segment shape not already covered;
    - paired guardrails for imported/exported provenance, second uses, function-code uses, passive segments, type/refinalization sensitivity, object identity, descriptor operations, and touched-function cleanup behavior as relevant;
    - focused tests plus direct SGO 10k fuzz and validation evidence for any behavior change.

- [SGO]003H - Shared Engine And Sibling Pass Exposure
  - Status: accepted on 2026-05-26. Evidence lives in `docs/wiki/raw/research/0699-2026-05-26-sgo-shared-family-exposure.md`.
  - Goal: expose Binaryen-family parity for plain `simplify-globals` and `propagate-globals-globally` without aliasing them incorrectly to the optimizing sibling.
  - Completed tasks:
    - [x] kept the shared global-simplification core in `src/passes/simplify_globals_optimizing.mbt` while adding distinct wrappers;
    - [x] added public registry/dispatcher tests proving `simplify-globals`, `simplify-globals-optimizing`, and `propagate-globals-globally` are distinct active module passes;
    - [x] implemented plain `simplify-globals` as the shared core without nested cleanup;
    - [x] implemented `propagate-globals-globally` as the startup/global-only subset, preserving function bodies and disabling SGO single-use complex-initializer inlining for this sibling;
    - [x] added pass-fuzz-compare support for both newly active pass names;
    - [x] ran direct 10k fuzz lanes: `.tmp/pass-fuzz-sgo-plain-sibling-0699-10000` and `.tmp/pass-fuzz-pgg-sibling-0699b-10000` both reported `6759/10000` compared, `0` mismatches, and `0` Starshine validation failures before the configured 20 Binaryen/tool command-failure stop.
  - Future reopen criteria:
    - a new direct fuzz mismatch, validation failure, source-backed sibling behavior gap, or preset scheduling requirement.

- [SGO]004 - Exact Nested Default Cleanup Scheduler And Performance Parity
  - Status: accepted / evidence-gated on 2026-05-25. Evidence lives in `docs/wiki/raw/research/0666-2026-05-25-sgo-nested-cleanup-scheduler-deferral-audit.md`; future scheduler broadening needs a concrete mismatch, validation failure, artifact/code-size target, wall-time owner, or verifier reproduction.
  - Goal: match or deliberately justify divergence from Binaryen's SGO optimizing wrapper: rerun the correct default function optimization sequence on every changed function, with no extra functions and no missing required cleanup slots.
  - Why: Starshine currently uses an accepted artifact-tuned pruned nested list and structural filters; Binaryen runs the full default function optimization pipeline per changed function. Full self-optimization parity may require exact scheduler behavior or a proven semantically equivalent schedule.
  - Tasks:
    - re-audit Binaryen `simplify-globals-optimizing` nested rerun source and saved no-DWARF optimize-path docs;
    - add trace tests for the expected nested pass list, order, repeated cleanup slots, and no `precompute-propagate` prefix;
    - characterize current filters: large touched function, value-block-control, module size, touched count, startup-only no-cleanup;
    - remove or narrow filters only with validation and pass-local timing evidence;
    - compare full nested list versus current pruned list on reduced modules and the debug artifact;
    - if exact Binaryen list is too slow but semantically equivalent, document accepted scheduler divergence with timing and artifact evidence.
  - Exit criteria:
    - nested cleanup produces valid wasm for all focused guardrail families;
    - direct artifact pass-local timing meets the 2x Binaryen floor or is attributed;
    - direct SGO 10k fuzz green;
    - self-optimize no longer has unexplained SGO-cleanup diffs.

- [SGO]005 - Full v0.1.0 Self-Optimization And 10k Fuzzer Signoff
  - Status: active final signoff slice with blockers from the 2026-05-26 signoff attempt in `docs/wiki/raw/research/0700-2026-05-26-sgo-full-parity-signoff-attempt.md`; depends on `[SGO]003A` through `[SGO]003H` and `[SGO]004`.
  - Goal: prove full Binaryen parity for SGO's role in the v0.1.0 no-DWARF default optimize path.
  - Tasks:
    - [x] run `moon info`, `moon fmt`, and `moon test` serially for the 2026-05-26 attempt (`moon test` passed `3723/3723`, with existing DAE unused warnings in `moon info`);
    - [x] run direct pass fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-full-parity-10000` (`6759/10000` compared, `0` mismatches, `0` Starshine validation failures, `20` Binaryen/tool command failures);
    - [x] run ordered late-tail neighborhood fuzz for `simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize`: `.tmp/pass-fuzz-sgo-late-tail-full-parity-10000` (`6597/10000` compared, `0` mismatches, `0` Starshine validation failures, `20` Binaryen/tool command failures);
    - [x] run direct debug artifact replay with `--simplify-globals-optimizing` and record first diff, sizes, validation, and pass-local timings: `.tmp/sgo-full-parity-direct-artifact-native` validates and first differs at `defined=55 abs=76`, classified as representation-only default-local/carrier drift, but Starshine pass time is over the 2x floor (`249.120ms` vs Binaryen `115.912ms`; repeat `257.074ms` vs `112.087ms`);
    - [x] run ordered late-tail debug artifact replay: `.tmp/sgo-full-parity-late-tail-artifact` first differs at the same `defined=55 abs=76` representation-only family, but Starshine pass time is over the 2x floor (`376.989ms` vs Binaryen `176.568ms`; repeat `385.680ms` vs `177.497ms`);
    - [ ] fix or explicitly accept the SGO direct/late-tail artifact pass-local runtime gap before final closeout; current evidence is slightly beyond the repo 2x floor and should not be hidden;
    - [ ] decide whether the `defined=55 abs=76` default-local/carrier drift is accepted for final SGO artifact signoff or needs compare-normalization/cosmetic parity work;
    - [ ] run full self-optimization / optimize-path comparison on `tests/node/dist/starshine-debug-wasi.wasm` and classify any remaining diffs; current helper rejects `--optimize` with `unsupported preset flag for self-optimize compare: --optimize`, so either add preset support to the helper or provide an explicit-pass equivalent before rerunning;
    - [x] update `docs/wiki/raw/research/[next]-YYYY-MM-DD-sgo-full-binaryen-parity-signoff.md`, `docs/wiki/log.md`, parity matrix, and this backlog for the 2026-05-26 attempt;
    - [x] commit the 2026-05-26 signoff-attempt docs/backlog update after reviewing status and staged diff (`c109a728`).
  - Required mismatch classification:
    - semantic-safe / representation-only only with explicit transform-contract or replay evidence;
    - validation failure, tool/Binaryen failure, size-losing, unknown/risky, and true semantic mismatch must stay visible until fixed or explicitly accepted.
  - Exit criteria:
    - `moon test` green;
    - direct SGO 10k has zero semantic mismatches and zero Starshine validation failures;
    - self-optimization comparison is green, or every remaining Binaryen difference is classified and accepted by the user with concrete dates, commands, output dirs, and rationale;
    - SGO pass-local runtime meets the 2x Binaryen floor on direct artifact comparison or the gap is assigned to `[WALL]001` with evidence.

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

No separate v0.1.1 SGO follow-up task is currently tracked. Full Binaryen parity work has been moved into the active v0.1.0 SGO slice above.

## v0.2.0 Backlog

### INL - Deferred Inliner Breadth

No active v0.2.0 INL backlog slices remain.

### HOT - Deferred Worker Queue

- [HOT]003 - Node-Package Worker Queue Port
  - Status: deferred behind [HOT]002 and future Node package rebuild work.
  - Deliverables: reuse the native hot-batch queue contract in the shipped Node package with `worker_threads`, one WasmGC module per worker, worker-local heap state, and stable-order serialized merge.
  - Dependencies: [HOT]002 native queue contract, worker-local function serialization hooks, and future Node package rebuild work.
