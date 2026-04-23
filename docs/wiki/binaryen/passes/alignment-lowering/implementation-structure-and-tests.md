---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md
  - ../../../raw/research/0171-2026-04-21-alignment-lowering-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AlignmentLowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/alignment-lowering.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
---

# Upstream implementation structure and test map for `alignment-lowering`

## Main implementation files

## `src/passes/pass.cpp`

Why it matters:

- proves `alignment-lowering` is a real public pass name
- gives the official one-line description
- confirms it is registered as a normal pass, not just a hidden helper

Most important takeaway:

- Binaryen itself defines the pass contract as lowering unaligned loads and stores to smaller aligned ones

## `src/passes/passes.h`

Why it matters:

- proves the pass has a dedicated constructor entrypoint: `createAlignmentLoweringPass()`
- helps place it among other public pass declarations

Most important takeaway:

- this is not an ad hoc mode of another pass; it is a first-class standalone pass

## `src/pass.h`

Why it matters:

- defines `WalkerPass<PostWalker<...>>`
- shows the default `isFunctionParallel()` behavior is false unless overridden

Most important takeaway:

- the reviewed pass is a small post-order AST walker and does not advertise function-parallel execution in its own file

## `src/passes/AlignmentLowering.cpp`

Why it matters:

- this is the whole reviewed implementation
- the file's narrow structure is itself part of the contract

Most important takeaways:

- the real engine is only four methods: `lowerLoadI32`, `lowerStoreI32`, `visitLoad`, `visitStore`
- only ordinary `Load` and `Store` nodes are rewritten
- `i32` helper logic is the central chunking engine for most scalar types
- pointer and value temporaries are mandatory for single-evaluation preservation
- unreachable loads/stores have explicit special handling

## `src/ir/bits.h`

Why it matters:

- provides `Bits::makeSignExt`
- reviewed `alignment-lowering` uses it for signed 16-bit lowered loads

Most important takeaway:

- restoring signed meaning after byte-based rebuilding is an explicit helper contract, not an incidental peephole

## Dedicated upstream lit coverage

## `test/lit/passes/alignment-lowering.wast`

Why it matters:

- this is the dedicated reviewed pass test file
- it shows the intended printed WAT after the pass runs

Most important positive families covered in the reviewed file:

- naturally aligned no-op `i32` load/store families
- `align=1` and `align=2` `i32` load/store splitting
- offset-preserving variants of those same rewrites
- signed `i32.load16_s` restoration
- `i64` load splitting and narrow signed/unsigned extend cases
- `f32` and `f64` reinterpret-based load/store lowering
- unreachable load/store operand-preserving rewrites

## What the reviewed tests do not strongly show

The dedicated reviewed lit file did **not** give me a strong direct proof surface for:

- atomics
- SIMD memory instructions
- explicit lane memory operations
- a dedicated memory64-only section

That absence matches the implementation's narrow visitor surface, but it is still useful to keep explicit.

## Exact teaching map

If you need to re-open the official sources later, use them in this order:

1. `src/passes/pass.cpp`
   - confirm the public name and official one-line description
2. `src/passes/AlignmentLowering.cpp`
   - read the actual implementation contract
3. `test/lit/passes/alignment-lowering.wast`
   - verify which concrete WAT shapes are intended positives and no-ops
4. `src/pass.h`
   - confirm walker/pass framework assumptions
5. `src/ir/bits.h`
   - confirm signed-load repair behavior

## Current-main check

During this dossier review I compared `version_129` and current `main` for `AlignmentLowering.cpp`.
They were identical.
The reviewed official Binaryen `version_129` release page observed on 2026-04-23 showed publish date **2026-04-01**.

That means:

- the implementation summary here is not already stale relative to current upstream, at least on the reviewed implementation file

## Porting checklist for future Starshine work

Before calling a future Starshine port faithful, verify all of these against the reviewed upstream sources:

- public pass name remains `alignment-lowering`
- only ordinary `Load` / `Store` families are in scope unless an intentional extension is documented
- natural-alignment nodes are left unchanged
- chunk size depends on the weak alignment (`1` -> bytes, `2` -> halfwords where possible)
- signed narrow loads restore sign with the equivalent of `makeSignExt`
- `f32` / `f64` use reinterpret staging, not numeric conversion
- 64-bit values split and rebuild through two 32-bit halves
- pointer and store-value expressions are evaluated once and spilled
- unreachable loads/stores preserve operand evaluation shape instead of vanishing silently

## Sources

- [`../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md)
- [`../../../raw/research/0171-2026-04-21-alignment-lowering-binaryen-research.md`](../../../raw/research/0171-2026-04-21-alignment-lowering-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AlignmentLowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/alignment-lowering.wast>
