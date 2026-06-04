---
kind: raw-source
status: current
last_reviewed: 2026-06-04
sources:
  - https://webassembly.github.io/spec/core/syntax/types.html#memory-types
  - https://webassembly.github.io/spec/core/binary/types.html#memory-types
  - https://webassembly.github.io/spec/core/valid/types.html#memory-types
  - https://webassembly.github.io/threads/core/syntax/types.html#memory-types
  - https://webassembly.github.io/threads/core/binary/types.html#memory-types
  - https://webassembly.github.io/threads/core/valid/types.html#memory-types
  - https://webassembly.github.io/threads/core/syntax/instructions.html
  - https://webassembly.github.io/threads/core/valid/instructions.html
  - https://webassembly.github.io/threads/core/exec/instructions.html
  - https://github.com/WebAssembly/threads/blob/main/proposals/threads/Overview.md
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/binary/tests.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/wast/lower_to_lib.mbt
related:
  - ../../validate/resource-sections-and-limits.md
  - ../../wast/resource-declaration-authoring.md
  - ../../wast/atomic-memory-instruction-authoring.md
  - ../../binary/type-table-memory-global-tag-sections.md
  - ../../fuzzing/generator-coverage-ledger.md
---

# Linear Memory Threads Shared-Memory Refresh (2026-06-04)

## Why this note exists

Several Starshine pages need to talk about **linear shared memory**, **atomic memory instructions**, and **memory-type binary flags** without accidentally implying those rules are already part of stable Core WebAssembly 3.0. This note is the shared bridge for those claims.

Use it when updating resource validation claims about shared-memory maxima, WAST declaration caveats for memory64/shared-memory authoring, binary memory-type flag fixtures, generator `[FZG]006` and `[FZG]017` claims, and linear-memory atomic validation claims.

## Source refresh

Checked on 2026-06-04:

- Core 3.0 memory type syntax, binary, and validation pages describe stable memories and limits but do not make Starshine's `shared` bit a stable-core-owned resource field.
- The threads proposal and threads draft spec pages are the correct source for shared linear-memory syntax, binary flags, validation, and atomic instruction semantics.
- The threads draft memory type grammar includes an optional `shared` marker on memory types.
- The threads draft binary memory-type flags cover memory32 and memory64 combinations for min-only, min+max, shared min-only, and shared min+max.
- The threads draft validation rule requires shared memories to carry a maximum.
- The threads draft instruction rules add the `0xFE` atomic instruction family. Its execution text distinguishes ordinary atomic memory accesses from wait operations that can trap when the memory is unshared.

## Starshine local evidence

- `src/lib/types.mbt` represents memory types as `MemType(Limits, shared : Bool)` and has both `I32Limits` and `I64Limits`.
- `src/binary/decode.mbt` accepts memory32 flags `0x00`, `0x01`, `0x02`, `0x03` and memory64 flags `0x04`, `0x05`, `0x06`, `0x07`. The `0x02` and `0x06` shapes represent shared memories without maxima.
- `src/binary/encode.mbt` can emit the same flag matrix from the core `MemType` representation.
- `src/validate/validate.mbt` rejects any shared memory whose limits have no maximum. Therefore shared-without-max byte shapes are decode-accepted invalid-module fixtures, not valid round trips.
- `src/validate/typecheck.mbt` currently requires the selected memory to be shared for all linear-memory atomic families. This is stricter/conservative relative to the proposal distinction where wait-on-unshared is specifically trapping.
- `src/validate/gen_valid.mbt` emits atomics only when it can find a shared memory.
- `src/wast/lower_to_lib.mbt` currently lowers WAST memory declarations through `Limits::i32(...)` and has no text spelling for shared memory or memory64 declarations.

## Durable conclusions

1. Do **not** cite stable Core 3.0 alone as the owner for Starshine's shared-memory flag. Route shared-memory claims through the threads proposal/draft or through local Starshine code.
2. Shared memories must carry maxima in Starshine validation and in the threads proposal validation model.
3. Binary fixtures using flags `0x02` or `0x06` are valid decode coverage but must be described as invalid validation specimens because they encode shared memories without maxima.
4. WAST resource declarations are narrower than core/binary resources today. They can prove ordinary memory32 declarations, but not memory64 or shared-memory declarations.
5. `[FZG]006` shared-memory generation should keep shared memories bounded. `[FZG]017` atomics generation is Starshine-valid core/binary/validator evidence, not high-level WAST text evidence.
6. Starshine's current all-atomics-require-shared validation is a conservative local rule. Avoid rewriting it as proposal-exact breadth unless the typechecker is deliberately widened and fixtures prove the new split.

## Links checked

- Core 3.0 memory type syntax: <https://webassembly.github.io/spec/core/syntax/types.html#memory-types>
- Core 3.0 memory type binary: <https://webassembly.github.io/spec/core/binary/types.html#memory-types>
- Core 3.0 memory type validation: <https://webassembly.github.io/spec/core/valid/types.html#memory-types>
- Threads proposal overview/spec change text: <https://github.com/WebAssembly/threads/blob/main/proposals/threads/Overview.md>
- Threads draft memory type syntax: <https://webassembly.github.io/threads/core/syntax/types.html#memory-types>
- Threads draft memory type binary: <https://webassembly.github.io/threads/core/binary/types.html#memory-types>
- Threads draft memory type validation: <https://webassembly.github.io/threads/core/valid/types.html#memory-types>
- Threads draft instruction syntax/validation/execution: <https://webassembly.github.io/threads/core/syntax/instructions.html>, <https://webassembly.github.io/threads/core/valid/instructions.html>, <https://webassembly.github.io/threads/core/exec/instructions.html>
