# Binaryen IR And Starshine Representation Boundary Source Capture

- Source family: Binaryen official repository documentation and source; Starshine local IR implementation.
- Capture date: 2026-07-11.
- Purpose: establish a durable, beginner-safe boundary between WebAssembly's encoded/stack-machine form, Binaryen's named expression IR, Binaryen's optional Flat IR restriction, and Starshine's boundary `@lib` plus optimizer-owned `HotFunc` representations.

## Primary upstream sources

- Binaryen README: <https://github.com/WebAssembly/binaryen/blob/main/README.md>
- Binaryen Flat IR contract: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/flat.h>
- Binaryen flatten implementation: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Flatten.cpp>
- Binaryen `wasm-opt` driver: <https://github.com/WebAssembly/binaryen/blob/main/src/tools/wasm-opt.cpp>

## Repository evidence

- Starshine IR ownership map: [`../../../src/ir/README.md`](../../../src/ir/README.md)
- Starshine owned HOT storage: [`../../../src/ir/hot_core.mbt`](../../../src/ir/hot_core.mbt)
- Boundary-to-HOT conversion: [`../../../src/ir/hot_lift.mbt`](../../../src/ir/hot_lift.mbt)
- HOT-to-boundary conversion and label-depth remapping: [`../../../src/ir/hot_lower.mbt`](../../../src/ir/hot_lower.mbt)
- Current architecture contract: [`../../ir2/architecture-rules.md`](../../ir2/architecture-rules.md)
- Upstream named-label implications: [`../../binaryen/passes/remove-unused-names/control-names-implicit-blocks-and-delegates.md`](../../binaryen/passes/remove-unused-names/control-names-implicit-blocks-and-delegates.md)
- Upstream symbolic-global implications: [`../../binaryen/passes/reorder-globals/index.md`](../../binaryen/passes/reorder-globals/index.md)

## Source-backed takeaways

- Binaryen's documented IR has its own expression and naming rules. In particular, its control labels are unique names and branches resolve those names; do not equate a Binaryen branch target with a Wasm binary label-depth immediate.
- `src/ir/flat.h` defines **Flat IR** as a stricter, optional shape used by passes such as `flatten`. It is not a synonym for all Binaryen IR and it is not a claim about Starshine's `HotFunc` layout.
- `wasm-opt.cpp` is orchestration over parsing, pass running, binary I/O, Stack IR support, and validation. It is not the specification of individual pass rewrites.
- Starshine deliberately has two local layers: boundary `@lib.Module` / `@lib.Expr` values for decode, encode, validation, and printing; and one owned optimizer body, `HotFunc`, for function-body mutation. Its analyses are revision-keyed overlays, not additional owned IRs.
- Starshine lift records stable HOT labels and lowering reconstructs boundary label depths from the active control stack. A port must preserve that translation rather than transplanting Binaryen's name-based branch handling.

## Caveats

- This capture explains representation boundaries; it does not establish parity for any one pass. Use the owning pass dossier and its source/test map for an algorithm contract.
- Existing pass pages intentionally retain more detailed, pass-specific evidence. This capture centralizes only the cross-cutting vocabulary so those pages do not need to re-explain the same representation mismatch.
