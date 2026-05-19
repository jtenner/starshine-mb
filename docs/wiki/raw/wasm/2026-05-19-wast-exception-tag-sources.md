---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-05-19
sources:
  - https://webassembly.github.io/spec/core/syntax/modules.html#syntax-tag
  - https://webassembly.github.io/spec/core/text/modules.html#text-tag
  - https://webassembly.github.io/spec/core/syntax/instructions.html#syntax-instr-control
  - https://webassembly.github.io/spec/core/valid/instructions.html#valid-instr
  - https://webassembly.github.io/spec/core/binary/modules.html#binary-tagsec
  - https://webassembly.github.io/spec/core/binary/types.html#binary-tagtype
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/wast/module_wast.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/validate/validate.mbt
related:
  - ../../wast/exception-tag-authoring.md
  - ../../binary/type-table-memory-global-tag-sections.md
  - ../../validate/module-validation-phases.md
---

# WAST Exception Tag Authoring Sources - 2026-05-19

This manifest captures the primary-source and in-repository evidence used to add the focused WAST exception/tag authoring guide.

## Official WebAssembly sources checked

- WebAssembly 3.0 core syntax modules, `Tags`: tags live in the module tag section, carry a tag type, and their type index must refer to a function type. Tag indices start after tag imports. URL: <https://webassembly.github.io/spec/core/syntax/modules.html#syntax-tag>.
- WebAssembly 3.0 text modules, `Tags`: text tags can bind symbolic ids; inline tag import/export abbreviations are part of the text format; exports can refer to tag indices. URL: <https://webassembly.github.io/spec/core/text/modules.html#text-tag>.
- WebAssembly 3.0 core syntax instructions, `Control Instructions`: the current core control-instruction grammar includes `throw`, `throw_ref`, `try_table`, and the catch clause family `catch`, `catch_ref`, `catch_all`, and `catch_all_ref`. URL: <https://webassembly.github.io/spec/core/syntax/instructions.html#syntax-instr-control>.
- WebAssembly 3.0 instruction validation: `throw` and `throw_ref` are stack-polymorphic; `throw` consumes the selected tag payload; `throw_ref` consumes an exception reference; `try_table` validates its body under a temporary result label while its catches target labels in the surrounding context. URL: <https://webassembly.github.io/spec/core/valid/instructions.html#valid-instr>.
- WebAssembly 3.0 binary modules, `tagsec`: section id `13` decodes into the module-defined tag list. URL: <https://webassembly.github.io/spec/core/binary/modules.html#binary-tagsec>.
- WebAssembly 3.0 binary types, `tagtype`: binary tag types encode an attributes byte followed by a type index; the current attributes byte is `0x00` and the spec leaves it open for future extension. URL: <https://webassembly.github.io/spec/core/binary/types.html#binary-tagtype>.

## Starshine sources checked

- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) defines `TagIdx`, `TagType`, `Catch`, `Throw`, `ThrowRef`, and `TryTable` as the core in-memory representation.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) parses tag fields, tag import/export shorthand, `throw`, `throw_ref`, modern `try_table` catches, and legacy `try` / `do` / `catch` / `catch_all` / `delegate` / `rethrow` syntax.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) resolves tag ids to imported-prefix absolute `TagIdx` values, lowers modern `try_table` to core `TryTable`, lowers legacy `try` to synthetic block/unreachable shapes, rejects invalid legacy delegate/rethrow labels before validation, and has focused tests for imported tags, inline exports, catch depth, `catch_ref` / `catch_all_ref` exnref flows, implicit typeuse reuse, and validation of lowered fixtures.
- [`src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt) prints tag fields, tag import/export descriptors, `throw`, `throw_ref`, `try_table`, catches, and legacy catch clauses.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) enforces payload pop and unreachable continuation for `throw`, nullable `exnref` consumption for `throw_ref`, catch payload/label matching for `catch` and `catch_ref`, empty or exnref label expectations for catch-all forms, and the surrounding-label semantics of `try_table` catches.
- [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt) validates tag sections after memories and before globals; `TagType` must resolve to a function type with an empty result list.

## Durable conclusions

1. Starshine should document exception authoring as a WAST/text-to-core topic, not only as a binary tag-section topic, because the difficult local behavior is in parsing/lowering label scopes and legacy syntax.
2. The modern source-backed target for new fixtures is `try_table` plus the four catch clause forms. Legacy `try` syntax is accepted for compatibility but lowers to synthetic code rather than preserving a first-class core `try` instruction.
3. Catch label indices are easy to get wrong. Starshine intentionally resolves `try_table` catch labels against the enclosing label space, while the try body receives its own temporary result label.
4. Tag imports and local tag definitions share one absolute imported-prefix tag index space. Any pass that rewrites tags must update throws, catches, exports, imports, names, and validation summaries together.
5. The spec leaves the binary tag-type attributes byte open for future extension. Starshine currently models tag types as only a `TypeIdx`; future binary broadening should not assume no tag attributes can ever exist.
