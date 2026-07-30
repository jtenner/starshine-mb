---
kind: concept
status: supported
last_reviewed: 2026-07-30
sources:
  - ./index.md
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../../src/passes_perf_long/remove_unused_brs_perf_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./pattern-catalog.md
  - ./parity.md
  - ./tail-and-return-cleanups.md
  - ./select-and-condition-rewrites.md
  - ./branch-exit-and-payload-rewrites.md
  - ./carried-guards-and-result-blocks.md
  - ./returned-ladder-hot-shapes.md
  - ./visit-order-and-bailouts.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Current Starshine `remove-unused-brs` strategy

This page is the local strategy overview for the 2026-07-30 Binaryen-v131 closeout. For the helper walk and raw/HOT wiring, use [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md).

## Short version

Starshine's represented direct behavior is closed against Binaryen `version_131`. The implementation combines focused raw admission/no-op filters with a HOT fixpoint covering the staged upstream families:

- tail branch and return flow cleanup
- constant and one-/two-arm branch cleanup
- loop reshaping and block sinking
- EH caught-throw cleanup
- GC `br_on_*` simplification
- jump-threading and branch-to-trap cleanup
- `br_if`, `br_table`, `select`, `local.set`, and `local.tee` final optimization
- exact wrapper/dead-shell cleanup where Starshine emits canonically smaller wasm
- bounded artifact-backed raw and HOT no-op skipping for known unchanged large ladders

The remaining documented differences are product-level boundaries such as expression branch-hint metadata and `remove-unused-brs-never-unconditionalize` pass-argument plumbing, not open represented behavior or scheduler gaps.

## Exact local code map

| Surface | Owner |
| --- | --- |
| descriptor, public summary, HOT implementation | `src/passes/remove_unused_brs.mbt` |
| raw pre-lift admission, focused skip classifiers, writeback guards | `src/passes/pass_manager.mbt` |
| public registration and exact three-slot preset placement | `src/passes/optimize.mbt` |
| focused behavior and boundary tests | `src/passes/remove_unused_brs_test.mbt` and `src/passes/remove_unused_brs_wbtest.mbt` |
| exact scheduler contract | `src/passes/registry_test.mbt` |
| 21-leaf generator and profile tests | `src/validate/gen_valid.mbt`, `src/validate/gen_valid_remove_unused_brs_tests.mbt`, and `src/validate/gen_valid_tests.mbt` |
| long native-release performance lane | `src/passes_perf_long/remove_unused_brs_perf_test.mbt` |
| ordered artifact/CLI replay | `src/cmd/cmd_wbtest.mbt` |

The exact helper inventory remains in [`./pattern-catalog.md`](./pattern-catalog.md).

## What the local pass already models well

### 1. Tail branch and return cleanup

The local pass removes branch and return wrappers that already flow to the surrounding continuation, including multi-value forms.

### 2. Branch-to-`br_if` and branch-to-`select` rewrites

The current HOT engine rewrites:

- one-arm `if` breaks into `br_if`
- reorder-safe condition ladders into `select`
- value-`if` shapes into `select`
- branch-conditioned payload and return ladders when the shape is safe

### 3. Equality ladders and wrapper repair

The local pass can turn dense `br_if eq const` ladders into `br_table`, collapse lifted one-target value `br_table`s to a dropped selector plus payload branch when the selector/value order is locally safe, and retarget `br_table` continuation wrappers to the outer exit when the wrapper is redundant.

### 4. Loop and block shaping

The current engine also includes loop rotation and block sinking so later cleanup sees shallower, more obvious exit shapes.

### 5. Raw and HOT skip families

The local strategy is not just rewrite-heavy; it also has explicit skip families for very large no-op shapes. The currently named buckets include:

- `large-result-br-table-dispatch-ladder-noop`
- `large-value-if-branch-ladder-noop`
- `large-typed-br-table-encoder-ladder-noop`
- `large-drop-heavy-branch-ladder-noop`
- `structured-return-ladder-noop`
- `unique-loop-select-return-ladder-noop`
- `large-br-table-return-ladder-noop`
- `large-tagged-result-prefix-ladder-noop`
- `medium-branchy-block-ladder-noop`
- `call-heavy-mixed-if-mesh-noop`
- `localset-heavy-value-if-mesh-noop`
- `large-void-if-return-ladder-noop`
- `nested-constructor-return-ladder-noop`

Those names are implementation details, but they are useful because they tie the strategy page to exact behavior in `pass_manager.mbt` and `remove_unused_brs.mbt`.

## What upstream Binaryen still does that Starshine lacks

The local pass does not yet model the upstream visitor families for:

- the full GC `br_on_*` surface beyond the current safe subset (`br_on_null`, `br_on_non_null`, successful/not-taken and non-null disjoint-failure `br_on_cast*`, selected branch-taking prefix payloads, the no-payload `SuccessOnlyIfNonNull` split, plus child-form ordinary unreachable-input `br_on_cast*` cleanup); notes `1380`/`1396` narrow the remaining GC entries to exact blockers/non-goals: the stack-payload fallthrough `SuccessOnlyIfNonNull` split needs `ChildLocalizer`/scratch-local repair, descriptor `br_on_cast_desc_eq*` needs local representation, broader fallthrough/local.tee cast insertion needs a localizer/refinalization proof, public stack-form unreachable-input cleanup remains blocked until child-form HOT exposure or raw proof exists, and nullable disjoint `SuccessOnlyIfNull` is a Binaryen `version_131` TODO. Note `1395` rechecked the stack-payload split for `[O4Z-AUDIT-RUB-T]` and keeps it closed as a precise localizer blocker until a scratch-local proof exists; note `1396` rechecked descriptor and public stack-form status for `[O4Z-AUDIT-RUB-U]`/`[O4Z-AUDIT-RUB-W]`.
- branch-hint propagation and `remove-unused-brs-never-unconditionalize` remain unsupported until Starshine grows expression-level code-metadata representation, parser/lowerer/binary or opaque-code-metadata policy, pass-remap tests, and public pass-argument plumbing; note `1397` closes RUB-X as a product-level representation/pass-option blocker and rejects superficial RUB-only metadata rewrites or hidden flags
- the full `throw`/`try_table` cleanup family beyond the safe exact-catch and non-ref `catch_all` subset; legacy old-`try` remains a representation/candidate-exposure boundary because public WAT lowering turns it into synthetic block/unreachable forms before RUB (note `1376`)
- final-optimizer behavior outside the completed `tablify` dense-ladder, late one-target value-switch collapse, direct `selectify`, local `restructureIf` self-branch, local `optimizeSetIf`, the note `1377` same-value self-target `br_if` tail subset, the note `1378` value-legality boundary audit, the note `1379` stack-representation boundary audit, and the note `1382` final adjacent/self-target closeout; metadata-aware variants, unreachable-condition HOT-lift support, child-less stack-payload switch representation, and broader expression-equality/effect variants are accepted branch-hint/helper-proof/tooling boundaries with note `1383` reopening criteria
- broader helper-driven motion checks around label scopes and unconditionalization, including JumpThreader table retargeting for switch-owned mostly-default tables; note `1396` replaces the blanket nine-target table guard with a mostly-default-shape predicate, so pure ten-target shell retargeting is implemented while ten-target mostly-default tables stay conservative. Reopen broader table work only with tests proving mostly-default switch expectations, below-threshold mostly-default boundaries, and artifact raw gates stay green.
- a literal AST-postwalk implementation inside one owner file

Post-RUB-X bounded perf evidence in note `1398` keeps the direct pass within the repo's pass-local target on the sampled repros: median `0.715 ms` Starshine vs `0.686 ms` Binaryen on the O4z startup sample, and median `1.154 ms` vs `0.930 ms` on the normalized-equal slot42 sample. The slot42 whole-command path is still slower because non-pass traced/untraced overhead dominates, so treat the pass-local and whole-command numbers separately.

Those boundaries are intentional and documented so readers do not confuse represented behavior closeout with a literal one-to-one port of every upstream metadata and helper surface. The 2026-07-30 matrix supersedes the older approved-substitute wording: all current dedicated and random-all residuals are measured smaller Starshine outputs, and the isolated O4z-option lane contains only canonical byte matches or strictly smaller outputs. Reopen only for validation or semantic failure, loss of a measured win, a new size-losing/unclassified family, or upstream post-v131 drift.

## How to read this with the rest of the folder

- [`./index.md`](./index.md) explains the overall pass role and page map.
- [`./binaryen-strategy.md`](./binaryen-strategy.md) explains the upstream Binaryen contract.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) maps the upstream owner files and proof surfaces.
- [`./wat-shapes.md`](./wat-shapes.md) gives the beginner-friendly shape catalog.
- [`./pattern-catalog.md`](./pattern-catalog.md) records the current in-tree rewrite and skip surface.
- [`./tail-and-return-cleanups.md`](./tail-and-return-cleanups.md) covers tail exits and return-context cleanup.
- [`./select-and-condition-rewrites.md`](./select-and-condition-rewrites.md) covers value-`if`, `select`, and condition folding.
- [`./branch-exit-and-payload-rewrites.md`](./branch-exit-and-payload-rewrites.md) covers block-local `br_if`, payload-branch rewrites, and local-set arm cleanup.
- [`./carried-guards-and-result-blocks.md`](./carried-guards-and-result-blocks.md) covers carried-guard and result-block families.
- [`./returned-ladder-hot-shapes.md`](./returned-ladder-hot-shapes.md) covers the artifact-backed returned-ladder shapes.
- [`./visit-order-and-bailouts.md`](./visit-order-and-bailouts.md) covers raw/hot skip rules, mutation limits, and performance heuristics.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) is the exact MoonBit helper/code-map companion.
- [`./parity.md`](./parity.md) keeps the current artifact signoff state and the remaining gaps visible.

## Validation guidance

The current local evidence surface is:

- focused WAT tests for the exact families listed above,
- registry and explicit-pass CLI tests proving `remove-unused-brs` remains active,
- repeated-pass replay coverage on the debug artifact and ordered generated-artifact predecessors, and
- pass-targeted fuzz comparison when the implementation changes.

That is enough to keep the current HOT subset honest while preserving the distinction between local reality and upstream Binaryen's wider pass contract.
