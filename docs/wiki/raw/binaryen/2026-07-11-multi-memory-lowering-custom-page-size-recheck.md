# Binaryen `multi-memory-lowering` current-main custom-page-size recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source bridge for the living `docs/wiki/binaryen/passes/multi-memory-lowering/` dossier and the Custom Page Sizes boundary

## Question

The existing dossier correctly says that Binaryen requires every input memory to have the same `pageSizeLog2`. It did not answer the distinct output question:

> Does current `multi-memory-lowering` copy that shared custom page size to the one combined output memory?

This distinction matters because page counts become byte offsets through `pageSizeLog2`, while the combined memory's own `memory.size` / `memory.grow` semantics use the combined memory declaration.

## Official primary sources consulted

- Binaryen current `main`, `src/passes/MultiMemoryLowering.cpp`  
  <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MultiMemoryLowering.cpp>
- Binaryen current `main`, `src/passes/pass.cpp`  
  <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Binaryen current `main`, `src/passes/passes.h`  
  <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- Binaryen current `main`, unchecked lit fixture  
  <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/multi-memory-lowering.wast>
- Binaryen current `main`, checked lit fixture  
  <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/multi-memory-lowering-with-bounds-checks.wast>

The owner, registry, constructor declarations, and both official fixture routes remain the relevant primary evidence. This capture does not treat the WebAssembly proposal as Binaryen transform evidence.

## Current-source result

The pass remains publicly registered under both spellings and both factories remain declared:

- `multi-memory-lowering`;
- `multi-memory-lowering-with-bounds-checks`.

The owner still:

1. disables Binaryen's `MultiMemory` feature before returning for zero/one-memory modules;
2. requires all input memories to agree on address type, sharedness, and `pageSizeLog2`;
3. computes offset-global byte values with `offsetRunningTotal << memory->pageSizeLog2`;
4. uses each original memory's `pageSizeLog2` when virtual size/grow helpers translate between pages and bytes; and
5. creates the combined output by calling `Builder::makeMemory(combinedMemory)` and assigning sharedness, address type, initial pages, maximum pages, and optional import data.

The reviewed `addCombinedMemory()` body does **not** explicitly assign the saved input `pageSizeLog2` to the new combined-memory object.

## Durable interpretation

This is a source-observed **page-size propagation gap**, not proof of a user-visible Binaryen bug:

- The source clearly enforces equal input page sizes.
- The source clearly uses that size for layout and virtual-helper arithmetic.
- The reviewed output-construction body does not visibly propagate that field.
- This capture does not establish the constructor's effective default or execute a custom-page-size module, so it must not claim that Binaryen definitely emits an incorrect module.

Accordingly, living documentation must not say that the pass preserves custom page size merely because it accepts equal-page-size inputs. Custom-page-size lowering remains an unresolved upstream verification case until one of these is available:

1. an upstream source change that assigns the output page size;
2. an upstream regression fixture/output proving the effective constructor behavior for a non-default page size; or
3. a reproducible current Binaryen execution showing the emitted combined memory's page size and virtual `memory.size` / `memory.grow` behavior.

## Why the distinction is correctness-relevant

For a non-default page size, a pass that laid out byte offsets using the input page size but declared the output with another page size could make the generated virtual helpers disagree with the actual combined memory's page units. The checked sibling's bounds-check caveat is separate: it concerns effective-address overflow, not page-size propagation.

## Starshine consequences

Starshine currently has no page-size field in `MemType`, so it cannot reproduce, test, or mask this exact case today. A future Starshine port should therefore either:

- reject custom-page-size inputs before lowering until representation support and an upstream oracle contract exist; or
- add page size to the core memory model and test input equality, combined-memory propagation, byte-offset layout, virtual `memory.size`, and `memory.grow` together.

Do not use memory32, memory64, sharedness, or ordinary 64 KiB multi-memory fixtures as custom-page-size evidence.

## Supersession and limits

This capture supersedes only the earlier unqualified teaching implication that equal input page sizes establish a supported/preserved custom-page-size transform. It does **not** supersede the broader 2026-04-25 and 2026-04-26 strategy/port-readiness captures for ordinary page-size inputs.

The raw GitHub retrieval path exposed the owner source and the fixture routes during this review, but did not provide full fixture bodies. Therefore this note records no claim that either fixture does or does not contain a custom-page-size case.
