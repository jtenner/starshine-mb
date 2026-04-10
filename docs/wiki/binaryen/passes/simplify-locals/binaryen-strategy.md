---
kind: concept
status: supported
last_reviewed: 2026-04-10
sources:
  - ../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md
related:
  - ./index.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./implementation-map.md
  - ./effect-ordering-and-barriers.md
  - ./raw-lane-and-writeback.md
  - ./performance-and-artifact-frontiers.md
  - ../../no-dwarf-default-optimize-path.md
---

# `simplify-locals` Binaryen Strategy

## Core Claim

- Binaryen's `simplify-locals` family is a staged locals optimizer, not a single peephole and not a pure dead-store remover.
- The strategy we want to mimic is the *phase structure* and *safety envelope*, not every incidental AST-storage workaround inside Binaryen's implementation.
- In practical terms, the Binaryen plan is:
  1. count local uses
  2. run an iterative sink-and-tee loop
  3. invalidate candidates conservatively with directional effect ordering
  4. optionally lift locals into structured control results
  5. canonicalize equivalent copies late
  6. run one last dead-set cleanup outside SSA assumptions

## Why This Pass Exists At All

- WebAssembly producers often materialize values into locals even when the next meaningful use is very close.
- Those locals can exist for several different reasons:
  - a frontend wanted a named temporary
  - a previous pass needed to expose a value on both arms of control
  - a stack-machine lowering step needed a concrete temporary for reordering
  - a builder generated more local traffic than the optimizer actually wants to keep
- Binaryen's `simplify-locals` exists to recover the tighter tree-shaped value flow that other passes prefer:
  - fewer trivial `local.set` / `local.get` pairs
  - fewer copied-local chains
  - more values used directly at the consuming expression
  - more control nodes that directly return a value instead of writing a local and reading it back

## Variant Matrix

- Binaryen exposes five public variants:
  - `simplify-locals`
  - `simplify-locals-nonesting`
  - `simplify-locals-notee`
  - `simplify-locals-nostructure`
  - `simplify-locals-notee-nostructure`
- The important semantic axes are:
  - whether the pass may synthesize `local.tee`
  - whether the pass may rewrite structure to return values directly
  - whether the pass may recurse into nested control aggressively
- The repo does not currently expose this full user-facing matrix, but the *internal* Starshine design needs to respect the same distinctions because they explain why some Binaryen transforms happen only in later slots.

## Binaryen's Real Phase Structure

### 1. Get Counting And Candidate Setup

- Binaryen begins by counting `local.get` uses.
- That count is not bookkeeping noise. It is the gate that distinguishes:
  - single-use values that may be inlined directly
  - multi-use values that may need a `local.tee`
  - dead writes that can be erased entirely
- This is why the pass is not reducible to a small "replace adjacent set/get" peephole. The profitable or legal rewrite depends on *future use count* and not just local adjacency.

### 2. Main Sink Fixpoint

- The main loop walks linear execution order and keeps at most one pending sinkable set per local per active linear trace.
- The first cycle is stricter than later cycles:
  - it prefers obvious single-use wins
  - it does not rush into tee synthesis
- Later cycles permit more aggressive reuse once the earlier easy cleanups have stabilized the function.
- When Binaryen reaches a matching `local.get`, it has a few canonical outcomes:
  - direct replacement when the value is only used once
  - `local.tee` synthesis when the first read may consume the value but later reads still need the local
  - overwrite cleanup when a later `local.set` makes the earlier pending write obsolete before any real read

### 3. Effect And Control Invalidation

- Binaryen does not treat pending locals as algebraic equalities that survive arbitrary motion.
- It uses directional effect ordering, not just a boolean "side effects present" bit.
- The practical consequence is that the pass asks questions like:
  - may this producer move *before* the intervening code?
  - may this later read see the producer *after* the intervening code?
  - does the intervening code read or write the local, mutable globals, memory, tables, or other observable state that would change meaning?
- Important barrier classes include:
  - local read/write conflicts
  - mutable global conflicts
  - memory and table read/write conflicts
  - control-flow transfers
  - exceptions and traps, especially around `try` and `try_table`
  - dangling stack values such as `pop`
- This directional invalidation logic is one of the main things Starshine needs to mimic faithfully. It is the reason many apparently-trivial inlines are actually wrong.

### 4. Structured Return Rewrites

- When structure rewriting is enabled, Binaryen stops treating locals as only dataflow carriers and starts asking whether they are really encoding a control result.
- The pass can lift values out of:
  - blocks
  - `if` / `if-else`
  - loops
- These are not blanket rewrites. Binaryen guards them tightly:
  - one-armed `if` lifting needs a defaultable local type because the synthetic else path may need a default value
  - `br_if` lifting must preserve the condition/value split and not pull branch payloads across the wrong boundary
  - blocks that already own a value type or already have conflicting exits cannot be rewritten casually
  - loop lifting must preserve the meaning of fallthrough versus backedge behavior
- This structure phase is the reason the pass has late-slot importance in the Binaryen pipeline. Early no-structure cleanup simplifies local traffic without committing to control rewrites too early.

### 5. Late Equivalent-Copy Cleanup

- After the main sink loop stabilizes, Binaryen runs a second, more canonicalization-focused phase over equivalent locals.
- This phase is not the same as the earlier sink loop. It is specifically about copies like:
  - `local.set B (local.get A)`
  - later `local.get B`
- Binaryen can rewrite later gets toward a preferred representative when the two locals remain equivalent.
- The preference is not arbitrary. Binaryen ranks candidates by:
  - more refined type when relevant
  - more useful remaining get count
- This phase is where many later "same-arm alias" or copied-local cleanups happen, and it is also where Starshine had to learn to preserve tee-backed locals for later call children while still canonicalizing same-arm aliases back to the source local when safe.

### 6. Final Dead-Set Cleanup

- Binaryen finishes with a dead-set sweep that is broader than the repo's old SSA-only cleanup.
- The important property is that this sweep still preserves side effects:
  - dead pure `local.set` can become `nop`
  - dead effectful `local.set` becomes `drop(value)` or an equivalent side-effect-preserving form
  - dead `local.tee` can collapse to the underlying value
- This final phase matters because optimized code still contains dead locals in unreachable or non-SSA-friendly regions. Binaryen does not rely on the rest of the optimizer pipeline to catch those later.

## Why Binaryen Sometimes Preserves `nop`

- Binaryen's printed output can preserve `nop` sentinels in places that look unnecessary if you only think in terms of final canonical WAT prettiness.
- Two different facts are easy to confuse:
  - some `nop`s are just AST-management artifacts in Binaryen's own walker
  - some `nop`s are actually part of the observable or stable emitted shape that later passes do not immediately erase
- The repo has direct evidence that broad `nop` stripping is unsafe to treat as a general parity move:
  - the lowered-`nop` stripping experiment diverged almost immediately on the `gen-valid` pass-fuzz lane
  - several one-armed `if` artifact gaps reduced only after Starshine learned to preserve the same then-arm `nop` sentinel Binaryen keeps
- So the strategy we mimic is not "never emit nops" but "match the semantic and shape conditions under which Binaryen still leaves them behind."

## Mode And Pipeline Placement

- On the no-DWARF optimize path, the no-structure variants run earlier than the full structured pass.
- That ordering is not incidental:
  - early cleanup reduces local traffic before later passes like `reorder-locals`, `heap2local`, `local-cse`, and the full `simplify-locals` run
  - the late full pass can then finish structure lifting and equivalent-copy cleanup on a simpler body
- The living optimizer-path summary is in [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md), and this page should stay aligned with that rule.

## What Starshine Should Mimic Exactly

- Mimic these semantics exactly:
  - use-count-sensitive sink behavior
  - directional effect-order invalidation
  - structure lifting guards
  - late equivalent-local ranking
  - side-effect-preserving dead-set cleanup
- Do *not* mimic these details literally unless the underlying reason still exists in HOT IR:
  - Binaryen's `Expression**` stability hacks
  - trailing-`nop` retry tricks that exist mainly to keep AST storage stable mid-walk
  - internal tree-walker implementation choices that do not map onto node-id-based region surgery

## Source Status

- The archived research note is pinned to Binaryen commit `88a07e028cfb4aa68e7a94743646a0867b31c15b` as captured on 2026-04-01.
- The shared repo oracle for living Binaryen pass pages is now `version_129`.
- Refresh this page if upstream `SimplifyLocals.cpp`, `effects.h`, or the no-DWARF pass ordering changes materially from the archived note.

## Sources

- Archived research note: [`../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md`](../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md)
- No-DWARF optimize path: [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- WAT families in this repo: [`./wat-shapes.md`](./wat-shapes.md)
- Barrier model used by the repo port: [`./effect-ordering-and-barriers.md`](./effect-ordering-and-barriers.md)
