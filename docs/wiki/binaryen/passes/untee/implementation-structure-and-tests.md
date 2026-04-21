---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0185-2026-04-21-untee-binaryen-research.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Untee.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/untee.wast
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Untee.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/untee.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./flattening-code-pushing-and-tee-boundaries.md
  - ./wat-shapes.md
---

# `untee` implementation structure and tests

This page is the file-by-file map for Binaryen `untee`.

## Main implementation file

## `src/passes/Untee.cpp`

This file contains essentially the whole pass.
That small size is itself part of the contract.
There is no hidden side analysis spread across helper libraries.

What it defines:

- the pass class `Untee`
- `isFunctionParallel()`
- the single visitor `visitLocalSet(LocalSet* curr)`
- the unreachable fast path
- the reachable tee rewrite into a `makeSequence(curr, get)` wrapper
- `createUnteePass()`

What it proves:

- only `LocalSet` / `local.tee` nodes matter
- nested tees are handled by a postwalk
- the reachable rewrite is literally "set then get"
- the unreachable rewrite is literally "just keep the unreachable child"

## Registration file

## `src/passes/pass.cpp`

This file proves `untee` is a real public pass name, not just an internal helper.

What it adds:

- CLI/public registration under the exact pass name `untee`
- the short public description `removes local.tees, replacing them with sets and gets`

What it does **not** add:

- any default no-DWARF optimize-path scheduling in the reviewed preset logic

That distinction matters because this dossier is about the public pass contract, not about claiming `untee` is part of the repo's current parity queue.

## Constructor declaration surface

## `src/passes/passes.h`

This file declares:

- `Pass* createUnteePass();`

That matters for two reasons:

1. it confirms the pass is part of the normal public pass roster
2. it places `untee` beside other first-class passes instead of leaving it as an internal rewrite helper

## Dedicated upstream test file

## `test/lit/passes/untee.wast`

This is the key behavioral oracle.
Even though the implementation is tiny, the lit file proves the main semantic families clearly.

What it proves:

### 1. Basic dropped-tee rewrite

The file checks that a plain dropped tee like:

- `(drop (local.tee $x (i32.const 1)))`

becomes a result block containing:

- `local.set $x ...`
- `local.get $x`

So the test locks down the core "set then get" expansion shape.

### 2. Type preservation across different scalar types

The test includes both:

- `i32`
- `f64`

tee cases.

That proves the pass is not hardcoded to integer-only behavior.
It must preserve the local's declared value type when constructing the synthetic get.

### 3. Tee feeding another set

The file checks an outer `local.set` whose value is an inner tee.
That proves the pass preserves expression-result semantics instead of simply dropping the result half of the tee.

### 4. Nested tee chains

The file checks:

- a tee whose value is itself another tee

That proves the intended traversal order is inside-out postorder expansion.

### 5. Unreachable fast path

The file checks:

- `(drop (local.tee $x (unreachable)))`

becoming just:

- `(drop (unreachable))`

This is the clearest official proof that unreachable tees are a real special case, not an incidental cleanup by some other nearby pass.

## Freshness check against `main`

A narrow 2026-04-21 drift check compared:

- `src/passes/Untee.cpp`
- `test/lit/passes/untee.wast`
- the relevant `pass.cpp` lines

between `version_129` and `main`.

Result:

- no diff in the reviewed implementation or dedicated test surface

That means the `version_129` release tag is a reliable oracle for this pass at the moment.

## What the source layout does **not** contain

This absence matters too.
There is no separate:

- CFG helper
- effects helper
- local-graph helper
- profitability heuristic
- nested cleanup runner
- second lit roster for GC/EH/strings/etc.

That absence tells us the real scope is intentionally tiny.

## Best file-reading order for future work

If someone needs to port or verify the pass later, the fastest reliable reading order is:

1. `src/passes/Untee.cpp`
   - to understand the whole algorithm
2. `test/lit/passes/untee.wast`
   - to understand the exact positive and bailout shapes
3. `src/passes/pass.cpp`
   - to confirm the public name and non-preset status
4. `src/passes/passes.h`
   - to confirm constructor/public-pass identity

## Future Starshine porting checklist

When this pass is eventually ported, these are the source-backed obligations to preserve:

- exact public name: `untee`
- function-parallel scope
- `LocalSet` / tee-only rewrite surface
- postorder nested-tee behavior
- ordinary-tee expansion into set plus get
- local declared-type reuse for the synthetic get
- unreachable-tee deletion instead of expansion
- explicit distinction from default-preset parity work

## Sources

- [`../../../raw/research/0185-2026-04-21-untee-binaryen-research.md`](../../../raw/research/0185-2026-04-21-untee-binaryen-research.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Untee.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/untee.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Untee.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/untee.wast>
