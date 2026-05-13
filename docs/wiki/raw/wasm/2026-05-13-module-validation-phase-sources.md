# WebAssembly Module Validation Phase Source Snapshot

- Capture date: 2026-05-13
- Source family: WebAssembly Core Specification 3.0 draft plus current Starshine validator implementation
- Primary sources:
  - WebAssembly Core Specification, `Validation / Modules — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly Core Specification, `Validation / Instructions — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - WebAssembly Core Specification, `Structure / Validation — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/valid/index.html>
- Repository evidence checked:
  - `src/validate/validate.mbt`
  - `src/validate/typecheck.mbt`
  - `src/validate/env.mbt`
  - `src/validate/match.mbt`
  - `src/validate/invalid_fuzzer.mbt`
  - `src/validate/gen_invalid.mbt`
  - `src/validate_trace/main.mbt`
  - `docs/wiki/binary/module-section-map.md`
  - `docs/wiki/validate/ref-func-declarations.md`
  - `docs/wiki/validate/fuzz-hardening.md`
  - `docs/wiki/tooling/validation-gates.md`
  - `docs/wiki/validate/trace-benchmark-baseline.md`
  - `docs/wiki/validation/moonbit-prove-strategy.md`

## Durable takeaways

- The official validation model is context-building plus typed judgement checking. Module validation first derives context entries for functions, tables, memories, globals, tags, elements, data, exports, start, and function-reference declarations, then validates expressions and instructions against those contexts.
- The official instruction-validation model is stack-typed and admits unreachable-code stack polymorphism: after control flow becomes unreachable, missing stack operands can be treated as unknown values, but concrete values produced after that point must still be consumed and matched correctly.
- The official module rules are semantic dependency rules, not merely binary section-order rules. A validator may perform checks in an order that differs from wire order if every check sees the context entries it requires.
- Current Starshine implements whole-module validation in `validate_module_impl(...)` with explicit trace phases: `typesec`, `importsec`, `funcsec`, `tablesec`, `memsec`, `tagsec`, `globalsec`, `elemsec`, `datasec`, `datacnt`, `datacnt_requirement`, `startsec`, `exportsec`, `ref_func_declarations`, `codesec`, and `namesec`.
- Starshine's `Env` is the local validation context. It accumulates global types, function signatures plus optional type indices, table/memory/global/tag types, element/data segment descriptors, locals, labels, and function return types.
- Starshine separates three kinds of validation logic that are easy to conflate:
  - section and index-space validation in `validate.mbt`;
  - expression/instruction stack typing in `typecheck.mbt`;
  - subtype/import/export matching in `match.mbt`.
- Starshine intentionally has a few local policy extensions or divergences from the core spec source pages:
  - it validates the structured `NameSec` indices and rejects raw `name` custom sections in `custom_secs` because the checked-in representation owns parsed name metadata;
  - it runs a separate `ref_func_declarations` phase and currently does not treat `start_sec` alone as declaring a `ref.func` target, even though the official module `refs` source set includes start;
  - it has an explicit `datacnt_requirement` phase that reports body-scoped diagnostics when bulk-memory data-segment instructions appear without a data-count section.
- Trace output is part of the durable validator maintenance surface. `validate_module_with_trace(...)` emits phase start/done/error lines, helper totals, and optional function-body hotspot summaries used by `src/validate_trace` and the wiki trace benchmark baseline.
- Invalid fuzzing should treat every validator family as a diagnostic contract, not just a rejection outcome. The current invalid AST registry checks that each `ValidationIssue` family has at least one deterministic mutation strategy.

## Starshine implications

- Mutating passes should call or conceptually satisfy whole-module validation after any section/index-space rewrite. A function-index, type-index, table/memory/global/tag-index, segment-index, or name-map change can be invalid even if the local instruction rewrite appears stack-correct.
- New validator features should be placed in the narrowest layer that has the required information:
  - type/subtype shape rules belong in `validate.mbt` plus `match.mbt`;
  - per-instruction stack rules belong in `typecheck.mbt`;
  - cross-section rules such as `ref.func` declaration coverage, data-count requirements, and name-map bounds belong in whole-module validation.
- Trace phase names are externally consumed by docs and benchmarks, so renaming or merging phases should update `docs/wiki/validate/module-validation-phases.md`, `docs/wiki/validate/trace-benchmark-baseline.md`, and related tests together.
- When official spec rules and Starshine policy diverge, keep both facts visible in the live wiki and in invalid-fuzzer expectations instead of silently normalizing one to the other.

## Follow-up questions

- Should the Starshine `ref_func_declarations` phase align with the official start-as-declaration-source rule? The focused `ref.func` page records the current local divergence.
- Should structured name-section validation remain a hard validator error for all public entrypoints, or should some binary-roundtrip APIs allow raw `name` custom payloads without structured index checks?
- If `StringRefsSec` becomes standardized or changes section id, refresh this source snapshot together with the binary section-map pages so validation-order examples do not imply a stale local section layout.
