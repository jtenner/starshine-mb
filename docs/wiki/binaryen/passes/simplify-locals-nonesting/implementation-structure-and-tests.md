---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md
  - ../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./flatness-variant-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-locals/implementation-structure-and-tests.md
---

# Binaryen `simplify-locals-nonesting` implementation structure and tests

## Why this page exists

The landing and strategy pages explain the pass contract.
This page answers a narrower question:

- which official files and tests prove that contract?

That matters here because the pass is implemented inside a shared family file.
Without a file/test map, it is easy to think the nonesting variant is only an incidental template setting.

## Upstream file map

## 1. `src/passes/SimplifyLocals.cpp`

This is the owning implementation file.
For the nonesting variant it provides:

- the shared template `SimplifyLocals<allowTee, allowStructure, allowNesting>`
- the exact constructor `createSimplifyLocalsNoNestingPass()`
- the extra nonesting gate inside `optimizeLocalGet(...)`
- the shared fixed-point cycling logic
- the late `EquivalentOptimizer`
- the final `UnneededSetRemover` cleanup

If you need the answer to “is this behavior really inside Binaryen?”, this is the first file to inspect.

## 2. `src/passes/pass.cpp`

This file proves two public-contract facts.

### Public name

It registers:

- `simplify-locals-nonesting`

### Public meaning

The description explicitly says:

- `no nesting at all`
- `preserves flatness`

That wording is the cleanest official evidence that the variant is intentionally stronger than `-notee-nostructure`.

## 3. `src/passes/passes.h`

This file proves the variant is a first-class public constructor:

- `Pass* createSimplifyLocalsNoNestingPass();`

That matters because it keeps the variant on the same footing as the other public locals-family names.

## 4. Shared helper headers indirectly required by the implementation

These are not variant-specific, but they are still part of the real contract because `SimplifyLocals.cpp` depends on them.

### `ir/linear-execution.h`

Explains the trace model used for the main sink loop.

### `ir/effects.h`

Explains why sinks are blocked by effect, trap, global, table, memory, atomic, and EH ordering.

### `ir/local-utils.h`

Provides:

- `LocalGetCounter`
- `UnneededSetRemover`

### `ir/equivalent_sets.h`

Explains the late equivalent-local phase.

## File-to-responsibility map

| File | What it proves for this dossier |
| --- | --- |
| `src/passes/SimplifyLocals.cpp` | exact `<false, false, false>` identity, nonesting gate, late cleanup phases |
| `src/passes/pass.cpp` | real public pass registration and the official flatness wording |
| `src/passes/passes.h` | first-class constructor surface |
| `src/ir/linear-execution.h` | straight-line-trace execution model |
| `src/ir/effects.h` | movement-safety barriers |
| `src/ir/local-utils.h` | get counting plus dead-set cleanup |
| `src/ir/equivalent_sets.h` | late equal-local canonicalization |

## Dedicated test surface

## 1. `test/passes/simplify-locals-nonesting.wast`

This is the main dedicated input file.
The named functions are small and teaching-friendly:

- `figure-1a`
- `figure-1b`
- `figure-3-if`

The file is valuable because it is not just a smoke test.
It is built from exactly the kinds of local-copy ladders and condition shapes that let you see the flatness policy.

## 2. `test/passes/simplify-locals-nonesting.txt`

This is the expected output.
It proves the visible contract:

- lots of redundant local traffic disappears
- but the pass does not invent new tees or structured result carriers
- many removed sites become `nop`
- the final shape stays visibly flat

## What the dedicated pair teaches

The pair proves three beginner-facing lessons:

1. the pass is real and visible enough to deserve its own golden output
2. the pass still does useful cleanup
3. the cleanup surface is intentionally flatter than the neighboring variants

## Combo lit surface

## `test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast`

This file proves a real pipeline relationship:

- `--flatten --simplify-locals-nonesting --dfo -O3`

That is important evidence that the pass exists for more than unit-test completeness.
It is a real flatten-neighbor cleanup before another flatness-sensitive pass.

## `flatten_simplify-locals-nonesting_souperify_enable-threads.wast`
## `flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast`

These files prove another practical role:

- the nonesting variant is also used before extraction/analysis-style passes where preserving a flatter expression shape matters

The important lesson is not that `souperify` is semantically part of `simplify-locals`.
The lesson is that Binaryen keeps this public variant around because downstream passes genuinely benefit from its flatter cleanup style.

## Test-to-behavior map

| Test file | Main lesson |
| --- | --- |
| `simplify-locals-nonesting.wast` | dedicated public-variant input surface |
| `simplify-locals-nonesting.txt` | visible flat cleanup output contract |
| `flatten_simplify-locals-nonesting_dfo_O3.wast` | real aggressive pipeline role before `dfo` |
| `flatten_simplify-locals-nonesting_souperify_enable-threads.wast` | real flatten-neighbor role before `souperify` |
| `flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast` | same story for the single-use Souper extraction surface |

## What these files do *not* prove

The future Starshine test ladder that builds on these files is now in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
Being explicit about non-proof is useful here.
These files do **not** prove that:

- the pass is in the repo's current no-DWARF default path
- the pass is equivalent to `flatten`
- the pass is equivalent to `simplify-locals-notee-nostructure`

Those are exactly the misconceptions the dedicated folder should prevent.

## Narrow freshness check

A same-day current-main check found:

- `src/passes/SimplifyLocals.cpp`: only small container drift on checked declarations, not a checked semantic nonesting rewrite change
- `test/passes/simplify-locals-nonesting.wast`: unchanged
- `test/passes/simplify-locals-nonesting.txt`: unchanged

So the practical rule for this dossier is:

- teach `version_129` as the released oracle
- cite the 2026-04-25 raw primary-source manifest for durable provenance
- record only a narrow freshness note unless later source checks show real semantic drift

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md)
- [`../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md`](../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md`](../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nonesting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nonesting.txt>
