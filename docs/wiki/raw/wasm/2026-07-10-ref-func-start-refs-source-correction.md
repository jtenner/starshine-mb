# WebAssembly `ref.func` / Start `refs` Source Correction

- Capture date: 2026-07-10
- Source family: current WebAssembly Core 3.0 validation sources plus Starshine validator evidence
- Primary sources:
  - WebAssembly Core Specification, `Validation / Modules — WebAssembly 3.0 (2026-07-10)`: <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly Core Specification, `Validation / Instructions — WebAssembly 3.0 (2026-07-10)`: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - WebAssembly Core Specification, `Syntax / Modules — WebAssembly 3.0 (2026-07-10)`: <https://webassembly.github.io/spec/core/syntax/modules.html>
  - WebAssembly Core Specification, `Binary Format / Modules — WebAssembly 3.0 (2026-07-10)`: <https://webassembly.github.io/spec/core/binary/modules.html>
- Repository evidence checked:
  - `src/validate/validate.mbt`
  - `src/validate/typecheck.mbt`
  - `docs/wiki/validate/ref-func-declarations.md`
  - `docs/wiki/validate/start-section.md`
  - `docs/wiki/validate/module-validation-phases.md`
  - `docs/wiki/validate/local-spec-divergence-ledger.md`
  - `docs/wiki/wast/function-call-and-module-authoring.md`
  - `docs/wiki/binary/function-import-export-and-code-sections.md`

## Durable takeaways

- `ref.func x` still has two independent validation obligations: `x` must be in the module function context and must be in the declaration set `C.refs`.
- The current module-validation rule constructs `C*.refs` from function-index occurrences in globals, memories, tables, element segments, and exports. **The optional start field is not part of that formula.**
- Start is validated separately as an optional function index whose expanded function type has empty parameters and results. The standard binary start section remains id `8`, and text retains `(start ...)`.
- Starshine's `collect_declared_funcs_bitmap(...)` intentionally excludes `start_sec`, while still marking exports, global/table initializer `ref.func` values, raw element function lists, and element-expression `ref.func` values. On start-only declaration coverage, that local behavior now matches the current Core rule rather than diverging from it.
- The executable regression `validate_module does not treat start as a ref.func declaration source` remains correct: a start target is a function-index carrier and an instantiation entrypoint, but it is not by itself a `ref.func` declaration source.

## Supersession and uncertainty

- This correction supersedes the **standards-source claim** in the older raw captures that optional start contributes to `refs`, especially [`2026-06-04-ref-func-start-refs-current-refresh.md`](2026-06-04-ref-func-start-refs-current-refresh.md), [`2026-05-20-ref-func-declaration-refresh.md`](2026-05-20-ref-func-declaration-refresh.md), and [`2026-05-20-start-section-validation-sources.md`](2026-05-20-start-section-validation-sources.md). Those immutable captures remain useful for their local code maps and historical audit trail.
- This review does not establish whether the official source changed after the older captures or whether their formula was misread. Do not claim a precise standards-change date without a versioned upstream diff.
- Consequently, living pages must not call start-only `ref.func` rejection a current Starshine/Core divergence. It is a current shared rule, while the old divergence statements are historical and superseded.
