---
kind: concept
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../CHANGELOG.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./implementation-map.md
  - ./performance-and-artifact-frontiers.md
  - ./parity.md
  - ./validation-and-signoff.md
---

# `simplify-locals` Raw Lane And Exact Writeback

## Why The Raw Lane Exists

- Some artifact-scale functions are expensive to hot-lift, scan, and lower even when `simplify-locals` ultimately returns `changed=false`.
- Other families are easy to repair directly on exact instructions without paying the full lifted pass cost.
- The raw lane exists to keep those families from dominating the artifact lane while preserving Binaryen parity.

## The Three Raw-Lane Jobs

### 1. Cheap Exact Rewrites

- These are direct exact-instruction rewrites that are narrow, reduced, and parity-backed.
- Examples already in tree include:
  - pure later-call-argument cleanup
  - structured pure-tail temp cleanup
  - validator-skip copied-local cleanup across flat statement groups
  - validator-skip loop-temp cleanup across pure local-copy barriers

### 2. Raw Skip For Proven No-Op Families

- These are families where tracing showed Starshine and Binaryen were already equal enough that hot lift was pure cost.
- The pass-manager now recognizes several artifact-shaped no-op families and returns a skip reason instead of lifting.

### 3. Exact Writeback Cleanup

- After exact lowering, Starshine can still remove a very small set of dead temporary patterns without broad shape drift.
- This is intentionally separated from HOT IR because the lowered exact body has different constraints and because the repo rejected a broader cleanup experiment.

## Raw Rewrite Families Currently Worth Keeping

### `structured-pure-copy-call-tail`

- Family:
  - call-backed temp
  - pure stack prefix
  - later local get used in a compare or call tail
- Why it exists:
  - large exact instruction bodies often preserve a temp only because a pure prefix sits between producer and use
- Maintenance rule:
  - keep this family narrow and trace-backed

### Validator Structured Copy Cleanup

- Family:
  - validator-heavy structured helper
  - copied locals survive after flat zero-stack statement groups
  - top-level body still takes `skip-raw reason=validator-structured-call-heavy`
- Why it exists:
  - several artifact frontiers reduced only after the repo allowed copied-local cleanup to run even when the whole function stayed on the validator raw-skip lane

### Validator Cleanup-`if` Barrier

- Family:
  - exact copied local
  - one immediate zero-result cleanup `if`
  - barrier is the only top-level structured op
  - barrier does not touch source or target locals
- Why it exists:
  - it retires a real copied-local artifact family without reviving a broader "sink across arbitrary structured barriers" rewrite

### Validator Loop-Temp Barrier

- Family:
  - single-use effectful temp
  - intervening pure local-copy barrier
  - later compare/store consumer
- Why it exists:
  - this retired the old `Func 50` temp drift without needing the whole validator-heavy function to lift

## Raw Skip Families Currently Worth Keeping

### `validator-structured-call-heavy`

- Shape:
  - validator-like, loop-heavy, structured call walkers
- Why it is skipped:
  - these functions were repeatedly expensive and often unchanged
- Important nuance:
  - the repo no longer treats this as "nothing happens"
  - the exact temp cleanup helper now runs on validator raw-skip results too

### `dense-structured-call-heavy`

- Shape:
  - large low-loop structured call-heavy helpers
  - artifact examples include internal helpers like `Func 395`, `430`, `818`, `2083`, and `2098`
- Why it is skipped:
  - tracing showed these were Binaryen-equal but still paying full hot cost

### `huge-straight-line-call-builder`

- Shape:
  - giant straight-line tee-heavy builders
  - artifact example: `KeywordTable::new`
- Why it is skipped:
  - no-op family with high lift and scan cost

### Other Stable Skip Families

- The repo also carries other artifact-shaped raw skips such as:
  - stringview trim loops
  - decode-shaped structured helpers
  - branchy decode fanout
  - transformer catch walkers
  - loop-heavy validator helpers
- These belong in the raw lane because they are mainly artifact-scale performance decisions, not the semantic heart of simplify-locals.

## Exact Writeback Cleanup That Stayed

### Dead Copied `local.tee`

- Kept:
  - prune dead copied `local.tee` roots after lower
- Why:
  - this matched Binaryen often enough and stayed green on the fuzz lane

### Dead Adjacent `local.set` / `local.get`

- Kept:
  - erase adjacent one-use lowered temps when the local has no later exact reads
- Why:
  - removes a common lowered shuttle pattern without introducing new tees

## Exact Writeback Cleanup That Was Rejected

### Broad Lowered-`nop` Stripping

- Rejected:
  - removing lowered `nop` roots broadly after lower
- Why rejected:
  - the `gen-valid` differential lane diverged almost immediately
  - Binaryen preserves many lowered `nop`s that the repo had incorrectly assumed were disposable

### Broad Selectification

- Rejected:
  - turning simple `if (result)` shapes into `select` broadly
- Why rejected:
  - direct reduced Binaryen probes showed Binaryen does not perform the simple selectification variants Starshine could have emitted

## The Exact Cleanup Helper Rule

- A raw or exact-body cleanup belongs in the shared helper only if all of the following are true:
  - the family is exact-instruction-local, not structure-heavy
  - the family has a reduced regression
  - the family survives the pass-fuzz compare lane
  - the family does not require broad lowered-`nop` removal

## Why The Raw Lane Must Stay Secondary

- The raw lane is not where new semantics should primarily be invented.
- It is acceptable for:
  - narrow exact rewrites
  - artifact-only no-op skips
  - shared exact cleanup on already-proven-safe shapes
- It is not the right long-term home for:
  - broad structure lifting
  - broad effect-ordering theory
  - general copied-local equivalence policy
  - control-result retagging

## Retirement Rule

- A raw heuristic should be retired when one of these becomes true:
  - the lifted HOT pass handles the family cheaply enough that the raw heuristic is no longer buying anything
  - the family stops appearing in artifact traces
  - the heuristic starts blocking a broader, cleaner HOT-IR parity fix

## Maintenance Rule

- Every raw-lane addition needs at least one of:
  - a focused synthetic regression
  - a perf test or wbtest for the skip reason
  - a traced artifact note that explains why the heuristic exists
- If a new idea's best evidence is "it makes the printed output look nicer," do not add it here.
