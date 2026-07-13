---
kind: source-capture
status: supported
last_reviewed: 2026-07-11
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nonesting.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nonesting.txt
  - ../../../../src/passes/optimize.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ../../binaryen/passes/simplify-locals-nonesting/index.md
  - ../../binaryen/passes/simplify-locals-nonesting/binaryen-strategy.md
  - ../../binaryen/passes/simplify-locals-nonesting/implementation-structure-and-tests.md
  - ../../binaryen/passes/simplify-locals-nonesting/flatness-variant-boundaries.md
  - ../../binaryen/passes/simplify-locals-nonesting/fuzzing.md
---

# Binaryen `simplify-locals-nonesting` current-main recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable focused current-main and local-admission source capture

## Scope

This capture refreshes the durable contract for Binaryen's public
`simplify-locals-nonesting` pass without claiming a line-by-line audit of the
whole shared locals engine. It rechecks the owner, public registration,
factory declaration, dedicated golden pair, and Starshine's current registry
and compare-harness admission.

The earlier 2026-04-25 and 2026-04-26 captures remain the fuller provenance
and port-readiness sources. This file supersedes their **freshness claim only**.

## Official Binaryen sources rechecked

| Surface | Current-main observation | Why it matters |
| --- | --- | --- |
| `src/passes/SimplifyLocals.cpp` | The shared `SimplifyLocals<allowTee, allowStructure, allowNesting>` owner still documents the no-nesting mode as disabling teeing and structure plus sinks that would create nesting. `optimizeLocalGet(...)` still permits a copied `local.get` and a sink into a parent `local.set`, rejects a non-copy sink under other parents, retargets a multi-use copy instead of teeing it, and keeps the fixed-point / late-cleanup / refinalization structure. | The pass remains a conservative shared-engine variant, not a no-op or a `flatten` alias. |
| `src/passes/pass.cpp` | The public spelling remains `simplify-locals-nonesting`; the description still says “no nesting at all” and “preserves flatness”; it still constructs `createSimplifyLocalsNoNestingPass`. | The upstream CLI contract and strongest flatness wording are unchanged. |
| `src/passes/passes.h` | `createSimplifyLocalsNoNestingPass()` remains a public factory declaration alongside the other locals-family constructors. | The variant remains first-class, rather than a test-only mode. |
| `test/passes/simplify-locals-nonesting.wast` and `.txt` | The dedicated golden pair remains present and still demonstrates local-copy cleanup without new tee or result-structure synthesis. | It remains the smallest direct behavior oracle. |

## Local Starshine admission recheck

- [`src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt) still lists only
  `simplify-locals-no-nesting` in its removed-name registry; the upstream
  spelling is not an active local pass.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../scripts/lib/pass-fuzz-compare-task.ts)
  still does not admit either spelling as a `compare-pass` target.
- Therefore, a rejected local command or `--list-passes` inspection remains a
  **roster observation**, not Binaryen-parity evidence. The existing
  [`fuzzing.md`](../../binaryen/passes/simplify-locals-nonesting/fuzzing.md)
  planned-only status remains correct.

## Reconciliation result

No behavior-bearing drift was found in the reviewed upstream or local-admission
surfaces. Keep these durable rules:

1. The Binaryen oracle is the public `--simplify-locals-nonesting` spelling.
2. The exact upstream policy remains `SimplifyLocals<false, false, false>`:
   no fresh tee, no structure synthesis, and no ordinary new nesting.
3. Flat copy retargeting, a direct `local.set` value-position sink, equivalent
   copy cleanup, dead-set cleanup, and needed refinalization remain part of the
   shared-engine contract.
4. Starshine is still not an implementation of that sibling. Its removed local
   alias and absent harness entry must not be represented as a runnable parity
   lane.

## Source URLs

- Binaryen current `SimplifyLocals.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
- Binaryen current pass registration: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Binaryen current public factories: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- Binaryen current dedicated input: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nonesting.wast>
- Binaryen current dedicated expected output: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nonesting.txt>
