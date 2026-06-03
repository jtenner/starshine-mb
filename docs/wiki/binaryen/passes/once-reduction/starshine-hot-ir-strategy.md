---
kind: concept
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md
  - ../../../raw/research/0238-2026-04-21-once-reduction-starshine-strategy-followup.md
  - ../../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md
  - ../../../raw/research/0202-2026-04-21-once-reduction-implementation-followup.md
  - ../../../raw/research/0256-2026-04-22-once-reduction-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0536-2026-05-06-once-reduction-direct-revalidation.md
  - ../../../raw/research/0701-2026-06-03-once-reduction-o4z-audit.md
  - ../../../../../src/passes/once_reduction.mbt
  - ../../../../../src/passes/once_reduction_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./dominance-propagation-and-cycle-safety.md
  - ./wat-shapes.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine `once-reduction` module-pass strategy

This page describes the **current local MoonBit implementation**, not the full upstream Binaryen `OnceReduction.cpp` contract.

## Current local surface

Starshine exposes `once-reduction` as an active **module pass** with:

- descriptor name: `once-reduction`
- summary text: `Reduce repeated calls to run-once functions guarded by monotonic once globals.`
- explicit module-pass dispatch through `pass_manager.mbt`
- preset placement in the early module cluster between `memory-packing` and `global-refining`
- CLI coverage through the explicit pass-flag roster in `cmd_wbtest.mbt`

The most important current local rule is:

- **Starshine implements a narrower recursive once-bit pass over boundary instruction arrays, not Binaryen's CFG + dominator + nested-pass engine.**

That means the local pass should be taught as a useful implemented subset, not as a full source-parity port of the released Binaryen strategy.

The 2026-06-03 O4z audit refreshed the direct-pass lane with `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass once-reduction --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-once-reduction-audit-current-10000-keepgoing`; the compare lane reported `9975 / 10000` compared cases, `9975` normalized matches, `0` semantic mismatches, and `25` Binaryen/tool command failures. The same audit added focused coverage for block-root once wrappers, defined idempotent fake roots, imported boundaries, extra global reads, and table / `ref.func` escape shapes.

## Current local code map

The easiest way to follow the in-tree implementation is this file map:

- `src/passes/once_reduction.mbt:2`
  - summary string used by the registry and docs
- `src/passes/once_reduction.mbt:208`
  - `or_find_once_global(...)`: current exact once-wrapper matcher, including the single-top-level-block form
- `src/passes/once_reduction.mbt:265`
  - `or_scan_instrs(...)`: candidate-global read/write scan and dataflow-interest prefilter
- `src/passes/once_reduction.mbt:321`
  - `or_analyze_instrs(...)`: recursive summary propagation with `if`-intersection, singleton-summary elision, and loop / try-table conservatism
- `src/passes/once_reduction.mbt:397`
  - `or_rewrite_instrs(...)`: recursive rewrite pass for redundant direct calls and redundant nonzero `global.set`s
- `src/passes/once_reduction.mbt:525`
  - `or_optimize_once_bodies(...)`: local empty-body and single-call-wrapper cleanup
- `src/passes/once_reduction.mbt:619`
  - `once_reduction_run_module_pass(...)`: end-to-end candidate discovery, defined-idempotent fake roots, fixed point, and module rewrite
- `src/passes/once_reduction_test.mbt:17`
  - repeated once-call elimination coverage
- `src/passes/once_reduction_test.mbt:44`
  - exported-global bailout coverage
- `src/passes/once_reduction_test.mbt:74`
  - trivial once-body collapse coverage
- `src/passes/once_reduction_test.mbt:97`
  - multiple independent once-global coverage
- `src/passes/pass_manager.mbt:8642`
  - active module-pass dispatch site
- `src/passes/optimize.mbt:234`
  - registry entry
- `src/passes/optimize.mbt:245`
  - optimize preset placement
- `src/passes/optimize.mbt:257`
  - shrink preset placement
- `src/passes/registry_test.mbt:76`
  - module-pass-category assertion
- `src/cmd/cmd_wbtest.mbt:5760`
  - explicit CLI pass-chain coverage including `--once-reduction`

## How the local pass works today

## 1. Candidate discovery is whole-module and export-conservative

`once_reduction_run_module_pass(...)` begins from full module state and computes:

- imported-global count
- imported-function count
- exported-global bitmap
- candidate slots for non-imported integer globals

A global becomes a candidate only when all of these are true:

- it is not imported
- it is not exported
- its declared type is `i32` or `i64`

That keeps the current local proof private and boolean-like, just as the parity page already says.

## 2. The local once-function matcher is still strict, but now handles the main block-root form

`or_find_once_global(...)` recognizes a tight boundary shape:

- `global.get $g`
- `if ... return`
- nonzero integer const
- `global.set $g`

and it also requires:

- the function to have no params
- the function to have no results

As of the 2026-06-03 O4z audit, Starshine accepts that prologue either directly in the function instruction array or inside one top-level `block`. That closes the most important local body-root mismatch with Binaryen's top-level block representation, but it is still not the full released Binaryen body matcher.

## 3. The read/write scan both filters globals and decides whether deeper analysis is needed

`or_scan_instrs(...)` recursively walks nested boundary control under:

- `block`
- `loop`
- `if`
- `try_table`

and does two jobs at once:

- counts `global.get` reads of candidate once-globals
- invalidates candidate globals when it sees a `global.set` not immediately preceded by a nonzero integer const

It also marks functions as needing the later fixed-point pass when it sees:

- candidate `global.set`
- `call`
- `return_call`

The 2026-06-03 audit added a small fast path: empty once wrappers are still scanned for legality, but they skip the later dataflow/rewrite loop and are handled by final body cleanup.

That is a smaller local analogue of Binaryen's split scan-plus-optimize structure.

## 4. The local fixed point is recursive and `if`-aware, but not CFG / dominator based

`or_analyze_instrs(...)` propagates a bitset of definitely-set once-globals through the instruction tree.

The key local rule is:

- plain nested regions union their learned facts into the parent,
- but `if` joins use explicit set intersection,
- while loops and `try_table` bodies are treated conservatively enough that they do not produce richer loop-carried or EH summary proofs.

This means Starshine really does have a fixed point over function summaries, but the proof engine is simpler than upstream Binaryen's:

- no `CFGWalker`
- no `DomTree`
- no immediate-dominator entry-state propagation
- no internal block-local relevant-expression lists

So the local pass should be taught as “fixed-point once-summary propagation with recursive structural control handling,” not as “the Binaryen algorithm in MoonBit syntax.” Defined no-param/no-result `@binaryen.idempotent` functions now enter this same summary framework as fake once roots; imported idempotent annotations remain a conservative boundary in the local pass.

## 5. Rewrite is direct and local: redundant calls and redundant writes become `nop`

`or_rewrite_instrs(...)` reruns the same recursive traversal over a copied instruction list and performs two local rewrites:

- if a candidate once-global is already known set, a redundant `call` becomes `nop`
- if a candidate once-global is already known set, a redundant `global.set` and its immediately preceding nonzero const both become `nop`

Like the analyzer, the rewrite is explicit about `if` intersection and recursive region rebuilding.

A small but real local divergence from upstream is visible here too:

- the MoonBit pass mentions `ReturnCall`, while the documented Binaryen surface is centered on ordinary direct `Call`

I am keeping that explicit as a local difference, not silently smoothing it away into “same as upstream.”

## 6. Final once-body cleanup is intentionally tiny locally too

`or_optimize_once_bodies(...)` is the local analogue of Binaryen's final wrapper cleanup step.
It recognizes only two current families, in either flat or single-top-level-block form:

- a four-instruction once body, which collapses fully to `nop`
- a five-instruction once body whose payload is exactly one direct `call`, which loses the first four instructions and keeps only that call

That is close in spirit to the official wrapper-cleanup tail, but it is still expressed through exact boundary instruction counts and explicit array replacement rather than the upstream file's more semantic helper structure.

## 7. Scheduling is honest and stable

The pass is not hidden behind a removed or boundary-only alias.
It is a real active module pass today.

The local registry and preset files make that explicit:

- `optimize.mbt` registers `once-reduction` as `module_pass`
- `optimize.mbt` schedules it in both public presets
- `pass_manager.mbt` dispatches it directly as a module pass
- `registry_test.mbt` locks the category
- `cmd_wbtest.mbt` covers it in the explicit flag chain

That means this folder should be maintained as living implementation docs, not as speculative future-port notes.

## What the local pass does not do

Compared with the full upstream Binaryen `version_129` contract, Starshine currently does **not** do these behaviors here:

- imported `@binaryen.idempotent` call removal; defined no-param/no-result idempotent functions are now supported as fake roots
- broader top-level-block and expression-body once-wrapper forms beyond the single-block shape added in the O4z audit
- CFG / immediate-dominator propagation
- the richer after-merge and long-control-flow precision that Binaryen gets from that CFG model
- the broader dedicated lit surface around difficult loop / cycle / EH cases

Those are real capability differences, not just wording differences.

## Biggest local-vs-upstream difference

The most important durable correction is:

- upstream Binaryen `once-reduction` is a small but real module pass with a parallel scan, a strict but block-shaped once matcher, a CFG / dominator optimizer, idempotent fake-global support, and a cycle-aware wrapper cleanup tail
- local Starshine `once-reduction` is currently a **narrower recursive boundary-array implementation** of the same overall once-bit idea

That narrower implementation is still valuable and already green on the saved generated-artifact slot recorded in `parity.md`.
But it should not be documented as if it were already the entire official Binaryen pass.

## Practical maintenance rule

Treat the current Starshine implementation as:

- a real active module pass
- a source-backed local subset of Binaryen `once-reduction`
- a recursive once-bit optimizer whose current limits are the still-narrow wrapper matcher, imported-idempotent boundary, and simpler control-flow proof model

Future work on this pass should answer one question explicitly:

- are we preserving the current explicit once-wrapper subset,
- or are we expanding toward the full Binaryen `OnceReduction.cpp` contract?

For `once-reduction`, those are meaningfully different projects, and the docs should keep that boundary explicit.

## Freshness note

The 2026-04-22 raw primary-source capture re-anchored this page to the reviewed official `version_129` release/source/test surfaces. The 2026-06-03 O4z audit refreshed the local implementation map and direct parity evidence after adding block-root, defined-idempotent, boundary, and escape-shape coverage.
