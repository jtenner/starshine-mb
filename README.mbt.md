# Starshine

## High-Level Overview
Starshine is a MoonBit WebAssembly toolkit focused on typed IR transforms, validation, optimization, and binary/text conversion.

The optimizer is organized around `ModulePass` scheduling in `src/passes/optimize.mbt` and always normalizes module code to typed IR first via `lift_to_texpr_pass()`. Most IR passes run through `IRContext`, which caches CFG/SSA/use-def/liveness/type information so multi-pass pipelines can reuse analysis state.

### Proposal Coverage (Current)
- GC + typed references: end-to-end modeled in core types/IR, validator, passes, and binary codec.
- Ref descriptor ops: `ref.get_desc`, `ref.test_desc(_null)`, and `ref.cast_desc_eq(_null)` are parsed, printed, validated, encoded/decoded, represented in `TInstr`, and handled by optimizer passes (including descriptor-aware global-struct inference mode).
- Threads proposal atomics: atomic memory ops (`memory.atomic.notify`, `memory.atomic.wait32/64`, `atomic.fence`, `atomic.rmw.*`, `atomic.rmw*.cmpxchg`) are supported across `lib`, `binary`, `validate`, `ir`, and `transformer`.
- Asyncify: staged transform with runtime state/data globals and import/global modes for integration styles.
- SIMD, exceptions, tables/memory/data/tag sections: represented throughout model + parser/validator + binary support.

## Project Layout
- `src/lib`: core Wasm model (`Module`, sections, `Instruction`, `TInstr`, utility constructors/traits).
- `src/validate`: typechecking and section/module validation.
- `src/ir`: CFG/SSA/use-def/liveness/GVN and `IRContext` cache.
- `src/passes`: optimization and lowering passes plus canonical scheduler.
- `src/transformer`: event-driven `ModuleTransformer` traversal framework.
- `src/binary`: wasm binary decode/encode.
- `src/wast`: WAST lexer/parser/printer and text<->module conversion.

## Primary Public Functions

### `jtenner/starshine/passes`

#### `optimize_module`

```mbt
pub fn optimize_module(
  mod : Module,
  passes : Array[ModulePass],
) -> Result[Module, String]
```

Runs the selected pass list on a module with default `OptimizeOptions`. The scheduler always lifts to typed IR first, then dispatches each pass via the right execution path (`IRContext` transformer, unit transformer, or module runner).

```mbt
using @lib { type Module }
using @passes { optimize_module, ModulePass }

fn run_basic_pipeline(mod : Module) -> Result[Module, String] {
  optimize_module(mod, [
    ModulePass::DeadCodeElimination,
    ModulePass::SimplifyLocals,
    ModulePass::Vacuum,
  ])
}
```

#### `optimize_module_with_options`

```mbt
pub fn optimize_module_with_options(
  mod : Module,
  passes : Array[ModulePass],
  options : OptimizeOptions,
) -> Result[Module, String]
```

Same as `optimize_module`, but with explicit optimization/shrink/inlining/monomorphization/low-memory tuning. Use this whenever pass behavior should depend on optimization level.

```mbt
using @lib { type Module }
using @passes {
  optimize_module_with_options,
  ModulePass,
  OptimizeOptions,
  InliningOptions,
}

fn run_tuned_pipeline(mod : Module) -> Result[Module, String] {
  let options : OptimizeOptions = {
    optimize_level: 3,
    shrink_level: 1,
    inlining: {
      always_inline_max_size: 2,
      one_caller_inline_max_size: -1,
      flexible_inline_max_size: 20,
      max_combined_binary_size: 400 * 1024,
      allow_functions_with_loops: false,
      partial_inlining_ifs: 2,
    },
    monomorphize_min_benefit: 5,
    low_memory_unused: true,
    low_memory_bound: 2048UL,
  }
  optimize_module_with_options(mod, [
    ModulePass::InliningOptimizing,
    ModulePass::Monomorphize,
    ModulePass::OptimizeAddedConstantsPropagate,
  ], options)
}
```

#### `default_function_optimization_passes`

```mbt
pub fn default_function_optimization_passes(
  mod : Module,
  options : OptimizeOptions,
) -> Array[ModulePass]
```

Builds the canonical function-level pass list for the module/features/options. This mirrors the Binaryen-style no-DWARF default sequencing and conditionally includes passes based on optimization/shrink levels and module feature shape.

Current parity-mode mappings in this scheduler are:
- `ssa-nomerge` -> `DataflowOptimization`
- `flatten` -> `SimplifyLocalsNoTeeNoStructure`
- `rereloop` -> early `MergeBlocks`
- `tuple-optimization` -> `DataflowOptimization` (when multivalue signatures are present)

```mbt
using @lib { type Module }
using @passes {
  default_function_optimization_passes,
  optimize_module_with_options,
  OptimizeOptions,
}

fn run_default_function_opts(mod : Module) -> Result[Module, String] {
  let options : OptimizeOptions = {
    optimize_level: 2,
    shrink_level: 1,
    inlining: {
      always_inline_max_size: 2,
      one_caller_inline_max_size: -1,
      flexible_inline_max_size: 20,
      max_combined_binary_size: 400 * 1024,
      allow_functions_with_loops: false,
      partial_inlining_ifs: 0,
    },
    monomorphize_min_benefit: 5,
    low_memory_unused: false,
    low_memory_bound: 1024UL,
  }
  let passes = default_function_optimization_passes(mod, options)
  optimize_module_with_options(mod, passes, options)
}
```

#### `default_global_optimization_pre_passes`

```mbt
pub fn default_global_optimization_pre_passes(
  mod : Module,
  options : OptimizeOptions,
  closed_world? : Bool = true,
) -> Array[ModulePass]
```

Builds the canonical whole-module pre-pass list for global/type/callgraph optimization. `closed_world=false` chooses conservative variants where needed (for example `RemoveUnusedModuleElements`).

Current parity-mode mappings in this scheduler are:
- `remove-unused-module-elements` (open-world mode) -> `RemoveUnusedModuleElements`
- `cfp-reftest` -> `ConstantFieldPropagation`
- `unsubtyping` -> `MinimizeRecGroups`
- `generate-global-effects` -> `PropagateGlobalsGlobally`

```mbt
using @lib { type Module }
using @passes {
  default_global_optimization_pre_passes,
  optimize_module_with_options,
  OptimizeOptions,
}

fn run_global_prepass_open_world(mod : Module) -> Result[Module, String] {
  let options : OptimizeOptions = {
    optimize_level: 3,
    shrink_level: 0,
    inlining: {
      always_inline_max_size: 2,
      one_caller_inline_max_size: -1,
      flexible_inline_max_size: 20,
      max_combined_binary_size: 400 * 1024,
      allow_functions_with_loops: false,
      partial_inlining_ifs: 0,
    },
    monomorphize_min_benefit: 5,
    low_memory_unused: false,
    low_memory_bound: 1024UL,
  }
  let passes = default_global_optimization_pre_passes(
    mod,
    options,
    closed_world=false,
  )
  optimize_module_with_options(mod, passes, options)
}
```

### `jtenner/starshine/validate`

#### `empty_env`

```mbt
pub fn empty_env() -> Env
```

Creates a fresh validation/typechecking environment with no module state loaded.

```mbt
using @validate { empty_env }

fn fresh_env() -> Bool {
  ignore(empty_env())
  true
}
```

#### `to_texpr`

```mbt
pub fn to_texpr(expr : Expr, env : Env) -> Result[TExpr, String]
```

Converts linear `Expr` instructions to typed IR (`TExpr`) using the provided environment. This is the typed conversion entry point used before IR-driven optimization.

```mbt
using @lib { Expr, Instruction }
using @validate { Env, to_texpr }

fn typed_nop() -> Result[TExpr, String] {
  let expr = Expr::new([Instruction::nop()])
  let env = Env::new()
  to_texpr(expr, env)
}
```

#### `validate_module`

```mbt
pub fn validate_module(mod : Module) -> Result[Unit, String]
```

Validates an entire module (all relevant sections and internal typing rules). It returns `Err(String)` with a diagnostic when validation fails.

```mbt
using @lib { type Module }
using @validate { validate_module }

fn is_valid(mod : Module) -> Bool {
  match validate_module(mod) {
    Ok(()) => true
    Err(_) => false
  }
}
```

#### `descriptor_compatible`

```mbt
pub fn descriptor_compatible(
  left : RefType,
  right : RefType,
  env : Env,
) -> Bool
```

Checks descriptor-level compatibility for ref types in a specific environment. Useful for descriptor op reasoning and diagnostics in tools built on top of the validator.

```mbt
using @lib { RefType, HeapType, AbsHeapType }
using @validate { Env, descriptor_compatible }

fn desc_ok() -> Bool {
  let env = Env::new()
  let a = RefType::new(false, HeapType::abs(AbsHeapType::any()))
  let b = RefType::new(true, HeapType::abs(AbsHeapType::any()))
  descriptor_compatible(a, b, env)
}
```

### `jtenner/starshine/binary`

#### `Decode::decode`

```mbt
pub trait Decode {
  decode(Bytes, Int) -> Result[(Self, Int), String]
}
```

Decodes a value of type `Self` from a byte buffer starting at `offset`, returning both the decoded value and the new cursor.

```mbt
using @lib { type Module }
using @binary { trait Decode }

fn decode_module(bytes : Bytes) -> Result[Module, String] {
  match Decode::decode(bytes, 0) {
    Ok((mod : Module, _next)) => Ok(mod)
    Err(e) => Err(e)
  }
}
```

#### `Encode::encode`

```mbt
pub trait Encode {
  encode(Self, Buffer) -> Result[Unit, String]
}
```

Encodes a value into a mutable buffer. This is implemented for `Module` and many core AST/value types.

```mbt
using @binary { trait Encode }
using @lib { type Module }

fn encode_module(mod : Module) -> Result[Bytes, String] {
  let buf = @buffer.new()
  match Encode::encode(mod, buf) {
    Ok(()) => Ok(buf.to_bytes())
    Err(e) => Err(e)
  }
}
```

#### `size_signed`

```mbt
pub fn size_signed(value : Int64, bits : Int) -> Result[Int, String]
```

Returns the encoded signed-LEB128 byte width for `value` constrained by `bits`.

```mbt
using @binary { size_signed }

fn s33_width(v : Int64) -> Result[Int, String] {
  size_signed(v, 33)
}
```

#### `size_unsigned`

```mbt
pub fn size_unsigned(value : UInt64, bits : Int) -> Result[Int, String]
```

Returns the encoded unsigned-LEB128 byte width for `value` constrained by `bits`.

```mbt
using @binary { size_unsigned }

fn u32_width(v : UInt64) -> Result[Int, String] {
  size_unsigned(v, 32)
}
```

### `jtenner/starshine/wast`

#### `wast_to_module`

```mbt
pub fn wast_to_module(
  text : String,
  filename? : String,
) -> Result[Module, String]
```

Parses module text format into `Module`.

```mbt
using @wast { wast_to_module }

fn parse_single(text : String) -> Bool {
  match wast_to_module(text, filename="sample.wat") {
    Ok(_) => true
    Err(_) => false
  }
}
```

#### `module_to_wast`

```mbt
pub fn module_to_wast(mod : Module) -> Result[String, String]
```

Prints a `Module` as WAST/WAT text.

```mbt
using @lib { type Module }
using @wast { module_to_wast }

fn print_module(mod : Module) -> Result[String, String] {
  module_to_wast(mod)
}
```

#### `module_to_wast_with_context`

```mbt
pub fn module_to_wast_with_context(
  mod : Module,
  ctx : PrettyPrintContext,
) -> Result[String, String]
```

Same as `module_to_wast`, but with explicit pretty-print context controls.

```mbt
using @lib { type Module, PrettyPrintContext }
using @wast { module_to_wast_with_context }

fn print_with_ctx(mod : Module, ctx : PrettyPrintContext) -> Result[String, String] {
  module_to_wast_with_context(mod, ctx)
}
```

#### `wast_to_script`

```mbt
pub fn wast_to_script(
  text : String,
  filename? : String,
) -> Result[WastScript, String]
```

Parses script-style WAST text (`assert_*`, module/script forms) into an AST.

```mbt
using @wast { wast_to_script }

fn parse_script(text : String) -> Bool {
  match wast_to_script(text, filename="suite.wast") {
    Ok(_) => true
    Err(_) => false
  }
}
```

#### `script_to_wast`

```mbt
pub fn script_to_wast(script : WastScript) -> Result[String, String]
```

Prints script AST back to WAST text.

```mbt
using @wast { script_to_wast, wast_to_script }

fn roundtrip_script(text : String) -> Result[String, String] {
  match wast_to_script(text, filename="in.wast") {
    Ok(script) => script_to_wast(script)
    Err(e) => Err(e)
  }
}
```

#### `script_to_wast_with_context`

```mbt
pub fn script_to_wast_with_context(
  script : WastScript,
  ctx : PrettyPrintContext,
) -> Result[String, String]
```

Script printer with explicit pretty-print context.

```mbt
using @lib { PrettyPrintContext }
using @wast { script_to_wast_with_context, wast_to_script }

fn pretty_script(text : String, ctx : PrettyPrintContext) -> Result[String, String] {
  match wast_to_script(text, filename="ctx.wast") {
    Ok(script) => script_to_wast_with_context(script, ctx)
    Err(e) => Err(e)
  }
}
```

### `jtenner/starshine/ir`

#### `CFG::build`

```mbt
pub fn CFG::build(body : TExpr) -> CFG
```

Builds control-flow graph form from typed instruction trees.

```mbt
using @ir { CFG }
using @lib { TExpr, TInstr }

fn make_cfg() -> CFG {
  let body = TExpr::new([TInstr::nop()])
  CFG::build(body)
}
```

#### `CFG::to_ssa`

```mbt
pub fn CFG::to_ssa(
  self : CFG,
  idom : Map[BlockId, BlockId],
  df : Map[BlockId, Set[BlockId]],
  param_count : Int,
) -> SSACFG
```

Converts CFG to SSA form using dominator and dominance-frontier inputs plus function parameter count.

```mbt
using @ir { CFG }
using @lib { TExpr, TInstr }

fn cfg_to_ssa_example() -> SSACFG {
  let cfg = CFG::build(TExpr::new([TInstr::nop()]))
  let idom = cfg.dominators()
  let df = cfg.dominance_frontier()
  cfg.to_ssa(idom, df, 0)
}
```

#### `SSACFG::to_cfg`

```mbt
pub fn SSACFG::to_cfg(self : SSACFG, next_local : Int) -> CFG
```

Lowers SSA form back to CFG (typically after optimization passes).

```mbt
using @ir { CFG }
using @lib { TExpr, TInstr }

fn lower_back() -> CFG {
  let cfg = CFG::build(TExpr::new([TInstr::nop()]))
  let ssa = cfg.to_ssa(cfg.dominators(), cfg.dominance_frontier(), 0)
  ssa.to_cfg(0)
}
```

#### `SSACFG::build_use_def`

```mbt
pub fn SSACFG::build_use_def(self : SSACFG) -> UseDefInfo
```

Builds SSA use-def chains for downstream analysis/rewrites.

```mbt
using @ir { CFG }
using @lib { TExpr, TInstr }

fn usedef_info() -> UseDefInfo {
  let cfg = CFG::build(TExpr::new([TInstr::nop()]))
  let ssa = cfg.to_ssa(cfg.dominators(), cfg.dominance_frontier(), 0)
  ssa.build_use_def()
}
```

#### `SSACFG::compute_liveness`

```mbt
pub fn SSACFG::compute_liveness(self : SSACFG) -> LivenessInfo
```

Computes block-level live-in/live-out sets for SSA values.

```mbt
using @ir { CFG }
using @lib { TExpr, TInstr }

fn liveness_info() -> LivenessInfo {
  let cfg = CFG::build(TExpr::new([TInstr::nop()]))
  let ssa = cfg.to_ssa(cfg.dominators(), cfg.dominance_frontier(), 0)
  ssa.compute_liveness()
}
```

#### `SSACFG::optimize`

```mbt
pub fn SSACFG::optimize(self : SSACFG) -> SSACFG
```

Runs SSA-level optimization routines on an SSA graph.

```mbt
using @ir { CFG }
using @lib { TExpr, TInstr }

fn optimize_ssa_graph() -> SSACFG {
  let cfg = CFG::build(TExpr::new([TInstr::nop()]))
  let ssa = cfg.to_ssa(cfg.dominators(), cfg.dominance_frontier(), 0)
  ssa.optimize()
}
```

#### `run_gvn`

```mbt
pub fn run_gvn(ssa : SSACFG, idom : Map[BlockId, BlockId]) -> SSACFG
```

Runs global value numbering over SSA using immediate-dominator structure.

```mbt
using @ir { CFG, run_gvn }
using @lib { TExpr, TInstr }

fn gvn_once() -> SSACFG {
  let cfg = CFG::build(TExpr::new([TInstr::nop()]))
  let idom = cfg.dominators()
  let ssa = cfg.to_ssa(idom, cfg.dominance_frontier(), 0)
  run_gvn(ssa, idom)
}
```

#### `infer_ssa_types`

```mbt
pub fn infer_ssa_types(ssa : SSACFG, ctx : TypeContext) -> SSATypeInfo
```

Infers SSA value types from operations and module type context.

```mbt
using @ir { infer_ssa_types, IRContext }

fn infer_types_with_ctx(irctx : IRContext) -> Result[SSATypeInfo, String] {
  let ssa = irctx.get_ssa()
  match irctx.get_type_ctx() {
    Ok(type_ctx) => Ok(infer_ssa_types(ssa, type_ctx))
    Err(e) => Err(e)
  }
}
```

### `jtenner/starshine/transformer`

#### `ModuleTransformer::new`

```mbt
pub fn[T] ModuleTransformer::new() -> ModuleTransformer[T]
```

Creates an empty transformer with no hooks installed.

```mbt
using @transformer { ModuleTransformer }

fn empty_transformer() -> ModuleTransformer[Int] {
  ModuleTransformer::new()
}
```

#### `change`

```mbt
pub fn[T, Elem] change(t : T, elem : Elem) -> Result[(T, Elem)?, String]
```

Helper return for hook callbacks that changed the current node.

```mbt
using @transformer { change, type TransformerResult }
using @lib { TInstr }

fn replace_nop(instr : TInstr) -> TransformerResult[Unit, TInstr] {
  change((), instr)
}
```

#### `unchanged`

```mbt
pub fn[T, Elem] unchanged() -> Result[(T, Elem)?, String]
```

Helper return for hook callbacks when no rewrite is needed.

```mbt
using @transformer { unchanged, type TransformerResult }
using @lib { TInstr }

fn keep(instr : TInstr) -> TransformerResult[Unit, TInstr] {
  ignore(instr)
  unchanged()
}
```

#### `error`

```mbt
pub fn[T, Elem] error(msg : String) -> Result[(T, Elem)?, String]
```

Helper return for hook callbacks that fail with a diagnostic.

```mbt
using @transformer { error, type TransformerResult }
using @lib { TInstr }

fn reject(instr : TInstr) -> TransformerResult[Unit, TInstr] {
  ignore(instr)
  error("unsupported instruction")
}
```

#### `ModuleTransformer::on_tinstruction_evt`

```mbt
pub fn[T] ModuleTransformer::on_tinstruction_evt(
  self : ModuleTransformer[T],
  cb : (ModuleTransformer[T], T, TInstr) -> Result[(T, TInstr)?, String],
) -> ModuleTransformer[T]
```

Registers a typed-instruction event hook used for local rewrites and analyses.

```mbt
using @transformer { ModuleTransformer, change, unchanged }
using @lib { TInstr }

fn drop_nop_hook() -> ModuleTransformer[Unit] {
  ModuleTransformer::new().on_tinstruction_evt(fn(_, t, instr) {
    match instr {
      TNop => change(t, TInstr::unreachable_())
      _ => unchanged()
    }
  })
}
```

#### `ModuleTransformer::walk_tinstruction`

```mbt
pub fn[T] ModuleTransformer::walk_tinstruction(
  self : ModuleTransformer[T],
  t : T,
  instr : TInstr,
) -> Result[(T, TInstr)?, String]
```

Runs a transformer (including default traversal + hooks) over one typed instruction tree.

```mbt
using @transformer { ModuleTransformer, unchanged }
using @lib { TInstr }

fn walk_one(instr : TInstr) -> Result[TInstr, String] {
  let tr = ModuleTransformer::new().on_tinstruction_evt(fn(self, t, i) {
    self.walk_tinstruction_default(t, i)
  })
  match tr.walk_tinstruction((), instr) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(instr)
    Err(e) => Err(e)
  }
}
```

#### `ModuleTransformer::walk_module`

```mbt
pub fn[T] ModuleTransformer::walk_module(
  self : ModuleTransformer[T],
  t : T,
  mod : Module,
) -> Result[(T, Module)?, String]
```

Runs full-module traversal and returns rewritten module/state when a change occurs.

```mbt
using @transformer { ModuleTransformer }
using @lib { type Module }

fn visit_module(mod : Module) -> Result[Module, String] {
  let tr = ModuleTransformer::new()
  match tr.walk_module((), mod) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(mod)
    Err(e) => Err(e)
  }
}
```

## Pass Registry (Implemented `ModulePass` Variants)

The following list is the current implemented `ModulePass` registry in `src/passes/optimize.mbt`.

### IR Canonicalization and Local Cleanup

#### `AlignmentLowering`
Normalizes load/store (including atomic forms) alignment fields to legal/effective values so downstream optimizers can assume canonical memory access alignment.

#### `AvoidReinterprets`
Reduces problematic reinterpret-heavy instruction patterns into forms that are easier for canonical IR optimizations to reason about and fold.

#### `CoalesceLocals`
Coalesces equivalent local value flows and removes redundant local traffic when dataflow proves values can share storage safely.

#### `CodeFolding`
Performs local tree folding on typed IR to reduce expression size, remove duplicated shape, and simplify control/data instruction forms.

#### `CodePushing`
Pushes computation closer to real use sites (for example into branch arms) when safe, which can reduce temporary locals and expose additional fold opportunities.

#### `ConstHoisting`
Detects repeated literal materializations and hoists reusable constants to reduce repeated constant construction.

#### `DataflowOptimization`
Runs SSA-based optimization through `IRContext` (`CFG -> SSA -> optimization -> back`) and applies profitable transformed bodies.

#### `DeadCodeElimination`
Removes typed instructions that have no observable effects and are not needed for control/value flow.

#### `LocalCSE`
Performs local common subexpression elimination with explicit effect-invalidation tracking (memory, globals, calls, traps, control flow).

#### `LoopInvariantCodeMotion`
Hoists loop-invariant expressions out of loop bodies when side effects and trap behavior allow equivalent execution ordering.

#### `MergeBlocks`
Compacts nested/adjacent block structures and rewrites equivalent control trees into shorter structured forms.

#### `MergeLocals`
Merges compatible locals and rewrites local usage to reduce local count and local-section/code-size overhead.

#### `OptimizeAddedConstants`
Optimizes additive constant patterns (especially address math style chains) without propagation mode.

#### `OptimizeAddedConstantsPropagate`
Same family as `OptimizeAddedConstants`, with additional propagation behavior for deeper simplification opportunities.

#### `OptimizeInstructions`
Main peephole/algebraic simplifier for typed instructions; rewrites many canonical idioms into cheaper equivalent forms.

#### `Precompute`
Evaluates pure constant expressions ahead of time to remove runtime computation.

#### `PrecomputePropagate`
`Precompute` with additional propagation steps to push constant knowledge through more IR uses.

#### `RedundantSetElimination`
Removes local/global set patterns where written values are overwritten or never read.

#### `PickLoadSigns`
Chooses signed vs unsigned load forms that reduce later extend/cast operations while preserving semantics.

#### `RemoveUnusedBrs`
Eliminates unnecessary branch instructions and rewrites surrounding structure when branch targets/results are unused.

#### `RemoveUnusedNames`
Removes unneeded branch/label naming artifacts and fixes depth-indexed control references accordingly.

#### `SimplifyLocals`
Full simplify-locals mode: sinks sets to use sites, performs structural rewrites (`if`/`block`/`loop` value forms), and cleans dead/equivalent local traffic iteratively.

#### `SimplifyLocalsNoTee`
`SimplifyLocals` variant that avoids introducing/retaining tee-oriented forms.

#### `SimplifyLocalsNoStructure`
`SimplifyLocals` variant that disables structural control reshaping and focuses on local dataflow simplification.

#### `SimplifyLocalsNoTeeNoStructure`
Combines the `NoTee` and `NoStructure` restrictions.

#### `SimplifyLocalsNoNesting`
Most conservative simplify-locals variant: avoids tee usage and nested structural formation.

#### `Untee`
Lowers `local.tee` into explicit set/get block structure to simplify follow-up passes that prefer non-tee canonical form.

#### `Vacuum`
General cleanup pass that removes dead wrappers, simplifies constant/unreachable branches, compacts blocks, canonicalizes drops, and strips throw-free `try_table` shells.

#### `ReorderLocals`
Keeps parameters fixed, reorders non-param locals by use profile/first-use, and drops trailing unused locals with index remapping.

### Global, Type, and Reference Optimization

#### `AbstractTypeRefining`
Parameters:
- `traps_never_happen : Bool`: enables more aggressive abstract-heap-type normalization when trap-behavior constraints allow.

Refines abstract heap typing relationships and cast/test forms to tighter safe representations while preserving runtime cast/trap semantics.

#### `ConstantFieldPropagation`
Propagates known constant struct/array field values through typed IR/global flows when reads can be proven to observe those constants.

#### `GlobalRefining`
Refines global usage and (where legal) global value typing to reduce dynamic checks and enable stronger downstream simplifications.

#### `GlobalStructInference`
Infers more precise struct/array target information from module-wide usage and rewrites compatible operations to exploit refined heap types.

#### `GlobalStructInferenceDescCast`
Descriptor-aware global-struct inference mode; adds descriptor-cast-based rewriting paths (including conservative singleton/global opportunities) where safe.

#### `GlobalTypeOptimization`
Whole-module global/type optimization stage that coordinates global inference/refinement with section/type rewrite updates.

#### `SimplifyGlobals`
Iterative global simplification pass: removes dead writes, prefers immutable-copy patterns, and propagates constant globals into inits/typed bodies when observable behavior is preserved.

#### `SimplifyGlobalsOptimizing`
`SimplifyGlobals` followed by additional cleanup (`OptimizeInstructions`, `DeadCodeElimination`, `CodeFolding`) for better fixed-point quality.

#### `PropagateGlobalsGlobally`
Pushes globally-known immutable values across function boundaries where visibility and side-effect constraints allow.

#### `TypeRefining`
Refines function-local and direct-call parameter typing with Binaryen-style fixup-local handling when refined params are assigned less-specific values.

#### `SignaturePruning`
Closed-world signature transform that removes uniformly unused/constant parameters across functions sharing the same signature and rewrites call/call_ref sites.

#### `SignatureRefining`
Closed-world signature refinement pass for parameter/result types based on callsite/body evidence; rewrites affected function bodies and shared signature users.

#### `LocalSubtyping`
Infers tighter local supertypes/subtypes from set/get value flows and rewrites local declarations/uses when subtype-safe.

#### `OptimizeCasts`
Simplifies cast/test chains (`ref.cast`, `ref.test`, `ref.as_non_null`, descriptor-eq variants) with type/effect-safe rewrites.

#### `MinimizeRecGroups`
Canonicalizes and minimizes GC recursion group structure/order for compact, stable type encoding while preserving external/public type contracts.

#### `ReorderTypes`
Reorders private members inside recursion groups using dependency-aware cost modeling to reduce encoded type-index size.

#### `ReorderGlobals`
Reorders defined globals by usage/dependency constraints and remaps global indices module-wide.

#### `ReorderGlobalsAlways`
Always-on `ReorderGlobals` variant with smooth per-index cost weighting so reordering still occurs in small/global-light modules.

#### `RemoveUnusedTypes`
Rebuilds `type_sec` from reachable roots plus transitive references, then rewrites all type/heap-type users to compact surviving indices.

### Heap and GC-Sensitive Passes

#### `Heap2Local`
Promotes eligible heap object usage patterns to local variable form (including descriptor-op-aware paths), reducing heap traffic where alias/effect safety holds.

#### `HeapStoreOptimization`
Eliminates or rewrites redundant heap stores/loads under conservative alias/effect rules, including atomics-aware invalidation handling.

#### `GUFA`
Runs GUFA heap/reference flow analysis and applies corresponding simplifications in conservative mode.

#### `GUFAOptimizing`
Runs `GUFA` then immediate cleanup (`DeadCodeElimination` + `CodeFolding`) for stronger post-analysis reduction.

#### `GUFACastAll`
GUFA variant with aggressive cast-oriented rewriting mode enabled.

### Whole-Module and Callgraph Passes

#### `DeadArgumentElimination`
Removes dead function parameters and rewrites direct callers/locals/signature usage accordingly.

#### `DuplicateImportElimination`
Merges duplicate imports with equivalent external contracts and remaps dependent indices/usages.

#### `DuplicateFunctionElimination`
Detects and merges equivalent functions (guided by options), then remaps callsites to retained definitions.

#### `Directize`
Parameters:
- `initial_immutable : Bool`: whether table initial contents should be treated as immutable during indirect-call analysis.

Rewrites `call_indirect`/select-table forms to direct calls or known traps when target resolution is provably static.

#### `Inlining`
Runs inlining with configured thresholds from `OptimizeOptions.inlining`.

#### `InliningOptimizing`
Inlining mode tuned for additional optimization opportunities (more aggressive action planning and follow-up interaction).

#### `InlineMain`
Specialized inlining mode focused on entry/main-like function expansion.

#### `MergeSimilarFunctions`
Hashes and compares function bodies to merge structurally equivalent implementations.

#### `Monomorphize`
Context-sensitive specialization mode gated by `OptimizeOptions.monomorphize_min_benefit`.

#### `MonomorphizeAlways`
Always-on monomorphization variant (ignores benefit threshold gate).

#### `OnceReduction`
Reduces one-time initialization patterns and related guard logic when single-execution behavior can be proven.

#### `ReorderFunctions`
Reorders defined functions by usage profile (including direct calls and section references) and remaps `FuncIdx` users.

#### `ReorderFunctionsByName`
Name-based reorder mode; currently preserves existing order because this IR model does not retain symbolic function names in `Func` bodies.

#### `RemoveUnused`
Closed-world removal of unused functions/types/globals/tables/elements/data/tags with full index remapping.

#### `RemoveUnusedModuleElements`
Open-world-friendly pruning mode that keeps function reachability conservative while removing unused non-function elements.

#### `RemoveUnusedNonFunctionElements`
Legacy alias for `RemoveUnusedModuleElements`; kept for compatibility.

### Lowering, Runtime, and Memory Transformation

#### `Asyncify`
Parameters:
- `imports : Array[String]`: import patterns treated as async roots.
- `ignore_imports : Bool`: skip import-based async root inference.
- `ignore_indirect : Bool`: disable indirect-call propagation.
- `asserts : Bool`: insert unwind/rewind correctness assertions.
- `ignore_unwind_from_catch : Bool`: relax unwind-correctness behavior around catch regions.
- `verbose : Bool`: enable extra diagnostics.
- `memory : String?`: named memory selection override.
- `removelist : Array[String]`: explicit exclusion patterns.
- `addlist : Array[String]`: explicit inclusion patterns.
- `propagate_addlist : Bool`: propagate addlist marks through callgraph.
- `onlylist : Array[String]`: strict inclusion list.
- `import_globals : Bool`: use imported asyncify state/data globals.
- `export_globals : Bool`: export generated asyncify globals.
- `in_secondary_memory : Bool`: use secondary memory configuration.
- `secondary_memory_size : UInt64`: stack region size for secondary memory mode.

Transforms synchronous call stacks into async unwind/rewind state machine form, generating and wiring runtime helpers/globals and rewriting asyncify intrinsic imports.

#### `MemoryPacking`
Parameters:
- `zero_filled_memory : Bool`: assume/default-enable zero-fill behavior where legal.
- `traps_never_happen : Bool`: allow trap-based assumptions for more aggressive packing.
- `max_data_segments : Int`: cap for segment splitting/rewrite expansion.

Rewrites data segments and their users (`memory.init`, `data.drop`, segment refs) for denser layout and updates data-count/index mappings consistently.

#### `I64ToI32Lowering`
Lowers i64-oriented ABI/storage patterns into i32-pair style representations for targets/configurations that need it.

#### `DeNaN`
Canonicalizes NaN-producing floating behavior toward deterministic forms useful for reproducibility and binary-size/optimization interaction.

## Additional Usage Cookbook

### Optimize package examples

#### Build a two-stage canonical pipeline

```mbt
using @lib { type Module }
using @passes {
  optimize_module,
  ModulePass,
}

fn canonical_opt(mod : Module) -> Result[Module, String] {
  optimize_module(mod, [
    ModulePass::SimplifyLocals,
    ModulePass::Vacuum,
    ModulePass::OptimizeInstructions,
    ModulePass::RedundantSetElimination,
    ModulePass::Vacuum,
  ])
}
```

#### Run global pre-passes then function passes

```mbt
using @lib { type Module }
using @passes {
  default_global_optimization_pre_passes,
  default_function_optimization_passes,
  optimize_module_with_options,
  OptimizeOptions,
}

fn full_default_pipeline(mod : Module) -> Result[Module, String] {
  let options : OptimizeOptions = {
    optimize_level: 3,
    shrink_level: 0,
    inlining: {
      always_inline_max_size: 2,
      one_caller_inline_max_size: -1,
      flexible_inline_max_size: 20,
      max_combined_binary_size: 400 * 1024,
      allow_functions_with_loops: false,
      partial_inlining_ifs: 0,
    },
    monomorphize_min_benefit: 5,
    low_memory_unused: false,
    low_memory_bound: 1024UL,
  }

  let pre = default_global_optimization_pre_passes(mod, options)
  let post = default_function_optimization_passes(mod, options)
  let passes = pre + post
  optimize_module_with_options(mod, passes, options)
}
```

#### Asyncify with imported state/data globals

```mbt
using @lib { type Module }
using @passes {
  optimize_module,
  ModulePass,
  AsyncifyPassProps,
}

fn run_asyncify(mod : Module) -> Result[Module, String] {
  let props : AsyncifyPassProps = {
    imports: ["env.sleep"],
    ignore_imports: false,
    ignore_indirect: false,
    asserts: true,
    ignore_unwind_from_catch: false,
    verbose: false,
    memory: None,
    removelist: [],
    addlist: [],
    propagate_addlist: false,
    onlylist: [],
    import_globals: true,
    export_globals: false,
    in_secondary_memory: false,
    secondary_memory_size: 1024UL,
  }
  optimize_module(mod, [ModulePass::Asyncify(props)])
}
```

#### Memory packing with custom limits

```mbt
using @lib { type Module }
using @passes {
  optimize_module,
  ModulePass,
  MemoryPackingPassProps,
}

fn run_memory_packing(mod : Module) -> Result[Module, String] {
  let props : MemoryPackingPassProps = {
    zero_filled_memory: true,
    traps_never_happen: false,
    max_data_segments: 200000,
  }
  optimize_module(mod, [ModulePass::MemoryPacking(props)])
}
```

#### Directize indirect calls with immutable initial table assumption

```mbt
using @lib { type Module }
using @passes { optimize_module, ModulePass }

fn run_directize(mod : Module) -> Result[Module, String] {
  optimize_module(mod, [ModulePass::Directize(true)])
}
```

### Validate package examples

#### Validate then optimize

```mbt
using @lib { type Module }
using @validate { validate_module }
using @passes { optimize_module, ModulePass }

fn validate_then_opt(mod : Module) -> Result[Module, String] {
  match validate_module(mod) {
    Ok(()) => optimize_module(mod, [ModulePass::Vacuum])
    Err(e) => Err("invalid module: " + e)
  }
}
```

#### Convert function body to typed IR before analysis

```mbt
using @lib { Expr, Instruction }
using @validate { Env, to_texpr }

fn typed_expr_example() -> Result[TExpr, String] {
  let env = Env::new()
  let expr = Expr::new([
    Instruction::i32_const(I32(1)),
    Instruction::drop(),
  ])
  to_texpr(expr, env)
}
```

#### Descriptor compatibility check for tool diagnostics

```mbt
using @lib { RefType, HeapType, AbsHeapType }
using @validate { Env, descriptor_compatible }

fn check_descriptor_types() -> Bool {
  let env = Env::new()
  let lhs = RefType::new(false, HeapType::abs(AbsHeapType::struct_()))
  let rhs = RefType::new(true, HeapType::abs(AbsHeapType::eq()))
  descriptor_compatible(lhs, rhs, env)
}
```

#### Section-by-section validation pipeline

```mbt
using @lib { type Module }
using @validate {
  Env,
  validate_typesec,
  validate_importsec,
  validate_funcsec,
  validate_codesec,
}

fn validate_core_sections(mod : Module) -> Result[Unit, String] {
  let env0 = Env::new()
  let env1 = validate_typesec(mod.type_sec, env0)?
  let env2 = validate_importsec(mod.import_sec, env1)?
  let env3 = validate_funcsec(mod.func_sec, env2)?
  validate_codesec(mod.code_sec, mod.func_sec, env3)
}
```

### Binary package examples

#### Decode + validate + re-encode module bytes

```mbt
using @binary { trait Decode, trait Encode }
using @lib { type Module }
using @validate { validate_module }

fn checked_roundtrip(bytes : Bytes) -> Result[Bytes, String] {
  let (mod : Module, _next) = Decode::decode(bytes, 0)?
  validate_module(mod)?
  let out = @buffer.new()
  Encode::encode(mod, out)?
  Ok(out.to_bytes())
}
```

#### Decode from non-zero offset

```mbt
using @binary { trait Decode }
using @lib { type Module }

fn decode_after_prefix(bytes : Bytes, prefix : Int) -> Result[(Module, Int), String] {
  Decode::decode(bytes, prefix)
}
```

#### Encode a single instruction payload

```mbt
using @binary { trait Encode }
using @lib { Instruction }

fn encode_nop() -> Result[Bytes, String] {
  let buf = @buffer.new()
  Encode::encode(Instruction::nop(), buf)?
  Ok(buf.to_bytes())
}
```

#### Compute signed/unsigned LEB lengths

```mbt
using @binary { size_signed, size_unsigned }

fn leb_sizes() -> Result[(Int, Int), String] {
  let a = size_signed(-1L, 64)?
  let b = size_unsigned(624485UL, 64)?
  Ok((a, b))
}
```

#### Decode primitive value types directly

```mbt
using @binary { trait Decode }
using @lib { I32 }

fn decode_i32(bytes : Bytes, off : Int) -> Result[(I32, Int), String] {
  Decode::decode(bytes, off)
}
```

### WAST package examples

#### Parse and print a module text

```mbt
using @wast { wast_to_module, module_to_wast }

fn normalize_wat(text : String) -> Result[String, String] {
  let mod = wast_to_module(text, filename="in.wat")?
  module_to_wast(mod)
}
```

#### Parse script tests and print with context

```mbt
using @wast { wast_to_script, script_to_wast_with_context }
using @lib { PrettyPrintContext }

fn normalize_script(text : String, ctx : PrettyPrintContext) -> Result[String, String] {
  let script = wast_to_script(text, filename="suite.wast")?
  script_to_wast_with_context(script, ctx)
}
```

### IR package examples

#### Build CFG/SSA and run GVN

```mbt
using @ir { CFG, run_gvn }
using @lib { TExpr, TInstr }

fn optimize_body_once(body : TExpr) -> SSACFG {
  let cfg = CFG::build(body)
  let idom = cfg.dominators()
  let ssa = cfg.to_ssa(idom, cfg.dominance_frontier(), 0)
  run_gvn(ssa, idom)
}
```

#### Collect use-def and liveness

```mbt
using @ir { CFG }
using @lib { TExpr }

fn analyze(body : TExpr) -> (UseDefInfo, LivenessInfo) {
  let cfg = CFG::build(body)
  let ssa = cfg.to_ssa(cfg.dominators(), cfg.dominance_frontier(), 0)
  (ssa.build_use_def(), ssa.compute_liveness())
}
```

### Transformer package examples

#### Rewrite all `nop` instructions

```mbt
using @transformer { ModuleTransformer, change, unchanged }
using @lib { TInstr }

fn rewrite_nop(instr : TInstr) -> Result[TInstr, String] {
  let tr = ModuleTransformer::new().on_tinstruction_evt(fn(self, t, i) {
    let walked = match self.walk_tinstruction_default(t, i) {
      Ok(Some((t2, out))) => (t2, out)
      Ok(None) => (t, i)
      Err(e) => return Err(e)
    }
    let (_, out) = walked
    match out {
      TNop => change(t, TInstr::unreachable_())
      _ => unchanged()
    }
  })
  match tr.walk_tinstruction((), instr) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(instr)
    Err(e) => Err(e)
  }
}
```

## Local Development Checks
- `moon info && moon fmt`
- `moon check`
- `moon test`

## License
Project license: MIT.

Binaryen-derived pass implementations retain Apache-2.0 attribution labels at pass/file level.

## Attribution
Authored and maintained by Joshua Tenner with AI-assisted development support.
