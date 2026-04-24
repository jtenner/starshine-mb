---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md
  - ../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `remove-relaxed-simd` implementation structure and tests

## Owner files

### `src/passes/RemoveRelaxedSIMD.cpp`

This is the owner file for the pass.
The reviewed `version_129` file contains:

- the pass-level rationale: relaxed SIMD has nondeterminism and this pass removes it by trapping;
- `UnreachableRewriter`, a small post-walker that records whether anything changed;
- `rewrite(...)`, which constructs the replacement block through `ChildLocalizer` and appends `unreachable`;
- visitors for relaxed `Unary`, `Binary`, and `SIMDTernary` expressions;
- `doWalkFunction(...)`, which applies the walker only when relaxed SIMD features are present and refinalizes changed functions.

The source shape is important because it means the pass is not table-driven over all opcodes in one list.
The opcode coverage is split by expression arity.

### `src/ir/child-localizer.h`

`ChildLocalizer` is not pass-specific, but it is part of this pass's correctness proof.
The pass depends on it to preserve child expression evaluation when the original relaxed operation is replaced by a trap.

A port that simply swaps the parent instruction for `unreachable` without preserving child effects would be too aggressive.

### `src/passes/pass.cpp`

`pass.cpp` owns the public pass registration.
For `version_129`, it registers the CLI/pass-manager name `remove-relaxed-simd` and describes the behavior as replacing relaxed SIMD instructions with `unreachable`.

### `src/passes/passes.h`

`passes.h` declares the pass constructor `createRemoveRelaxedSIMDPass()`.

## Official test file

### `test/lit/passes/remove-relaxed-simd.wast`

The dedicated lit file is the primary executable proof surface.
It demonstrates:

- relaxed SIMD instructions becoming traps;
- `drop` wrappers adapting to the new unreachable expression shape;
- ordinary deterministic SIMD instructions remaining ordinary SIMD instructions;
- representative relaxed arithmetic, conversion, and dot-product families.

The test file should not be overread as a one-case-per-op exhaustive proof.
For complete opcode coverage, use the source visitor enumerations in `RemoveRelaxedSIMD.cpp`.

## Source-to-test map

| Contract | Source location | Test evidence |
| --- | --- | --- |
| Public pass spelling is `remove-relaxed-simd` | `pass.cpp` registration | lit command line for the pass |
| Relaxed operations trap | `RemoveRelaxedSIMD.cpp` `rewrite(...)` | expected `unreachable` output |
| Child effects must be preserved | `ChildLocalizer` use in `rewrite(...)` | source-backed; add local tests before porting |
| Ordinary SIMD is not rewritten | visitor only matches relaxed opcodes | non-relaxed SIMD expectations in lit file |
| Changed functions are refinalized | `doWalkFunction(...)` | source-backed; validation should catch regressions |
| No relaxed-SIMD feature means no work | feature check in `doWalkFunction(...)` | source-backed; add a Starshine no-op test if porting |

## Current-main drift check

The `main` versions reviewed on 2026-04-24 kept the same owner file, public spelling, and lit filename.
No teaching-level drift from the `version_129` strategy was found in this focused check.

## Porting cautions

- Do not implement this as relaxed-to-deterministic lowering unless a new source changes the contract.
- Do not erase side-effecting operands.
- Do not assume the official lit file proves every relaxed opcode directly; mirror the source opcode set in local tests.
- Source-confirm feature metadata behavior before advertising output as fully relaxed-SIMD-free at the module feature level.

## Sources

- [`../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md)
- [`../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md`](../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md)
- Binaryen `RemoveRelaxedSIMD.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveRelaxedSIMD.cpp>
- Binaryen `child-localizer.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/child-localizer.h>
- Binaryen test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-relaxed-simd.wast>
