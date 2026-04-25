---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-rse-source-correction.md
  - ../../../raw/research/0348-2026-04-25-rse-source-correction-and-starshine-followup.md
  - ../../../raw/binaryen/2026-04-22-rse-primary-sources.md
  - ../../../raw/research/0259-2026-04-22-rse-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./cfg-and-value-tracking.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `rse` Strategy

## Upstream source rule

Use [`../../../raw/binaryen/2026-04-25-rse-source-correction.md`](../../../raw/binaryen/2026-04-25-rse-source-correction.md) as the current provenance anchor.
It re-read official Binaryen `version_129` plus current `main` on 2026-04-25 and corrects the older `rse` dossier's over-broad dataflow interpretation.

Primary source URLs:

- `RedundantSetElimination.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
- `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `numbering.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
- `properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `rse_all-features.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
- `rse-gc.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>

## High-level intent

Binaryen uses `rse` to remove repeated writes of a local to a value the pass already knows that local holds.
The implementation is intentionally small:

- a `PostWalker` visits function expressions;
- the pass tracks one remembered value number per local;
- `ValueNumbering` decides whether two RHS expressions are the same value;
- the walker clears remembered facts at boundaries that could make a straight-line local fact unsafe;
- after rewriting, Binaryen refinalizes the function and runs `vacuum` as a follow-up cleanup.

This is narrower than the old local wiki wording.
`rse` in `version_129` is **not** a LocalGraph/liveness algorithm and it does not prove that overwritten different-value writes are dead.

## The pass in one table

| Step | What Binaryen does | Why |
| --- | --- | --- |
| Initialize state | Create one `Value*` slot per local, all empty | Remember the current value only when it is safe |
| Visit ordinary expressions | Let the walker and value-numbering engine see child expressions first | Later set/get decisions can reuse numbered values |
| Visit `local.get` | If a remembered value exists and its type is a subtype of the get type, refine the value-numbering result for the get | Preserve a more precise known type without changing syntax directly |
| Visit `local.set` / `local.tee` | Compare the RHS value number with the remembered value for the target local | Same-value writes are redundant |
| Rewrite redundant set/tee | Replace `local.set` with `drop(value)` when needed; replace `local.tee` with `value` | Preserve RHS effects/results while deleting only the local write |
| Clear facts | Clear one local or all locals at control/effect/local-state barriers | Avoid carrying straight-line facts across unsafe boundaries |
| Finalize | Refinalize, then schedule `vacuum` afterward | Keep valid typed IR and clean debris |

## Core state: one value-number slot per local

The corrected source-backed model is simple.
For each local, Binaryen stores either:

- no trusted value, or
- a pointer to the current `ValueNumbering::Value` for that local.

There is no predecessor lattice, no set-history set, no liveness map, and no local graph in this pass.
If the pass cannot trust the straight-line fact, it forgets it.

## `visitLocalGet`: type refinement, not direct local-get rewriting

When the walker sees a `local.get`, it checks whether there is a remembered value for that local.
If there is, and the remembered expression type is a subtype of the `local.get` type, Binaryen tells value numbering to treat this get as the known value with the more precise type.

Important consequences:

- the `local.get` expression is not replaced by a copied syntax tree here;
- the value-numbering fact can still make later same-value `local.set` checks succeed;
- the GC/ref-type behavior belongs here because refined expressions can carry narrower reference types.

## `visitLocalSet`: the only removal rule

For `local.set` and `local.tee`, Binaryen value-numbers the RHS.
Then it compares that value number with the remembered current value for the same local.

If they match, the write is redundant.
If they do not match, Binaryen remembers the new RHS value number for that local.

### Plain `local.set`

A plain `local.set` has no result.
When Binaryen removes the set shell, it still preserves the RHS evaluation.
If the RHS has a value type, the replacement is wrapped in `drop`.

Conceptual rewrite:

```wat
(local.set $x VALUE) ;; where $x already holds VALUE
```

becomes:

```wat
(drop VALUE)
```

when `VALUE` produces a result.

### `local.tee`

A `local.tee` returns its RHS value.
When the write is redundant, Binaryen replaces the tee with the RHS value itself.

Conceptual rewrite:

```wat
(local.tee $x VALUE) ;; where $x already holds VALUE
```

becomes:

```wat
VALUE
```

## Conservative invalidation is the control-flow strategy

The pass does not merge facts through diamonds or loops.
It clears facts.

The source has two kinds of clearing:

- `clearLocal(local)`: forget one local's value after a barrier that may change or invalidate that local;
- `clearAllLocals()`: forget every local after broader control/effect boundaries.

The clear-all family includes many forms of non-linear control, calls, memory/table/atomic/GC interactions, `pop`, continuation-related forms, and other expression classes where keeping a single straight-line fact would be unsound or too expensive.

That is the real Binaryen strategy: stay small and forgetful.

## Scheduler placement

`rse` appears late in the no-DWARF function cleanup path, after many local and structural simplifications have already run.
Binaryen's scheduler then runs `vacuum` after `rse`.

That order is meaningful:

- earlier passes expose repeated same-value local writes;
- `rse` removes the redundant set/tee shells;
- `vacuum` removes pure `drop` debris that is now obviously unused.

## What the pass explicitly is not

The corrected source read means future docs and ports should avoid these claims unless a newer upstream version or Starshine-local design changes scope:

- not global-set elimination;
- not memory-store elimination;
- not `struct.set` / `array.set` elimination;
- not LocalGraph/liveness dead-store elimination;
- not copied-local inheritance;
- not same-block read rewriting;
- not exact-vs-merged predecessor dataflow;
- not general overwritten-write deletion.

## Validation surface

Use the official tests as source-backed examples:

- `test/passes/rse_all-features.wast` and expected output cover the ordinary same-value local cases and barrier behavior.
- `test/lit/passes/rse-gc.wast` covers the reference-type refinement side.

For Starshine parity, direct `--rse` comparisons should be followed by `--rse --vacuum` or the late no-DWARF tail because Binaryen expects `vacuum` to clean after this pass.
