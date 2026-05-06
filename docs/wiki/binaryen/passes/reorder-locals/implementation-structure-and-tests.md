---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-reorder-locals-current-main-recheck.md
  - ../../../raw/research/0472-2026-05-05-reorder-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-reorder-locals-validation-primary-sources.md
  - ../../../raw/research/0430-2026-04-27-reorder-locals-validation-bridge.md
  - ../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md
  - ../../../raw/research/0142-2026-04-20-reorder-locals-binaryen-research.md
  - ../../../raw/research/0253-2026-04-22-reorder-locals-primary-sources-and-code-map-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./names-roundtrip-and-porting.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ./parity.md
  - ./multivalue-call-scope.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `reorder-locals` implementation structure and tests

This page is the compact owner-file and proof-surface map for Binaryen `reorder-locals`.
Use it when you need to answer "which upstream file proves what?" without re-reading the whole folder.

## Source rule

Use Binaryen `version_129` as the released oracle for this pass.
For the immutable manifest of the reviewed official release, source, and test URLs, see:

- [`../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md)

A narrow 2026-05-05 current-`main` spot check on `ReorderLocals.cpp`, `pass.cpp`, and the dedicated pass tests found no teaching-relevant drift beyond the dossier's existing claims. The 2026-04-27 validation recheck still stands, and the new 2026-05-05 freshness layer simply refreshes the current-main owner/scheduler/test provenance and the Starshine signoff bridge at [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## One-table summary

| Surface | What it owns | Why it matters |
| --- | --- | --- |
| `src/passes/ReorderLocals.cpp` | The actual pass: access counting, first-use ranking, sort comparator, zero-count tail trim, local-user reindexing, and local-name repair | This file is the semantic core; almost the whole public contract lives here |
| `src/passes/pass.cpp` | Public registration string plus the three no-DWARF scheduler slots | Proves where Binaryen thinks the pass belongs in the default optimize pipeline |
| `test/passes/reorder-locals.wast` + `.txt` | Ordering and trimming examples | Proves the hot-local, tie-break, and zero-count-drop behavior |
| `test/passes/reorder-locals_print_roundtrip.wast` + `.txt` | Print/write roundtrip visibility of reordered locals and names | Proves the metadata/declaration-order half of the contract |
| `src/wasm/wasm-ir-builder.cpp` + `src/wasm/wasm-stack.cpp` | Remaining multivalue-call scratch-local/writeback boundary | Important for parity triage, but not part of `reorder-locals` itself |

## `ReorderLocals.cpp`: the real owner file

The reviewed `version_129` source keeps almost the whole pass in one tiny file.
The two key regions are:

- `ReIndexer` helper around lines `8-63`
  - rewrites only `LocalGet` and `LocalSet` users after the new numbering is known
  - tee traffic is still covered because Binaryen models tee as `LocalSet`
- `ReorderLocals` pass body around lines `65-162`
  - counts local accesses
  - records first-use ranks
  - sorts `newToOld`
  - forces params to keep identity
  - truncates the zero-count body-local suffix
  - builds the inverse map
  - rewrites local users
  - rewrites `localNames` and `localIndices`

That small file layout is itself an important teaching point:

- there is no CFG analysis here
- no `LocalGraph`
- no liveness or dominance engine
- no `ReFinalize`
- no non-nullable-local fixup phase

If a future reader expects a heavier locals-analysis implementation, this owner map is the quickest correction.

## `pass.cpp`: public identity and scheduler role

`pass.cpp` proves two different things about the pass.

### 1. Public pass identity

Binaryen registers the public name:

- `reorder-locals`
  - `sorts locals by access frequency`

That short description is real, but incomplete unless you also keep the declaration-order and local-name repair half of the contract in view.

### 2. Default pipeline placement

The same file also proves the exact repeated no-DWARF placement:

1. after `simplify-locals-nostructure` and `vacuum`
2. after `simplify-locals` and `vacuum`
3. after the second `coalesce-locals`, before the final `vacuum`

That matters because it shows Binaryen using `reorder-locals` as cleanup glue after neighboring locals passes change the local table, not as a one-time cosmetic sort.

## Dedicated tests: what each pair actually proves

## `reorder-locals.wast` and `reorder-locals.txt`

These are the main semantic examples for the core sorter.
They prove the public beginner-visible rules:

- parameters stay fixed
- body locals reorder by descending access count
- live ties break by first use
- zero-count body locals keep original order until they are collectively truncated
- write traffic still counts as access

This pair is the main proof surface for the sorter itself.

## `reorder-locals_print_roundtrip.wast` and `reorder-locals_print_roundtrip.txt`

This pair proves the part that is easiest to miss if you read only the short registration string.
It checks that reordered declarations remain visible and correct after print/write roundtrip, including named locals whose order changes because one is hotter than another.

That makes the durable lesson explicit:

- `reorder-locals` is not only an in-memory remap
- local declaration order and local-name alignment are part of the public contract

## Supporting boundary files: important, but not part of the pass owner surface

The dossier still cites:

- `src/wasm/wasm-ir-builder.cpp`
- `src/wasm/wasm-stack.cpp`

Those files matter only because they explain the remaining multivalue-call scratch-local and writeback drift discussed on the parity pages.
They do **not** mean `reorder-locals` itself is a writer or tuple-packaging pass.

Use them only for the standing scope decision:

- when non-converging multivalue-call local growth appears, do not blame `ReorderLocals.cpp` first

## Practical read order for future work

If you need the fastest correct upstream refresher, read in this order:

1. `ReorderLocals.cpp`
2. `pass.cpp`
3. `reorder-locals.wast`
4. `reorder-locals_print_roundtrip.wast`
5. this folder's [`names-roundtrip-and-porting.md`](./names-roundtrip-and-porting.md)
6. this folder's [`starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
7. this folder's [`parity.md`](./parity.md)

That sequence gets you from upstream owner files to the exact local module-pass adaptation and the still-open multivalue boundary caveat without reopening old confusion about what the core pass itself actually owns.
