# WebAssembly GC Aggregate Instruction Source Snapshot

- Capture date: 2026-05-19
- Sources:
  - WebAssembly Core Specification, `Instructions — WebAssembly 3.0`: <https://webassembly.github.io/spec/core/syntax/instructions.html>
  - WebAssembly Core Specification, `Text Instructions — WebAssembly 3.0`: <https://webassembly.github.io/spec/core/text/instructions.html>
  - WebAssembly Core Specification, `Validation of Instructions — WebAssembly 3.0`: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - WebAssembly Core Specification, `Binary Instructions — WebAssembly 3.0`: <https://webassembly.github.io/spec/core/binary/instructions.html>
  - WebAssembly Core Specification, `Types — WebAssembly 3.0`: <https://webassembly.github.io/spec/core/syntax/types.html>

## Durable Takeaways

- The official GC instruction surface separates typed aggregate operators from the type declarations themselves. Struct operators are `struct.new`, `struct.new_default`, `struct.get`, `struct.get_s`, `struct.get_u`, and `struct.set`; array operators are `array.new`, `array.new_default`, `array.new_fixed`, `array.new_data`, `array.new_elem`, `array.get`, `array.get_s`, `array.get_u`, `array.set`, `array.len`, `array.fill`, `array.copy`, `array.init_data`, and `array.init_elem`.
- Struct and array instructions carry type indices, and some array instructions also carry data or element indices. The text form lets those indices be symbolic, but the core and binary forms are still module index spaces that rewrites must keep consistent.
- `struct.get_s`, `struct.get_u`, `array.get_s`, and `array.get_u` are only meaningful for packed integer fields/elements. They sign- or zero-extend the packed value to `i32`; unpacked scalar/reference fields use the plain `get` form.
- `struct.set`, `array.set`, `array.fill`, `array.copy`, `array.init_data`, and `array.init_elem` require mutable aggregate storage. Copy/init operations also depend on compatible source and destination array element types plus live data/element segments.
- `ref.i31`, `i31.get_s`, and `i31.get_u` are the scalar i31 part of the GC instruction cluster: they convert an `i32` to an `i31ref` and read it back with signed or unsigned interpretation.
- `any.convert_extern` and `extern.convert_any` are reference-conversion operations around `externref` and `anyref`; they share the reference/GC validation surface but are not aggregate storage operations.

## Starshine Reconciliation Notes

- Starshine's core instruction model, binary codec, validator, and valid-generator already represent the broad GC aggregate family, including `struct.set` and array constructor/accessor/init/copy operations.
- Starshine's higher-level WAST text path is narrower in this snapshot: `src/wast/keywords.mbt`, `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, and `src/wast/module_wast.mbt` expose struct constructors, struct gets, descriptor constructors, `ref.get_desc`, descriptor cast/test helpers, i31 operations, and `any`/`extern` conversions, but do not expose official `struct.set` or any `array.*` instruction keywords.
- Pass, fuzz, or reducer work should therefore choose fixture format deliberately: use WAST for the locally supported struct-get/constructor/i31 subset, and use core/binary/generated fixtures for `struct.set` and array operations until the WAST parser/printer/lowerer are widened with tests.
- Array data/element instructions bridge multiple resource spaces: type indices, data indices, element indices, and function/table declaration sources. Keep the aggregate guide linked to the data/element and table/function pages rather than duplicating those section rules.

## Follow-up Questions

- Decide whether a WAST text widening should add all official aggregate operations at once or start with `struct.set` plus array get/set/new before adding data/element-backed array init/new forms.
- When adding array text support, decide how to print and lower named type/data/element indices consistently with existing `memory.init`, `table.init`, and typed element segment authoring.
- Recheck custom-descriptor proposal drift before changing descriptor constructor text forms; the official WebAssembly 3.0 source snapshot does not define Starshine's descriptor-family local extensions.
