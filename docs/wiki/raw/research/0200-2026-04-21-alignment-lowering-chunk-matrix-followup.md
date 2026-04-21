# Binaryen `alignment-lowering` chunk-matrix follow-up

Date: 2026-04-21
Author: OpenAI Codex
Status: source-backed follow-up

## Why this follow-up exists

The existing `alignment-lowering` dossier already captured the pass as a narrow scalar misalignment-legalization pass, but it still had one major teaching gap for a future Starshine port:

- the folder did **not** yet isolate the exact load/store chunk-selection matrix and builder-level operand-preservation rules that Binaryen `version_129` actually implements in `AlignmentLowering.cpp`
- that gap matters because this pass is easy to mis-port as “emit some smaller loads/stores” while silently getting signedness repair, temporary-local evaluation order, or unreachable handling wrong

This follow-up therefore keeps the chosen pass the same (`alignment-lowering`) and deepens the dossier with the missing source-confirmed mechanics page.

`agent-todo.md` still has **no dedicated `alignment-lowering` slice**.

## Local sources re-read

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/alignment-lowering/index.md`
- `docs/wiki/binaryen/passes/alignment-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/alignment-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/alignment-lowering/wat-shapes.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `agent-todo.md`

## Official Binaryen sources re-reviewed

- `version_129` `src/passes/AlignmentLowering.cpp`
- `version_129` `src/passes/pass.cpp`
- `version_129` `src/passes/passes.h`
- `version_129` `src/pass.h`
- `version_129` `src/ir/bits.h`
- `version_129` `test/lit/passes/alignment-lowering.wast`
- current `main` `src/passes/AlignmentLowering.cpp`

## Fresh source-confirmed conclusions

## 1. The real helper matrix is narrower than the general pass summary sounds

The pass-level summary “unaligned loads and stores become smaller aligned ones” is true, but `AlignmentLowering.cpp` is much more specific:

- the dedicated `i32` helpers only need to handle misaligned `2`-byte and `4`-byte integer families
- single-byte families are already naturally aligned and therefore return early before the helper logic matters
- the only live weak alignments in the helper matrix are:
  - `bytes=2, align=1`
  - `bytes=4, align=1`
  - `bytes=4, align=2`
- any other combination in those helpers is treated as an internal-unreachable bug, not a dynamic fallback case

That means a future port should encode a **small exact matrix**, not a vague generic chunker.

## 2. Binaryen explicitly prefers the largest naturally aligned chunk still allowed by the declared alignment

The source does **not** always split to bytes.

Instead:

- `align=1` uses byte chunks
- `align=2` uses halfword chunks where possible
- full-width `i64`/`f64` lowering reuses the same weak alignment for both 32-bit halves, because the only live weak alignments at that stage are `1`, `2`, and `4`

So the real heuristic is:

> use the biggest aligned chunk family that the original weaker alignment still legally permits

This is the key mechanic behind the pass’s output shapes.

## 3. Signed narrow loads are repaired *after* unsigned chunk assembly

The helper does not issue signed byte loads while rebuilding a 16-bit signed result.
Instead it:

- assembles the raw bits from unsigned byte loads
- then calls `Bits::makeSignExt(..., 2, ...)`

That ordering matters because it makes the signedness repair a separate explicit step, not an incidental property of the chosen small-load opcodes.

## 4. `f32`, `f64`, and narrow/full `i64` are all wrappers around the integer chunk engine

The follow-up review confirms the exact reuse surface:

- `f32`: reinterpret to or from `i32`
- narrow `i64`: lower through the `i32` helper, then sign- or zero-extend
- full `i64`: build from two lowered 32-bit halves
- `f64`: reinterpret to or from that full `i64` path

So the porting center of gravity really is the integer helper matrix plus reinterpret/extend wrappers.

## 5. Operand preservation is builder-structured, not just a conceptual promise

The source makes the preservation strategy very concrete:

- loads spill the pointer into a fresh local and then wrap the sequence in a result block
- stores spill both pointer and value into fresh locals before issuing split stores
- unreachable loads are replaced by the pointer child alone
- unreachable stores are replaced by a `drop(ptr); drop(value)` sequence

Those are not afterthought cleanup rules.
They are the actual correctness boundary of the pass.

## 6. The dedicated lit file covers the public shapes, but the helper matrix itself still benefits from a dedicated living explainer

`alignment-lowering.wast` proves the visible rewrite families, including offsets, signed loads, floats, full-width 64-bit values, and unreachable cases.
But the file is still a printed-output surface, not a step-by-step explanation of:

- which helper combinations are actually reachable
- which combinations are internal errors
- why `align=2` becomes halfwords instead of bytes
- why unreachable load/store handling preserves only operands

That is the gap this follow-up closes in the living wiki.

## Durable documentation updates made in this change

- Added `docs/wiki/binaryen/passes/alignment-lowering/chunk-selection-and-unreachable-semantics.md`
- Updated the landing page for `alignment-lowering` to point at the new page and to make the dedicated gap closure explicit
- Updated:
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/index.md`
  - `docs/wiki/log.md`
  so future recursive pass-wiki threads can see that the dossier now covers the exact chunk matrix and operand-preserving unreachable contract, not just the broad pass summary

## Sources

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AlignmentLowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/alignment-lowering.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/AlignmentLowering.cpp>
- `docs/wiki/raw/research/0171-2026-04-21-alignment-lowering-binaryen-research.md`
