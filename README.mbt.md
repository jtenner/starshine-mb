# Starshine

## High-Level Overview
Starshine is a MoonBit-based WebAssembly toolchain focused on typed IR transforms, validation, optimization passes, and binary/text conversion utilities. The project includes:

- A rich core wasm type and instruction model (`lib`)
- Binary codec support for wasm modules (`binary`)
- A validation and typed-expression pipeline (`validate`)
- An event-driven transformation framework (`transformer`)
- SSA/CFG IR infrastructure (`ir`)
- A growing set of Binaryen-inspired optimization passes (`passes`)
- WAST parsing/printing utilities (`wast`)
- A legacy/in-progress dataflow framework (`dataflow`)

This repository is intended for compiler and tooling work around WebAssembly 3.0-oriented features, especially GC-related transforms and pass pipelines.

## Current Primary Features

### Optimization Pipeline
- Central pass scheduler via `optimize_module` / `optimize_module_with_options`
- Lift-to-typed-expression preprocessing and pass chaining
- Implemented pass families include:
  - Dead code elimination
  - Duplicate import/function elimination
  - DeNaN
  - Global refining
  - Global struct inference
  - Global type optimization
  - GUFA (+ variants)
  - Heap2Local
  - HeapStoreOptimization
  - Inlining (`Inlining`, `InliningOptimizing`, `InlineMain`)
  - LocalCSE
  - LocalSubtyping
  - MergeBlocks
  - MemoryPacking
  - Code folding/pushing
  - Const hoisting
  - Constant field propagation
  - Directize
  - Optimize casts
  - Alignment lowering

### Core Compiler/IR Capabilities
- CFG construction, SSA conversion, use-def, liveness, type inference, GVN, and SSA optimization hooks
- IRContext-driven cached analyses for passes
- Local graph support for local flow constraints in passes

### Validation & Typing
- Module-level validation against wasm structures
- Expression-to-typed-expression conversion (`to_texpr`)
- Type matching/compatibility traits and helpers
- Random valid-module generation helpers for fuzz-style testing

### Binary and WAST Utilities
- Binary encode/decode traits covering module structures
- LEB size helpers (`size_signed`, `size_unsigned`)
- WAST-to-module and module-to-WAST conversion entry points

## Project Layout

- `src/lib`: Core wasm model (`Module`, `Instruction`, `TInstr`, types, constructors, utilities)
- `src/binary`: Binary wasm codec
- `src/validate`: Typechecking/validation + typed conversion
- `src/transformer`: Generic `ModuleTransformer` framework
- `src/ir`: CFG/SSA/analysis infrastructure
- `src/passes`: Optimization passes + pipeline scheduler
- `src/wast`: WAST parser/printer/conversion helpers
- `src/dataflow`: Legacy/experimental dataflow framework (partial)

## Primary Functions (Most Important Entry Points)

### `jtenner/starshine/passes`
- `optimize_module(mod, passes)`
- `optimize_module_with_options(mod, passes, options)`
- `global_type_optimization(mod)`
- `run_denam(mod)`
- `remove_unused(mod)`
- `dataflow_optimization_pass(mod)`
- `alignment_lowering_pass(mod)`

### `jtenner/starshine/validate`
- `validate_module(mod)`
- `to_texpr(expr, env)`
- `validate_typesec/validate_importsec/...` section validators
- `gen_valid_module(random_state)`

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
- `cfg_to_ssa(...)`, `ssa_to_cfg(...)`
- `build_use_def(ssa_cfg)`
- `compute_liveness(ssa_cfg)`
- `run_gvn(ssa_cfg, idom)`
- `optimize_ssa(ssa_cfg)`

### `jtenner/starshine/transformer`
- `ModuleTransformer::new()`
- `change(...)`, `unchanged()`, `error(...)`
- `walk_module(...)`, `walk_tinstruction(...)`, and event hooks

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

### 1b) Configure inlining options
```mbt
using @passes {
  optimize_module_with_options,
  OptimizeOptions,
  InliningOptions,
  ModulePass
}

fn run_inlining(mod : Module) -> Module {
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
  )
  match optimize_module_with_options(mod, [
    ModulePass::Inlining,
    ModulePass::InliningOptimizing,
    ModulePass::InlineMain,
  ], options) {
    Ok(out) => out
    Err(_) => mod
  }
}
```

Inlining notes:
- Callsite planning is reachability-aware (calls in unreachable tails are not considered inline candidates).
- Try-context tail-call hoisting is supported for `return_call`, `return_call_indirect`, and `return_call_ref` wrappers.

LocalCSE notes:
- Works on repeated whole expression trees within linear/basic-block-like regions.
- Uses a 3-phase pipeline (`Scanner`, `Checker`, `Applier`) to request, validate via effect interference, and apply rewrites.
- Rewrites first occurrences to `local.tee` on fresh temps and later repeats to `local.get`.
- Active CSE state is cleared at non-linear boundaries (`if`/`block`/`loop`/`try_table` and branch-like control transfers).

LocalSubtyping notes:
- Refines reference-typed local variable declarations to tighter subtypes inferred from assigned values.
- Uses iterative LUB-based refinement and stops at convergence.
- Non-nullable narrowing is only applied when local-flow checks show default/null cannot be observed; otherwise candidates are relaxed to nullable.
- Refinements are validated by subtype/defaultability guards (`new <: old`, non-`none`, safe defaultability).
- Run it via `ModulePass::LocalSubtyping` in `optimize_module(...)` / `optimize_module_with_options(...)`.

MemoryPacking notes:
- Splits data segments around large zero spans to reduce encoded binary size.
- Preconditions:
  - Requires exactly one memory (no multi-memory support).
  - If that memory is imported, enable `zero_filled_memory=true`.
  - Skips optimization when active-segment safety checks fail (non-constant offsets across multi-segment startup init or overlapping active spans).
- Passive vs active handling:
  - Passive segments can be split and instruction referrers are rewritten.
  - Active segments are split only at constant offsets, and startup-trap parity is preserved (including preserving one trailing write byte when needed).
- Rewritten instructions:
  - `memory.init` may become sequences of `memory.init` + `memory.fill`.
  - `data.drop` may become split-segment drops (or `nop` when removable).
  - GC data-op referrers (`array.new_data`, `array.init_data`) are remapped for segment index changes.
- Invoke with `ModulePass::MemoryPacking(MemoryPackingPassProps::new(...))`.

Example:
```mbt
using @passes { optimize_module, ModulePass, MemoryPackingPassProps }

fn run_memory_packing(mod : Module) -> Module {
  match optimize_module(mod, [
    ModulePass::MemoryPacking(
      MemoryPackingPassProps::new(
        zero_filled_memory=true,
        traps_never_happen=false,
      ),
    ),
  ]) {
    Ok(out) => out
    Err(_) => mod
  }
}
```

MergeBlocks notes:
- Merges nested `block` nodes into parent block lists, including safe loop-tail extraction from `loop` bodies of the form `loop(block(...))`.
- Optimizes `drop(block(...))` by pushing `drop` inward and removing/rewriting break values when safety checks pass.
- Includes conservative `ProblemFinder` checks for break-value removal:
  - rejects side-effecting break values
  - rejects unsupported origin-targeting branch forms
  - handles `try_table` origin-target catches only in safe cases
- Performs expression restructuring to expose additional merge opportunities by pulling block prefixes out of child operands when effect reordering is valid.
- Preserves safety by respecting branch targets and effect invalidation constraints; it does not reorder invalidating operations.
- Run it via `ModulePass::MergeBlocks` in `optimize_module(...)` / `optimize_module_with_options(...)`.

### 2) Validate a module
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

### 3) Decode + encode wasm binary
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

### 4) Parse WAST to module
```mbt
using @wast { wast_to_module }

fn parse_wast(text : String) -> Bool {
  match wast_to_module(text) {
    Ok(_) => true
    Err(_) => false
  }
}
```

## Build, Check, and Test

In this workspace, `moon` may not be on `PATH` in non-interactive shells.
Use:

```bash
/home/jtenner/.moon/bin/moon check
/home/jtenner/.moon/bin/moon test
/home/jtenner/.moon/bin/moon info && /home/jtenner/.moon/bin/moon fmt
```

## Low-Hanging Fruit (Quick Improvements)

- Replace simplified cost model in `code_folding` with a closer Binaryen-style measurer
- Improve `optimize_casts` flow tracking through `br_on_cast` / `br_on_cast_fail`
- Add CFG/LocalGraph-based `canMoveSet` parity logic to `heap_store_optimization`
- Migrate remaining passes to full `IRContext` usage (`de_nan`, `remove_unused`)
- Add CI gate that fails on `moon check` warnings regressions
- Add more parity stress tests for complex CFG in `heap2local`, `global_type_optimization`, and `dead_code_elimination`

## Navigation Tips

- Start at `src/passes/optimize.mbt` to understand pass scheduling
- Use `src/passes/pkg.generated.mbti` to discover public pass APIs quickly
- Use `src/lib/types.mbt` and `src/lib/texpr.mbt` for core IR/model understanding
- Use `src/ir/ir_context.mbt` to understand analysis caching and pass dataflow

## License

This repository currently includes an Apache-2.0 `LICENSE` file and `moon.mod.json` metadata set to `Apache-2.0`.

MIT license note: if you intend to distribute under MIT, update both `LICENSE` and `moon.mod.json` to keep licensing metadata consistent.

## Attribution

This project was written and tested by `GPT-5.3-Codex` and inspected by Joshua Tenner for quality.
