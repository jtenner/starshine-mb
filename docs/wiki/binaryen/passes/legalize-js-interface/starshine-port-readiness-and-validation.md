---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-legalize-js-interface-port-readiness-primary-sources.md
  - ../../../raw/research/0395-2026-04-26-legalize-js-interface-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../legalize-and-prune-js-interface/index.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast.mbt
  - ../../../../../src/binary/decode.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./temp-ret-helpers-and-pruning-split.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../legalize-and-prune-js-interface/index.md
  - ../i64-to-i32-lowering/index.md
---

# Starshine port readiness and validation for `legalize-js-interface`

This page bridges Binaryen's source-backed strategy to a practical future Starshine implementation order.
It does **not** claim Starshine implements the pass today.
The current local status remains the one described in [`./starshine-strategy.md`](./starshine-strategy.md): the pass is upstream-only and unknown to the local registry.

## Why this page exists

The existing dossier already explains what Binaryen does, but a future Starshine implementer still needs a smaller answer:

- what local surfaces must be edited together?
- what is the safest first slice?
- what should be validated before deleting original imports or adding prune mode?

The answer is that `legalize-js-interface` should be treated as a **module ABI rewrite**, not a HOT peephole.
A faithful port must update function types, imports, defined functions, exports, direct calls, and `ref.func` references as one coherent function-index rewrite.

## Current Starshine status to preserve until implementation

As of the 2026-04-26 local code review:

- `legalize-js-interface` is absent from `pass_registry_boundary_only_names()` in [`src/passes/optimize.mbt#L127-L143`](../../../../../src/passes/optimize.mbt#L127-L143).
- It is also absent from `pass_registry_removed_names()` in [`src/passes/optimize.mbt#L146-L151`](../../../../../src/passes/optimize.mbt#L146-L151).
- A requested `--pass legalize-js-interface` therefore reaches the unknown-pass error in [`src/passes/optimize.mbt#L462-L465`](../../../../../src/passes/optimize.mbt#L462-L465), not the boundary-only rejection in [`src/passes/optimize.mbt#L468-L471`](../../../../../src/passes/optimize.mbt#L468-L471).
- There is no `src/passes/legalize_js_interface.mbt` owner file and no dedicated backlog slice.

If a future change wants better CLI honesty before implementation, the smallest safe change is to add explicit boundary-only registry coverage plus tests.
That would be a status change and should update this page, [`./starshine-strategy.md`](./starshine-strategy.md), and [`../tracker.md`](../tracker.md).

## Local IR/module shapes a port must transform

The important local shapes line up with Binaryen's wrapper phases from [`./binaryen-strategy.md`](./binaryen-strategy.md).

### 1. Function types and boundary items

Starshine already represents the section-level pieces:

- `FuncExternType(TypeIdx)` in [`src/lib/types.mbt#L171-L177`](../../../../../src/lib/types.mbt#L171-L177) points imported functions at function types.
- `Import(Name, Name, ExternType)` and `Export(Name, ExternIdx)` in [`src/lib/types.mbt#L199-L211`](../../../../../src/lib/types.mbt#L199-L211) model the boundary records that Binaryen retargets.
- `Module` owns `type_sec`, `import_sec`, `func_sec`, `export_sec`, `elem_sec`, and `code_sec` in [`src/lib/types.mbt#L301-L326`](../../../../../src/lib/types.mbt#L301-L326).
- `FuncType`, `TypeSec`, `ImportSec`, `FuncSec`, and `ExportSec` live in [`src/lib/types.mbt#L358-L377`](../../../../../src/lib/types.mbt#L358-L377), which is the first place a wrapper-creating pass must keep counts and references coherent.

A port cannot only rewrite `ExportSec` names.
It must add or reuse function types, add imports/definitions, and preserve index consistency across later sections.

### 2. Export stubs

Binaryen's export-stub shape from [`./wat-shapes.md`](./wat-shapes.md#1-exported-i64-result---legal-wrapper-returning-low-i32) becomes the safest first mutation family:

Before, Starshine may represent:

```wat
(func $f (param i64) (result i64) ...)
(export "f" (func $f))
```

A future pass should synthesize conceptually:

```wat
(func $legalstub$f (param i32 i32) (result i32)
  ;; rebuild incoming i64, call $f, return low half,
  ;; store high half through temp-ret helper
)
(export "f" (func $legalstub$f))
```

This first slice proves:

- new function types can be inserted or reused
- a new defined wrapper can be appended
- an export can be retargeted to the wrapper
- temp-ret helper imports can be added only when an `i64` result needs them

It avoids the harder import-deletion and call-retargeting hazards until the section-update machinery is proven.

### 3. Import wrappers and deletion-last ordering

The next slice should implement the import side from [`./wat-shapes.md`](./wat-shapes.md#3-imported-i64-params---wasm-facing-wrapper-splits-them):

```wat
(import "env" "imp" (func $imp (param i64) (result i64)))
```

becomes conceptually:

```wat
(import "env" "imp" (func $legalimport$imp (param i32 i32) (result i32)))
(func $legalfunc$imp (param i64) (result i64)
  ;; split params, call legal import, rebuild result from temp-ret
)
```

The original illegal import must not disappear until all uses are repaired.
That deletion-last order is a correctness invariant from Binaryen and should become an explicit Starshine test.

### 4. Direct `call` repair

Import legalization changes which function body wasm code should call.
After creating `legalfunc$...`, calls that targeted the original illegal import must target the wasm-facing wrapper.

This is where a future implementation must decide whether to write a general function-index remapper first.
The pass should not hand-patch only one syntactic path if Starshine later gains more function-reference forms.

### 5. `ref.func` repair

Binaryen repairs `ref.func` in both ordinary function bodies and module code.
Starshine already has these local surfaces:

- WAT keyword recognition in [`src/wast/keywords.mbt#L98`](../../../../../src/wast/keywords.mbt#L98).
- Text printing in [`src/wast/module_wast.mbt#L416`](../../../../../src/wast/module_wast.mbt#L416).
- WAT lowering of `ref.func` to `Instruction::ref_func(...)` in [`src/wast/lower_to_lib.mbt#L2386-L2388`](../../../../../src/wast/lower_to_lib.mbt#L2386-L2388).
- Element-item detection and lowering in [`src/wast/lower_to_lib.mbt#L172-L176`](../../../../../src/wast/lower_to_lib.mbt#L172-L176) and [`src/wast/lower_to_lib.mbt#L3373-L3438`](../../../../../src/wast/lower_to_lib.mbt#L3373-L3438).
- Binary decode support in [`src/binary/decode.mbt#L2773-L2774`](../../../../../src/binary/decode.mbt#L2773-L2774).
- The library constructor in [`src/lib/types.mbt#L3979-L3981`](../../../../../src/lib/types.mbt#L3979-L3981).

A beginner trap is to test only direct calls.
A correct port also needs at least one `ref.func` body case and one represented module/element case before deleting original imports.

## Suggested implementation ladder

1. **Registry honesty first**
   - Decide whether to keep the names unknown or add boundary-only entries.
   - Add request tests for both `legalize-js-interface` and `legalize-and-prune-js-interface` if the registry status changes.
2. **Shared function-index rewrite helper**
   - Build or identify a helper that can append imports/functions and retarget all affected function indices.
   - Keep name-section and annotation-section policy explicit; do not silently corrupt optional metadata.
3. **Export-stub-only slice**
   - Cover `i64` params, `i64` result, combined param/result, and no-op legal exports.
4. **Default temp-ret helper imports**
   - Add `env.setTempRet0` and `env.getTempRet0` only when needed.
   - Preserve non-`i64` signatures unchanged.
5. **Import wrappers plus direct-call repair**
   - Add `legalimport$...` and `legalfunc$...` pairs.
   - Retarget direct calls.
   - Keep original illegal imports until every use is repaired.
6. **`ref.func` repair**
   - Cover ordinary bodies and the module/element surfaces Starshine can represent.
7. **Deletion of original illegal imports**
   - Delete only after direct-call and `ref.func` repairs are green.
8. **Pass arguments**
   - Add `legalize-js-interface-export-originals` and `legalize-js-interface-exported-helpers` only after default behavior is stable.
9. **Prune sibling later**
   - Implement [`../legalize-and-prune-js-interface/index.md`](../legalize-and-prune-js-interface/index.md) as a separate phase after plain legalization, not as part of the first port.

## Validation matrix

| Validation lane | Minimum cases | Why it matters |
| --- | --- | --- |
| Registry | unknown vs boundary-only vs implemented behavior for both public names | Prevents stale wiki/CLI claims. |
| Export stubs | `i64` param, `i64` result, combined signature, already-legal export | Proves wrapper synthesis and export retargeting. |
| Temp-ret default | result-high setter/getter imports appear only when needed | Prevents ABI helpers from being injected unnecessarily. |
| Import wrappers | illegal import with params, result, and combined signature | Proves `legalimport$` / `legalfunc$` split. |
| Direct calls | call to illegal import retargets to wasm-facing wrapper | Matches Binaryen's call repair before deletion. |
| `ref.func` | body expression and represented element/module-code expression | Covers the easy-to-miss non-call function-reference surface. |
| Original import deletion | stale original illegal imports disappear after repairs | Catches deletion-before-rewrite corruption. |
| Pass args | `export-originals` and `exported-helpers` separately | Keeps Binaryen's two option bits independently testable. |
| Binaryen oracle | official all-features, exported-helpers, export-originals fixtures | Gives source-backed parity before fuzzing. |

## Known non-goals for the first plain-port slice

- Do not implement whole-module `i64` operation lowering here; that belongs to [`../i64-to-i32-lowering/index.md`](../i64-to-i32-lowering/index.md).
- Do not implement prune-mode unsupported-feature removal in the plain first slice; that belongs to [`../legalize-and-prune-js-interface/index.md`](../legalize-and-prune-js-interface/index.md).
- Do not assume direct calls are the only user of an imported function; `ref.func` repair is part of the upstream contract.
- Do not delete original imports before proving all call and function-reference users were retargeted.

## Open design questions

- Should Starshine preserve the pass name as boundary-only before implementation, or keep the stricter unknown-pass behavior until a real module pass lands?
- Should function-index remapping be built once for several future module passes, or be introduced locally inside this pass first and generalized later?
- How should optional name and annotation sections be updated for synthesized `legalstub$`, `legalimport$`, and `legalfunc$` symbols?
- Which module-code surfaces beyond element expressions must be in the first `ref.func` repair test set?

## Sources

- [`../../../raw/binaryen/2026-04-26-legalize-js-interface-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-legalize-js-interface-port-readiness-primary-sources.md)
- [`../../../raw/research/0395-2026-04-26-legalize-js-interface-port-readiness.md`](../../../raw/research/0395-2026-04-26-legalize-js-interface-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md`](../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../legalize-and-prune-js-interface/index.md`](../legalize-and-prune-js-interface/index.md)
