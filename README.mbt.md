# Starshine

## High-Level Overview
Starshine is a MoonBit-based WebAssembly toolchain centered on typed IR transforms, validation, optimization, and binary/text conversion. It targets WebAssembly 3.0-era features (including GC-heavy workloads) and follows a pass-pipeline model similar to Binaryen.

## Current Primary Features

### Optimization Pipeline
- Central scheduler: `optimize_module` / `optimize_module_with_options` in `src/passes/optimize.mbt`.
- Pipeline always starts with `lift_to_texpr_pass()` and then runs selected `ModulePass` variants in order.
- Passes are primarily implemented as `ModuleTransformer[IRContext]` adapters.

### Core Compiler/IR Capabilities
- Typed tree IR (`TExpr`/`TInstr`) and linear IR conversion support.
- CFG/SSA infrastructure and analyses in `src/ir/*`.
- `IRContext` analysis caching for multi-pass workflows.
- `LocalGraph` utilities used by control/data-flow-sensitive passes.

### Validation & Typing
- Wasm module validation utilities in `src/validate/*`.
- Typed conversion and compatibility helpers (`to_texpr`, matching/typing traits).

### Binary and WAST Utilities
- Binary encode/decode in `src/binary/*`.
- WAST parsing/printing in `src/wast/*`.

## Project Layout
- `src/lib`: Core wasm model/types/helpers.
- `src/ir`: CFG/SSA/dataflow-style analysis helpers + IR context.
- `src/passes`: Optimization and transform passes.
- `src/transformer`: Event-based module transformer framework.
- `src/validate`: Validation/typechecking.
- `src/binary`: Wasm binary codec.
- `src/wast`: WAST parser/printer.
- `src/dataflow`: Legacy/partial framework, being replaced by `IRContext`-backed flow.

## Primary Functions (Most Important Entry Points)

### `jtenner/starshine/passes`
- `optimize_module(mod, passes)`
- `optimize_module_with_options(mod, passes, options)`
- `InliningOptions::new(...)`
- `OptimizeOptions::new(...)`

### `jtenner/starshine/validate`
- `validate_module(mod)`
- `to_texpr(expr, env)`

### `jtenner/starshine/binary`
- `Decode::decode(bytes, offset)`
- `Encode::encode(value, buffer)`
- `size_signed(value, bits)`
- `size_unsigned(value, bits)`

### `jtenner/starshine/wast`
- `wast_to_module(text, filename?)`
- `module_to_wast(module)`
- `wast_to_script(text, filename?)`
- `script_to_wast(script)`

### `jtenner/starshine/ir`
- `build_cfg(texpr)`
- `cfg.to_ssa(...)`, `ssa.to_cfg(...)`
- `build_use_def(ssa_cfg)`
- `compute_liveness(ssa_cfg)`
- `run_gvn(ssa_cfg, idom)`
- `optimize_ssa(ssa_cfg)`

### `jtenner/starshine/transformer`
- `ModuleTransformer::new()`
- `change(...)`, `unchanged()`, `error(...)`
- `walk_module(...)`, `walk_tinstruction(...)`, event hooks

## Pass Registry (Authoritative)
Current `ModulePass` variants in `src/passes/optimize.mbt`:

### IR / Canonicalization / Folding
- `AlignmentLowering`
- `AvoidReinterprets`
- `CoalesceLocals`
- `CodeFolding`
- `CodePushing`
- `ConstHoisting`
- `ConstantFieldPropagation`
- `DeadCodeElimination`
- `OptimizeInstructions`
- `Precompute`
- `PrecomputePropagate`
- `OptimizeAddedConstants`
- `OptimizeAddedConstantsPropagate`
- `RedundantSetElimination`
- `PickLoadSigns`
- `RemoveUnusedBrs`
- `RemoveUnusedNames`
- `RemoveUnusedTypes`

### Global / Type / Ref Inference
- `AbstractTypeRefining(AbstractTypeRefiningPassProps)`
- `GlobalRefining`
- `GlobalStructInference`
- `GlobalStructInferenceDescCast`
- `GlobalTypeOptimization`
- `TypeRefining`
- `MinimizeRecGroups`

### Heap / GC / Ref Optimizations
- `Heap2Local`
- `HeapStoreOptimization`
- `OptimizeCasts`
- `GUFA`
- `GUFAOptimizing`
- `GUFACastAll`

### Callgraph / Whole-Module / Function-shape
- `DeadArgumentElimination`
- `DuplicateImportElimination`
- `DuplicateFunctionElimination`
- `Directize(Bool)`
- `MergeLocals`
- `MergeBlocks`
- `MergeSimilarFunctions`
- `Monomorphize`
- `MonomorphizeAlways`
- `Inlining`
- `InliningOptimizing`
- `InlineMain`
- `OnceReduction`
- `RemoveUnused`

### Lowering / Runtime / Memory
- `DataflowOptimization`
- `I64ToI32Lowering`
- `Asyncify(AsyncifyPassProps)`
- `MemoryPacking(MemoryPackingPassProps)`
- `DeNaN`

## High-Impact Pass Notes
- `Asyncify`: staged transform, emits runtime globals/API (`__asyncify_state`, `__asyncify_data`, asyncify_* exports).
- `I64ToI32Lowering`: lowers i64 ABI/storage to i32 pairs (single-result i64 path supported; explicit limitations remain).
- `Inlining`: supports full, optimizing, and `InlineMain` modes; options are exposed via `InliningOptions` in `OptimizeOptions`.
- `Heap2Local` / `HeapStoreOptimization`: conservative, LocalGraph/effect-aware rewrites with trap/side-effect parity handling.
- `GlobalTypeOptimization` / `GlobalStructInference` / `MinimizeRecGroups`: whole-module type and struct transformations with external-contract safety guards.
- `Monomorphize`: empirical and always-on variants, with `OptimizeOptions.monomorphize_min_benefit` gating empirical mode.

## Example Usage

### 1) Run an optimization pipeline
```mbt
using @lib { type Module }
using @passes { optimize_module, ModulePass }

fn run_opts(mod : Module) -> Module {
  match optimize_module(mod, [
    ModulePass::GlobalTypeOptimization,
    ModulePass::Heap2Local,
    ModulePass::HeapStoreOptimization,
    ModulePass::DeadCodeElimination,
  ]) {
    Ok(out) => out
    Err(_) => mod
  }
}
```

### 2) Configure optimize options (inlining + monomorphize + low-memory)
```mbt
using @lib { type Module }
using @passes {
  optimize_module_with_options,
  OptimizeOptions,
  InliningOptions,
  ModulePass,
}

fn run_configured(mod : Module) -> Module {
  let inlining = InliningOptions::new(
    always_inline_max_size=2,
    one_caller_inline_max_size=-1,
    flexible_inline_max_size=20,
    max_combined_binary_size=400 * 1024,
    allow_functions_with_loops=false,
    partial_inlining_ifs=2,
  )
  let options = OptimizeOptions::new(
    optimize_level=3,
    shrink_level=0,
    inlining=inlining,
    monomorphize_min_benefit=5,
    low_memory_unused=true,
    low_memory_bound=1024UL,
  )
  match optimize_module_with_options(mod, [
    ModulePass::InliningOptimizing,
    ModulePass::Monomorphize,
    ModulePass::OptimizeAddedConstants,
  ], options) {
    Ok(out) => out
    Err(_) => mod
  }
}
```

### 3) Validate a module
```mbt
using @validate { validate_module }
using @lib { type Module }

fn checked(mod : Module) -> Bool {
  match validate_module(mod) {
    Ok(()) => true
    Err(_) => false
  }
}
```

### 4) Decode + encode wasm binary
```mbt
using @binary { trait Decode, trait Encode }
using @lib { type Module }

fn roundtrip(bytes : Bytes) -> Bytes? {
  match Decode::decode(bytes, 0) {
    Ok((mod : Module, _)) => {
      let buf = @buffer.new()
      match Encode::encode(mod, buf) {
        Ok(()) => Some(buf.to_bytes())
        Err(_) => None
      }
    }
    Err(_) => None
  }
}
```

### 5) Parse WAST to module
```mbt
using @wast { wast_to_module }

fn parse_wast(text : String) -> Bool {
  match wast_to_module(text) {
    Ok(_) => true
    Err(_) => false
  }
}
```

## Low-Hanging Fruit (Quick Improvements)
- Migrate remaining non-IRContext passes (`de_nan`, `remove_unused`) to the IRContext transformer pattern.
- Stabilize `DataflowOptimization` internals and fix the underlying data-structure issues causing test instability.
- Implement descriptor-aware mode for `GlobalStructInferenceDescCast` once descriptor ops exist in this IR.
- Expand parity stress tests for complex CFG/type-hierarchy edge cases in:
  - `Heap2Local`
  - `GlobalTypeOptimization`
  - `RemoveUnusedBrs`
- Add atomics/threading support in core IR + validator, then enable atomics-dependent parity work in heap passes.
- Add CI gating for `moon check` warning regressions.

## Navigation Tips
- Start at `src/passes/optimize.mbt` for pass scheduling and dispatch.
- Use `src/passes/pkg.generated.mbti` for exported pass APIs.
- Use `src/ir/ir_context.mbt` for analysis caching and pass state.
- Use `src/lib/types.mbt` and `src/lib/texpr.mbt` for core IR model definitions.

## License
Repository metadata is currently Apache-2.0 (`LICENSE` and `moon.mod.json`).

## Attribution
Project authored and maintained by Joshua Tenner, with AI-assisted development support.
