---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md
  - ../../../raw/research/0253-2026-04-22-reorder-locals-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0142-2026-04-20-reorder-locals-binaryen-research.md
  - ../../../raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md
  - ../../../raw/research/0074-2026-04-02-binaryen-multivalue-call-local-disparity.md
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/reorder_locals_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals_print_roundtrip.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals_print_roundtrip.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-ir-builder.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-stack.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./parity.md
  - ./multivalue-call-scope.md
---

# `reorder-locals`: names, roundtrips, and porting boundaries

This page explains the half of `reorder-locals` that is easiest to underestimate.
It should now be read together with the immutable primary-source manifest at [`../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md).

The algorithm in `ReorderLocals.cpp` is tiny, but the practical contract is larger because:

- local names must still line up with declarations
- the reordered declaration order must survive binary write/read roundtrips
- and some remaining compare drift comes from Binaryen's multivalue writeback layers rather than from the pass itself

## The most important practical rule

Do **not** treat `reorder-locals` as "just rename local indices in the function body."

A correct implementation or parity claim must also account for:

- local-name metadata
- emitted declaration order
- and the boundary between the pass and Binaryen's tuple/scratch-local writeback machinery

## Binaryen-side metadata surface

Inside `ReorderLocals.cpp`, the pass rewrites two pieces of function-local metadata:

- `curr->localNames`
- `curr->localIndices`

The rewrite rule is straightforward:

- iterate the final kept `newToOld` order
- if the old local had a name, move it to the new index
- dropped locals simply disappear from the name maps

That means name maintenance is not optional polish.
It is part of the official implementation.

## Why the print-roundtrip tests matter

Binaryen ships a dedicated test pair:

- `test/passes/reorder-locals_print_roundtrip.wast`
- `test/passes/reorder-locals_print_roundtrip.txt`

The interesting case is the second function in that test.
Conceptually, it starts with:

```wat
(func $b
  (local $x i32)
  (local $y f64)
  (drop (local.get $x))
  (drop (local.get $y))
  (drop (local.get $y)))
```

Because `$y` is used twice and `$x` only once, the pass reorders the declarations to:

```wat
(func $b
  (local $y f64)
  (local $x i32)
  ...)
```

And the golden file checks that **the roundtripped output still prints that order**.

That is the key lesson:

- the pass contract is visible at the printed-module level, not just in memory

If a tool rewrites the AST correctly but re-normalizes local declarations on writeout, it still misses a real part of Binaryen parity.

## Why this became a module pass in Starshine

Upstream Binaryen can implement `reorder-locals` as a per-function AST pass because its function object directly owns the relevant local-name metadata.

Starshine's boundaries are different.
Relevant repo facts:

- local declarations live in boundary `@lib.Func`
- parameter types come from module type metadata
- local-name metadata lives in `NameSec.local_names`
- raw encoded name payload can also survive separately as `raw_name_sec_payload`

So a clean Starshine port had to operate as a module pass that can see all of this at once.

That is why the in-tree implementation and tests explicitly handle:

- parameter-count lookup from module type info
- rebuilding grouped body-local runs
- rewriting nested local indices in boundary `Expr`
- rewriting local names only for changed defined functions
- preserving imported-function local-name entries untouched
- clearing stale raw name payloads after layout changes

Those are good Starshine design choices, but they are repo-local adaptation work, not evidence that upstream `ReorderLocals.cpp` itself is more analysis-heavy.

## What the in-tree tests lock down on the Starshine side

`src/passes/reorder_locals_test.mbt` already covers the important boundary-specific surface:

- multiple defined functions with different parameter arities
- params-only no-op behavior
- frequency and first-use ordering
- write-only locals staying live
- tee counting
- nested `block` / `loop` / `if` / `try_table` local rewrites
- local-name rewrites for changed defined functions
- imported-function local-name preservation
- raw name payload invalidation

The module-pass category and preset policy are also locked elsewhere:

- `registry_test.mbt` keeps `reorder-locals` classified as `module_pass`
- `optimize_test.mbt` keeps it out of `optimize` and `shrink` until neighboring passes land honestly
- `cmd_wbtest.mbt` keeps explicit `--reorder-locals` CLI execution working

## Honest scheduler policy in this repo

Binaryen runs `reorder-locals` three times in the no-DWARF function pipeline.
Starshine does **not** yet replay those slots in the public presets.

That is intentional and honest.

The missing neighbors still matter:

- `simplify-locals-nostructure`
- `local-subtyping`
- `coalesce-locals`

Without those, claiming the same preset slot story would overstate parity.
So the current repo rule is:

- `reorder-locals` is implemented and available explicitly
- but it stays out of `optimize` and `shrink` until the neighboring Binaryen-local cleanup cluster can be modeled truthfully

## The remaining writeback caveat is outside `ReorderLocals.cpp`

The other practical boundary to keep explicit is the long-standing multivalue-call parity caveat.

Earlier repo research already showed that some tiny multivalue call fixtures can keep growing locals across repeated Binaryen no-pass or `--reorder-locals` roundtrips.
Re-checking the official upstream sources confirms that this does not come from the sorter itself.

### Where the growth actually comes from

`wasm-ir-builder.cpp` shows Binaryen introducing scratch locals and tuple extraction when packaging hoisted multivalue expressions.
Key patterns include:

- hoisting expressions into scratch locals
- using tuple-typed scratch locals
- repackaging tuple values with `tuple.extract`
- synthesizing additional locals for carried multivalue control-flow traffic

`wasm-stack.cpp` then shows the binary writer layer expanding tuple locals and scratch locals back into plain wasm locals.
Key patterns include:

- grouped-by-type local emission
- mapped scalar binary locals for tuple locals
- scratch locals for tuple extracts with nonzero index
- extra writer-local allocation for certain stack / refinement cases

So the durable conclusion is:

- `ReorderLocals.cpp` decides **which** locals stay and in what relative order
- the IR-builder and writer layers can still decide that extra scratch locals need to exist around multivalue packaging and writeback

That is why some raw-output drift persists even when the reorder algorithm itself matches.

## Practical compare rule

For this repo, the honest compare rule remains:

- use stable-boundary compares when Binaryen no-pass roundtrips converge
- do not blame non-converging multivalue-call writeback on `reorder-locals` itself
- only expand the pass scope if matching Binaryen's broader tuple/scratch-local writeback layer becomes an explicit project goal

That rule is already summarized on the dedicated decision page:

- [`./multivalue-call-scope.md`](./multivalue-call-scope.md)

## What future port work must preserve

A future Starshine refactor or parity push must keep these points explicit:

- local-name metadata is part of pass correctness
- reordered declaration order must survive write/read roundtrips
- imported-function local-name entries should not be damaged when rewriting defined functions
- stale raw name payloads must not outlive a changed local layout
- explicit-pass availability is honest today; preset placement is still intentionally deferred
- multivalue-call local growth belongs to the Binaryen representation boundary, not to the frequency sorter itself

## Bottom line

`reorder-locals` is one of the clearest examples in this campaign that:

- tiny optimization passes can still have real metadata and roundtrip contracts

If a future reader remembers only one thing from this page, it should be:

- matching `ReorderLocals.cpp` is necessary, but matching the **name maps** and the **roundtripped declaration order** is also part of real Binaryen parity.
