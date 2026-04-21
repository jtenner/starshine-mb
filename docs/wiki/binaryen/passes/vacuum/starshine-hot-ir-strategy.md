---
kind: concept
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0130-2026-04-20-vacuum-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./effect-pruning-and-traps-never-happen.md
  - ./wat-shapes.md
---

# Starshine `vacuum` strategy

## Current rule

Starshine's current `vacuum` implementation is intentionally much smaller than Binaryen's.

The repo does **not** currently try to port Binaryen's full tree cleanup semantics here.

Instead, the in-tree pass is:

- a HOT-IR recursive region sweep that removes explicit `nop` entries

That is useful and honest, but it is not upstream parity.

## Current in-tree implementation

The active implementation lives in `src/passes/pass_manager.mbt`.

The key helper is:

- `hot_pass_remove_region_nops(...)`

It recursively visits:

- the root region
- block / loop bodies
- `if` then/else regions
- `try` body/catch regions
- `try_table` body/catch-list regions

When it sees `HotOp::Nop` as a region entry, it:

- splices that entry out of the region
- deletes the detached nodes

That is the whole transformation today.

The pass registry entry in `src/passes/optimize.mbt` describes it accurately:

- `Remove \`nop\` roots and region entries through hot IR cleanup.`

## What Starshine already does well

- It is cheap.
- It is structurally simple.
- It works in the existing `HotFunc` / `HotRegionRef` ownership model.
- It already gives the repo a useful cleanup step after `simplify-locals` residue.
- The pass manager correctly invalidates broad HOT analyses after it mutates the function.

## Current in-tree proof points

The repo already has a few useful pass-local locks:

- `src/passes/optimize_test.mbt`
  - `vacuum cleans simplify-locals structured return residue in the late cleanup pair`
- `src/passes/trace_golden_test.mbt`
  - deterministic trace coverage for a one-pass `vacuum` run
- `src/passes/perf_test.mbt`
  - timer coverage for `pass:vacuum`
- `src/passes/pass_manager.mbt`
  - `vacuum`-specific writeback validation guard using the same helper family as `precompute`

Those tests are valuable, but they lock only the repo's current narrower semantics.

## What Starshine does **not** yet model from Binaryen

Current Starshine `vacuum` does not yet implement upstream behaviors such as:

- unused-result pruning through effect analysis
- collapsing pure wrappers down to effectful children
- default-value insertion when a concrete fallthrough cannot simply vanish
- constant-condition `if` selection
- unreachable-condition `if` collapse
- flipping `if` conditions when the `then` arm is empty
- flipping branch hints when that `if` flip happens
- `drop(local.tee(...)) -> local.set(...)`
- block-result popping with branch-target safety checks
- non-throwing `try` / `try_table` wrapper removal
- TNH-specific trap-path cleanup
- whole-function `nop` cleanup when a void function has no observable effects
- explicit-`unreachable` preservation at function scope
- mandatory post-rewrite refinalization of Binaryen-style tree rewrites

So the practical repo rule is:

- do not read the current Starshine pass as if it already means Binaryen parity

## Why that narrower strategy made sense locally

The repo got real value from a tiny `vacuum` first because:

- many in-tree cleanup needs really were just leftover `nop` region entries
- the ordered generated-artifact audit eventually showed the two scary `vacuum` corruption slots were replay-boundary symptoms, not proof that the pass should invent richer typed repairs
- a small HOT-IR region sweep is easy to reason about, cheap to rerun, and easy to validate after late local cleanup passes

That made the pass a good early implementation target even though it is far from full Binaryen behavior.

## Current boundary lesson from the retired artifact failures

The retired slot-23 and slot-33 raw notes are important context.

They showed:

- `vacuum` was sometimes the replay boundary where invalid output became visible
- but the underlying fixes lived elsewhere:
  - earlier HOT-lower carrier-wrapper guarding
  - validator / writeback hygiene

That lesson still matters for future work:

- richer Binaryen parity should come from correctly porting Binaryen semantics
- not from treating `vacuum` as a place to synthesize ad hoc repair carriers

## Honest future port shape

If Starshine wants closer Binaryen parity, the likely path is still HOT-IR-centric, but broader than region `nop` trimming.

A plausible staged expansion would be:

1. keep the current region-`nop` sweep
2. add effect-aware dropped-wrapper elimination in HOT IR
3. add the easy structural cases:
   - constant / unreachable `if`
   - drop-of-tee to set
   - trivial loop-body removal
4. add branch-result-aware block cleanup
5. add TNH cleanup only with explicit barrier modeling
6. add whatever HOT-IR equivalent of refinalization / exact writeback proof is required for GC and EH-sensitive rewrites

## Port invariants to preserve

Any future Starshine expansion should keep these Binaryen-derived invariants explicit:

- never delete structure in a way that changes observable effects
- never drop a concrete result without a valid replacement story
- preserve explicit `unreachable` propagation
- keep branch payload structure honest when popping block results
- flip branch metadata if a flipped-`if` rewrite ever lands
- keep TNH cleanup conservative around calls, control transfer, may-not-return, and `pop`

## Bottom line

Current Starshine `vacuum` is a small, useful HOT-IR cleanup pass.

It is correctly named and honestly wired into the scheduler.

But compared to upstream Binaryen, it is still just the first slice:

- **Starshine today:** recursive explicit-`nop` trimming
- **Binaryen `version_129`:** effect-aware unused-result pruning plus structural cleanup and TNH-sensitive residue removal

This page exists so future work does not confuse those two meanings.
