---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0126-2026-04-20-directize-binaryen-research.md
  - ../../../raw/research/0209-2026-04-21-directize-source-confirmation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Directize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/call-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-wasm64.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./table-info-and-immutability.md
  - ./wat-shapes.md
---

# Upstream implementation structure and test map for `directize`

## Main implementation files

## `src/passes/Directize.cpp`

This is the real pass file.
It owns almost all of the top-level behavior that matters:

- module-level early exits when no tables exist
- pass-arg parsing for `directize-initial-contents-immutable`
- whole-module `TableUtils::computeTableInfo(...)` setup
- the fast “no table can optimize by entry” bail-out
- the `CallIndirect`-only function walker
- constant-target classification into `Known`, `Trap`, or `Unknown`
- direct-call and tail-direct-call emission
- trap-to-`unreachable` replacement with operand side effects preserved
- the handoff to the select-lowering helper
- and post-edit `ReFinalize()` repair when types changed

That file layout proves the most important beginner fact:

- `directize` is not a generic indirect-call optimizer spread across many passes
- it is a small module pass wrapped around a tiny walker plus shared helpers

## `src/passes/call-utils.h`

This helper file owns the supported non-constant target special case.
It proves that Binaryen's extra rewrite surface is deliberately narrow:

- only `select` targets are handled
- both select arms must classify to `Known` or `Trap`
- any `Unknown` arm blocks the rewrite
- unreachable operands and unreachable select types block the rewrite
- operands are spilled to fresh locals so they are evaluated once
- the rewrite result is an `if`, not a more general symbolic-call simplifier

If you want to understand why `directize` can lower some non-constant targets but not ordinary arithmetic or nested symbolic expressions, this is the decisive file.

## `src/ir/table-utils.h` and `src/ir/table-utils.cpp`

These files own the table-knowledge contract.
They prove:

- what `TableInfo` stores (`mayBeModified`, `initialContentsImmutable`, `flatTable`)
- why `canOptimizeByEntry()` can fail even for constant indices
- which situations count as mutation barriers
- how flat tables are materialized from constant-offset function element segments
- and why weird or non-flat table layouts conservatively disable entry-level directization

This is the real source backing for all of the dossier's imported/exported/mutated-table caveats.
`Directize.cpp` consumes these facts, but it does not define them.

## `src/ir/type-updating.h`

This helper matters because `directize` can change visible IR types.
It is the source-backed reason the pass uses `ReFinalize()` after rewriting:

- known traps can make a reachable call become `unreachable`
- known direct callees can expose a more precise result type
- select lowering can add fresh locals

Without this file, it would be easy to misread refinalization as optional cleanup instead of part of the real contract.

## Registration and scheduler files

## `src/passes/pass.cpp`

This file proves three durable things:

- `directize` is a real public pass name
- it sits at the end of the no-DWARF optimize tail tracked in this repo
- Binaryen's own scheduler comments say the pass may unlock more `inlining` or `dae`, but only a converging optimization run comes back for them

That keeps the pass's public identity and “final tail cleanup, not recursive optimizer” role honest.

## `src/passes/passes.h`

This header proves constructor identity:

- `createDirectizePass()`

That matters because it shows `directize` is its own pass surface rather than a hidden mode of another pass.

## Official lit files and what each one proves

## `test/lit/passes/directize_all-features.wast`

This is the main official behavior map.
It directly proves:

- constant-index direct-call positives
- tail `return_call_indirect` positives
- known-trap rewrites to `unreachable`
- multi-table coverage
- ordinary imported/exported-table conservatism
- the `directize-initial-contents-immutable` mode
- the hole-versus-beyond-known-prefix distinction
- select lowering to `if` with fresh locals
- and conservative no-ops when flat-table reasoning fails

It also directly covers mutation barriers for at least:

- `table.set`
- `table.fill`
- `table.init`

## `test/lit/passes/directize-gc.wast`

This file is the official proof that directization uses subtype compatibility rather than exact type-name equality.
It shows:

- supertype-typed indirect calls can directize to subtype targets
- the reversed subtype direction is a known trap
- and exposing a direct callee can refine the visible result type

This is the test file that keeps the pass from being mis-taught as exact-signature-only.

## `test/lit/passes/directize-wasm64.wast`

This file proves the target-classification logic is width-correct on wasm64.
Its practical value is simple:

- Binaryen does not accidentally truncate large `i64` table indices to `i32`

That small file is the whole dedicated source-confirmed map for the wasm64 boundary.

## What the official tests do not isolate cleanly

The lit files are good, but some important facts are still easier to see from the implementation than from testcase headings:

- the exact ownership split between `Directize.cpp` and `call-utils.h`
- the whole-pass early no-op when no table can optimize by entry
- destination `table.copy` as a mutation barrier
- and the explicit post-edit `ReFinalize()` contract

So the safest teaching split is:

- lit files for concrete observable behavior families
- source files for owner boundaries and helper responsibilities

## Practical reading order for future Starshine port work

1. `src/passes/Directize.cpp`
   - understand the main pass and the three-way target classification
2. `src/ir/table-utils.{h,cpp}`
   - understand when Binaryen trusts table entries at all
3. `src/passes/call-utils.h`
   - understand the exact supported `select` rewrite boundary
4. `src/ir/type-updating.h`
   - keep the refinalization requirement honest
5. `src/passes/pass.cpp`
   - confirm public identity and late-tail placement
6. `src/passes/passes.h`
   - confirm constructor identity
7. the three lit files
   - map each major observed rewrite family back to shipped tests

## Porting checklist that falls out of this file map

Before calling a future Starshine port faithful, verify all of these against the official files:

- whole-module table-info prepass exists
- the pass fast-exits when no table is entry-optimizable
- only `CallIndirect` / tail-`CallIndirect` are rewritten directly
- constant targets classify to `Known`, `Trap`, or `Unknown`
- the only extra non-constant helper case is supported `select`
- trap rewrites preserve child side effects
- subtype compatibility matters for typed targets
- mutable-table ordinary-mode conservatism matches `table-utils`
- `directize-initial-contents-immutable` changes only the initial-contents trust boundary, not the flat-table requirements
- rewritten functions are refinalized afterward

## Sources

- [`../../../raw/research/0126-2026-04-20-directize-binaryen-research.md`](../../../raw/research/0126-2026-04-20-directize-binaryen-research.md)
- [`../../../raw/research/0209-2026-04-21-directize-source-confirmation-followup.md`](../../../raw/research/0209-2026-04-21-directize-source-confirmation-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Directize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/call-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-wasm64.wast>
