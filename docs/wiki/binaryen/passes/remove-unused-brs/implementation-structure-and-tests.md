---
kind: concept
status: supported
last_reviewed: 2026-06-19
sources:
  - ../../../raw/binaryen/2026-06-18-remove-unused-brs-version-130-source-refresh.md
  - ../../../raw/binaryen/2026-05-06-remove-unused-brs-current-main-recheck.md
  - ../../../raw/research/0505-2026-05-06-remove-unused-brs-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-05-remove-unused-brs-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-remove-unused-brs-primary-sources.md
  - ../../../raw/research/0461-2026-05-05-remove-unused-brs-current-main-recheck.md
  - ../../../raw/research/0146-2026-04-20-remove-unused-brs-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/RemoveUnusedBrs.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/branch-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/branch-hints.h
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/cost.h
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/drop.h
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/gc-type-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/localize.h
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/properties.h
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs-desc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs-exact.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs-exact-only.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs-intrinsics.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_branch-hints.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_branch-hints-unconditionalize.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_branch-hints-shrink.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_enable-multivalue.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_levels.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_shrink-level=1.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_trap.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedBrs.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./parity.md
---

# Upstream implementation structure and test map for `remove-unused-brs`

## Why this page exists

The older RUB folder already had many local family pages, but it still lacked one compact source-backed page answering these practical questions together:

- which upstream files really matter
- which helpers are part of the algorithm rather than incidental utilities
- which official test families prove the real pass surface
- what small current-main drift has actually been verified

This page is that file-and-test map.

## File map

| File | Why it matters | Durable lesson |
| --- | --- | --- |
| `src/passes/RemoveUnusedBrs.cpp` | Core implementation | RUB is a staged function pass: flow cleanup, loop cleanup, block sinking, GC cleanup, jump-threading, and a late final optimizer. |
| `src/passes/pass.cpp` | Registration and scheduler placement | RUB is a public pass and is intentionally rerun multiple times in the default optimize pipeline. |
| `src/ir/branch-utils.h` | Branch search and retarget helpers | RUB is deeply about scope-target discovery and controlled branch retargeting, not only deletion. |
| `src/ir/branch-hints.h` | Metadata propagation helpers | Branch-hint metadata survival is part of the contract. |
| `src/ir/effects.h` | Reorder / side-effect legality | Many RUB rewrites are guarded by effect invalidation, not just by shape. |
| `src/ir/cost.h` | Unconditionalization policy | RUB only turns branching into unconditional execution when the cost model says it is worthwhile. |
| `src/ir/properties.h` | Fallthrough and select emission helpers | `selectify`, constant-branch cleanup, and GC reasoning depend on these helpers. |
| `src/ir/localize.h` | `ChildLocalizer` | Some rewrites preserve child evaluation order by explicitly localizing children. |
| `src/ir/drop.h` | Child-dropping helper | Throw/GC rewrites preserve child side effects even when replacing the parent control form. |
| `src/ir/gc-type-utils.h` | GC cast reasoning | GC BrOn simplification is a real sub-surface of RUB. |

## The core C++ shape

The pass is one function-parallel `WalkerPass<PostWalker<RemoveUnusedBrs>>`.

The main state is intentionally small:

- `anotherCycle`
- `neverUnconditionalize`
- `flows`
- `ifStack`
- `loops`
- `catchers`

That matters because it teaches what the pass is **not** using as its core proof:

- no whole CFG construction
- no SSA
- no local liveness framework
- no dominant big global summary

Instead, it is a custom structured-control walk with a few targeted helper stacks and late helper passes.

## The real helper dependency story

### Helpers that are part of the real algorithm

- `BranchUtils::BranchSeeker`
- `BranchUtils::replacePossibleTarget(...)`
- `BranchUtils::operateOnScopeNameUsesAndSentTypes(...)`
- `BranchUtils::getUniqueTargets(...)`
- `EffectAnalyzer`
- `TooCostlyToRunUnconditionally`
- `Properties::canEmitSelectWithArms(...)`
- `Properties::getFallthrough(...)`
- `Properties::getFallthroughType(...)`
- `ChildLocalizer`
- `getDroppedChildrenAndAppend(...)`
- `GCTypeUtils::evaluateCastCheck(...)`
- `BranchHints::{copyTo, copyFlippedTo, applyAndTo, applyOrTo, flip}`
- `ReFinalize`

### Helpers it notably does not use as the central proof

RUB is **not** built around:

- a classic dominator tree
- dataflow liveness over locals
- alias analysis
- a broad CFG optimizer framework

That absence is part of the real teaching surface.
RUB is structured-control-heavy, not generic-control-flow-heavy.

## Current-main freshness note

A 2026-06-18 source refresh found:

- local `wasm-opt --version` reports `wasm-opt version 130 (version_130)`, so `version_130` is the current local release oracle for this pass
- the `version_130` helper stack and `RemoveUnusedBrs.cpp` are the same staged algorithm this dossier already described
- the previous JumpThreader one-child block type-equality relaxation is now part of the local release oracle, not merely current-`main` drift
- the branch-to-trap rewrite is also part of the local `version_130` source and `remove-unused-brs_trap.wast` baseline
- a fresh `version_130` versus `main` check found no drift in `RemoveUnusedBrs.cpp` or the requested helper headers; only `remove-unused-brs_enable-multivalue.wast` expectation text drift remains, with several expected `local.tee` lines on `version_130` expected as `local.set` on `main`

Treat `version_130` as the release-oracle teaching story here. Keep the narrow lit-expectation-only `main` drift separate from release behavior.

## Official lit-family map

The upstream `version_130` lit roster contains fifteen `remove-unused-brs*` files.
That alone is a helpful teaching fact: Binaryen itself treats RUB as much broader than plain dead-branch stripping.

### `remove-unused-brs.wast`

This is the main core-behavior file.
It covers:

- `if` to `br_if`
- nested-condition folding
- `restructureIf`
- block-tail redundant `br_if` value cleanup
- `selectify`
- `optimizeSetIf`
- `tablify`

If someone only studies one upstream test file first, this should be it.

### `remove-unused-brs-gc.wast`

This is the best single file for the GC half of the pass.
It proves that RUB owns:

- `br_on_null`
- `br_on_non_null`
- `br_on_cast`
- `br_on_cast_fail`
- ref-type LUB / GLB and refinalization behavior
- some selectification in ref-typed shapes

### `remove-unused-brs-desc.wast`

This file shows the custom-descriptor side of GC branch cleanup.
It proves that descriptor-based cast forms are part of the real surface and that the pass must preserve descriptor semantics while simplifying control.

### `remove-unused-brs-exact.wast` and `remove-unused-brs-exact-only.wast`

These files prove that exact-type cast behavior matters here.
They are especially useful for teaching that RUB may need to insert or preserve casts while simplifying a BrOn family, not merely erase control instructions.

### `remove-unused-brs-eh.wast`

This is the clearest proof that caught-throw-to-branch rewriting is part of RUB.
It covers:

- `throw` caught by `try_table`
- `catch_all` versus exact `catch`
- `catch_ref` / `catch_all_ref` negative cases
- multivalue thrown payloads
- mixed `Try` versus `TryTable` conservatism

### `remove-unused-brs_trap.wast`

This file shows trap-sensitive branch threading and preservation.
It is the best single reminder that “jump goes to a trap” is not just a parity anecdote; it is an official tested family.

### `remove-unused-brs-intrinsics.wast`

This file connects RUB to Binaryen intrinsics and shrink-level behavior.
It proves that cost-sensitive unconditionalization interacts with `binaryen-intrinsics` surfaces rather than only with arithmetic toy examples.

### `remove-unused-brs_branch-hints.wast`

This file proves branch-hint metadata movement is part of the real pass contract.
Rewrites are not correct if they only preserve control semantics but lose or misplace branch hints.

### `remove-unused-brs_branch-hints-unconditionalize.wast`

This is the clearest official proof that `remove-unused-brs-never-unconditionalize` is a real behavior knob.
The flag is not wiki folklore; it has dedicated upstream coverage.

### `remove-unused-brs_branch-hints-shrink.wast`

This file proves that branch-hint propagation also matters in shrink-sensitive adjacent-`br_if` merging.

### `remove-unused-brs_levels.wast` and `remove-unused-brs_shrink-level=1.wast`

These files are the best place to learn how RUB's cost model changes with shrink level.
They show that the pass does **not** have one fixed aggressiveness mode.

### `remove-unused-brs_enable-multivalue.wast`

This file proves RUB must stay honest around multivalue control.
It is a good antidote to beginner overgeneralization from scalar-only `selectify` examples.

### `remove-unused-brs_all-features.wast`

This is the broadest surface file.
It exercises many combined modern-feature shapes and is useful for teaching that RUB is part of the general all-features optimizer, not just the MVP branch-cleanup corner.

## What the test surface means for the docs

The official test roster says RUB has at least these stable teaching buckets:

- core structured branch cleanup
- GC BrOn cleanup
- descriptor and exact-type subtleties
- EH throw-to-branch cleanup
- trap-sensitive jump threading
- branch-hint propagation
- shrink-level and unconditionalization policy
- multivalue and all-features coverage

Any dossier that only explains tail `br` / `return` stripping is therefore incomplete.

## RUB-A `version_130` behavior matrix

This matrix is the `[O4Z-AUDIT-RUB-A]` source-backed shape map for follow-up slices. It uses the local `version_130` Binaryen oracle verified on 2026-06-18. Per user instruction, WebAssembly 3.0 baseline features are assumed enabled by default; GC is not modeled as an optional gated feature for Starshine unless a local parser/tool limitation is documented as a blocker.

| Binaryen phase / helper | Source and lit evidence | Behavior family | Current Starshine coverage | Missing / partial / local blocker | Owning slice | Wasm 3.0 feature-gate note |
| --- | --- | --- | --- | --- | --- | --- |
| Main flow cleanup fixpoint: `visitAny`, `scan`, return-flow drain | `RemoveUnusedBrs.cpp` records flowing plain `br` / `return`, removes same-target block breaks, strips terminal block `nop`, merges `if` arm flows, and drains flowing returns; core coverage lives in `remove-unused-brs.wast` and multivalue edge coverage in `remove-unused-brs_enable-multivalue.wast`. | Tail `br` / `return` removal, value-forwarding of branch/return payloads, one-arm flow stops, unreachable/value-flow bailouts. | Meaningful HOT subset is implemented: tail branch/return removal, multi-value branch/return tail cleanup, tail `if` exit stripping, return-context tail stripping, carried wrapper/result-block families, and trailing-`nop` preservation rules. | Keep as current core baseline; future slices should avoid regressing payload/value-flow safety while implementing broader phases. | Covered by current core; rechecked under RUB-O final signoff. | Baseline structured-control and multivalue behavior. |
| Early `optimizeSwitch(...)` | `RemoveUnusedBrs.cpp` trims trailing default targets, removes leading defaults by subtracting an offset, handles default-only / one-target / two-option tables, and lowers very large mostly-default tables to nested `if`; `remove-unused-brs_shrink-level=1.wast` has `simple-switch*` cases. | Early switch cleanup before final optimizer. | Starshine now covers the safe early switch subset: no-payload trailing-default trimming, leading-default offsetting with `i32.sub`, default-only lowering to `drop(selector); br`, one-explicit-target/two-option lowering to branch-if structure, and large mostly-default nested stack-style lowering via a narrow O4z raw-gate exception that lets the existing HOT switch optimizer see the exact selector-plus-`br_table` region. Value-carrying trailing-default trimming and leading-default offsetting preserve payload children and stop before Binaryen's value-sensitive switch-to-branch bailout. It still has br_table continuation-wrapper retargeting and repeated equality-ladder-to-`br_table`. | Child-less local stack-payload switch shapes stay conservative because ordinary lifted value switches carry payloads as br_table children. | `[O4Z-AUDIT-RUB-B]` target cleanup and safe no-payload lowering complete, including the formerly fail-closed large nested mostly-default switch fixture. | Baseline `br_table`; no optional gate. |
| Early one-arm `visitIf(...)` cleanup | `RemoveUnusedBrs.cpp` turns one-arm `if { br }` into `br_if`, combines nested one-arm conditions with `select`, preserves branch hints, and honors effect/cost/multivalue/`neverUnconditionalize` guards; covered by `remove-unused-brs.wast`, branch-hint lit files, and multivalue lit. | One-arm branch lowering and nested condition folding. | Starshine covers one-armed `if br`, nested condition merges, two-arm branch exits, and many payload/value-if variants. | Adjacent/final optimizer variants and full `never-unconditionalize`/branch-hint semantics remain separate follow-ups. | `[O4Z-AUDIT-RUB-H]`, `[O4Z-AUDIT-RUB-N]`; some current core. | Baseline; branch hints are metadata, not a feature gate. |
| EH `visitThrow(...)` | `RemoveUnusedBrs.cpp` rewrites definitely caught `throw` to `br` for exact `catch` and `catch_all` without exnref; it drops children for catch_all and bails on `catch_ref`, `catch_all_ref`, and mixed legacy `Try`; proven by `remove-unused-brs-eh.wast`. | Caught exception-as-control-flow cleanup. | Starshine now covers the safe `try_table` subset: exact tag catches rewrite `throw` to `br` with payload children preserved, and `catch_all` without ref rewrites to payload-preserving drops followed by `br`. Focused negatives keep tag mismatches, `catch_ref`, `catch_all_ref`, and earlier `catch_ref` before later `catch_all` as exnref-transport boundaries. | Legacy old-`try`/new-`try_table` mixed-control remains documented as a local blocker for this slice because checked-in WAT lowering desugars legacy `try` to synthetic block/unreachable forms rather than producing HOT `Try` from the public pipeline; keep HOT `Try` conservative if a binary-decoder path exposes it. | `[O4Z-AUDIT-RUB-E]` complete; rechecked under RUB-O final signoff. | EH is part of the Wasm 3.0 baseline framing for this audit; the only remaining boundary is local old-`try` representation/tooling. |
| Loop cleanup: `optimizeLoop(...)` | `RemoveUnusedBrs.cpp` records loops, then after the main walk moves/conditionalizes trailing `br $loop` patterns, flips adjacent `br_if`, moves trailing slices into dead-end `if` arms, uses `BranchSeeker::count`, and stops on intervening control transfer; covered by core and multivalue lit loop cases plus branch-hint loop cases. | Loop-top branch conditionalization and suffix movement to expose removable exits. | Starshine now covers the loop reshaper: existing `if` suffix movement and block/loop rotation are joined by adjacent `br_if $exit; br $loop` condition flipping, single-use block-exit `br_if` suffix movement into an `else` arm, and Binaryen-shaped one-arm `eqz` backedge-if normalization. | Keep broad traversal closed: the implementation is local to the loop/block region and guards on childless backedges, no branch values, single-use block labels, void suffix roots, and intervening-control negatives. | `[O4Z-AUDIT-RUB-C]` complete; rechecked under RUB-O final signoff. | Baseline loop/control behavior. |
| Block sinking: `sinkBlocks(...)` | `RemoveUnusedBrs.cpp` sinks named one-child blocks into a wrapped loop body or into a safe `if` arm, skips unreachable conditions, rejects condition label use, and refinalizes; lit evidence is spread through core/multivalue shapes where later cleanup is exposed. | Move outer exit label inward so later flow cleanup can fire. | Starshine now covers the void safe subset: existing loop-wrapper rotation moves a named void block around a single loop, and `remove_unused_brs_try_sink_single_if_exit_block(...)` sinks a named void block whose sole child is an `if` into the one multi-root arm that uses the block label when the condition and opposite arm do not. | Explicit fail-closed boundaries: result-typed block/if sinks, sink-specific unreachable-condition assertions when ordinary DCE erases the shape first, single-root branch-tail arms handled by existing one-arm/self-branch cleanup instead of this sinker, and exact Binaryen branch-hint/refinalization metadata behavior. | `[O4Z-AUDIT-RUB-D]` safe subset complete | Baseline structured-control behavior; remaining deferrals are local representation/proof boundaries, not feature gating. |
| GC `optimizeGC(...)` BrOn cleanup | `RemoveUnusedBrs.cpp` uses `Properties::getFallthroughType`, `GCTypeUtils::evaluateCastCheck`, `ChildLocalizer`, `getDroppedChildrenAndAppend`, casts, descriptor handling, and `ReFinalize`; proven by `remove-unused-brs-gc.wast`, `remove-unused-brs-desc.wast`, `remove-unused-brs-exact*.wast`, and all-features lit. | `br_on_null`, `br_on_non_null`, `br_on_cast`, `br_on_cast_fail`, descriptor variants, definitely taken/not-taken, success/failure/unreachable, refinalization. | Starshine now covers the single-ref-child safe subset in HOT after a narrow raw candidate-gate update and `br_on_non_null` lifting support: non-null operands remove `br_on_null`; `ref.null` operands rewrite `br_on_null` to `drop` plus `br`; non-null operands rewrite `br_on_non_null` to direct `br`; `ref.null` operands remove `br_on_non_null`; operand types already matching the cast target rewrite `br_on_cast` to direct `br` and remove definitely-not-taken `br_on_cast_fail`. | Explicit fail-closed boundaries: BrOn forms with payload/prefix children, nullable-cast success-only-if-non-null splitting to `br_on_non_null` plus appended `ref.null`, descriptor variants absent from local `Instruction` / `HotOp`, broader fallthrough-type/local.tee cast insertion, and unreachable-input dropped-child construction. Reopen when local child-localization/cast-insertion and descriptor BrOn representation exist. | `[O4Z-AUDIT-RUB-F]` safe subset complete | GC is baseline under the user rule; the remaining deferrals are local representation/proof boundaries, not feature gating. |
| JumpThreader | `RemoveUnusedBrs.cpp` collects no-value scope uses via `operateOnScopeNameUsesAndSentTypes`, redirects through one-child named blocks, redirects child jumps to a following simple `br`, and turns simple jumps to child-plus-`unreachable` into direct `unreachable`; `remove-unused-brs_trap.wast` proves trap-sensitive behavior. | Trivial jump retargeting and branch-to-trap direct trap rewrite. | Starshine now covers three safe subsets: branch-to-trap direct `br` rewriting for a void block followed by `unreachable`; no-payload `br_if` retargeting through one-child named block shells; and no-payload `br_if` retargeting from a child block to a following simple jump. | Explicit fail-closed boundaries: unconditional direct `br` retargeting beyond the trap subset, `br_table` retargeting, branch payload sent-type preservation, and broader `replacePossibleTarget` parity. Existing local branch-exit cleanup owns several direct-`br` shapes, so those are not retargeted by the new JumpThreader helper. | `[O4Z-AUDIT-RUB-M]` complete for branch-to-trap; `[O4Z-AUDIT-RUB-G]` safe subset complete | Baseline; branch-to-trap and relaxed one-child block retargeting are in local `version_130`, not optional drift. |
| FinalOptimizer block-tail `if br else br` and adjacent `br_if` merge | `RemoveUnusedBrs.cpp` late `visitBlock` turns block-tail if/else breaks into `br_if` plus fallthrough, flips as needed, merges adjacent same-target `br_if`s under shrink with `i32.or`, and preserves/combines branch hints; lit evidence includes core, shrink-level, and branch-hints-shrink files. | Late branch lowering and adjacent conditional merge. | Starshine covers two-arm branch exits, many one-arm/payload branch rewrites, and the shrink-mode no-payload adjacent `br_if` safe subset: same-target child/stack conditions merge with `i32.or` when the later condition is locally safe to speculate, including a narrow O4z raw-gate exception for simple stack conditions. | Remaining partials: payload/value branches, broader Binaryen effect/cost modeling, adjacent `br_if` + unconditional `br` cleanup / `never-unconditionalize`, and branch-hint propagation. Starshine currently has no RUB branch-hint metadata representation, so hint `applyOrTo` behavior is explicitly deferred to `[O4Z-AUDIT-RUB-N]`. | `[O4Z-AUDIT-RUB-H]` safe subset complete; `[O4Z-AUDIT-RUB-N]` for hints / unconditionalization | Baseline; shrink level is pass option behavior, not feature gating. |
| FinalOptimizer `tablify(...)` and `visitSwitch(...)` | `RemoveUnusedBrs.cpp` lowers dense same-value equality `br_if` runs to `br_table`, requiring unique constants, no values, side-effect-free shared condition, range heuristics, fresh default labels, and uniquification; late `visitSwitch` collapses one-target switches when condition/value reorder is safe. | Dense `br_if` ladder to `br_table`; late single-target switch collapse. | Starshine now covers the no-payload dense `tablify(...)` family: `i32.eq` and `i32.eqz`, local/local.tee selector sharing, distinct branch targets, unique constants, Binaryen range thresholds, min-offset selector subtraction, and wrapper default blocks; existing br_table wrapper cleanup subsets remain covered. | Late `visitSwitch` collapse parity and branch-hint metadata behavior remain separate from the completed tablify slice; payload/value branch ladders stay conservative. | `[O4Z-AUDIT-RUB-I]` complete; `[O4Z-AUDIT-RUB-B]` for early switch; `[O4Z-AUDIT-RUB-N]` for hints | Baseline `br_table`. |
| FinalOptimizer `restructureIf(...)` | `RemoveUnusedBrs.cpp` rewrites named blocks starting with self-target `br_if`/`drop(br_if)` into `if` or `select`, requires single target use, side-effect/reorder safety, and `neverUnconditionalize`; core and branch-hints lit files cover the family. | Block-sinking-like reconstruction of `if` / `select` around self-exit `br_if`. | Starshine now covers the local HOT forms: void self-exit `br_if` prefixes rebuild to an outer one-arm `if (i32.eqz condition)`, dropped value self-exit prefixes rebuild to result `if` when the value is locally reorder-safe, and side-effectful value prefixes rebuild to `select` when the fallthrough arm is pure/order-safe enough to execute unconditionally. Existing carried-guard/result-block cleanup and block-carried one-arm payload/value-selection forms remain covered. | Branch-hint metadata transfer and public `never-unconditionalize` behavior remain explicit `[O4Z-AUDIT-RUB-N]` boundaries; value/select legality stays conservative to single-result arms with matching local HOT value types and pure fallthrough arms. | `[O4Z-AUDIT-RUB-J]` complete; `[O4Z-AUDIT-RUB-N]` for hints / unconditionalization | Baseline. |
| FinalOptimizer `selectify(...)` | `RemoveUnusedBrs.cpp` turns pure two-arm `if` into `select` when arms are emit-select-compatible, condition is reachable, arms have no side effects, condition does not invalidate arms, and the cost model permits unconditional execution; covered by core, levels, intrinsics, multivalue, all-features, and branch-hints-unconditionalize lit. | Pure value-`if` to `select` with cost/effect/refinement guards. | Starshine covers many value-if/select rewrites and reorder-safe condition ladders. | Full cost-level, intrinsic-cost, branch-hint, multivalue, and refinalization behavior is still partial. | `[O4Z-AUDIT-RUB-K]`, `[O4Z-AUDIT-RUB-N]` | Baseline; multivalue/all-features are assumed available under audit framing. |
| FinalOptimizer `optimizeSetIf(...)` | `RemoveUnusedBrs.cpp` rewrites `local.set/tee (if ...)` when one arm is a simple `br`, or when one arm copies the same local; it can recurse and flips branch hints as needed; covered by core and branch-hints lit. | Local-set/tee if-arm cleanup. | Starshine covers the locally representable `local.set` and `local.tee` arm-cleanup shapes: copy arms in either branch become one-armed setters, tee copy arms preserve the tee result through a result block, branch arms in either branch extract to `br_if` plus the surviving store/tee, flipped arms use `i32.eqz`, and region re-entry recursively cleans nested set-if copy arms exposed by branch extraction. | Branch-hint metadata transfer and public `never-unconditionalize` behavior remain explicit `[O4Z-AUDIT-RUB-N]` boundaries; broader select-cost/refinalization policy remains with `[O4Z-AUDIT-RUB-K]`. | `[O4Z-AUDIT-RUB-L]` complete; `[O4Z-AUDIT-RUB-N]` for hints / unconditionalization | Baseline local/control behavior. |
| FinalOptimizer constant-condition `visitBreak(...)` | `RemoveUnusedBrs.cpp` uses `Properties::getFallthrough` and `ChildLocalizer` to fold constant `br_if` conditions to unconditional `br` or fallthrough while preserving child evaluation and refinalizing; core lit covers constant branch restructuring. | Constant `br_if` cleanup with payload/child preservation. | Starshine covers constant `br_if` folding, including payload-carrying forms after the 2026-06-09 audit. | Treat as current core but recheck under final signoff for child-localizer-equivalent order preservation. | Covered by current core; rechecked under RUB-O. | Baseline. |
| Branch hints and `never-unconditionalize` | `branch-hints.h` provides `copyTo`, `copyFlippedTo`, `applyAndTo`, `applyOrTo`, `flip`, and `clear`; `RemoveUnusedBrs.cpp` calls them across early/final rewrites; branch-hint lit files and `remove-unused-brs_branch-hints-unconditionalize.wast` prove metadata and the pass argument. | Preserve/transform branch-hint annotations and avoid unconditionalizing when requested. | Starshine currently has no expression-level branch-hint representation in HOT/lib, no WAST parser/lowerer path for instruction-local `@metadata.code.branch_hint`, no binary code-metadata section, no RUB remap target, and no CLI/pass-manager `--pass-arg` equivalent for `remove-unused-brs-never-unconditionalize`. Existing condition-combining, selectifying, and restructuring rewrites therefore operate as the direct pass without metadata preservation or a public never-unconditionalize mode. | Reopen only with a representation design plus parser/lowerer/binary or opaque-code-metadata policy, pass-remap tests for `copyTo`, `copyFlippedTo`, `applyAndTo`, `applyOrTo`, `flip`, and `clear`, and explicit pass-option tests for every RUB rewrite that Binaryen guards with `neverUnconditionalize`. | `[O4Z-AUDIT-RUB-N]` source/docs boundary complete | Branch hints are Core 3.0 metadata, but local support is absent; absence is a documented metadata boundary rather than a semantic Wasm feature gate. |
| Helper safety layer | `branch-utils.h`, `effects.h`, `cost.h`, `drop.h`, `localize.h`, `properties.h`, and `gc-type-utils.h` provide target search, retargeting, effect/reorder checks, unconditionalization cost, dropped-child preservation, child localization, fallthrough types, select legality, and cast-result reasoning. | Safety contract for all phase rows. | Starshine has local HOT/raw safety checks but not a one-to-one port of Binaryen helper semantics. | Each implementation slice must state which helper semantics it mirrors or which local proof replaces them. | All RUB-B..RUB-N slices | Feature bits are not the primary blocker; local IR/tool support must be named specifically. |

## Practical porting lesson

A future Starshine port or parity refinement should preserve the same division of labor:

- early flow cleanup
- mid-phase loop/block preparation
- separate GC cleanup
- late jump-threading
- late final optimizer families
- metadata and refinalization repair

The official file-and-test map makes it clear that this division is not accidental implementation clutter.
It is the pass contract.
