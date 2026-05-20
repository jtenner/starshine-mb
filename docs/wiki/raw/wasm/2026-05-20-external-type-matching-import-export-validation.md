# External Type Matching And Import/Export Validation Sources (2026-05-20)

This source manifest anchors [`../../validate/import-export-and-external-type-matching.md`](../../validate/import-export-and-external-type-matching.md). It was prepared to split import/export section validation and the reusable external-type matching relation out of the broad module-validation phase map.

## Primary external sources checked

- WebAssembly Core Specification 3.0, validation of modules, current as checked on 2026-05-20: <https://webassembly.github.io/spec/core/valid/modules.html>. This anchors import descriptors, export descriptors, duplicate export-name rejection, and start/export/reference-source context during module validation.
- WebAssembly Core Specification 3.0, validation of types, current as checked on 2026-05-20: <https://webassembly.github.io/spec/core/valid/types.html>. This anchors limits, memory/table/global/tag/function type validity, and the named external-type matching relation used to decide whether a supplied external value is compatible with an expected import type.
- WebAssembly Core Specification 3.0, abstract module syntax, current as checked on 2026-05-20: <https://webassembly.github.io/spec/core/syntax/modules.html>. This anchors separate import/export fields, external types, external indices, and the imported-prefix index-space model.
- WebAssembly Core Specification 3.0, runtime module execution, current as checked on 2026-05-20: <https://webassembly.github.io/spec/core/exec/modules.html>. This anchors the instantiation-side distinction: a module's imports are matched against runtime external values, while exports are produced from validated module indices.

## Starshine repository evidence checked

- [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt) validates imported `ExternType` declarations, extends function/table/memory/global/tag index spaces in import order, validates export indices after all resources and start have been validated, and rejects duplicate export names in `validate_exportsec_unique(...)`.
- [`src/validate/match.mbt`](../../../../src/validate/match.mbt) implements `Match` for limits, memories, globals, tables, tags, functions, and `ExternType`. It encodes the local external-type compatibility relation, including range containment for limits, shared-flag equality for memories, immutable-global covariance versus mutable-global invariance, table reference-type invariance, tag function-type equivalence, and function subtype matching through type indices.
- [`src/validate/env.mbt`](../../../../src/validate/env.mbt) provides the validation context and imported-prefix helpers used by `validate_importsec(...)`, export-index validation, and function-body typechecking.
- [`src/validate/invalid_fuzzer.mbt`](../../../../src/validate/invalid_fuzzer.mbt) and [`src/validate/gen_invalid_tests.mbt`](../../../../src/validate/gen_invalid_tests.mbt) keep import-section and export-section diagnostics as stable invalid-AST families, including invalid imported function/tag type indices, duplicate export names, and invalid export indices for function/table/global/memory/tag targets.
- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) defines `ExternType`, `ExternIdx`, `Import`, and `Export`; [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) preserve the corresponding binary section shapes and external-kind tags.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) lowers WAST explicit imports, inline exports, explicit exports, and named references into core `ImportSec` / `ExportSec` entries with resolved numeric indices.

## Reconciled takeaways

- Module validation and external import matching are related but different phases. Module validation validates an import declaration's external type and extends the local index space; it does not prove that a host module will provide a value with that type. Host-supplied import matching belongs to instantiation/linking policy.
- Starshine currently exposes and tests the local external-type compatibility relation in `src/validate/match.mbt`, but the active validator's `validate_importsec(...)` does not call it against host values. Treat `Match for ExternType` as the reusable semantic relation for future linker or embedding surfaces, not as evidence that Starshine has a complete runtime instantiation API.
- Export validation is simpler than external matching: Starshine validates that every exported index resolves in the target index space, then checks that export names are unique. The export's external type can be derived from the already-built environment.
- The imported-prefix rule matters for both import and export docs. Imported functions/tables/memories/globals/tags occupy the first entries in their respective index spaces, so an export of index `0` may name an import rather than a local definition.
- Matching rules are variance-sensitive. Limits match by containment (`actual min >= expected min`, `actual max <= expected max` when bounded); memories additionally require the same shared flag and same i32/i64 limit kind; immutable globals are covariant but mutable globals are invariant; table reference types are invariant even when their heap types have a subtype relation; tag types require bidirectional function-type compatibility; function external types follow function subtyping through type indices.

## Follow-up questions

- If Starshine adds a public instantiation/linking API, document which layer owns host import matching, how diagnostics report `(module, name)` pairs, and whether that API uses `Match for ExternType` exactly or adds host-policy restrictions.
- If `externidx` carriers are remapped by a module pass, keep this manifest linked from the pass dossier so function/table/memory/global/tag exports and structured names are repaired together.
- If the official spec changes external-type matching for typed function references, table element variance, shared memories, or tag types, refresh this manifest with `src/validate/match.mbt` and the focused validation page in the same change.
