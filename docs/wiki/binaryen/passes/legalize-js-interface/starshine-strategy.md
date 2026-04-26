---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-legalize-js-interface-port-readiness-primary-sources.md
  - ../../../raw/research/0395-2026-04-26-legalize-js-interface-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md
  - ../../../raw/research/0291-2026-04-24-legalize-js-interface-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/tests.mbt
  - ../../../../../src/wast/keywords.mbt
  - ../../../../../src/wast/module_wast.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
  - ../../../../../agent-todo.md
  - ../i64-to-i32-lowering/index.md
  - ../legalize-and-prune-js-interface/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./temp-ret-helpers-and-pruning-split.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../i64-to-i32-lowering/index.md
  - ../legalize-and-prune-js-interface/index.md
---

# Starshine Strategy For `legalize-js-interface`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md`](../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code surfaces that already model the needed module shapes, and the main policy question a future port must answer.

## The honest current status

`legalize-js-interface` is currently **upstream-only** for Starshine.
There is no `src/passes/legalize_js_interface.mbt`, no similarly named owner file, and no active pass that creates `legalstub$...`, `legalimport$...`, or `legalfunc$...` wrappers.

The status is weaker than an ordinary boundary-only pass:

- `src/passes/optimize.mbt` does **not** list `legalize-js-interface` in `pass_registry_boundary_only_names()`.
- `src/passes/optimize.mbt` does **not** list `legalize-js-interface` in `pass_registry_removed_names()`.
- `legalize-and-prune-js-interface` is also not registered locally.
- A requested `--pass legalize-js-interface` therefore follows the unknown-pass path rather than the boundary-only or removed-pass rejection path.
- `agent-todo.md` has no dedicated `legalize-js-interface` slice.

So this page is a **status-and-port-planning** bridge, not an implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- pass registry omission and request behavior
  - [`src/passes/optimize.mbt#L111-L130`](../../../../../src/passes/optimize.mbt#L111-L130)
    - boundary-only names include nearby ABI / layout passes such as `i64-to-i32-lowering`, but do not include `legalize-js-interface` or `legalize-and-prune-js-interface`
  - [`src/passes/optimize.mbt#L133-L153`](../../../../../src/passes/optimize.mbt#L133-L153)
    - removed names also omit both JS-interface pass names
  - [`src/passes/optimize.mbt#L451-L455`](../../../../../src/passes/optimize.mbt#L451-L455)
    - unknown names produce `unknown pass flag ...`
  - [`src/passes/optimize.mbt#L459-L465`](../../../../../src/passes/optimize.mbt#L459-L465)
    - boundary-only and removed names have distinct explicit rejection paths, which `legalize-js-interface` does not reach today
  - [`src/passes/registry_test.mbt#L1-L83`](../../../../../src/passes/registry_test.mbt#L1-L83)
    - registry classification tests cover active, module, and removed examples, but not this pass family yet
- module ABI representation that a future wrapper pass would mutate
  - [`src/lib/types.mbt#L139-L153`](../../../../../src/lib/types.mbt#L139-L153)
    - `FuncExternType(TypeIdx)` models imported function signatures through type indices
  - [`src/lib/types.mbt#L174-L189`](../../../../../src/lib/types.mbt#L174-L189)
    - `Import`, `Export`, and their `ExternIdx` / `ExternType` references model the boundary items Binaryen rewrites
  - [`src/lib/types.mbt#L320-L350`](../../../../../src/lib/types.mbt#L320-L350)
    - `Module` owns the optional `type_sec`, `import_sec`, `func_sec`, `export_sec`, and `code_sec` surfaces that a faithful port would need to keep consistent
  - [`src/lib/types.mbt#L358-L377`](../../../../../src/lib/types.mbt#L358-L377)
    - `FuncType`, `TypeSec`, `ImportSec`, `FuncSec`, and `ExportSec` are the local section-level pieces a wrapper-creating module pass would update
- binary section encode/decode support for those ABI surfaces
  - [`src/binary/encode.mbt#L1151-L1178`](../../../../../src/binary/encode.mbt#L1151-L1178)
    - encodes import sections and function extern types
  - [`src/binary/encode.mbt#L1351-L1352`](../../../../../src/binary/encode.mbt#L1351-L1352)
    - encodes export sections
  - [`src/binary/decode.mbt#L2109-L2113`](../../../../../src/binary/decode.mbt#L2109-L2113)
    - decodes import sections
  - [`src/binary/decode.mbt#L2280-L2284`](../../../../../src/binary/decode.mbt#L2280-L2284)
    - decodes export sections
  - [`src/binary/tests.mbt#L181-L205`](../../../../../src/binary/tests.mbt#L181-L205)
    - fuzz-roundtrips import and export sections
- WAT import/export and `ref.func` surfaces
  - [`src/wast/keywords.mbt#L30-L31`](../../../../../src/wast/keywords.mbt#L30-L31)
    - recognizes textual `import` and `export`
  - [`src/wast/keywords.mbt#L98`](../../../../../src/wast/keywords.mbt#L98)
    - recognizes textual `ref.func`
  - [`src/wast/module_wast.mbt#L416`](../../../../../src/wast/module_wast.mbt#L416)
    - prints `ref.func` with the current function index/name
  - [`src/wast/module_wast.mbt#L843-L912`](../../../../../src/wast/module_wast.mbt#L843-L912)
    - prints import and export fields
  - [`src/wast/lower_to_lib.mbt#L172-L176`](../../../../../src/wast/lower_to_lib.mbt#L172-L176)
    - recognizes element items that are `ref.func`, one of the imported-use repair surfaces Binaryen updates
  - [`src/wast/module_wast_tests.mbt#L119-L136`](../../../../../src/wast/module_wast_tests.mbt#L119-L136)
    - roundtrips a table element with `ref.func`, showing the textual path exists even though no JS-legalization rewrite uses it today
- neighboring docs
  - [`../i64-to-i32-lowering/index.md`](../i64-to-i32-lowering/index.md)
    - whole-module internal `i64` pair lowering; this dossier repeatedly warns that Binaryen expects JS-boundary legalization to be a separate earlier concern
  - [`../legalize-and-prune-js-interface/index.md`](../legalize-and-prune-js-interface/index.md)
    - prune-mode sibling; also upstream-only today

That map is the durable local truth today: Starshine has the module, section, WAT, and binary data structures a future implementation would need, but no pass-level ownership or registry promise for this Binaryen pass family.

## What Starshine currently does not do

Current Starshine does not yet:

- preserve the public pass spelling `legalize-js-interface` in the registry
- preserve the sibling public spelling `legalize-and-prune-js-interface`
- synthesize `legalstub$...` wrappers for exported functions with `i64` boundary signatures
- synthesize `legalimport$...` imports plus `legalfunc$...` wasm-facing wrappers for imported functions with `i64` boundary signatures
- split every boundary `i64` param into low/high `i32` params
- route high 32 bits of `i64` results through `setTempRet0` / `getTempRet0` or `__set_temp_ret` / `__get_temp_ret`
- rewrite direct `call` targets from illegal imports to wrapper functions
- rewrite `ref.func` targets from illegal imports to wrapper functions
- remove original illegal imports after repairing all uses
- implement `legalize-js-interface-export-originals`
- implement `legalize-js-interface-exported-helpers`
- implement prune-mode import stubbing, export removal, global-export removal, or post-prune refinalization

Those are the key differences from [`./binaryen-strategy.md`](./binaryen-strategy.md) and [`../legalize-and-prune-js-interface/index.md`](../legalize-and-prune-js-interface/index.md).

## Why this is not `i64-to-i32-lowering`

See [`../i64-to-i32-lowering/index.md`](../i64-to-i32-lowering/index.md).

The split should stay explicit:

- `legalize-js-interface` = JS-boundary adapter wrappers around imports and exports
- `i64-to-i32-lowering` = whole-module internal `i64` pair lowering after other prerequisites such as flattening

A future implementation should not hide the boundary wrapper pass inside `i64-to-i32-lowering` unless the registry, docs, and validation tests explicitly say the local pass has intentionally merged those Binaryen phases.

## Likely future landing shape

A faithful Starshine port would be a **module/boundary pass**, not a HOT peephole.
The pass must update type, import, function, export, and code surfaces together, then repair function references that may appear in ordinary bodies or module-level code.

A safe implementation ladder is now detailed in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md). In short:

1. choose the registry policy first:
   - keep the names unknown until implemented, or
   - add boundary-only entries plus tests that reject them honestly
2. add request tests for both `legalize-js-interface` and `legalize-and-prune-js-interface` if registry status changes
3. add a module-pass owner file only when wrapper generation exists
4. implement type-signature rewriting before wrapper bodies
5. implement export stubs before import wrappers, matching Binaryen's asymmetric directions
6. implement default temp-ret helper creation before exported-helper reuse
7. repair direct `call` and `ref.func` references before deleting original illegal imports
8. add prune-mode only after plain `i64` legalization is green
9. compare focused Binaryen fixtures before any broad fuzzing

## Validation plan for an eventual port

A future port should validate in layers:

1. registry behavior
   - prove whether the names are unknown, boundary-only, removed, or implemented
   - keep the prune sibling separate
2. export wrappers
   - `i64` params rebuild correctly from low/high `i32`s
   - `i64` results return low bits directly and high bits through temp-ret
   - `export-originals` preserves only the intended originals
3. import wrappers
   - JS-facing imports have legalized signatures
   - wasm-facing wrappers rebuild original wasm values
   - original illegal imports disappear only after all uses are repaired
4. reference repair
   - direct `call` rewrites are covered
   - `ref.func` rewrites are covered in bodies and any module-code surface Starshine supports
5. helper policy
   - default imported helpers and exported-helper reuse are tested separately
6. prune sibling
   - import stubs distinguish no-result, defaultable-result, and nondefaultable-result cases
   - function and global exports with still-illegal JS-surface types are removed
   - post-prune validation catches stale type/reference repairs

## Bottom line

Current Starshine `legalize-js-interface` strategy is honest non-adoption plus a precise future bridge:

- no local pass registry entry today
- no owner file today
- no active backlog slice today
- existing module/import/export/function/ref.func data structures are the natural substrate for a future module pass
- the pass must remain separate from whole-module `i64-to-i32-lowering` unless a future design intentionally merges them
- a faithful future port must preserve the plain-vs-prune sibling split and the temp-ret helper modes

For upstream behavior, read [`./binaryen-strategy.md`](./binaryen-strategy.md), [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), [`./temp-ret-helpers-and-pruning-split.md`](./temp-ret-helpers-and-pruning-split.md), and [`./wat-shapes.md`](./wat-shapes.md). For future local sequencing and validation, read [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
