---
kind: entity
status: supported
last_reviewed: 2026-06-21
sources:
  - ../../../raw/research/0886-2026-06-21-heap-store-optimization-descriptor-old-field-call-barrier.md
  - ../../../raw/research/0885-2026-06-21-heap-store-optimization-descriptor-old-field-effects.md
  - ../../../raw/research/0884-2026-06-21-heap-store-optimization-descriptor-block-br-if-trap-condition.md
  - ../../../raw/research/0883-2026-06-21-heap-store-optimization-later-field-block-br-if-trap-condition.md
  - ../../../raw/research/0882-2026-06-21-heap-store-optimization-later-field-if-trap-condition.md
  - ../../../raw/research/0881-2026-06-21-heap-store-optimization-descriptor-if-trap-condition.md
  - ../../../raw/research/0880-2026-06-21-heap-store-optimization-descriptor-select-trap-condition.md
  - ../../../raw/research/0879-2026-06-21-heap-store-optimization-later-field-select-trap-condition.md
  - ../../../raw/research/0878-2026-06-20-heap-store-optimization-later-field-block-br-if-pure-condition.md
  - ../../../raw/research/0877-2026-06-20-heap-store-optimization-descriptor-block-br-if-pure-condition.md
  - ../../../raw/research/0876-2026-06-20-heap-store-optimization-descriptor-block-br-if-call-condition.md
  - ../../../raw/research/0875-2026-06-20-heap-store-optimization-later-field-block-br-if-call-condition.md
  - ../../../raw/research/0874-2026-06-20-heap-store-optimization-later-field-if-call-condition.md
  - ../../../raw/research/0873-2026-06-20-heap-store-optimization-later-field-select-call-condition.md
  - ../../../raw/research/0872-2026-06-20-heap-store-optimization-descriptor-select-call-condition.md
  - ../../../raw/research/0871-2026-06-20-heap-store-optimization-mutable-descriptor-global.md
  - ../../../raw/research/0870-2026-06-20-heap-store-optimization-allocation-heavy-performance.md
  - ../../../raw/research/0869-2026-06-20-heap-store-optimization-exact-descriptor-cast-surface.md
  - ../../../raw/research/0868-2026-06-20-heap-store-optimization-unreachable-final-boundary.md
  - ../../../raw/research/0867-2026-06-20-heap-store-optimization-generic-dse-boundary.md
  - ../../../raw/research/0866-2026-06-20-heap-store-optimization-descriptor-br-on-non-null.md
  - ../../../raw/research/0865-2026-06-20-heap-store-optimization-descriptor-ref-as-non-null.md
  - ../../../raw/research/0864-2026-06-20-heap-store-optimization-descriptor-select.md
  - ../../../raw/research/0863-2026-06-20-heap-store-optimization-loop-backedge-local-read.md
  - ../../../raw/research/0862-2026-06-20-heap-store-optimization-br-table-local-escape.md
  - ../../../raw/research/0861-2026-06-20-heap-store-optimization-descriptor-later-field-global-write.md
  - ../../../raw/research/0860-2026-06-20-heap-store-optimization-descriptor-later-field-global-conflict.md
  - ../../../raw/research/0859-2026-06-20-heap-store-optimization-descriptor-later-field-local-read.md
  - ../../../raw/research/0858-2026-06-20-heap-store-optimization-descriptor-target-local-write-hazard.md
  - ../../../raw/research/0857-2026-06-20-heap-store-optimization-descriptor-target-local-hazard.md
  - ../../../raw/research/0856-2026-06-20-heap-store-optimization-descriptor-old-field-combinations.md
  - ../../../raw/research/0855-2026-06-20-heap-store-optimization-target-local-chain-variants.md
  - ../../../raw/research/0854-2026-06-20-heap-store-optimization-target-local-write-negative.md
  - ../../../raw/research/0853-2026-06-20-heap-store-optimization-subsequent-old-field-negative.md
  - ../../../raw/research/0852-2026-06-20-heap-store-optimization-subsequent-old-field-effects.md
  - ../../../raw/research/0851-2026-06-20-heap-store-optimization-core-chain-closeout.md
  - ../../../raw/research/0850-2026-06-20-heap-store-optimization-many-news-tee-barrier.md
  - ../../../raw/research/0849-2026-06-20-heap-store-optimization-many-fields-pattern-breaker.md
  - ../../../raw/research/0848-2026-06-20-heap-store-optimization-tee-later-chain.md
  - ../../../raw/research/0847-2026-06-20-heap-store-optimization-o4z-slot-evidence.md
  - ../../../raw/research/0846-2026-06-20-heap-store-optimization-br-table-table-side-stores.md
  - ../../../raw/research/0845-2026-06-20-heap-store-optimization-br-table-swap-wrappers.md
  - ../../../raw/research/0844-2026-06-20-heap-store-optimization-cross-family-store-swap.md
  - ../../../raw/research/0843-2026-06-20-heap-store-optimization-branch-wrapper-growth-boundaries.md
  - ../../../raw/research/0842-2026-06-20-heap-store-optimization-branch-wrapper-passive-boundaries.md
  - ../../../raw/research/0841-2026-06-20-heap-store-optimization-branch-wrapper-copy-boundaries.md
  - ../../../raw/research/0840-2026-06-20-heap-store-optimization-branch-wrapper-bulk-fill-boundaries.md
  - ../../../raw/research/0839-2026-06-20-heap-store-optimization-branch-wrapper-constructor-pingpong.md
  - ../../../raw/research/0838-2026-06-20-heap-store-optimization-branch-wrapper-table-global-swap.md
  - ../../../raw/research/0837-2026-06-20-heap-store-optimization-branch-wrapper-global-swap.md
  - ../../../raw/research/0836-2026-06-20-heap-store-optimization-deep-nested-growth-bulk-boundaries.md
  - ../../../raw/research/0835-2026-06-20-heap-store-optimization-nested-wrapped-growth-bulk-boundaries.md
  - ../../../raw/research/0834-2026-06-20-heap-store-optimization-nested-wrapped-growth-passive-boundaries.md
  - ../../../raw/research/0833-2026-06-20-heap-store-optimization-wrapped-growth-passive-boundaries.md
  - ../../../raw/research/0832-2026-06-20-heap-store-optimization-wrapped-passive-boundaries.md
  - ../../../raw/research/0831-2026-06-20-heap-store-optimization-wrapped-copy-boundaries.md
  - ../../../raw/research/0830-2026-06-20-heap-store-optimization-loop-wrapped-bulk-fill-boundaries.md
  - ../../../raw/research/0829-2026-06-20-heap-store-optimization-wrapped-bulk-fill-boundaries.md
  - ../../../raw/research/0828-2026-06-20-heap-store-optimization-mixed-index-copy-boundaries.md
  - ../../../raw/research/0827-2026-06-20-heap-store-optimization-multi-index-copy-boundaries.md
  - ../../../raw/research/0826-2026-06-20-heap-store-optimization-multi-index-bulk-boundaries.md
  - ../../../raw/research/0825-2026-06-20-heap-store-optimization-table-grow-bulk-boundaries.md
  - ../../../raw/research/0824-2026-06-20-heap-store-optimization-memory-grow-bulk-boundaries.md
  - ../../../raw/research/0823-2026-06-20-heap-store-optimization-memory-grow-data-boundaries.md
  - ../../../raw/research/0822-2026-06-20-heap-store-optimization-table-grow-elem-boundaries.md
  - ../../../raw/research/0821-2026-06-20-heap-store-optimization-table-size-elem-boundaries.md
  - ../../../raw/research/0820-2026-06-20-heap-store-optimization-memory-size-data-segment-boundaries.md
  - ../../../raw/research/0819-2026-06-20-heap-store-optimization-memory-size-memory-bulk-boundaries.md
  - ../../../raw/research/0818-2026-06-20-heap-store-optimization-table-size-table-set-swap.md
  - ../../../raw/research/0817-2026-06-20-heap-store-optimization-global-set-value-read-swap.md
  - ../../../raw/research/0816-2026-06-20-heap-store-optimization-unrelated-global-swap.md
  - ../../../raw/research/0815-2026-06-20-heap-store-optimization-growth-store-swap-boundaries.md
  - ../../../raw/research/0814-2026-06-20-heap-store-optimization-nested-wrapper-swap.md
  - ../../../raw/research/0813-2026-06-20-heap-store-optimization-wrapped-constructor-pingpong.md
  - ../../../raw/research/0812-2026-06-20-heap-store-optimization-loop-wrapped-table-grow-swap.md
  - ../../../raw/research/0811-2026-06-20-heap-store-optimization-loop-wrapped-memory-grow-swap.md
  - ../../../raw/research/0810-2026-06-20-heap-store-optimization-loop-wrapped-table-size-swap.md
  - ../../../raw/research/0808-2026-06-20-heap-store-optimization-if-wrapped-table-grow-swap.md
  - ../../../raw/research/0809-2026-06-20-heap-store-optimization-if-wrapped-table-size-swap.md
  - ../../../raw/research/0807-2026-06-20-heap-store-optimization-if-wrapped-memory-grow-swap.md
  - ../../../raw/research/0806-2026-06-20-heap-store-optimization-block-wrapped-memory-grow-swap.md
  - ../../../raw/research/0805-2026-06-20-heap-store-optimization-block-wrapped-table-grow-swap.md
  - ../../../raw/research/0804-2026-06-20-heap-store-optimization-block-wrapped-swap.md
  - ../../../raw/research/0803-2026-06-20-heap-store-optimization-call-swap-negative.md
  - ../../../raw/research/0802-2026-06-20-heap-store-optimization-memory-grow-swap.md
  - ../../../raw/research/0801-2026-06-20-heap-store-optimization-table-grow-swap.md
  - ../../../raw/research/0800-2026-06-20-heap-store-optimization-table-size-swap.md
  - ../../../raw/research/0799-2026-06-20-heap-store-optimization-final-root-no-swap.md
  - ../../../raw/research/0798-2026-06-20-heap-store-optimization-active-catch-throw-negative.md
  - ../../../raw/research/0797-2026-06-20-heap-store-optimization-external-exits.md
  - ../../../raw/research/0796-2026-06-20-heap-store-optimization-disappearing-bad-get.md
  - ../../../raw/research/0795-2026-06-20-heap-store-optimization-nested-control-sequence.md
  - ../../../raw/research/0794-2026-06-20-heap-store-optimization-in-function-catch-control.md
  - ../../../raw/research/0793-2026-06-20-heap-store-optimization-function-return-control.md
  - ../../../raw/research/0790-2026-06-20-heap-store-optimization-explicit-non-goals.md
  - ../../../raw/research/0789-2026-06-20-heap-store-optimization-core-chain-coverage.md
  - ../../../raw/research/0788-2026-06-20-heap-store-optimization-descriptor-loop-outer-branch.md
  - ../../../raw/research/0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../../raw/research/0530-2026-05-06-heap-store-optimization-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md
  - ../../../raw/research/0448-2026-05-05-heap-store-optimization-current-main-recheck.md
  - ../../../raw/research/0511-2026-05-06-heap-store-optimization-validation-bridge.md
  - ../../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md
  - ../../../raw/research/0246-2026-04-22-heap-store-optimization-primary-sources-and-code-map-followup.md
  - ../../../../../src/passes/heap_store_optimization.mbt
  - ../../../../../src/passes/heap_store_optimization_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap-store-optimization.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/HeapStoreOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/heap-store-optimization.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/HeapStoreOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/heap-store-optimization.wast
  - https://raw.githubusercontent.com/WebAssembly/binaryen/refs/heads/main/CHANGELOG.md
  - ../late-pipeline-dispatch.md
  - https://manpages.debian.org/experimental/binaryen/wasm-opt.1.en.html
  - https://docs.rs/wasm-opt/latest/wasm_opt/enum.Pass.html
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./swap-safety-and-control-flow.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../raw/research/0530-2026-05-06-heap-store-optimization-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../optimize-instructions/index.md
  - ../precompute/index.md
  - ../heap2local/index.md
  - ../late-pipeline-dispatch.md
---

# `heap-store-optimization`

## Role

- `heap-store-optimization` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, the public `pass.cpp` description is simply:
  - `optimize heap (GC) stores`

That summary is technically true, but it is too broad.

A better beginner summary is:

- Binaryen looks for a `struct.set` that writes into a **freshly created struct**,
- checks whether the stored value can be moved earlier safely,
- folds that value back into the matching `struct.new` field,
- and deletes or nops the now-redundant `struct.set`.

So this is **not** a general heap dead-store elimination pass.
It is a narrow GC constructor/store cleanup pass.

## Why this pass matters

- When this thread started, `docs/wiki/binaryen/passes/tracker.md` named `heap-store-optimization` as the strongest remaining implemented landing-page target.
- The canonical no-DWARF `-O` / `-Os` scheduler uses it **twice** in the default function pipeline:
  - once early after `optimize-instructions`
  - once late after the late `optimize-instructions`
- The saved generated-artifact `-O4z` audit observed the same top-level Binaryen slots:
  - slot `17`
  - slot `45`
- The saved Binaryen debug log contains `36` `running pass: heap-store-optimization` lines in total, so nested reruns matter here too.
- The local docs needed one especially important correction:
  - explain that upstream Binaryen `heap-store-optimization` is mostly about folding `struct.set` into nearby `struct.new` forms, not about generic GC store elimination or load forwarding.

## Most important durable takeaways

- Binaryen `heap-store-optimization` currently handles **`struct.set`**, not all heap stores.
- The source file itself still says:
  - `TODO: Add dead store elimination / load forwarding here.`
- The pass is built around a small number of ingredients:
  1. a CFG walk that records only `struct.set` and `block` action sites
  2. a direct tee-wrapped fold for `(struct.set (local.tee ... (struct.new ...)) VALUE)`
  3. a block-local chain scan for `(local.set X (struct.new ...))` followed by later matching `struct.set`s
  4. effect-order checks that prove the moved value can cross later constructor operands and the constructor wrapper itself
  5. a `LazyLocalGraph` query for the hardest case: control flow inside the moved value that might skip the `local.set`
  6. side-effect preservation when replacing an old field value that still matters
- `struct.new_default` can be expanded into explicit default operands so the later store can still be absorbed.
- Function-external exits are mostly safe for this pass's current goal, but in-function exits and catches can block the rewrite.
- Current upstream `main` is unusually stable here.
  - A 2026-05-05 focused current-main source bridge found no teaching-relevant drift in `HeapStoreOptimization.cpp`, the dedicated `heap-store-optimization.wast` test file, and helper surfaces versus the `version_129` contract.
- Target-local hazards are checked for each attempted chain movement.
  - Follow-up `0855` confirmed Binaryen preserves a chain when an early moved value writes the target local, but still folds an earlier harmless store before preserving a later target-local-read store.
  - Follow-up `0857` confirmed descriptor constructors keep the same moved-value target-local read hazard: Binaryen preserves the later `struct.set` rather than reading the target local before its fresh-struct assignment.
  - Follow-up `0858` confirmed the matching descriptor target-local write hazard: Binaryen preserves the later `struct.set` when the moved value assigns a replacement descriptor-constructed struct to the same local.
  - Follow-up `0859` fixed the complementary descriptor later-field local-read positive: Binaryen folds when the later constructor field reads the target local but the moved value itself has no local-state effects.
  - Follow-up `0860` fixed descriptor later-field global conflict handling for later-field reads: Binaryen folds when a later field reads mutable global `$g0` and the moved value writes unrelated `$g1`, but preserves `struct.set` when both touch `$g0`.
  - Follow-up `0861` fixed the complementary later-field global-write split: Binaryen folds when a later field writes `$g0` and the moved value reads or writes unrelated `$g1`, but preserves `struct.set` for same-global read/write conflicts.
  - Follow-up `0864` fixed a descriptor-expression parity gap for typed `select`: Binaryen folds a moved call into `struct.new_desc` when the descriptor operand selects between immutable descriptor globals under a pure condition, and Starshine now uses descriptor-aware child effect summaries for `HotOp::Select`.
  - Coverage note `0871` locked the mutable descriptor-global split: Binaryen folds a pure moved value across a mutable descriptor `global.get`, but preserves `struct.set` for a call-valued moved value that would reorder before that mutable descriptor read. Starshine already matched both shapes.
  - Coverage note `0872` locked the effectful descriptor-select boundary: Binaryen preserves `struct.set` when the descriptor operand is a typed `select` between immutable descriptor globals but the select condition is a call, and Starshine already matched.
  - Coverage note `0880` locked the trapping descriptor-select boundary: Binaryen preserves `struct.set` when the descriptor operand is a typed `select` whose condition is an `i32.load`, because folding would move a later call before a possible trap; Starshine already matched.
  - Coverage note `0881` locked the trapping descriptor-if boundary: Binaryen preserves `struct.set` when the descriptor operand is an `if` whose condition is an `i32.load`, because folding would move a later call before a possible trap; Starshine already matched.
  - Coverage note `0884` locked the trapping descriptor block `br_if` boundary: Binaryen preserves `struct.set` when a value-carrying descriptor block's `br_if` condition is an `i32.load`, because folding would move a later call before a possible trap; Starshine already matched.
  - Coverage note `0882` locked the trapping later-field `if` boundary: Binaryen preserves `struct.set` when a later constructor field is an `if` whose condition is an `i32.load`, because folding would move a later call before a possible trap; Starshine already matched.
  - Coverage note `0873` locked the matching effectful later-field select boundary: Binaryen preserves `struct.set` when a later constructor field is a typed `select` whose condition is a call, and Starshine already matched.
  - Coverage note `0874` locked the matching effectful later-field `if` boundary: Binaryen preserves `struct.set` when a later constructor field is an `if` whose condition is a call, and Starshine already matched.
  - Coverage note `0875` locked a branch-containing effectful later-field block boundary: Binaryen preserves `struct.set` when a later constructor field is a block with a value-carrying `br_if` whose condition is a call, and Starshine already matched.
  - Coverage note `0878` locked the pure side of the branch-containing later-field block split: Binaryen folds a call-valued later store through a later-field block with a value-carrying `br_if` when the branch operands are pure, and Starshine already matched.
  - Coverage note `0883` locked the trapping side of the later-field block `br_if` split: Binaryen preserves `struct.set` when a later-field block's value-carrying `br_if` condition is an `i32.load`, because folding would move a later call before a possible trap; Starshine already matched.
  - Coverage note `0879` locked a trapping later-field select boundary: Binaryen preserves `struct.set` when the later field's typed-select condition is an `i32.load`, because folding would move a later call before a possible trap; Starshine already matched.
  - Follow-up `0877` fixed the pure side of the descriptor block `br_if` split: Binaryen folds a call-valued later store through a descriptor block with a value-carrying `br_if` when the branch operands are pure; Starshine now matches by summarizing branch/drop children through descriptor-specific effects.
  - Coverage note `0876` locked the matching branch-containing effectful descriptor block boundary: Binaryen preserves `struct.set` when the descriptor operand is a block with a value-carrying `br_if` whose condition is a call, and Starshine already matched.
  - Coverage note `0865` locked the descriptor `ref.as_non_null` trap boundary: Binaryen and Starshine both preserve `struct.set` when a nullable descriptor operand may trap before the later call-valued store is evaluated.
  - Probe note `0866` found Binaryen preserves `struct.set` when a descriptor block uses `br_on_non_null` to produce an exact descriptor and falls through to `unreachable`; a focused Starshine AST fixture currently hits a HOT CFG/verifier surface blocker, so this remains an open local-surface blocker rather than HSO parity evidence or an accepted non-goal.
  - Surface note `0869` refreshed the exact descriptor `ref.cast` blocker from `0789`: Binaryen preserves `struct.set`, Starshine still rejects the exact WAT during decode, and a direct-AST `ref_cast_desc_eq` attempt does not validate as an equivalent HSO fixture. This remains a local decode/instruction-surface blocker, not an HSO semantic non-goal.
  - Coverage note `0885` locked descriptor old-field side-effect preservation: Binaryen folds a call-valued later store into `struct.new_desc` while preserving the overwritten old field's call under `drop`; Starshine already matched.
  - Coverage note `0886` locked the matching descriptor old-field plus later-field barrier: Binaryen preserves `struct.set` when folding would move a call-valued later store before a later constructor-field call, even though the overwritten old field is also a call; Starshine already matched.
- Control-flow skip-local-set hazards include loop backedges that can re-enter target-local reads.
  - Follow-up `0863` confirmed Binaryen preserves `struct.set` when a branch-valued store can `br_if` to a loop header that reads the fresh-struct target local before the next `local.set`; Starshine already matched this HSO-F negative.
- Descriptor/default old-field combinations follow the same directional effect rules.
  - Follow-up `0856` confirmed Binaryen folds `struct.new_default_desc` chain stores into `struct.new_desc` when safe, but preserves a descriptor `struct.set` when a later constructor field call orders before a moved call value.
- Generic heap dead-store elimination and load forwarding remain explicit non-goals for direct HSO.
  - Follow-up `0867` confirmed Binaryen `version_130` preserves repeated non-fresh-reference `struct.set` roots and a later `struct.get` after `struct.set`; Starshine now has matching boundary tests. Reopen only if Binaryen moves generic heap DSE/load forwarding into HSO or Starshine schedules a separate pass for those transforms.
- Unreachable constructor/set-value pairs are an explicit no-fold boundary for HSO.
  - Follow-up `0868` confirmed Binaryen `version_130` preserves `struct.set` for direct-root unreachable constructor and set-value shapes, matching Starshine's existing `0792` boundary tests. The exact direct-root set-value fixture remains a local HOT/test-surface caveat, not an accepted semantic non-goal.
- Allocation-heavy candidate performance is now measured but not closed.
  - Follow-up `0870` generated a 2000-function, 6000-`struct.set` synthetic candidate module. Both tools removed all `StructSet` roots and emitted validating wasm, but Starshine's median traced HSO pass-local time was about `10.97ms` versus Binaryen's `1.31ms`, with coarse whole-command wall time about `0.074s` versus `0.030s`. Keep HSO-I open until this is improved, accepted with release-context rationale, or superseded by broader artifact/neighborhood evidence.

## Beginner warning: what the name hides

The easy wrong mental model is:

- `heap-store-optimization` is a broad heap optimizer for GC code

The safer mental model is:

- Binaryen is mostly trying to **fold a later `struct.set` back into the constructor that made the same struct**,
- and the real work is proving that moving the stored value earlier does not reorder effects or skip the local assignment that keeps the new ref visible.

That difference matters a lot.

## What the pass sounds like versus what it actually does

What it sounds like:

- general GC heap store cleanup

What it actually is in `version_129`:

- a function-parallel CFG-based pass that only records `struct.set` and `block` action points,
- folds immediate tee or subsequent local-set patterns into `struct.new`,
- can swap a fresh `local.set(struct.new ...)` downward across safe blockers,
- materializes defaults for `with_default` constructors,
- preserves old field side effects when needed,
- and uses `LazyLocalGraph` only when control flow in the moved value might skip the moved `local.set`.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation structure, helper dependencies, scheduler placement, and the exact safety checks that make the pass much narrower than its name suggests.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Source-confirmed owner-file, helper, lit-test, registry, dispatcher, raw fast-skip, focused-test, perf-test, and CLI-replay map for upstream Binaryen and current Starshine.
- [`./swap-safety-and-control-flow.md`](./swap-safety-and-control-flow.md)
  - Focused guide to the easiest part of the pass to misunderstand: swap legality, field/descriptor reordering, target-local hazards, and the `LazyLocalGraph` rule that distinguishes safe exits from dangerous in-function skips.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering tee folds, subsequent local-set chains, default-materialization positives, safe and unsafe control-flow families, and the main bailout shapes.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current in-tree Starshine strategy and the major ways the HOT-region implementation differs from upstream Binaryen's CFG-based source while still pursuing the same core optimization; the refreshed page now also points readers to the exact MoonBit registry / dispatcher / helper-cluster / reduced-test / CLI-replay code map.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  - Compact validation bridge for the active local implementation, with the exact unit, perf, CLI replay, source-spotcheck, and refreshed direct `pass-fuzz-compare` parity surfaces.
- [`../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md)
  - Focused current-main source bridge plus exact Starshine code-map refresh for this dossier on 2026-05-05.
- [`../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md)
  - Immutable capture of the official Binaryen release, source, and lit-test URLs re-checked for this dossier on 2026-04-22.

## Freshness and naming note

The earlier landing page mostly existed to track naming evidence, so the richer dossier should keep those durable facts visible without letting them dominate the page.

Current durable answer:

- The current local release oracle is `wasm-opt version 130 (version_130)`.
- Binaryen `pass.cpp` still registers `heap-store-optimization` in `version_130`.
- The official Binaryen GitHub `version_129` release page re-checked on 2026-04-22 showed publish date **2026-04-01**.
- The current upstream changelog still records `Add a new --heap-store-optimization pass. (#6882)` under `v119`.
- A 2026-05-05 focused current-main source bridge preserved the no-teaching-drift result for `main` `HeapStoreOptimization.cpp`, the dedicated lit file, and helper surfaces, while refreshing the exact local code map.
- A 2026-06-20 `version_130` source refresh found byte-identical dedicated lit but a small source drift from `invalidates(...)` to directional `orderedBefore(...)` in swap, later-field, descriptor, and shallow-constructor movement checks. Follow-ups fixed plain-constructor shallow-effect overblocking for old-field call preservation plus moved-call folding, later-field trap/local-state overblocking where Binaryen moves a local-only value before a trapping field operand, descriptor global/call movement where an immutable descriptor `global.get` can be crossed but a mutable descriptor global cannot, one `trySwap(...)` underblocking gap where a constructor operand `global.get` cannot cross a later mutable `global.set`, and one `trySwap(...)` overblocking gap where an immutable descriptor `global.get` can cross an unrelated mutable `global.set`. A later coverage slice added source-backed `trySwap(...)` tests for `memory.size` constructor operands crossing unrelated `global.set`, trapping `i32.load` constructor operands not crossing `global.set`, and the constructor-local-set ping-pong no-fold boundary. Follow-up `0784` fixed descriptor-expression overblocking for block-wrapped immutable descriptor globals and descriptor `local.get`; follow-up `0785` fixed pure descriptor-`if` operands while preserving a call-condition negative; follow-up `0786` fixed descriptor block self-branch overblocking; follow-up `0787` fixed branchless descriptor-loop overblocking while locking a self-branching descriptor-loop negative; follow-up `0788` fixed descriptor-loop outer-branch overblocking by tracking the active loop label and then passed native-build plus direct 10000-case compare signoff. Follow-up `0789` added coverage-only repeated-store last-value and wrong-target-local tests; it also recorded exact descriptor `ref.cast` as blocked by local exact-cast/decode surface rather than accepted as an HSO non-goal. Follow-up `0790` added explicit boundary coverage for array stores remaining out of scope, but its ordinary-memory-store blocker claim was superseded by follow-up `0791`: Binaryen `version_130` crosses ordinary memory/table store blockers to reach a later fresh-struct `struct.set`, and Starshine now matches that behavior while preserving the stores themselves. Follow-up `0792` added focused unreachable constructor/set-value no-fold boundary coverage while recording a local direct-root unreachable fixture limitation. Follow-up `0793` fixed the `LazyLocalGraph`-style function-external `return` case: plain `Return` inside the moved set value is safe to fold because the taken return exits the function rather than skipping a later in-function read. Follow-up `0794` fixed the complementary in-function caught-call negative: a moved call/throw/return-call value is blocked while traversing a catchable `try`/`try_table` body because a caught throw could skip the delayed local assignment. Follow-up `0795` fixed nested expression traversal for `drop(block(result ...))` control-flow sequences so Starshine now reaches the nested local-set chain, folds the safe first store, and preserves unsafe escaping branch-valued stores when the target local is read after the block. Follow-up `0796` fixed Binaryen's exact one-disappearing-bad-get exception by allowing a branch-only root to move before the delayed constructor local assignment only when the target local is not read after the owner expression, which lets the following branch-valued store fold while keeping the `0795` outside-read negative blocked. Follow-up `0797` fixed safe external-exit classification for conditional `throw` and `return_call` set values, including Binaryen's observed `return_call` fold inside active `try_table`, while keeping ordinary caught-call behavior blocked. Follow-up `0798` promoted the active-catch conditional `throw` negative into focused coverage, confirming Starshine keeps `struct.set` there like Binaryen. Follow-up `0799` added source-backed final-root no-swap coverage for Binaryen's `trySwap(...)` last-element boundary. Follow-up `0800` added source/probe-backed coverage for swapping a `table.size` constructor operand across an unrelated mutable `global.set`, matching Binaryen's fold while preserving the table/global side effects. Follow-up `0801` added matching coverage for a table-growing constructor operand crossing an unrelated mutable `global.set`; Starshine already matched Binaryen by preserving `table.grow` / `global.set`, folding the later value into `struct.new`, and removing `struct.set`. Follow-up `0802` added matching coverage for a memory-growing constructor operand crossing an unrelated mutable `global.set`; Starshine already matched Binaryen by preserving `memory.grow` / `global.set`, folding the later value into `struct.new`, and removing `struct.set`. Follow-up `0803` added the complementary call-valued constructor operand swap negative: Binaryen keeps `struct.set` when a constructor `call` would need to cross an unrelated mutable `global.set`, and Starshine already matched. Follow-up `0804` added block-wrapped swap coverage: Binaryen folds when a `memory.size` constructor operand crosses a block-wrapped unrelated mutable `global.set`, and Starshine already matched. Follow-up `0805` added matching block-wrapped swap coverage for `table.grow` constructor operands; Starshine already matched by preserving `table.grow` / the block-wrapped `global.set`, folding the later value into `struct.new`, and removing `struct.set`. Follow-up `0806` added the corresponding block-wrapped `memory.grow` coverage; Starshine already matched by preserving `memory.grow` / the block-wrapped `global.set`, folding the later value into `struct.new`, and removing `struct.set`. Follow-up `0807` added an if-wrapped `memory.grow` counterpart; Starshine already matched by preserving `memory.grow` / the conditional `global.set`, folding the later value into `struct.new`, and removing `struct.set`. Follow-up `0808` added the matching if-wrapped `table.grow` counterpart; Starshine already matched by preserving `table.grow` / the conditional `global.set`, folding the later value into `struct.new`, and removing `struct.set`. Follow-up `0809` added the if-wrapped `table.size` counterpart; Starshine already matched by preserving `table.size` / the conditional `global.set`, folding the later value into `struct.new`, and removing `struct.set`. Follow-up `0810` added branchless loop-wrapped `table.size` coverage; Starshine already matched by preserving `table.size` / the loop-wrapped `global.set`, folding the later value into `struct.new`, and removing `struct.set`. Follow-up `0811` added matching branchless loop-wrapped `memory.grow` coverage; Starshine already matched by preserving `memory.grow` / the loop-wrapped `global.set`, folding the later value into `struct.new`, and removing `struct.set`. Follow-up `0812` added matching branchless loop-wrapped `table.grow` coverage; Starshine already matched by preserving `table.grow` / the loop-wrapped `global.set`, folding the later value into `struct.new`, and removing `struct.set`. Follow-up `0813` added the constructor ping-pong wrapper nuance: a direct intervening constructor `local.set` root remains a no-fold barrier, but `block`, `if`, and branchless `loop` wrappers around unrelated constructor assignments still fold like Binaryen. Follow-up `0814` added nested mixed-wrapper swap coverage: Binaryen folds a memory-growing constructor operand across unrelated mutable `global.set` roots nested as `block(if ...)`, `if(block ...)`, and branchless `loop(block ...)`, and Starshine already matched. Follow-up `0815` narrowed ordinary-store swap legality: Binaryen keeps `struct.set` when folding would move a constructor `memory.grow` past an intervening `i32.store` or a constructor `table.grow` past an intervening `table.set`, and Starshine already matched. Follow-up `0816` fixed mutable-global swap granularity: Binaryen folds when a constructor reads `global.get $a` and crosses an unrelated `global.set $b`, while the earlier same-global no-swap boundary from `0781` stays covered. Follow-up `0817` added coverage for the variant where the unrelated `global.set $b` value also reads `$a`; Starshine already matched Binaryen. Follow-up `0818` added a same-effect-family table boundary: Binaryen keeps `struct.set` when a constructor `table.size $ta` would need to cross an intervening `table.set $tb`, even when the tables differ, and Starshine already matched. Follow-up `0819` added same-kind memory-size/bulk-memory boundaries: Binaryen keeps `struct.set` when a constructor `memory.size` would need to cross `memory.fill` or `memory.copy`, and Starshine already matched. Follow-up `0820` extended that memory-size no-fold boundary to passive data-segment roots: Binaryen also keeps `struct.set` when the intervening root is `memory.init` or `data.drop`, and Starshine already matched. Follow-up `0821` added the corresponding table-size boundaries for table bulk / passive element roots: Binaryen keeps `struct.set` when a constructor `table.size` would need to cross `table.init` or `elem.drop`, and Starshine already matched. Follow-up `0822` added the side-effecting table.grow counterpart for those same table bulk / passive element roots, and Starshine already matched. Follow-up `0823` added the side-effecting memory.grow counterpart for passive data roots (`memory.init` / `data.drop`), and Starshine already matched. Follow-up `0824` added the memory-bulk counterpart for side-effecting `memory.grow` across `memory.fill` / `memory.copy`, and Starshine already matched. Follow-up `0825` added table-bulk counterparts for side-effecting `table.grow` across `table.fill` / `table.copy`, and Starshine already matched. Follow-up `0826` added multi-index same-effect-family fill boundaries: Binaryen keeps `struct.set` when `memory.size $ma` would cross `memory.fill $mb`, or `table.size $ta` would cross `table.fill $tb`, even when the indices differ; Starshine already matched. Follow-up `0827` added matching multi-index copy boundaries for `memory.size $ma` across `memory.copy $mb $mb` and `table.size $ta` across `table.copy $tb $tb`; Starshine already matched. Follow-up `0828` added mixed-endpoint copy boundaries for `memory.copy $mb $ma`, `memory.copy $ma $mb`, `table.copy $tb $ta`, and `table.copy $ta $tb`; Starshine already matched. Follow-up `0829` added block/if-wrapped bulk-fill boundaries where Binaryen keeps `struct.set` before same-effect-family `memory.fill` / `table.fill`; Starshine already matched. Follow-up `0830` extended that no-fold boundary to branchless loop-wrapped `memory.fill` / `table.fill`; Starshine already matched. Follow-up `0831` added block/if/loop-wrapped copy-root boundaries where Binaryen keeps `struct.set` before same-effect-family `memory.copy` / `table.copy`; Starshine already matched. Follow-up `0832` added block/if/loop-wrapped passive data/element boundaries where Binaryen keeps `struct.set` before same-effect-family `memory.init`, `data.drop`, `table.init`, and `elem.drop`; Starshine already matched. Follow-up `0833` added the side-effecting memory.grow/table.grow counterparts for those same wrapped passive roots; Starshine already matched. Follow-up `0834` added nested mixed-wrapper `block(if ...)`, `if(block ...)`, and `loop(block ...)` growth/passive no-fold coverage; Starshine already matched. Follow-up `0835` added the same nested mixed-wrapper coverage for side-effecting growth/bulk `memory.fill`, `memory.copy`, `table.fill`, and `table.copy` roots; Starshine already matched. Follow-up `0836` added deeper `block(block(if ...))`, `if(block(block ...))`, and `loop(block(block ...))` growth/bulk boundaries for those same roots; Starshine already matched. Follow-up `0837` added branch-containing wrapper coverage for unrelated global-write swap positives: Binaryen still folds a memory-growing constructor across wrappers where a `block`, `if` arm, or loop body performs `global.set` and branches to the wrapper end, and Starshine already matched. Follow-up `0838` added the matching table-side branch-wrapper positives: Binaryen folds `table.size` and `table.grow` constructor operands across the same branch-containing unrelated `global.set` wrappers, and Starshine already matched. Follow-up `0839` added branch-containing constructor ping-pong wrapper positives: Binaryen folds through block/if/loop wrappers where an unrelated constructor `local.set` branches to the wrapper end, while the direct-root constructor ping-pong barrier remains covered, and Starshine already matched. Follow-up `0840` added branch-containing bulk-fill wrapper negatives: Binaryen keeps `struct.set` when constructor `memory.size` / `table.size` operands would cross block/if/loop wrappers around same-effect-family `memory.fill` / `table.fill` roots that branch to the wrapper end, and Starshine already matched. Follow-up `0841` added the matching branch-containing copy wrapper negatives for same-effect-family `memory.copy` / `table.copy` roots; Starshine already matched. Follow-up `0842` added the matching branch-containing passive data/element wrapper negatives for `memory.size` / `table.size` constructors; Starshine already matched. Follow-up `0843` added the side-effecting `memory.grow` / `table.grow` counterparts for branch-containing bulk-memory/table and passive data/element roots; Starshine already matched. Follow-up `0844` added cross-family ordinary-store positives where `memory.size` crosses `table.set` and `table.size` crosses `i32.store`; Starshine already matched. Follow-up `0845` added explicit `br_table` wrapper coverage where the cross-family `memory.size` / `table.set` fold still happens while a same-effect-family `memory.fill` wrapper remains a no-fold barrier; Starshine already matched. Follow-up `0846` added the table-side `br_table` wrapper counterpart: Binaryen folds `table.size` across a `br_table`-wrapped `i32.store`, but keeps `struct.set` when side-effecting `table.grow` would cross the same wrapper/store shape; Starshine already matched both. Follow-up `0847` refreshed generated O4z slot evidence on current `_build/wasm/debug/build/cmd/cmd.wasm`: the first top-level early/late HSO neighborhoods remain slots `17` and `45`, and Starshine direct HSO replay on both Binaryen-produced predecessor artifacts was exact-equal and normalized-equal to Binaryen with raw-fast-skip (`0.000ms` Starshine pass-local time). Follow-up `0848` fixed the Binaryen lit `$tee-and-subsequent` family: after an immediate tee-wrapped store is folded into a `local.set(struct.new)`, Starshine now continues the same chain scan and folds later `struct.set(local.get)` roots into the same constructor instead of leaving them for a nonexistent second pass. Follow-up `0849` added coverage-only tests for the Binaryen lit `$many-fields` independent tee-root positive and `$pattern-breaker` local-copy negative; Starshine already matched both. Follow-up `0850` fixed the `$many-news` independent tee-chain barrier: an unprocessed tee-wrapped `struct.set` root now blocks another fresh-constructor chain from swapping across it, matching Binaryen's action-order behavior. Follow-up `0851` closed HSO-C by classifying the source-backed core-chain families as behavior-parity covered with no residual debris/output-shape drift in the latest direct lanes. Follow-up `0852` added Binaryen lit-backed coverage for the subsequent-chain old-field side-effect family where a later `struct.set(local.get)` replaces only one field while preserving an earlier side-effecting constructor field; Starshine already matched and focused HSO tests passed `204/204`. Follow-up `0853` added the subsequent-chain counterpart of Binaryen's old-field side-effect conflict negative, where folding would move a side-effecting field-0 store value before a side-effecting field-1 constructor operand; Starshine already matched and focused HSO tests passed `205/205`. Follow-up `0854` added source-backed target-local write hazard coverage for a moved value that overwrites the same fresh-struct local before yielding the stored value; Binaryen keeps `struct.set`, and Starshine already matched with focused HSO tests passing `206/206`. Follow-up `0855` added target-local chain variants where Binaryen preserves both stores after an early target-local write, but folds an earlier harmless store before preserving a later target-local-read hazard; Starshine already matched with focused HSO tests passing `208/208`. Follow-up `0856` added default/descriptor old-field combination coverage: Binaryen folds safe `struct.new_default_desc` chain stores into `struct.new_desc`, but keeps a descriptor `struct.set` when a later constructor field call orders before the moved call; Starshine already matched with focused HSO tests passing `210/210`. Follow-up `0857` added descriptor target-local read hazard coverage: Binaryen preserves `struct.set` when a `struct.new_desc` chain's moved value reads the fresh-struct target local; focused HSO tests passed `211/211`, and no implementation change was needed. Follow-up `0858` added the matching descriptor target-local write hazard coverage: Binaryen preserves `struct.set` when the moved value writes a replacement descriptor-constructed struct to that same local; focused HSO tests passed `212/212`, and no implementation change was needed. Follow-up `0859` fixed descriptor later-field target-local-read overblocking and passed direct 10000-case compare. Follow-up `0860` fixed descriptor later-field same-global conflict handling after Binaryen probes showed a later-field read with unrelated-global write positive and same-global write negative. Follow-up `0861` fixed the complementary later-field global-write conflict surface: unrelated moved reads/writes now fold, but same-global read/write conflicts keep `struct.set`. Follow-up `0873` added coverage-only evidence for an effectful later-field select condition: Binaryen and Starshine both keep `struct.set` when a call-valued moved store would need to cross a call in the select condition. Follow-ups `0874` and `0875` added matching coverage-only evidence for effectful later-field `if` conditions and branch-containing block `br_if` conditions; Binaryen and Starshine both preserve `struct.set` for those call-condition boundaries. Follow-up `0879` added the trapping-but-non-call later-field select condition counterpart: Binaryen and Starshine both preserve `struct.set` when the select condition is `i32.load`. Follow-up `0881` added the matching descriptor-if trapping condition counterpart: Binaryen and Starshine both preserve `struct.set` when the descriptor `if` condition is `i32.load`. Follow-up `0884` added the descriptor block `br_if` trapping condition counterpart: Binaryen and Starshine both preserve `struct.set` when the descriptor block's `br_if` condition is `i32.load`. Follow-up `0886` added descriptor old-field plus later-field call-barrier coverage: Binaryen and Starshine both preserve `struct.set` when folding would move a later call before a call in a later constructor field, even though the overwritten old field also has call side effects. Broader arbitrary descriptor expressions, remaining later-field shapes, broader default/descriptor old-field combinations, descriptor/later-field hazard combinations, broader moved-value hazards, broader in-function branch/catch negatives, final non-goal wording, and broader swap directionality remain active audit work until focused tests and compare evidence classify them.
- A 2026-05-06 direct revalidation ran `pass-fuzz-compare` at `--count 10000 --seed 0x5eed`, producing 6759 compared normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group command failures.
- The Debian experimental `wasm-opt` manpage still lists `--heap-store-optimization`.
- The published docs.rs `wasm_opt::Pass` enum still omits `HeapStoreOptimization`, so that surface is still wrapper lag, not rename pressure.

## Current maintenance rule

- Treat this folder as the canonical home for future `heap-store-optimization` parity and scheduler research.
- Use Binaryen `version_130` as the current release source oracle.
- Keep the narrow-scope correction explicit:
  - this pass is mainly about folding `struct.set` into nearby `struct.new` families
  - it is not yet generic GC heap dead-store elimination or load forwarding
- Keep the older current-main no-drift note explicit as historical stability evidence, but do not use it to hide the `version_130` directional `orderedBefore(...)` movement-check drift.
- Keep [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) in sync with local owner/test line ranges when the active HOT implementation moves.

## Validation quick links

- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  - Compact local validation bridge for unit, perf, CLI replay, and source-spotcheck checks.

## Sources

- [`../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md)
- [`../../../raw/research/0448-2026-05-05-heap-store-optimization-current-main-recheck.md`](../../../raw/research/0448-2026-05-05-heap-store-optimization-current-main-recheck.md)
- [`../../../raw/research/0511-2026-05-06-heap-store-optimization-validation-bridge.md`](../../../raw/research/0511-2026-05-06-heap-store-optimization-validation-bridge.md)
- [`../../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md`](../../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md)
- [`../../../../../src/passes/heap_store_optimization.mbt`](../../../../../src/passes/heap_store_optimization.mbt)
- [`../../../../../src/passes/heap_store_optimization_test.mbt`](../../../../../src/passes/heap_store_optimization_test.mbt)
- [`../../../../../src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`](../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md) preserves the saved generated-artifact `-O4z` slot, summary, and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
- Binaryen `version_130` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/cfg/cfg-traversal.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/local-graph.h>
- Binaryen `version_130` dedicated lit test:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap-store-optimization.wast>
- Historical Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/HeapStoreOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/heap-store-optimization.wast>
- Narrow freshness and naming sources:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/HeapStoreOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/heap-store-optimization.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/refs/heads/main/CHANGELOG.md>
  - <https://manpages.debian.org/experimental/binaryen/wasm-opt.1.en.html>
  - <https://docs.rs/wasm-opt/latest/wasm_opt/enum.Pass.html>
