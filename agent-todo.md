# Agent Tasks

## Scope
- Keep only active unreleased work or explicitly deferred future work.
- Group work by release target.
- Use explicit slice ids so future agents can execute in dependency order.
- Move completed work and historical evidence to the relevant docs/wiki page, release notes, or git history.

## Current Parity Focus
- Keep the Binaryen no-DWARF default optimize path as the v0.1.0 parity target.
- Canonical order and nested-shape notes live in `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` and `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`.
- Prefer direct-pass semantic parity first, then ordered-neighborhood replay, then preset scheduling.
- Do not widen public `optimize` / `shrink` slots until the surrounding Binaryen neighborhood is representable and oracle-proven.

## v0.1.0 Active Slices

### O4z debug startup recovery

- [O4Z-STARTUP]001 - Reduced Startup Map Init Trap
  - Status: smoke-green on 2026-06-02; keep only follow-up hardening here until a full-suite signoff or smaller artifact-generation fixture replaces the integration-shaped guard.
  - Goal: keep the repaired debug-WASI artifact/reduced fixture and conservative pass guards from regressing while broader self-optimized spec coverage is scheduled.
  - Why: the original stale artifact trap was repaired by regenerating the committed debug-WASI artifact and reduced fixture from the current correct `$moonbit.malloc` shape. Subsequent full self/debug `-O4z` prefix probes exposed optimizer owners that are now guarded conservatively: `ssa-nomerge` nested-control liveness, `optimize-instructions` commutative canonicalization, `simplify-locals-nostructure` local.tee/load sinking, `coalesce-locals` loop/structured-local.tee coalescing, and `vacuum` branchy structured write cleanup.
  - Durable evidence: `docs/wiki/raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md`.
  - Remaining follow-ups:
    - [ ] Keep `tests/repros/o4z-debug-startup-map-init-repro.wasm` as the focused repro until a smaller source/build-artifact fixture replaces it.
    - [ ] Recover optimization precision one pass at a time only with focused tests and semantic evidence: nested SSA liveness, safe commutative operand ordering, local.tee-aware simplify-locals sinking, path-sensitive coalesce-locals, and branchy structured vacuum cleanup.
  - Suggested tests: `moon fmt`, `moon test src/passes`, `moon build --target native --release src/cmd`, `bun test scripts/lib/o4z-debug-startup-map.test.ts`, `wasm-tools validate --features all tests/repros/o4z-debug-startup-map-init-repro.wasm`, `wasm-tools validate --features all .tmp/o4z-bench/starshine-o4z-candidate.wasm`, and the self-optimized spec smoke commands listed in the research note.

### Whole-command wall-time budget

- [WALL]001 - Cross-Pass Runtime Budget And Attribution
  - Goal: own whole-command Starshine-vs-Binaryen wall-time measurement outside individual pass parity slices.
  - Why: direct pass slices may be signed off while aggregate preset or no-op command paths still hide parse/emit, validation, HOT lift/lower, cache, or buffering costs.
  - Current known target: isolate or guard `ssa-nomerge` on the large branchy Wast opcode parser function (`Func 2977`, `_M0MP37jtenner9starshine4wast10WastParser26parse__opcode__instruction`) before retrying full preset comparison; previous direct `--ssa-nomerge` artifact attempts timed out while Binaryen direct completed quickly.
  - Deliverables:
    - Separate pass-local runtime, harness/tool startup, parse/emit, validation, HOT lift/lower, analysis cache, and artifact representation costs.
    - Maintain a prioritized list of cross-cutting runtime fixes without blocking pass correctness signoff on aggregate wall time.
    - Evaluate remaining non-pass candidates such as encoder size/backpatch and code-section buffering reduction.
  - Suggested tests: focused timing traces, `moon info`, `moon fmt`, `moon test`, and targeted self-compare commands for any changed pass/tool path.

### O4z Per-Pass Deep Audits

Release gate: complete these before the v0.1.0 release so `-O4z` pass coverage is more comprehensive and pass-local runtime owners are known before publishing.

Use this checklist for every `[O4Z-AUDIT-*]` slice below:
- Start from the pass wiki page and owner source/test files; update docs if findings become durable.
- Run or refresh direct pass oracle evidence with `bun scripts/pass-fuzz-compare.ts --pass <name> --count 1000` first, then scale to 10000 only when changing behavior or closing the slice.
- Inspect tests for missing positive/negative shapes, add focused test-first fixtures for any bug or missed optimization, and keep validation failures separate from representation drift.
- Capture pass-local timing where available; file whole-command issues under `[WALL]001` unless the pass is clearly the owner.
- Replay the pass's `-O4z` slot/neighborhood when it has saved artifacts or documented generated-audit evidence.
- Close with an agent-classified findings note: bugs found/fixed, missing shapes added, performance owners, deferred risks, exact commands, counts, and artifact paths.

- [O4Z-AUDIT-DFE] - Deep audit `duplicate-function-elimination`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: duplicate defined-function equivalence, ref.func/export/start/table/global remapping, local Starshine type-compaction extras, repeated-slot behavior, and pass-local runtime.
  - Deliverables: apply the common checklist; add focused fixtures for any missing function identity/remap/type/name shape; refresh direct compare and ordered `DFE` slot evidence; record whether local extra cleanup should stay bundled or be split.

- [O4Z-AUDIT-RUME] - Deep audit `remove-unused-module-elements`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: function/table/global/memory/tag/elem/data liveness, export/start/ref.func/type-use roots, nonfunction-only sibling behavior, and module rewrite cost.
  - Deliverables: apply the common checklist; cover roots and remaps not already tested; refresh direct compare plus `DFE -> RUME` neighborhood evidence; classify any retained dead elements or over-removal risks.

- [O4Z-AUDIT-GR] - Deep audit `global-refining`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: global initializer/type LUB refinement, mutable/exported/imported guardrails, GC heap type precision, descriptor/stringref interactions, and validation/refinalization behavior.
  - Deliverables: apply the common checklist; add subtype and visibility fixtures; refresh direct compare and `GR` slot evidence; record any under-refinement or unsafe-boundary risks.

- [O4Z-AUDIT-GSI] - Deep audit `global-struct-inference`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: closed-world struct field constants, packed fields, default/descriptor constructors, mutable/exported/imported global negatives, nullable refs, and code-size/runtime impact.
  - Deliverables: apply the common checklist; coordinate with `[AUDIT004-A]` through `[AUDIT004-C]`; refresh direct compare and `GSI` slot evidence; document supported and intentionally unsupported closed-world shapes.

- [O4Z-AUDIT-SSA] - Deep audit `ssa-nomerge`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: HOT SSA construction/lowering without merges, phi copy placement, large branchy function runtime, local-name/type preservation, and Func2977-style wall-time ownership.
  - Deliverables: apply the common checklist; add reduced large-branch stress fixtures if needed; refresh direct compare and early `SSA` slot evidence; file pass-local runtime fixes here and whole-command residuals under `[WALL]001`.

- [O4Z-AUDIT-DCE] - Deep audit `dead-code-elimination`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: unreachable tails, dropped-value safety, structured-control result repair, EH/try_table behavior, writeback guards, raw-skip paths, and repeated cleanup interactions.
  - Deliverables: apply the common checklist; add missing dead-tail/control/EH fixtures; refresh direct compare and `DCE` slot evidence; classify Binaryen-shape differences as semantic, representation, or size tradeoffs.

- [O4Z-AUDIT-RUN] - Deep audit `remove-unused-names`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: label-use tracking, block merge/demotion, delegate/try behavior, repeated RUN slots, name-section expectations, and interaction with branch cleanup.
  - Deliverables: apply the common checklist; add label/delegate/repeated-slot fixtures; refresh direct compare and all `RUN` slot evidence; record any missed same-type wrapper collapses.

- [O4Z-AUDIT-RUB] - Deep audit `remove-unused-brs`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: tail branch/return removal, branch-to-trap rewrite, value-if/select lowering, br_table labels, raw gate thresholds, and retired slot14/slot40 corruption families.
  - Deliverables: apply the common checklist; coordinate with `[AUDIT002-B]` through `[AUDIT002-E]`; refresh direct compare and all `RUB` slot evidence; measure pass-local impact of raw skip choices.

- [O4Z-AUDIT-OI] - Deep audit `optimize-instructions`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: exact peepholes, shift/compare/boolean rewrites, effect-aware folds, use-def/effects metadata, raw O4z slot16/slot44 predecessors, and pass-local runtime.
  - Deliverables: apply the common checklist; coordinate descriptor work with `[AUDIT001-A]`/`[AUDIT001-B]`; refresh direct compare and all `OI` slot evidence; classify any missed Binaryen folds by safety/effect reason.

- [O4Z-AUDIT-HSO] - Deep audit `heap-store-optimization`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: struct.new/struct.set folding, local escape analysis, effect ordering, GC descriptor/refinalization shapes, and allocation-heavy performance.
  - Deliverables: apply the common checklist; add missing GC/effect/escape fixtures; refresh direct compare and `HSO` slot evidence; record unsafe fold blockers separately from missed profitable folds.

- [O4Z-AUDIT-PC] - Deep audit `precompute`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: constant folding, trap/effect preservation, raw precleaner/writeback guards, precompute-propagate prefix distinction, GC/array atomic exclusions, and O4z slot19/slot43 history.
  - Deliverables: apply the common checklist; coordinate descriptor work with `[AUDIT001-E]`/`[AUDIT001-F]`; refresh direct compare and all `PC` slot evidence; record missed folds versus deliberate trap/effect bailouts.

- [O4Z-AUDIT-CP] - Deep audit `code-pushing`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: safe local/global computation sinking, effect/trap boundaries, if/else arm use analysis, nested control, and tuple/local-cleanup neighborhood effects.
  - Deliverables: apply the common checklist; add missing push/bailout fixtures; refresh direct compare and `CP` slot evidence; classify downstream code-size wins and regressions.

- [O4Z-AUDIT-TO] - Deep audit `tuple-optimization`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: multivalue spill/copy splitting, passthrough chains, branch-exit carriers, local compaction, interaction with SLNS/RL/RUB, and candidate-heavy function runtime.
  - Deliverables: apply the common checklist; add missing tuple carrier fixtures; refresh direct compare and `TO` exact-slot neighborhood evidence; record any host-lane/local-map invariants clearly.

- [O4Z-AUDIT-SLNS] - Deep audit `simplify-locals-nostructure`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: no-structure local sinking, no-tee variant spelling, dead write cleanup, interaction with tuple/reorder/vacuum, and raw gate behavior.
  - Deliverables: apply the common checklist; add missing no-structure/no-tee fixtures; refresh direct compare and `SLNS` slot evidence; keep structure-producing rewrites out unless intentionally scheduled.

- [O4Z-AUDIT-VQ] - Deep audit `vacuum`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: nop/drop cleanup, explicit unreachable preservation, nested value-expression debris, empty if/block rewrites, repeated VQ slots, and retired slot23/slot33 histories.
  - Deliverables: apply the common checklist; add missing pure/nontrapping and control cleanup fixtures; refresh direct compare and all `VQ` slot evidence; measure cleanup value versus HOT traversal cost.

- [O4Z-AUDIT-RL] - Deep audit `reorder-locals`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: access-count sorting, zero-count truncation, parameter stability, local-name repair, multivalue scratch locals, TypeIdx invariant docs, and module-pass runtime.
  - Deliverables: apply the common checklist; coordinate invariant docs with `[AUDIT006-E]`; add missing reorder/name/multivalue fixtures; refresh direct compare and `RL` slot evidence.

- [O4Z-AUDIT-H2L] - Deep audit `heap2local`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: non-escaping struct locals, scalar field locals, null comparisons, GC type/refinalization, primary artifact fixtures, and heap-heavy function runtime.
  - Deliverables: apply the common checklist; add missing escape/null/field fixtures; refresh direct compare and `H2L` slot evidence; record memory and code-size effects.

- [O4Z-AUDIT-OC] - Deep audit `optimize-casts`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: ref.cast/ref.test/br_on_cast folding, descriptor casts, nullability trap preservation, local-subtyping neighborhood, and GC validation.
  - Deliverables: apply the common checklist; add missing cast/descriptor/nullability fixtures; refresh direct compare and `OC` slot evidence; classify any trap-mode-sensitive decisions.

- [O4Z-AUDIT-LS] - Deep audit `local-subtyping`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: local type refinement, write-site and join behavior, GC refs, call_ref and try_table shapes, interaction with optimize-casts/DAE, and validation refinalization.
  - Deliverables: apply the common checklist; add missing local-refinement fixtures; refresh direct compare and `LS` slot evidence; document conservative join/bailout policy.

- [O4Z-AUDIT-CL] - Deep audit `coalesce-locals`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: interference graph/coloring, local remap/name cleanup, TypeIdx invariant docs, copy-pair cleanup, and large-function coloring runtime.
  - Deliverables: apply the common checklist; coordinate invariant docs with `[AUDIT006-D]`; add missing interference/ref/name fixtures; refresh direct compare and `CL` slot evidence.

- [O4Z-AUDIT-LCSE] - Deep audit `local-cse`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: local expression reuse, effect barriers, memory/table/global/call/EH/GC/SIMD shapes, module adapter behavior, and pass-local runtime.
  - Deliverables: apply the common checklist; coordinate shape tests with `[AUDIT004-J]`/`[AUDIT004-K]`; refresh direct compare and `LCSE` slot evidence; classify missed CSE opportunities by barrier type.

- [O4Z-AUDIT-SL] - Deep audit `simplify-locals`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: local sinking, tee synthesis, structured result rewrites, dead writes, raw gate thresholds, value-carrier spills, and late cleanup interactions.
  - Deliverables: apply the common checklist; coordinate raw gate coverage with `[AUDIT002-F]`/`[AUDIT002-G]`; refresh direct compare and `SL` slot evidence; record shrink candidates separately from semantic fixes.

- [O4Z-AUDIT-CF] - Deep audit `code-folding`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: shared tails, terminating returns/unreachable, branch poison, label/helper generation, late cleanup neighborhood, and downstream code-size impact.
  - Deliverables: apply the common checklist; add missing tail/branch/label fixtures; refresh direct compare and `CF` slot evidence; decide whether any remaining Binaryen tail-sharing is worth implementing.

- [O4Z-AUDIT-MB] - Deep audit `merge-blocks`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: branch-free block flattening, loop-tail merging, drop(block) cleanup, O4z slot42 witness, label/branch safety, and interaction with RUB/RUN.
  - Deliverables: apply the common checklist; add missing merge/bailout fixtures; refresh direct compare and all `MB` slot evidence; measure any large nested-control runtime cost.

- [O4Z-AUDIT-RSE] - Deep audit `redundant-set-elimination`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: same-value set/tee removal, branch/default facts, loop invariants, refined local.get retargeting, GC wrapper/accessor facts, and late-tail preset role.
  - Deliverables: apply the common checklist; add missing CFG/value-flow fixtures; refresh direct compare and `RSE` slot evidence; classify any full fixed-point loop convergence gap.

- [O4Z-AUDIT-DAE] - Deep audit `dae-optimizing`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: dead argument/result removal, nested cleanup scheduler, selected-shape genericization, raw cleanup policy, type liveness, and pass-local runtime.
  - Deliverables: apply the common checklist; coordinate with `[AUDIT003-*]`; refresh DAE-normalized direct compare and late `DAE` slot evidence; keep accepted raw-cleanup drift separate from semantic mismatches.

- [O4Z-AUDIT-INL] - Deep audit `inlining-optimizing`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: direct inlining heuristics, optimizing cleanup scheduler, no-inline policy interaction, helper compaction, tail-call/multivalue surfaces, and local-declaration drift.
  - Deliverables: apply the common checklist; refresh direct compare and `INL` slot evidence; classify residual local-declaration mismatches; file partial-inlining/name repair only if new evidence warrants reopening deferred slices.

- [O4Z-AUDIT-DIE] - Deep audit `duplicate-import-elimination`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: duplicate import equivalence, import remapping, call/ref.func/table/export users, nonfunction and signature negatives, and metadata preservation.
  - Deliverables: apply the common checklist; coordinate tests with `[AUDIT004-G]`/`[AUDIT004-H]`; refresh direct compare and `DIE` slot evidence; record any ABI-visible import-order constraints.

- [O4Z-AUDIT-SGO] - Deep audit `simplify-globals-optimizing`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: global value propagation, nested cleanup runtime, late-tail scheduling, closed/open-world boundaries, string/GC/refinalization breadth, and accepted default-local drift.
  - Deliverables: apply the common checklist; refresh direct compare and `SGO` tail evidence; coordinate with `[SGO]003` through `[SGO]005`; keep accepted v0.1.0 signoff separate from new improvement findings.

- [O4Z-AUDIT-SG] - Deep audit `string-gathering`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: string.const gathering, canonical global reuse, data/name/export interactions, late-tail ordering, and string-heavy module code-size impact.
  - Deliverables: apply the common checklist; add missing stringref/global fixtures; refresh direct compare and `SG` tail evidence; document any Binaryen canonical-string reuse gap.

- [O4Z-AUDIT-RG] - Deep audit `reorder-globals`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: dependency-preserving global order, global.get/set remaps, exports/imports/start/elem/data interactions, string global late tail, and names/metadata.
  - Deliverables: apply the common checklist; add missing dependency/remap fixtures; refresh direct compare and `RG` tail evidence; record any order-only representation drift separately from correctness.

- [O4Z-AUDIT-DIR] - Deep audit `directize`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: immutable table facts, holes/traps, type matching/subtyping, select lowering, imported/exported/mutated table negatives, tail calls, and late-tail code-size impact.
  - Deliverables: apply the common checklist; coordinate tests with `[AUDIT004-D]` through `[AUDIT004-F]`; refresh direct compare and final `DIR` tail evidence; document any broader directization opportunities or safety bailouts.

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

### SGO - Follow-Up Improvements

- [SGO]003 - Optional Binaryen `SimplifyGlobals.cpp` Breadth
  - Status: deferred to v0.1.1; not a v0.1.0 blocker.
  - Resume when: a new semantic mismatch, wasm validation failure, targeted artifact/code-size need, or string/GC/refinalization requirement points at SGO breadth.
  - Candidate families: side-effecting-but-safe `read-only-to-write` value-flow positives, broader same-as-init expression matching beyond direct literal / `ref.null` / `ref.func`, broader runtime linear-trace propagation, and additional GC/refinalization-safe replacement surfaces.
  - Deliverables when resumed: add focused shape tests first, rerun direct `--pass simplify-globals-optimizing` oracle fuzz for the new family, and update the SGO wiki pages with the exact accepted subset.

- [SGO]004 - Nested Cleanup Runtime And Exact-Scheduler Experiment
  - Status: deferred to v0.1.1.
  - Resume when: a measured SGO-specific wall-time owner appears, the nested `vacuum` wrapper overhead becomes a concrete runtime target, or an artifact/code-size case demonstrates value from omitted nested default-function slots.
  - Candidate work: reduce nested `vacuum` / lift-lower wrapper cost, add cheaper function-filtered adapters for currently module-shaped cleanup passes, or run a controlled exact-scheduler experiment with artifact and fuzz evidence.
  - Deliverables when resumed: trace before/after nested timers, preserve validation and direct 10k SGO fuzz parity, and document whether the accepted artifact-tuned lane changes.

- [SGO]005 - Default-Local Compare Normalization
  - Status: deferred to v0.1.1 tooling/cosmetic follow-up.
  - Goal: eliminate or normalize the accepted direct SGO artifact diff where Binaryen preserves an explicit default local initialization and Starshine relies on WebAssembly default local zero-initialization.
  - Resume when: exact artifact diffs need to become quieter for release QA or compare-harness work.
  - Deliverables when resumed: either teach the compare helper to ignore explicit default local initialization when semantically equivalent, or add a deliberate Starshine emission/canonicalization option if preserving the explicit set proves more useful.

## v0.2.0 Backlog

### INL - Deferred Inliner Breadth

- [INL]005 - Partial Inlining Splitter
  - Status: deferred to v0.2.0; not a v0.1.0 blocker.
  - Resume only if a reduced Pattern A/B fixture demonstrates one of: semantic or validation correctness, a clear pass-local performance win, a downstream size/optimization win that offsets code growth, or a user-facing need for `no-partial-inline` splitter behavior.
  - Deliverables when resumed: implement or explicitly reject/scope out Pattern A and Pattern B splitting, add reduced splitter and helper-cleanup fixtures, define `no-partial-inline` behavior against the splitter, and compare direct `--pass inlining` / `--pass inlining-optimizing` on split-family repros.

- [INL]006 - Residual Name/Annotation Repair
  - Status: deferred to v0.2.0.
  - Resume only with a concrete user-facing debug-name requirement, annotation-collision requirement, semantic mismatch, wasm validation failure, or proven pass-local performance/code-size issue.
  - Deliverables when resumed: add focused repair tests first, then either implement deterministic Binaryen-like local/label name reconstruction and broader annotation collision repair or explicitly document the unsupported surface as rejected.

### Tooling And Runtime Follow-Up

- [TOOL]001 - Self-Optimize Compare Normalization Symmetry
  - Goal: make the exact artifact helper stop reporting harmless raw/debug-only outer-block drift as a pass blocker.
  - Deliverables: either canonicalize Binaryen through the same strip-debug path before canonical-function comparison while preserving `binaryen.raw.wasm`, or teach the canonical-function fallback to ignore transparent unused-label void block wrappers.
  - Acceptance: the exact-slot artifact command no longer reports `defined=200 abs=217` solely because Binaryen raw `--debug` kept an outer block that symmetric normalization removes.

- [HOT]003 - Node-Package Worker Queue Port
  - Status: deferred behind [HOT]002 and future Node package rebuild work.
  - Deliverables: reuse the native hot-batch queue contract in the shipped Node package with `worker_threads`, one WasmGC module per worker, worker-local heap state, and stable-order serialized merge.
  - Dependencies: [HOT]002 native queue contract, worker-local function serialization hooks, and future Node package rebuild work.

### FUZ - Fuzzer Hardening and GenValid Widening

#### Tiny FUZ work-slice board

Use this board as the tracking view for fuzzer work. Each slice should be small enough for one focused TDD loop: add/adjust focused tests, implement one narrow behavior, update docs/wiki counters, and run the targeted fuzz smoke plus `moon test src/fuzz` or the relevant package test. Prefer finishing p1 GenValid/metamorphic slices before p2 infrastructure unless a bug or release need says otherwise.

p1 next-up / active:
- None currently tracked. Prefer adding a new tiny GenValid/metamorphic slice before broad p2 infrastructure work if a release need appears.

p2 invalid/binary/text tiny slices:
- Census note: `[FUZ]1020D1` audited the checked-in invalid-AST registry and wiki history. The registry currently has 265 deterministic AST-invalid strategy specs across all 15 `ValidationIssueFamily` buckets after `[FUZ]1020F3` added packed-field plain-accessor coverage. Already-covered breadth includes the closed `[FUZ]1020A`/`B`/`C`/`D3`/`D4`/`D5`/`E1`/`E2`/`E3`/`E4`/`E5`/`F1`/`F2`/`F3` families: start out-of-range/wrong-kind plus imported-start signature variants, cross-kind duplicate export names, datacount absent/too-small/too-large plus mixed active/passive cardinality mismatch, element function-index/typed-expression/table-index basics plus active element/table ref-type mismatch, table/data/memory bulk operand/index families, atomics non-shared, natural-alignment, and stack/index families, SIMD lane/operand/index families, GC aggregate/input/variance/descriptor basics plus final-supertype policy, descriptor `describes` previous-definition boundary, and packed-field accessor-shape failures, ref/branch payloads including `br_on_null`, `br_on_non_null`, `br_on_cast`, multi-value `br_table` arity, `call_indirect` table element compatibility, `return_call_indirect` table element compatibility, ordinary `try_table` catch payload mismatch, and `try_table` `catch_ref` payload-plus-exnref mismatch, name-map out-of-range indices, and code-section cardinality/imported-body families. Name-section indirect-map ordering/count invalidity was classified by `[FUZ]1020G1` as binary/codec-invalid rather than AST-invalid: `NameMap` and `IndirectNameMap` arrays can be constructed in memory, but `src/binary/encode.mbt` rejects non-increasing indices with `InvalidNameMapOrder`, `src/binary/decode.mbt` rejects malformed ordered/count payloads before validation, and existing binary invalid tests cover the decode/validate split. Do not add an AST-invalid strategy for ordering/count unless the in-memory model gains a representation that bypasses codec ordering invariants and reaches `validate_name_sec(...)`.





p2 oracle/reporting/infrastructure tiny slices:
- None currently tracked. Add a new tiny slice before broad oracle/reporting/infrastructure work.
