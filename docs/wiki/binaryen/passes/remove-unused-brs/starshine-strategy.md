---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-06-remove-unused-brs-current-main-recheck.md
  - ../../../raw/research/0505-2026-05-06-remove-unused-brs-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-05-remove-unused-brs-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-remove-unused-brs-primary-sources.md
  - ../../../raw/research/0461-2026-05-05-remove-unused-brs-current-main-recheck.md
  - ../../../raw/research/0247-2026-04-22-remove-unused-brs-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0146-2026-04-20-remove-unused-brs-binaryen-research.md
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../../src/passes/perf_test.mbt
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

This page is the local strategy overview. A 2026-05-06 current-main recheck stayed aligned on the reviewed surfaces, so the local gap story is unchanged.
For the exact helper walk and finer-grained code map, use [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md).

## Short version

Current Starshine `src/passes/remove_unused_brs.mbt` is a real HOT pass, but it is still narrower than the current local Binaryen `version_130` `RemoveUnusedBrs.cpp` oracle.

The implemented center of gravity is:

- tail `br` / `return` cleanup
- one-arm and two-arm `if` cleanup
- `br_if` / `select` canonicalization
- `br_if` equality ladders to `br_table`
- block-local payload and result-block cleanup
- `br_table` continuation-wrapper repair
- loop rotation and block sinking
- recursive region cleanup around explicit `nop`, pure-result `drop`, and `unreachable` residue
- artifact-backed raw and HOT no-op skipping for very large branch/return ladders

That is a meaningful implemented pass.
But it is not yet the full upstream AST surface.

## Exact local code map

| Surface | Exact code location |
| --- | --- |
| registry descriptor and public summary | `src/passes/optimize.mbt:184-186` |
| repeated optimize/shrink preset slots | `src/passes/optimize.mbt:287-290`, `src/passes/optimize.mbt:299-303`, `src/passes/optimize.mbt:443-447`, `src/passes/optimize.mbt:457-460` |
| raw pre-lift gate, classifier, and writeback guard | `src/passes/pass_manager.mbt:7402-7523`, `src/passes/pass_manager.mbt:8061-8063`, `src/passes/pass_manager.mbt:8493-8495` |
| hot-pass dispatch | `src/passes/pass_manager.mbt:8988` |
| owner file and pass summary | `src/passes/remove_unused_brs.mbt:2-16` |
| HOT skip-family scan | `src/passes/remove_unused_brs.mbt:148-154`, `src/passes/remove_unused_brs.mbt:518-579`, `src/passes/remove_unused_brs.mbt:5457-5597`, `src/passes/remove_unused_brs.mbt:5611-5688` |
| region rewrite helpers | `src/passes/remove_unused_brs.mbt:1162-2473`, `src/passes/remove_unused_brs.mbt:2476-3015`, `src/passes/remove_unused_brs.mbt:3018-4188`, `src/passes/remove_unused_brs.mbt:4191-4496`, `src/passes/remove_unused_brs.mbt:4499-5608` |
| focused reduced-pass tests | `src/passes/remove_unused_brs_test.mbt` |
| perf / replay / preset evidence | `src/passes/perf_test.mbt`, `src/passes/optimize_test.mbt`, `src/cmd/cmd_wbtest.mbt` |

The exact code map is the practical read-along path for the current local implementation.

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

The local pass can turn dense `br_if eq const` ladders into `br_table`, and it can retarget `br_table` continuation wrappers to the outer exit when the wrapper is redundant.

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

- the full GC `br_on_*` surface beyond the single-ref-child safe subset (`br_on_null`, `br_on_non_null`, successful `br_on_cast`, and not-taken `br_on_cast_fail`)
- branch-hint propagation as a first-class contract
- the full `throw`/`try_table` cleanup family beyond the safe exact-catch and non-ref `catch_all` subset
- the complete `restructureIf` / `tablify` profitability ladder
- broader helper-driven motion checks around label scopes and unconditionalization
- a literal AST-postwalk implementation inside one owner file

That gap is intentional and documented so readers do not mistake the current local pass for a full upstream port.

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
