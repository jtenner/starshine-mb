# Agent Tasks

## Scope And Rules

- Keep only active unreleased work or explicitly deferred future work.
- Binaryen `version_130` O4z means `wasm-opt --all-features -O4 --shrink-level 4`.
- The current 56-slot oracle, Starshine preset diff, and per-pass status audit are recorded in `docs/wiki/raw/research/1568-2026-07-13-o4z-backlog-reconstruction.md`.
- Direct pass behavior comes before ordered-neighborhood proof; preset scheduling comes last.
- Behavior parity is the target. Raw wasm/WAT equality is not required, but every remaining difference must be source-backed, measured, classified, and covered by reopening criteria.
- A pass is not closed merely because an ordinary random lane found no mismatch. Source/docs breadth, pass-specific generation, validity, performance, and the required four-lane closeout matrix still apply.
- Use `_build/native/release/build/cmd/cmd.exe` after a current native release build. Treat `target/native/...` as stale unless explicitly proven fresh.
- Moon commands must run serially.

## Binaryen v130 O4z Pass Ledger

This table covers every unique owner in the 56-slot top-level O4z path. Only rows marked **open** have active v0.1.0 work below.

| Pass | Current Starshine status | Active work |
| --- | --- | --- |
| `duplicate-function-elimination` | Direct behavior closed; both slots scheduled. | None. |
| `remove-unused-module-elements` | Direct behavior closed. | **Open scheduler gap:** second early slot. |
| `memory-packing` | Closed. | None. |
| `once-reduction` | Closed. | None. |
| `global-refining` | Closed. | None. |
| `global-struct-inference` / `gsi` | Closed for ordinary GSI. | None. |
| `ssa-nomerge` | Closed. | None; full `ssa` is separate future work. |
| `flatten` | Internal active-partial implementation; public registry remains `Removed`. | **Open implementation and public wiring.** |
| `simplify-locals-notee-nostructure` | Direct pass active; omitted from presets. | **Open modern closeout and scheduling.** |
| `local-cse` | Direct behavior closed. | **Open scheduler gap:** aggressive-prelude slot. |
| `dead-code-elimination` / `dce` | Closed. | None. |
| `remove-unused-names` | Closed. | None. |
| `remove-unused-brs` | Direct behavior closed. | **Open scheduler reconciliation:** Starshine has one extra slot. |
| `optimize-instructions` | Closed under the 2026-07-12 maintained parity contract. | None; reopen only under documented criteria. |
| `heap-store-optimization` | Closed. | None. |
| `pick-load-signs` | No known behavior gap; dedicated profile exists. | **Open modern four-lane closeout.** |
| `precompute-propagate` | Public pass removed/unimplemented; private prefix helper exists. | **Open implementation and scheduling.** |
| `code-pushing` | Closed. | None. |
| `tuple-optimization` | Closed with accepted performance exception. | None. |
| `simplify-locals-nostructure` | Closed with accepted performance caveat. | None. |
| `vacuum` | Direct behavior closed. | **Open scheduler placement:** remove/justify extra early slot and restore final slot. |
| `reorder-locals` | Closed; three slots scheduled. | None. |
| `heap2local` | Closed. | None. |
| `merge-locals` | Active-partial direct pass. | **Open LocalGraph parity and preset proof.** |
| `optimize-casts` | Closed. | None. |
| `local-subtyping` | Closed. | None. |
| `coalesce-locals` | Closed for direct and checked O4z neighborhood scope. | None. |
| `simplify-locals` | Closed. | None. |
| `code-folding` | Active narrow direct pass; not preset-ready. | **Open behavior breadth and scheduling.** |
| `merge-blocks` | Closed for the current v0.1.0 audit. | None. |
| `redundant-set-elimination` / `rse` | Direct behavior and 1x timing closed. | **Open scheduler slot.** |
| `dae-optimizing` | Active-partial; direct DAE remains raw-red; nested cleanup is incomplete. | **Open implementation and closeout.** |
| `inlining-optimizing` | Direct audit and 1x timing closed. | Shared nested-scheduler proof only. |
| `duplicate-import-elimination` | Closed and scheduled. | None. |
| `simplify-globals-optimizing` | Closed and scheduled. | Shared nested-scheduler proof only. |
| `string-gathering` | Accepted direct/preset status. | Non-blocking decoder/performance follow-up only. |
| `reorder-globals` | Accepted direct/preset status. | None. |
| `directize` | Accepted default direct/preset status. | Optional pass-arg breadth deferred. |

## v0.1.0 Primary O4z Work

### [O4Z-FLAT]001 - Implement `flatten`

- **Status:** internal active-partial owner and focused tests now exist; registry category remains `Removed` until the admitted surface is safe to expose.
- **Goal:** implement Binaryen v130 `flatten` sufficiently for the O4z aggressive local-cleanup prelude.
- **Why:** O4z slot 9 is the first missing executable owner and blocks the exact `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood.
- **Current progress:** analysis-only Flat IR classification, scalar function-result materialization, reachable/unreachable `local.tee` lowering at function roots, structured-region roots, and ordinary operand positions, ordered scalar ordinary-operand preludes, branch-free defaultable scalar `block`/`if` routing, branch-free defaultable independently produced multivalue `block`/`if`, one exact exclusive tuple-made multivalue block tail, if-arm tail, plain block/if-targeting `br` payload, repeated-target `br_table` payload, or exact block/if-targeting `br_if` flow, and zero-input `loop` routing across payloadless backedges through exclusive consumer spans, branch-targeted independently scalar multivalue `if` arms with plain exits, branch-free scalar and independently produced multivalue legacy `try` do/catch routing behind an EH-repair gate, branch-free zero-input/no-backedge scalar `loop` result routing, plain carried scalar `br`, plain independently scalar multivalue block-targeting `br` including mixed fallthrough plus nested plain exits, same-type carried scalar `br_if`, and the source-backed target-type versus false-path-flow-type `br_if` mismatch are implemented with focused verifier-backed tests. Scalar `br_if` now preserves rich ordinary payload origins: it evaluates an effectful payload once before the condition, redirects false-path and chained conditional uses through locals, and avoids generic operand spilling at the shared origin. Direct terminal branches unblock target-block result erasure, mixed supported `br`/`br_if` exits share one target temp, and mismatched `br_if` uses a second typed flow temp. Scalar `br_table` fanout now preserves rich ordinary payload origins too: it evaluates one payload into a staging temp before a rich selector, copies it to every unique defaultable scalar block/if target or one-parameter loop entry temp, deduplicates repeated labels, and removes the original terminal payload root. Same-vector multivalue `br_if` payloads now route for defaultable block/if targets when every distinct payload has exactly one non-branch use and those false-path uses form one contiguous ordered target-tail span. Same-vector multivalue `br_table` now stages independently scalar payload components once before selector work, deduplicates repeated labels, and copies the ordered vector into every exact nested defaultable block target channel. Repeated HOT region-tail ownership is admitted only as one exclusive ordered span so inner target results can feed an enclosing target without reevaluation; exact inputful loop-plus-enclosing-block fanout is admitted when the loop has independently scalar fallthrough results, and exact loop-plus-repeated-control fanout is admitted when one repeated exclusive block/if-result tail feeds a distinct loop-result vector, including one exact enclosing-block target. Broader mixed control fanout and nested or nonexclusive conditional loop flow remain gated. Vector type mismatch and ambiguous/shared flow ownership remain behind the intentional whole-function gate. Nested terminal `br`/`br_table`/`return`/`return_call`/`return_call_indirect`/`return_call_ref`/`throw`/`throw_ref` effects now stay in their owner-region prelude and leave an `unreachable` placeholder at the old operand, without duplicating an already sequenced root; payload and argument work remains before the terminal in source order, and later sibling preludes remain later; unsupported root value-controls are no longer wrapped under `local.set`. Defaultable scalar branch-targeted `if` now preflights all label uses, shares the arm-result temp with carried `br`/`br_if` channels, and keeps unsupported nondefaultable payloads whole-function fail-closed. Defaultable inputful scalar-result loops without backedges now stage each independently scalar entry once in source order, or scalarize one exact tuple-made entry whose immediate reversed direct-drop prefix owns every lane; both routes redirect body uses through typed locals, clear the loop parameter prefix, and keep result routing distinct. Inputful multivalue-result loops now admit independently scalar exact entries and independently scalar or one exact exclusive tuple-made fallthrough result tail for an exact independently scalar or exclusively tuple-made plain `br` backedge, an exact same-vector `br_if` from independently scalar or one exclusively tuple-made payload whose immediate reversed false path contains direct drops, single-use same-typed binary expressions with simple right operands, or single-use exact unary/conversion expressions, or an exact multivalue `br_table` that fans to the loop plus either an enclosing block or one repeated exclusive block/if-result tail, optionally with one enclosing-block target; entry, nested-control, enclosing-target, and result vectors remain distinct as applicable. Nondefaultable and other multivalue single-producer entries fail closed before mutation. Payloadless zero-input backedges and independently scalar defaultable one- or multi-parameter `br`/`br_if` backedges now reuse typed entry locals, evaluate payloads once in order before conditional tests, preserve conditional false-path flow, clear loop payload arity, and keep loop results on a distinct temp. Independently scalar defaultable one- or multi-parameter `br_table` backedges stage every payload once in source order, copy each vector into unique loop-target entry locals before selector work, clear table/loop arity, and remove terminal payload roots. All admitted block, if, and loop branch channels now share one per-label typed local vector with centralized type matching and allocation. Branch-free multivalue blocks and ifs plus zero-input multivalue loops with payloadless backedges and independently scalar defaultable tails now write ordered typed locals, erase control arity, and replace an exclusive repeated HOT consumer span with matching local reads. Mixed multivalue blocks preflight every label use, route nested plain `br` payloads and independently scalar fallthrough tails through one shared typed vector, and clear branch/control arity. Branch-targeted multivalue ifs admit independently scalar fallthrough arms, terminal plain `br` arms, and same-vector conditional arms with exact exclusive false-path tails through the same typed vector while preserving condition/arm placement. Scalar legacy tries route exact do/catch tails through one shared typed local, admit one exact named-target family where every try-label use is a plain carried `br`, and admit one exact scalar `br_if` family where a supported matching payload has exactly one immediate direct-drop, unary, conversion, or same-typed binary false-flow consumer with a simple opposite operand in the same arm; each remaining arm is an independently scalar matching fallthrough. Multivalue legacy tries route per-arm exact independently scalar tails or separately owned exact tuple-made tails with supported scalar component origins through one shared typed vector when the repeated HOT result uses form one exclusive consumer or region-tail span; the same vector accepts exact plain try-label `br` payloads and exact try-label `br_if` payloads from independently scalar lanes or one exclusively owned repeated `TupleMake`. Conditional payloads preserve payload-before-condition order. Independently scalar lanes or one exclusively owned repeated `TupleMake` admit one immediate reversed false-path span of direct drops or single-use exact unary/conversion consumers whose results are directly dropped. Independently scalar lanes and one exclusively owned repeated `TupleMake` also admit exact single-use same-typed binaries with simple right operands. Exact terminal scalar `br_table` families admit one repeated try label, that try plus a strict direct-enclosure chain of matching defaultable blocks without a hardcoded length cap, or that try plus zero or more such blocks followed by one or more directly enclosing matching value `if`s, with all ifs outermost and no hardcoded count cap. Exact multivalue families admit one repeated try label; independently scalar payloads may target that try plus a strict direct-enclosure chain of matching blocks or zero or more such blocks followed by one or more directly enclosing matching value `if`s, with all ifs outermost and no hardcoded count cap; one exclusively owned repeated `TupleMake` may target the unbounded strict block chain, or any strict directly enclosing matching block chain (including zero blocks) followed by one, two, three, four, five, six, or seven directly enclosing matching value `if`s, or exactly eight directly enclosing matching value `if`s with no intervening blocks. Every payload lane stages once before selector work and copies into distinct per-label channels. `flatten_eh_repair_requirement(...)` now classifies missing typed catch-payload tracking separately from exceptional-transfer repair before mutation. Functions with legacy `Catch`/`CatchAll`, `rethrow`, or `delegate` nodes remain whole-function fail-closed pending a representable Binaryen-equivalent payload-pop move and nested-pop repair. `FlattenRunAdmission` now distinguishes upstream-hard-unsupported `BrOn*`/`TryTable` from representable deferred loop, try, and branch families before mutation; whitebox coverage proves no partial rewrite, but public admission still requires Binaryen-compatible user-visible rejection. Remaining multivalue single-producer payloads, including richer tuple-made loop conditional/result producers, arbitrary multivalue single-producer legacy-try arms, and mixed/table loop backedges, mismatched or ambiguously shared multivalue `br_if`, broader mixed-control or nonexclusive multivalue `br_table`, nested or nonexclusive conditional multivalue loop control, broader mixed-target try tables, repeated-`TupleMake` payloads for block-plus-eight-if and nine-or-more-if chains, shared/mixed tuple table payloads, nonterminal try tables, multivalue reversed/rich-right binary, non-immediate, nested, or shared conditional flow, shared/mixed tuple branch-targeted, and repair-sensitive legacy-try/EH shapes, `rethrow`/`delegate` repair, profiles, and public wiring remain open.
- **Deliverables:**
  - [ ] Refresh the v130 owner/lit matrix and select the safe first Flat-IR/control linearization slice.
  - [ ] Add red-first focused fixtures for supported block/loop/if/EH shapes and explicit fail-closed negatives.
  - [ ] Add the real registry entry, dispatcher path, owner file, CLI/harness admission, and pass-specific GenValid aggregate.
  - [ ] Preserve validation, branch payloads, labels, traps, effects, local types, and nondefaultable-ref constraints.
  - [ ] Complete the required four-lane direct matrix and pass-local timing.
  - [ ] Prove the ordered `ssa-nomerge -> flatten -> simplify-locals-notee-nostructure -> local-cse -> dce` neighborhood before preset wiring.
- **Dependencies:** HOT control reconstruction, local/type repair, and exact label/branch handling documented in `docs/wiki/binaryen/passes/flatten/`.
- **Exit criteria:** direct Binaryen behavior parity for the admitted v0.1.0 surface, no broad undocumented family deferral, and a green aggressive-prelude neighborhood.

### [O4Z-SLNNS]001 - Modern-close and schedule `simplify-locals-notee-nostructure`

- **Status:** direct pass implemented and historically green; not modern-closeout complete and not preset-scheduled.
- **Goal:** make slot 10 independently signable and ready to follow `flatten`.
- **Why:** current evidence predates the pass-specific-profile/four-lane closeout standard, and living docs intentionally keep the pass direct-only.
- **Deliverables:**
  - [ ] Add a dedicated aggregate GenValid profile covering no-tee positives, no-structure constraints, control/EH barriers, effects/traps, and nondefaultable-ref boundaries.
  - [ ] Refresh v130 source/lit coverage and focused negative tests.
  - [ ] Reduce and remove, or narrowly justify with artifact evidence, the broad large-module skip that currently keeps hazardous direct shapes from running.
  - [ ] Run regular 100000, wasm-smith 10000, dedicated 10000, and random-all 10000 lanes.
  - [ ] Measure pass-local timing on representative candidate-heavy and O4z-prelude fixtures.
  - [ ] Add exact preset-order tests only after `[O4Z-FLAT]001` and the aggressive LCSE slot are ready.
- **Exit criteria:** modern direct closeout plus a green `flatten -> SLNNS -> local-cse` neighborhood.

### [O4Z-PCP]001 - Implement public `precompute-propagate`

- **Status:** public spelling is removed; `precompute_propagate_prefix_descriptor()` exists only as an internal helper.
- **Goal:** implement Binaryen's propagating precompute mode as a real direct pass and use it in O4z slots 19 and 43 plus nested optimizing reruns.
- **Why:** Starshine currently substitutes plain `precompute`, which is a different contract. Direct `precompute` closeout does not close `precompute-propagate`.
- **Deliverables:**
  - [ ] Refresh the v130 `Precompute.cpp` mode split and dedicated tests.
  - [ ] Expose a public descriptor/registry/dispatcher/harness spelling with truthful SSA requirements.
  - [ ] Add red-first propagation fixtures that plain `precompute` intentionally does not perform.
  - [ ] Add a pass-specific GenValid aggregate and four-lane closeout.
  - [ ] Replace both plain-precompute preset substitutions with the propagating pass after ordered proof.
  - [ ] Reuse the same public implementation for DAE/inlining nested prefixes rather than maintaining a private semantic fork.
- **Exit criteria:** direct propagating-mode parity, two green top-level neighborhoods, and shared nested-prefix use.

### [O4Z-ML]001 - Complete `merge-locals`

- **Status:** active-partial direct module pass; current implementation is a conservative linear same-typed copy-retargeting subset.
- **Goal:** implement Binaryen LocalGraph-equivalent orientation/rollback behavior needed by O4z slot 27.
- **Why:** broader control-flow-spanning copy traffic, graph orientation, rollback, and late-neighborhood proof remain explicitly open in the living dossier.
- **Deliverables:**
  - [ ] Build a source-backed matrix for diamonds, loops, branches, EH, multivalue, refs, tees, interrupted copy chains, and name/type repair.
  - [ ] Implement graph-backed candidate/orientation analysis without unsafe same-type slot aliasing.
  - [ ] Add a dedicated `merge-locals-all` GenValid profile and modern four-lane closeout.
  - [ ] Meet the direct pass-local timing target on copy-heavy structured fixtures.
  - [ ] Prove `heap2local -> merge-locals -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse`.
- **Exit criteria:** full admitted LocalGraph behavior parity and a green slot-27 neighborhood.

### [O4Z-CF]001 - Finish and schedule `code-folding`

- **Status:** active narrow direct HOT pass; prior direct audit accepted a subset, but current living docs still disclaim full Binaryen tail-sharing coverage and preset readiness.
- **Goal:** close the remaining source-backed terminating-tail/expression-exit families and schedule slot 38.
- **Why:** a subset signoff is not enough for O4z behavior parity, and `code-folding` is absent from both public presets.
- **Deliverables:**
  - [ ] Reconcile the v130/current cost/search structure and remaining exact tail-family matrix.
  - [ ] Implement or narrowly classify remaining named/unnamed, typed, EH, multivalue, and expression-parent families.
  - [ ] Add a pass-specific aggregate profile and current four-lane closeout.
  - [ ] Recheck candidate-heavy pass-local timing after current source-cost reconciliation.
  - [ ] Prove `vacuum -> code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks`.
- **Exit criteria:** no broad source-backed behavior disclaimer remains, direct closeout is current, and slot 38 is scheduled with exact-order tests.

### [O4Z-DAE]001 - Complete `dae-optimizing`

- **Status:** highest remaining implemented-pass risk. Direct/plain DAE remains raw-red; the latest reduction-disabled 10000-case evidence is `5000` normalized dedicated direct, `9136` normalized direct random-all, and `9633` normalized optimizing random-all, with zero failures but unresolved families. Current `dae_run_nested_cleanup(...)` applies one exact-ref fold/rerun path and otherwise returns the module unchanged.
- **Goal:** replace selected/artifact-specific behavior with generic Binaryen-compatible DAE and implement real touched-function optimizing cleanup.
- **Why:** O4z slot 48 is already scheduled, but the implementation and nested scheduler are still partial.
- **Deliverables:**
  - [ ] Keep shrinking direct DAE residual families by source-backed transform ownership, not output-shape acceptance alone.
  - [ ] Complete generic parameter removal, constant-actual propagation, result removal, GC type refinement, multivalue/control reconstruction, tail-call safety, and type-section repair.
  - [ ] Replace remaining selected `FuncXXX` gates with generic recognizers where possible; document any retained artifact-only boundary with reopening criteria.
  - [ ] Implement the touched-function nested `precompute-propagate -> default O4z function pipeline` using shared scheduler infrastructure.
  - [ ] Remove or narrowly justify large-module/touched-set guards with runtime and performance evidence.
  - [ ] Keep direct DAE and `dae-optimizing` profiles/results separate.
  - [ ] Complete current four-lane direct and optimizing closeout plus ordered slot-48/runtime artifact proof.
- **Current sources:** `docs/wiki/binaryen/passes/dead-argument-elimination/`, `docs/wiki/binaryen/passes/dae-optimizing/`, and research notes `1562` through `1567`.
- **Exit criteria:** zero unclassified direct/optimizing residual families, real touched-only nested cleanup, no selected-function correctness dependency where a generic proof is feasible, and valid runtime-green O4z slot behavior.

### [O4Z-PLS]001 - Reclose `pick-load-signs` under the modern standard

- **Status:** evidence-only blocker; no known semantic behavior gap.
- **Goal:** complete the required current four-lane matrix using `pick-load-signs-all`.
- **Deliverables:**
  - [ ] Regular GenValid 100000 at seed `0x5eed`.
  - [ ] Explicit wasm-smith 10000 at seed `0x5eed`.
  - [ ] `pick-load-signs-all` 10000 at seed `0x5eed`.
  - [ ] `random-all-profiles` 10000 at seed `0x5555`.
  - [ ] Refresh pass-local timing and the saved/current slot-18 neighborhood if behavior or performance moved.
- **Exit criteria:** current matrix classified with no new behavior gap or Starshine failure; then remove this slice.

### [O4Z-PRESET]001 - Reconcile the exact 56-slot public preset

- **Status:** blocked on direct pass work above.
- **Goal:** make Starshine's `shrink`/O4z expansion intentionally match the Binaryen v130 56-slot top-level order, with documented Starshine-only extensions.
- **Current differences to resolve:**
  - [ ] Add the second early `remove-unused-module-elements` slot.
  - [ ] Add `flatten -> simplify-locals-notee-nostructure -> local-cse`.
  - [ ] Remove or prove the extra early `vacuum -> remove-unused-brs` pair.
  - [ ] Replace both plain `precompute` substitutions with `precompute-propagate`.
  - [ ] Add `merge-locals` after `heap2local`.
  - [ ] Add `code-folding` before the first late `merge-blocks`.
  - [ ] Add `redundant-set-elimination -> vacuum` after late HSO.
  - [ ] Keep final `strip-debug` explicitly documented as a Starshine extension outside the Binaryen 56 slots.
  - [ ] Preserve feature gates, no-DWARF policy, repeated cleanup slots, canonical aliases, and exact order tests.
- **Exit criteria:** exact expansion tests, every newly scheduled direct pass independently signed off, and an ordered generated-artifact/runtime/size comparison with no unclassified regression.

### [O4Z-NESTED]001 - Reconcile optimizing nested reruns

- **Status:** partially implemented across DAE, inlining, and SGO.
- **Goal:** make nested optimizing reruns use one shared, truthful, touched-function-filtered representation of the final O4z function pipeline.
- **Why:** top-level order is insufficient. Binaryen reruns function cleanup after DAE/inlining, and SGO reruns the default function pipeline without the extra propagating prefix.
- **Deliverables:**
  - [ ] Define one tested function-pipeline expansion API parameterized by O4z levels, feature gates, and whether `precompute-propagate` is prepended.
  - [ ] Route DAE, inlining, and SGO through it without semantic forks.
  - [ ] Preserve touched-function filtering; do not mutate unrelated functions.
  - [ ] Replace broad large-module/tail-call bypasses only with focused safe guards or repaired owners.
  - [ ] Add exact nested-order tests and pass-specific runtime/artifact evidence.
- **Dependencies:** `[O4Z-FLAT]001`, `[O4Z-SLNNS]001`, `[O4Z-PCP]001`, `[O4Z-ML]001`, `[O4Z-CF]001`, and `[O4Z-PRESET]001`.
- **Exit criteria:** DAE/inlining/SGO nested traces match the intended roster and stay valid, runtime-green, and within accepted pass-local performance bounds.

## v0.1.0 O4z Supporting Work

### [O4Z-STARTUP]001 - Preserve the startup-map regression guard

- Keep `tests/repros/o4z-debug-startup-map-init-repro.wasm` until a smaller generated-artifact fixture replaces it.
- Recover precision one owner at a time only with focused tests and runtime evidence: nested SSA liveness, safe commutative ordering, tee-aware local sinking, path-sensitive local coalescing, and branchy vacuum cleanup.
- Source: `docs/wiki/raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md`.

### [JSON-AS]001 - Repeatable artifact correctness and size signoff

- **Goal:** keep a pinned opt-in `json-as` replay that builds debug artifacts, validates Starshine/Binaryen outputs, executes runtime suites, and records section/function/type/code/custom-section deltas.
- **Active work:**
  - [ ] Add a documented opt-in clone/build/replay task under existing Bun tooling; do not add shell scripts under `scripts/`.
  - [ ] Re-measure the final `strip-debug` custom-section wins.
  - [ ] Measure each newly scheduled O4z pass/neighborhood on medium-naive, medium-simd, and large-swar artifacts.
  - [ ] Keep validation and runtime execution separate; validation alone previously missed corruption.
  - [ ] Prefer `d8` when available; otherwise retain a checked-in-equivalent Node/WASI smoke path.
- Historical completed correctness incidents belong in the wiki, not as active entries.

### [WALL]001 - Cross-pass wall-time attribution

- Separate pass-local time from decode, validation, HOT lift/lower, parse/emit, buffering, caching, and process startup.
- Keep aggregate wall time outside direct pass correctness closeout unless a pass is clearly the owner.
- Current recurring targets: self-optimization command overhead, repeated HOT lifting, validation/encoding, and any newly widened exact O4z preset.

### [AUDIT]002 - Raw skip and threshold boundary coverage

- Inventory all `can_skip`, `unchecked`, `giant`, `large`, and numeric threshold gates in `src/passes/pass_manager.mbt`.
- Add focused ±1 boundary tests and trace reasons for RUB and simplify-locals gate families.
- Distinguish correctness guards from performance guards and remove unexplained magic thresholds.

### [TOOL]001 - Self-opt compare normalization symmetry

- Canonicalize equivalent Binaryen/Starshine artifact paths symmetrically or ignore only proven transparent unused-label void wrappers.
- Preserve raw artifacts; do not hide semantic, size-losing, or validation differences behind normalization.

### [STRIP-DEBUG]001 - Artifact measurement

- Direct pass and final preset placement are complete.
- Re-measure debug-artifact custom-section size, validation, and runtime effects after the final O4z scheduler lands.

## v0.1.1 Optimizer Follow-ups

### [SSA-FULL]001 - Complete public full `ssa`

- Not an O4z blocker: O4z uses `ssa-nomerge`.
- Active work: simple explicit-write merge locals; parameter/default entry inputs and prepend ordering; loop/branch/EH/typed-control classification; harness admission; dedicated profile; direct closeout.

### [AUDIT]003 - DAE de-artifacting

- Inventory selected-function helpers by transform family and safety proof.
- Convert the smallest safe families to generic recognizers with red-first non-artifact fixtures.
- Keep selected fixtures as regressions; retain selected-only gates only with explicit reasons and reopening criteria.

### [AUDIT]004 - Thin module-pass coverage

- Keep only still-useful test expansion:
  - `directize`: imported/exported/passive/declarative/multi-table/tail-call negatives and positives;
  - `merge-locals`: multivalue/ref/control/effect interruption/name cleanup;
  - any newly widened scheduler owner from the primary O4z queue.
- Closed DIE/once-reduction audit batches do not need duplicate active tasks.

### [AUDIT]005 - Standalone no-inline policy tests

- Add focused `no-inline`, `no-full-inline`, and `no-partial-inline` marker tests independent of inlining integration.

### [AUDIT]006 - Function `TypeIdx`/`RecIdx` invariant documentation

- Finish the wiki/inline/test documentation that module function-section references are global `TypeIdx`, while `RecIdx` is rec-group-local and impossible in validated function-section positions.

### [SGO]003-[SGO]005 - Deferred SGO improvements

- Optional breadth only after a new semantic/artifact need.
- Nested-cleanup runtime experiments only with measured ownership.
- Default-local compare normalization is tooling/cosmetic work, not a direct SGO correctness blocker.

## v0.2.0 Deferred Work

### Shared-Everything Threads

Keep the dependency order; detailed proposal rules live in the Shared-Everything wiki pages.

1. Model proposal entities, heap/reference types, limits/flags, rec groups, shared descriptors, and annotations.
2. Decode/encode proposal bytes with contextual legality checks and round-trip tests.
3. Validate shared/unshared domains, type graphs, subtyping/LUB/GLB, rec groups, memory/table/global/tag rules, and proposal opcodes.
4. Link/import/export proposal entities and type graphs without index or ownership corruption.
5. Extend optimizer harness protocol, feature flags, semantic hashing, and compare/fuzz normalization.
6. Extend generators and shrinkers with high-yield proposal cases.
7. Preserve proposal structures through HOT lift/lower with provenance and correct failure boundaries.
8. Expose CLI flags, update docs, and run focused plus full proposal signoff.

### [INL]020-[INL]024 - Deferred inlining breadth

- Add EH/tail-call/multivalue/generated direct-call coverage only after the shared type/HOT substrate is ready.
- Revisit tiny hot-path struct/array allocation inlining only with measured canonical-size and wall-time wins.
- Keep table/indirect-call callee-recovery research deferred until the direct-call surface is stable.

### [HOT]001-[HOT]004 - Deferred structural improvements

- Replace exact-expression span identity with stronger source provenance where needed.
- Preserve unknown/custom metadata through HOT round trips.
- Reduce opaque fallback lowering without sacrificing correctness.
- Keep any O4z startup-map local/tee/loop repair tied to `[O4Z-STARTUP]001` rather than opening unrelated HOT rewrites.

### [FUZZ]001 - Continuous parity triage

- Keep no permanent active bug entry when all maintained suites are green.
- On a new mismatch: save the seed/artifacts, minimize it, classify it, add the focused regression first, repair the owning pass/harness/codec, and archive the durable result in the relevant dossier.

## Backlog Hygiene

- Remove a slice when its exit criteria are met; do not retain completed checkbox diaries here.
- Move durable closeout evidence to the pass dossier, `docs/wiki/log.md`, or a numbered research note.
- Add a new active slice only when it has a concrete owner, goal, reason, deliverables, dependencies, exit criteria, and suggested tests.
- Keep release blockers and known failures visible until resolved.
