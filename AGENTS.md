# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

## Project Structure
- MoonBit packages are directory-scoped (`moon.pkg` per package).
- Top-level module metadata is in `moon.mod.json`.
- Tests are usually colocated with code in this project.
- Common test suffixes:
  - blackbox: `_test.mbt`
  - whitebox: `_wbtest.mbt`

## Coding Convention
- MoonBit code is block-structured with `///|`; block order is not semantically relevant.
- Prefer constructor methods over open-struct literals.
- Put deprecated code in `deprecated.mbt` with `#deprecated` markers.
- If optimization state is reusable, put it in `IRContext` instead of threading extra parameters.
- Pass constructor parameters should be immutable and captured in `ModuleTransformer` event closures.

## Tooling
- Format: `moon fmt`
- Interface refresh: `moon info`
- Lint/check: `moon check`
- Tests: `moon test` (`moon test --update` for snapshot updates)
- Coverage helper: `moon coverage analyze > uncovered.log`
- Preferred final local check sequence:
  - `moon info && moon fmt`
  - `moon check`
  - `moon test`

In this workspace, use absolute moon path when needed:
- `/home/jtenner/.moon/bin/moon check`
- `/home/jtenner/.moon/bin/moon test`
- `/home/jtenner/.moon/bin/moon info && /home/jtenner/.moon/bin/moon fmt`

## Repository Layout
- `src/lib/*.mbt`: core wasm model/types (`types.mbt`), traits/helpers (`arbitrary.mbt`, `eq.mbt`, `show.mbt`, `texpr.mbt`)
- `src/ir/*.mbt`: IR analyses/utilities (`ir_context.mbt`, `liveness.mbt`, `gvn.mbt`, etc.)
- `src/passes/*.mbt`: optimization and lowering passes
- `src/transformer/*.mbt`: `ModuleTransformer` framework
- `src/validate/*.mbt`: wasm validation/typechecking
- `src/binary/*.mbt`: wasm binary encoding/decoding
- `src/wast/*.mbt`: s-expression text parsing/printing

## Pass Pipeline (Compressed)
- Canonical scheduler: `src/passes/optimize.mbt`.
- `optimize_module(...)` always runs `lift_to_texpr_pass()` first.
- Preferred integration shape:
  - pass constructor returns `ModuleTransformer[IRContext]` (or `Result[...]` if setup can fail)
  - scheduler dispatches `ModulePass` variants to constructors.
- `src/passes/util.mbt` has `wrap_unit_func_pass` for adapting `ModuleTransformer[Unit]` function passes.

## ModulePass Registry (Current)

### IR and canonicalization
- `AlignmentLowering`, `AvoidReinterprets`, `CoalesceLocals`, `CodeFolding`, `CodePushing`, `ConstHoisting`, `ConstantFieldPropagation`, `DeadCodeElimination`, `OptimizeInstructions`, `Precompute`, `PrecomputePropagate`, `OptimizeAddedConstants`, `OptimizeAddedConstantsPropagate`, `RedundantSetElimination`, `PickLoadSigns`, `RemoveUnusedBrs`, `RemoveUnusedNames`, `SimplifyLocals`, `SimplifyLocalsNoTee`, `SimplifyLocalsNoStructure`, `SimplifyLocalsNoTeeNoStructure`, `SimplifyLocalsNoNesting`, `Untee`, `Vacuum`, `ReorderLocals`, `ReorderTypes`, `ReorderGlobals`, `ReorderGlobalsAlways`, `ReorderFunctions`, `ReorderFunctionsByName`, `RemoveUnusedTypes`

### Global/type/ref analysis
- `AbstractTypeRefining(AbstractTypeRefiningPassProps)`, `GlobalRefining`, `GlobalStructInference`, `GlobalStructInferenceDescCast`, `GlobalTypeOptimization`, `SimplifyGlobals`, `SimplifyGlobalsOptimizing`, `PropagateGlobalsGlobally`, `TypeRefining`, `MinimizeRecGroups`

### Heap/ref and GC-related
- `Heap2Local`, `HeapStoreOptimization`, `OptimizeCasts`, `GUFA`, `GUFAOptimizing`, `GUFACastAll`

### Callgraph/whole-module
- `DeadArgumentElimination`, `SignaturePruning`, `SignatureRefining`, `DuplicateImportElimination`, `DuplicateFunctionElimination`, `Directize(Bool)`, `ReorderLocals`, `ReorderTypes`, `ReorderGlobals`, `ReorderGlobalsAlways`, `ReorderFunctions`, `ReorderFunctionsByName`, `MergeLocals`, `MergeBlocks`, `MergeSimilarFunctions`, `Monomorphize`, `MonomorphizeAlways`, `Inlining`, `InliningOptimizing`, `InlineMain`, `OnceReduction`, `RemoveUnused`

### Lowering/runtime/memory
- `DataflowOptimization`, `I64ToI32Lowering`, `Asyncify(AsyncifyPassProps)`, `MemoryPacking(MemoryPackingPassProps)`, `DeNaN`

## Key Learned Notes (Short)
- `GUFAOptimizing` runs GUFA then `dead_code_elimination_ir_pass` and `code_folding_ir_pass`.
- `InliningOptions` defaults are Binaryen-aligned (`2, -1, 20, 400*1024, false, 0`).
- `OptimizeAddedConstants*` is gated by `OptimizeOptions.low_memory_unused`.
- `Monomorphize` empirical mode uses `OptimizeOptions.monomorphize_min_benefit`.
- `Asyncify` is staged and emits runtime globals/APIs (`__asyncify_state`, `__asyncify_data`, `asyncify_*`).
- `Asyncify` rewrites wasm-internal `asyncify.*` imports (`start_unwind`/`stop_unwind`/`start_rewind`/`stop_rewind`/`get_state`) to direct calls to generated runtime functions and removes those imports with full `FuncIdx` remapping.
- `Asyncify` now pushes the actual unwind call index onto the asyncify stack (instead of a constant), preserving multi-call rewind fidelity.
- `Asyncify` local save/restore relevance now includes locals read anywhere in rewritten function bodies (not just call arguments), fixing zero-arg-call resume cases.
- `AsyncifyAssertUnwindCorrectness` now models `try_table` catch continuations via catch-target depth propagation instead of a plain lexical try-depth heuristic, avoiding blanket guarding of all try bodies.
- `AsyncifyAssertUnwindCorrectness` precision now also covers embedded `try_table` control-flow placements (for example inside value trees such as `local.set` values) without forcing blanket guards.
- `Asyncify` now supports `asyncify-import-globals` / `asyncify-relocatable` parity by importing mutable `env.__asyncify_state` (`i32`) and `env.__asyncify_data` (pointer-width) globals.
- `Asyncify` now lowers fake call-result globals to typed temp locals for all supported result value types and removes those temporary globals from the final module after lowering.
- `Asyncify` now guards unwind call-index pushes with a stack-end bounds check (`stack_pos + 4 > stack_end -> unreachable`) before writing.
- `MemoryPacking` rewrites segment refs/ops and maintains data-count consistency.
- `I64ToI32Lowering` is integrated; explicit limitations remain for certain global/result shapes.
- `RemoveUnusedNames` is implemented as a depth-based `LabelIdx` adaptation of Binaryen's name-based pass (this IR does not preserve symbolic block names in `TInstr`).
- `TypeRefining` is implemented with direct-callsite param type refinement and Binaryen-style param fixup locals when refined params are assigned less-specific values in function bodies.
- `RemoveUnusedTypes` rebuilds `type_sec` from non-type-section roots plus transitive subtype/signature/field references, then rewrites module `TypeIdx`/`HeapType` references.
- `ReorderFunctions` counts direct `call` usage plus start/export/element `FuncsElemKind` references, then reorders defined functions and remaps `FuncIdx` users.
- This IR does not retain symbolic function names in `Func`, so `ReorderFunctionsByName` currently preserves existing order.
- `ReorderGlobals` reorders defined globals by static `global.get`/`global.set` usage plus dependency-constrained topological ordering, then remaps `GlobalIdx` users module-wide.
- `ReorderGlobalsAlways` uses smooth per-index cost weighting (`1 + i / 128`) for size estimation so it still reorders below 128 globals.
- `ReorderLocals` uses function-signature param counts from `func_sec`/`type_sec` to keep params fixed, then sorts non-param locals by `local.get`/`local.set`/`local.tee` usage frequency and first-use order, dropping trailing unused locals and remapping `LocalIdx` uses.
- `ReorderTypes` reorders private members inside GC recursion groups by weighted use counts plus dependency-aware ordering; it scans multiple successor-weight factors, picks the lowest modeled LEB cost order, rewrites group-local `RecIdx`/external `TypeIdx` references, and remaps module-wide type uses.
- `SignaturePruning` is implemented as a closed-world, no-table transform over function `TypeIdx` groups; it prunes uniformly unused/constant parameters across all funcs sharing a signature and rewrites direct `call`/`call_ref` uses plus affected function-local param indexing.
- `SignatureRefining` is implemented as a closed-world, no-table transform over shared function signatures; it refines parameter/result `FuncCompType` values in-place, uses direct `call`/`call_ref` observations plus function-body result observations, and rewrites function-local param accesses with fixup locals when refined params are assigned less-specific values. It currently aligns with this validator’s `ref.func` typing (`funcref`/nullable), so `ref.func` alone does not prove non-null param refinement.
- `SignatureRefining` handles Binaryen-style `call.without.effects` dual-signature analysis when represented as a `binaryen-intrinsics.call.without.effects` import, applying extra-call argument evidence to the referenced function signature.
- `SignatureRefining` includes public-type observability gating aligned with module import/export/global/table/tag exposure and refinalizes changed typed function bodies via `to_expr`/`to_texpr` under updated signatures.
- `SimplifyGlobals` is implemented as an iterative module pass that combines write/read analysis, immutable-copy preference, dead `global.set` removal, and constant propagation across global inits/module offsets/typed code; `SimplifyGlobalsOptimizing` adds `OptimizeInstructions + DeadCodeElimination + CodeFolding` follow-up.
- `SimplifyLocals` is implemented as an iterative typed-function pass with Binaryen-style variants (`NoTee`, `NoStructure`, `NoTeeNoStructure`, `NoNesting`), including linear `local.set` sinking, structural `if`/`block`/`loop` return formation, and late equivalent-local canonicalization plus dead local-set/tee cleanup.
- `Untee` is implemented as a typed-function rewrite from `local.tee` to `block(result_type, [local.set, local.get])`, using function-signature parameter types plus typed locals to choose block result type; unreachable tee values are replaced directly by the unreachable child.
- `Vacuum` is implemented as a typed-function cleanup pass that performs Binaryen-style dead-wrapper elimination (`optimize` peeling through effectful children), block list compaction/truncation after `unreachable`, constant/unreachable `if` simplification, `drop` canonicalization (including tee lowering and nested-drop cleanup), loop-nop elimination, and throw-free `try_table` elimination.
- `ModuleTransformer::walk_module` dispatches `on_module_evt` before default traversal (consistent with other `walk_*` hooks).
- Audit note: every current `on_*` hook in `ModuleTransformer` has a corresponding `walk_*` dispatcher path; regression tests now cover section dispatchers and core/leaf hook dispatch.
- Threads atomics instruction support is implemented across `lib`/`binary`/`validate`/`ir`/`transformer`, including opcode coverage for `0xFE` `0..78` (`memory.atomic.{notify,wait32,wait64}`, `atomic.fence`, atomic load/store variants, all `atomic.rmw.*`, and all `atomic.rmw*.cmpxchg` forms).
- IR SSA now models atomics explicitly (`MemoryAtomicNotify/Wait32/Wait64`, `AtomicFence`, `AtomicRmw`, `AtomicCmpxchg`), and downstream passes were updated to preserve/rewrite atomic nodes conservatively.

## Current Gaps / Ongoing Work
- Migrate remaining non-IRContext-shaped passes (`de_nan`, `remove_unused`).
- Keep `IRContext`/SSA/CFG as the canonical optimization context for IR-driven passes.
- `GlobalStructInferenceDescCast` now includes a conservative singleton-global `ref.cast` lowering path; full opcode-level descriptor parity (`ref.get_desc` / descriptor-eq casts) still depends on descriptor IR support.
- Atomics/threading core instruction support is complete; remaining parity work is pass-specific atomics optimization behavior in heap passes.
- `Asyncify` parity follow-up remaining gaps are now mostly around wider Binaryen feature surface beyond current staged implementation (for example additional optimizer-stage parity and advanced unsupported value categories).

## Test/Validation Expectations for Pass Changes
- Update inline/dispatch tests in the pass file and/or `src/passes/optimize.mbt`.
- Run:
  - `/home/jtenner/.moon/bin/moon check`
  - `/home/jtenner/.moon/bin/moon test`
  - `/home/jtenner/.moon/bin/moon info && /home/jtenner/.moon/bin/moon fmt`
- Review `.mbti` diffs to confirm intended public API changes.

## Agent Task File
- `./agent-todo.md` contains AI-friendly backlog items.
