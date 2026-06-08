---
kind: concept
status: supported
last_reviewed: 2026-06-08
sources:
  - ../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md
  - ../../../raw/research/0717-2026-06-08-once-reduction-behavior-gap-inventory.md
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

This page describes the **current local MoonBit implementation** and how its tested behavior maps to the upstream Binaryen `OnceReduction.cpp` contract.

## Current local surface

Starshine exposes `once-reduction` as an active **module pass** with:

- descriptor name: `once-reduction`
- summary text: `Reduce repeated calls to run-once functions guarded by monotonic once globals.`
- explicit module-pass dispatch through `pass_manager.mbt`
- preset placement in the early module cluster between `memory-packing` and `global-refining`
- CLI coverage through the explicit pass-flag roster in `cmd_wbtest.mbt`

The most important current local rule is:

- **Starshine implements the source/lit behavior families with a recursive boundary-array engine, not by literally porting Binaryen's CFG + dominator + nested-pass implementation.**

The implementation shape is different, but `[O4Z-AUDIT-OR]` is now signed off for v0.1.0 behavior parity. The 2026-06-08 inventory and follow-ups cover the previously documented broad gaps with focused tests, and the final direct compare lane `.tmp/pass-fuzz-once-reduction-current-100000` compared `99751 / 100000`, normalized `99751`, and had `0` mismatches with `249` Binaryen/tool command failures.

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

So the local pass should be taught as “fixed-point once-summary propagation with recursive structural control handling,” not as “the Binaryen algorithm in MoonBit syntax.” Defined and imported no-param/no-result `@binaryen.idempotent` functions now enter this same summary framework as fake once roots.

## 5. Rewrite is direct and local: redundant calls and redundant writes become `nop`

`or_rewrite_instrs(...)` reruns the same recursive traversal over a copied instruction list and performs two local rewrites:

- if a candidate once-global is already known set, a redundant `call` becomes `nop`
- if a candidate once-global is already known set, a redundant `global.set` and its immediately preceding nonzero const both become `nop`

Like the analyzer, the rewrite is explicit about `if` intersection and recursive region rebuilding.

The rewrite also keeps the Binaryen source-surface distinction between ordinary direct calls and `return_call`: `return_call` cuts off local fact propagation and is not rewritten as a once call.

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

## Current behavior-parity coverage

Compared with the full upstream Binaryen `version_130` contract, the 2026-06-08 red-test/green phase and follow-up lit-surface expansion cover these important families:

- imported and defined no-param/no-result `@binaryen.idempotent` calls are fake once roots
- wrapper cleanup strips explicit once wrappers whose only payload calls an idempotent or once fake-root function, while preserving wrapper-cycle safety
- positive integer once writes are eligible, while negative, zero, and nonconstant writes are rejected to match Binaryen's scanner rule
- structural `if` no longer leaks two-arm merge facts that Binaryen's dominance-only pass intentionally ignores
- block branch exits, `return_call`, and `unreachable` stop local fact propagation
- loop and `try_table` bodies optimize and propagate facts in the covered Binaryen-positive shapes
- once-function-local transitive summaries are limited so dangerous recursive-cycle order-preservation cases keep their calls
- nonzero initial globals, params/results, non-integer globals, extra reads, near-once debris, mismatched globals, loop-root/too-short bodies, direct call-chain summaries, mixed once/non-once globals, self-recursion, and non-once callee summary directionality all have focused tests

The local implementation is still not literally Binaryen's CFG / `DomTree` engine. The signoff claim is behavior parity for the reviewed source/lit families and direct oracle lane, not implementation-shape parity. The detailed inventory, behavior checklist, and current green evidence live in [`../../../raw/research/0717-2026-06-08-once-reduction-behavior-gap-inventory.md`](../../../raw/research/0717-2026-06-08-once-reduction-behavior-gap-inventory.md).

## Biggest local-vs-upstream difference

The most important durable correction is:

- upstream Binaryen `once-reduction` is a small but real module pass with a parallel scan, a strict but block-shaped once matcher, a CFG / dominator optimizer, idempotent fake-global support, and a cycle-aware wrapper cleanup tail
- local Starshine `once-reduction` achieves the signed-off behavior with a recursive boundary-array implementation and focused guards instead of porting that implementation shape directly

## Practical maintenance rule

Treat the current Starshine implementation as:

- a real active module pass
- signed off for the reviewed Binaryen `once-reduction` behavior surface
- a recursive once-bit optimizer whose implementation shape differs from Binaryen's CFG / `DomTree` engine but whose source/lit families are protected by focused tests

Future work on this pass should keep behavior parity and implementation-shape parity separate. If new Binaryen source or lit tests add behavior, extend the behavior checklist and focused tests first, then decide whether the recursive Starshine engine can cover it safely or needs a deeper algorithmic port.

## Freshness note

The 2026-04-22 raw primary-source capture re-anchored this page to the reviewed official `version_129` release/source/test surfaces. The 2026-06-03 O4z audit refreshed the local implementation map and direct parity evidence after adding block-root, defined-idempotent, boundary, and escape-shape coverage.
