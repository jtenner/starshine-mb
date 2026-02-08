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

- Finish `de_nan` idempotency regression test and broaden float-producer coverage
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
