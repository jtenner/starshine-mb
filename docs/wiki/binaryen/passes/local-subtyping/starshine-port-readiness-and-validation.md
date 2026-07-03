---
kind: concept
status: supported
last_reviewed: 2026-07-03
sources:
  - ../../../raw/research/0534-2026-05-06-local-subtyping-direct-revalidation.md
  - ../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md
  - ../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../../../src/passes/local_subtyping.mbt
  - ../../../../../src/passes/local_subtyping_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./lubs-and-dominance.md
  - ./wat-shapes.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
---

# Starshine validation and parity gaps for `local-subtyping`

This bridge used to read like a future-port plan. That is stale.
Starshine already ships `local-subtyping`; this page now tracks the active subset and the remaining Binaryen parity gaps.

Use it with:

- [`./starshine-strategy.md`](./starshine-strategy.md) for current Starshine status;
- [`./binaryen-strategy.md`](./binaryen-strategy.md) for the upstream algorithm;
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for exact owner and test surfaces;
- [`./lubs-and-dominance.md`](./lubs-and-dominance.md) for the upstream semantics;
- [`./wat-shapes.md`](./wat-shapes.md) for before/after examples.

## Current local reality

Starshine `local-subtyping` is an active module pass.
The shipped implementation is narrower than Binaryen: it uses write-site evidence to narrow body locals and now has first straight-line plus non-null `local.tee` assignment/use validation, branch-free `block`, branch-free block-write post-state, terminal `br` / `br_table` dominated-get blocks, branch-free `loop` entry, a source-backed loop tail-`br_if` backedge subset, nested block/loop-`if`, root `if`, conditional-`return` branch, direct if-arm `return_call`/`return_call_indirect`/`return_call_ref` skips, direct if-arm `throw`/`throw_ref` skip, root/block terminal-`return`/direct `return_call`/`return_call_indirect`/`return_call_ref`, root non-final `return`/`return_call`/`return_call_indirect`/`return_call_ref` unreachable-tail-get slices, if-arm nested block terminal-`return`/`throw`, root/block terminal-`throw`/`throw_ref`, and `try_table` body non-null dominance slices including terminal body `return`/`throw`/`throw_ref`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/`throw_ref`/tail-call tails whose later gets are already dominated, plus source-backed nullable fallbacks for loop writes, all-arm `if` writes, branch-flow block post-state cases before later outside gets, `try_table` body writes before later outside gets, branch paths that can skip writes, direct block-return flow pending Starshine validator support for Binaryen's unreachable non-defaultable-local proof, and parameter preservation after writes. It still does not do full structural get-aware dominance repair, broad get/tee expression retagging, or iterative refinalization.

## The current Starshine slice

The shipped slice is:

1. collect write-site types from `local.set` / `local.tee`;
2. compute a safe common reference subtype;
3. allow nullable-to-non-null narrowing only for the current straight-line, branch-free `block`, branch-free block-write post-state, terminal `br` / `br_table` dominated-get block, branch-free `loop` entry, narrow loop tail-`br_if` backedge, nested branch-free region-`if`, branch-free root `if`, conditional-`return`/direct-`return_call`/direct-`return_call_indirect`/direct-`return_call_ref`/direct-`throw`/`throw_ref` branch subset, root/block terminal-`return`/direct `return_call`/`return_call_indirect`/`return_call_ref`, root non-final `return`/`return_call`/`return_call_indirect`/`return_call_ref` tails before already-dominated unreachable-tail gets, if-arm nested block terminal-`return`/`throw`, root/block terminal-`throw`/`throw_ref`, and `try_table` body dominated-get subsets including terminal body `return`/`throw`/`throw_ref`/`return_call`/`return_call_indirect`/`return_call_ref` and source-backed non-final body `return`/`throw`/`throw_ref`/tail-call tails where every raw `local.get` of that body local follows a dominating write and no broad `try_table`/EH flow, branch-skipped write, direct return/post-state validator boundary, broader non-final terminal flow outside the root and try-body tail subsets, broader loop backedge, or broader join/post-state case invalidates the simple proof; source-backed loop write, all-arm `if` write, branch-skipped write, branch-flow block post-state, try-table body post-state, and direct block-return cases fall back to nullable child rather than non-null;
4. rewrite body-local declarations only and preserve function parameters as ABI/signature types;
5. rebuild the module only when a body local changes.

That is a valid Starshine pass, but it is only a subset of the upstream contract.

## Exact Starshine code surfaces

| Surface | Why it matters |
| --- | --- |
| `src/passes/local_subtyping.mbt:1-19` | summary and public pass description. |
| `src/passes/local_subtyping.mbt:143-590` | subtype helpers, assignment collection, candidate narrowing, straight-line/block/loop/nested-if/root-if/conditional-return/direct-return_call/direct-return_call_indirect/direct-return_call_ref/direct-throw/direct-throw_ref skip dominance scanning including the tail-`br_if` loop-backedge subset, branch-free block write post-state propagation, terminal `br` / `br_table` dominated-get handling without outer post-state propagation, root/block terminal-`return`/direct `return_call`/`return_call_indirect`/`return_call_ref`, root non-final `return`/`return_call`/`return_call_indirect`/`return_call_ref` unreachable-tail-get handling, if-arm nested block terminal-`return`/`throw`, root/block terminal-`throw`/`throw_ref`, and `try_table` body dominated-get handling including terminal body `return`/`throw`/`throw_ref`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/`throw_ref`/tail-call tails with already-dominated tail gets, source-backed nullable loop/if/branch-flow/try-table-body/skipped-write/direct-return post-state fallback behavior, and function rewrite. |
| `src/passes/local_subtyping.mbt:591-622` | active module-pass entrypoint and module rebuild. |
| `src/passes/registry_test.mbt:78-82` | registry category is `module_pass`. |
| `src/passes/optimize.mbt:284-285, 296-312` | registry entry and hot-preset inclusion. |
| `src/passes/pass_manager.mbt:8937-8940` | active dispatcher case. |
| `src/passes/local_subtyping_test.mbt` | active pass tests for registry lookup, the shipped narrowing/fallback cases, non-null `local.tee` assignment/use validation, straight-line non-null dominance, branch-free block/loop dominance/fallback, loop tail-`br_if` backedge dominance, terminal `br` / `br_table` dominated-get narrowing, branch-free block-write post-state propagation, nested branch-free block-if dominance, conditional-return/direct-return_call/direct-return_call_indirect/direct-return_call_ref/direct-throw/direct-throw_ref skip dominance, root/block terminal-return/return_call/return_call_indirect/return_call_ref, root non-final return/tail-call unreachable-tail-get coverage, if-arm nested block terminal-return/throw, and root/block terminal-throw/throw_ref dominance, try_table body dominance including terminal body `return`/`throw`/`throw_ref`/`return_call`/`return_call_indirect`/`return_call_ref`, source-backed nullable loop/if/branch-flow/try-table-body/branch-skipped-write/direct-return post-state fallback, parameter preservation, and branch-free root-if dominance/fallback. |
| `src/cmd/cmd_wbtest.mbt:4376-4439` | end-to-end CLI proof for `--local-subtyping`. |
| `src/passes/optimize_test.mbt:522-526` | preset slot proof in the late local-cleanup neighborhood. |

## What still needs parity work

Compared with Binaryen, Starshine still lacks:

- full structural get-site dominance analysis;
- non-null fallback based on structural dominance across loops with backedges or post-state joins beyond the source-backed tail-`br_if` dominated-get subset, EH regions, broader `if` join/post-state cases, and blocks/ifs with branch/return/return_call/throw flow beyond the terminal-branch dominated-get, conditional-return/direct-return_call/direct-return_call_indirect/direct-return_call_ref/direct-throw/direct-throw_ref skip branch, root/block terminal-return/return_call/return_call_indirect/return_call_ref, root non-final return/tail-call unreachable-tail-get subsets, if-arm nested block terminal-return/throw, and root/block terminal-throw/throw_ref subsets; branch-free block write post-state is now covered, while branch-free loop writes, all-arm `if` writes, branch-skipped writes, branch-flow block post-state, try-table body post-state, and direct block-return cases currently follow Binaryen-observed nullable post-state behavior or a precise Starshine validator tooling boundary;
- broad get/tee expression retagging after declaration narrowing; a non-null `local.tee` assignment/use fixture validates today, but the general explicit Binaryen retagging contract remains open;
- repeated refinalize/reanalyze rounds;
- broader shape coverage for structured tees, non-null cases, and parameter/body-local boundaries beyond the now-guarded source-backed parameter-preservation case.

Those are the next parity slices, not the current shipped pass.

## Validation ladder

Current coverage should stay green first:

1. registry category proof;
2. body-local narrowing to a child heap type;
3. mixed-sibling common-parent narrowing;
4. CLI `--local-subtyping` end-to-end replay;
5. optimize-preset slot coverage;
6. dedicated `local-subtyping-all` GenValid profile coverage, currently composed from `local-subtyping-straight-line` and `local-subtyping-structured` leaves that emit nullable `anyref` body locals, non-null `struct.new_default` writes, and dominated straight-line/block/loop/if reads.

Refreshed direct signoff on 2026-05-06 ran `moon info`, `moon fmt`, `moon test`, and `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-subtyping --out-dir .tmp/pass-fuzz-local-subtyping`. The fuzz lane reported 6759 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures.

The current audit slices add and validate focused direct tests: `local.tee` assignments feed narrowing, including a non-null tee assignment/use that validates after non-null declaration narrowing; a straight-line non-null write before all gets can narrow a nullable body local to a non-null child type; branch-free `block` and `loop` bodies entered after a dominating write can contain non-null gets; a loop with a tail `br_if` backedge can contain gets dominated by an earlier pre-loop write; a branch-free `block` write can propagate to a later outer get; terminal `br` / `br_table` block bodies can contain gets dominated before the branch without propagating branch-carried writes to outer post-state; a branch-free nested `if` inside such a dominated region can contain non-null gets; a branch-free root `if` entered after a dominating write can contain non-null gets; a conditional `return` branch, direct if-arm `return_call` / `return_call_indirect` / `return_call_ref`, or direct if-arm `throw` or `throw_ref` before a later write/get can narrow because that path cannot reach the get; a root/block terminal `return`/direct `return_call` / `return_call_indirect` / `return_call_ref`, root non-final `return`/`return_call`/`return_call_indirect`/`return_call_ref` tail before already-dominated unreachable-tail gets, if-arm nested block terminal `return`/`throw`, root/block terminal `throw`/`throw_ref`, or `try_table` body after a dominated get, including terminal body `return`/`throw`/`throw_ref`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/`throw_ref`/tail-call tails, can narrow because the observed get is dominated without relying on an unsafe post-state proof; and early gets before the write, including gets inside an earlier block or `if` arm, fall back to the nullable child type. Source-backed fallbacks keep a branch-free loop write, all-arm `if` writes, a block write followed by branch flow before a later outside get, a try_table body write before a later outside get, a `br_if` path that can skip a later block write, and the direct block-return validator boundary nullable for a later outer get, and keep nullable function parameters unchanged after writes. The straight-line, block-entry, block-write post-state, terminal-branch, loop-entry, loop-backedge, nested block-if, root-if, conditional-return, direct return_call/return_call_indirect/return_call_ref skip, direct-throw/direct-throw_ref skip, root/block terminal-return/return_call/return_call_indirect/return_call_ref, root non-final return/tail-call unreachable-tail-get positives, if-arm nested block terminal-return/throw, root/block terminal-throw/throw_ref, and try_table body non-null positives including terminal body `return`/`throw`/`throw_ref`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/`throw_ref`/tail-call tails failed before implementation and now pass with optimized-module validation.

Then grow coverage in this order:

1. structured-control nullable-to-non-null positives and failures beyond branch-free `block` bodies, branch-free block-write post-state, branch-free `loop` entry bodies, the tail-`br_if` backedge subset, and branch-free root `if` arms;
2. `local.get` / `local.tee` expression retagging;
3. repeated refinement after a narrowing change;
4. broader parameter/body-local-only scope checks beyond the source-backed nullable-parameter preservation guard;
5. scale the new LS-specific `local-subtyping-all` GenValid aggregate profile through the required 10000-case dedicated direct signoff lane.

## What to avoid saying

Do not call this pass "future-only" or "removed-registry-only".
That was the stale reading corrected by the 2026-05-06 repo-source note.

## Related pages

- [`./index.md`](./index.md) - folder overview
- [`./starshine-strategy.md`](./starshine-strategy.md) - active Starshine status and parity-gap map
- [`./binaryen-strategy.md`](./binaryen-strategy.md) - upstream algorithm and correction history
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - owner and test surface map
- [`./lubs-and-dominance.md`](./lubs-and-dominance.md) - semantics guide
- [`./wat-shapes.md`](./wat-shapes.md) - concrete shapes
- [`../optimize-casts/index.md`](../optimize-casts/index.md) - left neighbor
- [`../coalesce-locals/index.md`](../coalesce-locals/index.md) - right neighbor
- [`../local-cse/index.md`](../local-cse/index.md) - later consumer
