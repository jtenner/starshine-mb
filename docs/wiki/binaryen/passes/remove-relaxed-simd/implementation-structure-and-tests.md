---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-remove-relaxed-simd-current-main-recheck.md
  - ../../../raw/research/0482-2026-05-05-remove-relaxed-simd-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-04-remove-relaxed-simd-current-main-recheck.md
  - ../../../raw/research/0437-2026-05-04-remove-relaxed-simd-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-remove-relaxed-simd-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md
  - ../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md
  - ../../../raw/research/0392-2026-04-26-remove-relaxed-simd-port-readiness.md
  - ../../../raw/research/0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md
  - ../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
supersedes:
  - ../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md
---

# `remove-relaxed-simd` implementation structure and tests

## Owner files

### `src/passes/RemoveRelaxedSIMD.cpp`

This is the owner file for the pass.
The reviewed `version_129` and current-`main` file contains:

- the pass-level rationale: relaxed SIMD has nondeterminism and this pass removes it by trapping;
- `RemoveRelaxedSIMD`, a small `WalkerPass<PostWalker<RemoveRelaxedSIMD>>`;
- `rewrite(...)`, which constructs the replacement block through `ChildLocalizer` and appends `unreachable`;
- visitors for relaxed `Unary`, `Binary`, and `SIMDTernary` expressions;
- `doWalkFunction(...)`, which runs the postwalk and then refinalizes the function.

The 2026-04-25 recheck corrected two older overreads:

- no per-function relaxed-SIMD feature gate was found in the reviewed owner file;
- no pass-local `changed` flag or conditional refinalization was found in the reviewed owner file.

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
| Functions are refinalized after the postwalk | `doWalkFunction(...)` | source-backed; validation should catch regressions |
| No feature-gated skip is shown | absence in reviewed owner file | correction from 2026-04-25 recheck |
| Dot-product naming differs across surfaces | Binaryen source/lit spelling vs Starshine keyword spelling; Starshine accepts and round-trips the current spellings in `src/wast/keywords.mbt:463-467`, `src/wast/lower_to_lib.mbt:1519-1522`, `src/binary/decode.mbt:3809-3812`, and `src/lib/show.mbt:2109-2112` | source-backed; add alias or documentation tests before porting |

## Current-main drift check

The `main` versions reviewed on 2026-05-06 kept the same owner file, public spelling, lit filename, trap replacement, and refinalization shape as `version_129`.
The 2026-05-06 recheck found no teaching-level drift from that correction and added a local implementation ladder in [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md).
The checks also found no teaching-level evidence for the older feature-gate wording.

## Porting cautions

- Do not implement this as relaxed-to-deterministic lowering unless a new source changes the contract.
- Do not erase side-effecting operands.
- Do not assume the official lit file proves every relaxed opcode directly; mirror the source opcode set in local tests.
- Do not treat feature metadata cleanup as part of the pass until a primary source proves it.
- Decide explicitly whether Starshine should accept Binaryen's dot-product WAT spelling without `relaxed_` as an alias or document the current spelling split.

## Sources

- [`../../../raw/binaryen/2026-05-06-remove-relaxed-simd-current-main-recheck.md`](../../../raw/binaryen/2026-05-06-remove-relaxed-simd-current-main-recheck.md)
- [`../../../raw/research/0501-2026-05-06-remove-relaxed-simd-current-main-recheck.md`](../../../raw/research/0501-2026-05-06-remove-relaxed-simd-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-05-remove-relaxed-simd-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-remove-relaxed-simd-current-main-recheck.md)
- [`../../../raw/research/0482-2026-05-05-remove-relaxed-simd-current-main-recheck.md`](../../../raw/research/0482-2026-05-05-remove-relaxed-simd-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-04-remove-relaxed-simd-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-remove-relaxed-simd-current-main-recheck.md)
- [`../../../raw/research/0437-2026-05-04-remove-relaxed-simd-current-main-recheck.md`](../../../raw/research/0437-2026-05-04-remove-relaxed-simd-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-remove-relaxed-simd-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-remove-relaxed-simd-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md)
- [`../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md)
- [`../../../raw/research/0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md`](../../../raw/research/0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md)
- [`../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md`](../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md)
- Binaryen `RemoveRelaxedSIMD.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveRelaxedSIMD.cpp>
- Binaryen `child-localizer.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/child-localizer.h>
- Binaryen test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-relaxed-simd.wast>
