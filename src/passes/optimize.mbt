///|
pub(all) enum ModulePass {
  AbstractTypeRefining(AbstractTypeRefiningPassProps)
  AlignmentLowering
  AvoidReinterprets
  CoalesceLocals
  CodeFolding
  CodePushing
  ConstHoisting
  ConstantFieldPropagation
  DataflowOptimization
  DeadCodeElimination
  DeadArgumentElimination
  SignaturePruning
  SignatureRefining
  DuplicateImportElimination
  GlobalRefining
  GlobalStructInference
  GlobalStructInferenceDescCast
  GlobalTypeOptimization
  SimplifyGlobals
  SimplifyGlobalsOptimizing
  PropagateGlobalsGlobally
  TypeRefining
  TypeGeneralizing
  Heap2Local
  HeapStoreOptimization
  Inlining
  InliningOptimizing
  InlineMain
  LocalCSE
  LocalSubtyping
  LoopInvariantCodeMotion
  MergeLocals
  MergeSimilarFunctions
  MergeBlocks
  Flatten
  TupleOptimization
  OnceReduction
  Asyncify(AsyncifyPassProps)
  MinimizeRecGroups
  Monomorphize
  MonomorphizeAlways
  MemoryPacking(MemoryPackingPassProps)
  OptimizeAddedConstants
  OptimizeAddedConstantsPropagate
  OptimizeInstructions
  Precompute
  PrecomputePropagate
  RedundantSetElimination
  PickLoadSigns
  GUFA
  GUFAOptimizing
  GUFACastAll
  I64ToI32Lowering
  DuplicateFunctionElimination
  Directize(Bool)
  OptimizeCasts
  DeNaN
  RemoveUnusedBrs
  RemoveUnusedNames
  SimplifyLocals
  SimplifyLocalsNoTee
  SimplifyLocalsNoStructure
  SimplifyLocalsNoTeeNoStructure
  SimplifyLocalsNoNesting
  Untee
  Vacuum
  ReorderLocals
  ReorderTypes
  ReorderGlobals
  ReorderGlobalsAlways
  ReorderFunctions
  ReorderFunctionsByName
  RemoveUnusedTypes
  RemoveUnused
  RemoveUnusedModuleElements
  RemoveUnusedNonFunctionElements
}

///|
pub struct InliningOptions {
  always_inline_max_size : Int
  one_caller_inline_max_size : Int
  flexible_inline_max_size : Int
  max_combined_binary_size : Int
  allow_functions_with_loops : Bool
  partial_inlining_ifs : Int
}

///|
fn InliningOptions::new(
  always_inline_max_size? : Int = 2,
  one_caller_inline_max_size? : Int = -1,
  flexible_inline_max_size? : Int = 20,
  max_combined_binary_size? : Int = 400 * 1024,
  allow_functions_with_loops? : Bool = false,
  partial_inlining_ifs? : Int = 0,
) -> InliningOptions {
  {
    always_inline_max_size,
    one_caller_inline_max_size,
    flexible_inline_max_size,
    max_combined_binary_size,
    allow_functions_with_loops,
    partial_inlining_ifs,
  }
}

///|
pub struct OptimizeOptions {
  optimize_level : Int
  shrink_level : Int
  inlining : InliningOptions
  monomorphize_min_benefit : Int
  low_memory_unused : Bool
  low_memory_bound : UInt64
}

///|
fn AbstractTypeRefiningPassProps::new(
  traps_never_happen? : Bool = false,
) -> AbstractTypeRefiningPassProps {
  { traps_never_happen, }
}

///|
fn OptimizeOptions::new(
  optimize_level? : Int = 0,
  shrink_level? : Int = 0,
  inlining? : InliningOptions = InliningOptions::new(),
  monomorphize_min_benefit? : Int = 5,
  low_memory_unused? : Bool = false,
  low_memory_bound? : UInt64 = 1024UL,
) -> OptimizeOptions {
  {
    optimize_level,
    shrink_level,
    inlining,
    monomorphize_min_benefit,
    low_memory_unused,
    low_memory_bound,
  }
}

///|
priv enum SchedulerPassContextKind {
  IRContextTransformerPass
  UnitTransformerPass
  ModuleRunnerPass
}

///|
fn[T] apply_transformer_pass(
  state : T,
  mod : Module,
  pass : ModuleTransformer[T],
) -> Result[Module, String] {
  match pass.walk_module(state, mod) {
    Ok(Some((_, new_mod))) => Ok(new_mod)
    Ok(None) => Ok(mod)
    Err(e) => Err(e)
  }
}

///|
fn apply_ir_transformer_pass(
  ctx : IRContext,
  mod : Module,
  pass : ModuleTransformer[IRContext],
) -> Result[Module, String] {
  apply_transformer_pass(ctx, mod, pass)
}

///|
fn apply_unit_transformer_pass(
  mod : Module,
  pass : ModuleTransformer[Unit],
) -> Result[Module, String] {
  apply_transformer_pass((), mod, pass)
}

///|
fn apply_module_runner_pass(
  mod : Module,
  runner : (Module) -> Result[Module, String],
) -> Result[Module, String] {
  runner(mod)
}

///|
fn module_pass_context_kind(pass : ModulePass) -> SchedulerPassContextKind {
  match pass {
    DeadCodeElimination => UnitTransformerPass
    SignatureRefining
    | DuplicateImportElimination
    | GlobalRefining
    | GlobalStructInference
    | GlobalStructInferenceDescCast
    | GlobalTypeOptimization
    | TypeRefining
    | TypeGeneralizing
    | Inlining
    | InliningOptimizing
    | InlineMain
    | LocalSubtyping
    | MergeSimilarFunctions
    | OnceReduction
    | Asyncify(_)
    | MinimizeRecGroups
    | Monomorphize
    | MonomorphizeAlways
    | MemoryPacking(_)
    | I64ToI32Lowering
    | DuplicateFunctionElimination
    | DeNaN
    | RemoveUnusedBrs
    | ReorderTypes
    | ReorderFunctions
    | ReorderFunctionsByName
    | RemoveUnusedTypes
    | RemoveUnused
    | RemoveUnusedModuleElements
    | RemoveUnusedNonFunctionElements => ModuleRunnerPass
    _ => IRContextTransformerPass
  }
}

///|
fn run_ir_context_transformer_scheduler_pass(
  ctx : IRContext,
  mod : Module,
  pass : ModulePass,
  options : OptimizeOptions,
) -> Result[Module, String] {
  match pass {
    AbstractTypeRefining(props) =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        abstract_type_refining(mod, props.traps_never_happen),
      )
    AlignmentLowering =>
      apply_ir_transformer_pass(ctx, mod, alignment_lowering_pass(mod))
    AvoidReinterprets =>
      apply_ir_transformer_pass(ctx, mod, avoid_reinterprets_pass(mod))
    CoalesceLocals =>
      apply_ir_transformer_pass(ctx, mod, coalesce_locals_pass(mod))
    CodeFolding =>
      apply_ir_transformer_pass(ctx, mod, code_folding_ir_pass(mod))
    CodePushing =>
      apply_ir_transformer_pass(ctx, mod, code_pushing_ir_pass(mod))
    ConstHoisting =>
      apply_ir_transformer_pass(ctx, mod, const_hoisting_ir_pass(mod))
    ConstantFieldPropagation =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        constant_field_propagation_ir_pass(mod),
      )
    DataflowOptimization =>
      apply_ir_transformer_pass(ctx, mod, dataflow_optimization_pass(mod))
    DeadArgumentElimination =>
      apply_ir_transformer_pass(ctx, mod, dead_argument_elim_pass(mod))
    SignaturePruning =>
      apply_ir_transformer_pass(ctx, mod, signature_pruning_ir_pass(mod))
    SimplifyGlobals =>
      apply_ir_transformer_pass(ctx, mod, simplify_globals_ir_pass(mod, false))
    SimplifyGlobalsOptimizing =>
      apply_ir_transformer_pass(ctx, mod, simplify_globals_ir_pass(mod, true))
    PropagateGlobalsGlobally =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        propagate_globals_globally_ir_pass(mod),
      )
    Heap2Local => apply_ir_transformer_pass(ctx, mod, heap2local_ir_pass(mod))
    HeapStoreOptimization =>
      apply_ir_transformer_pass(ctx, mod, heap_store_optimization_ir_pass(mod))
    LocalCSE =>
      apply_ir_transformer_pass(ctx, mod, local_cse_ir_pass(mod, options))
    LoopInvariantCodeMotion =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        loop_invariant_code_motion_ir_pass(mod),
      )
    MergeLocals =>
      apply_ir_transformer_pass(ctx, mod, merge_locals_ir_pass(mod, options~))
    MergeBlocks =>
      apply_ir_transformer_pass(ctx, mod, merge_blocks_ir_pass(mod, options~))
    Flatten => apply_ir_transformer_pass(ctx, mod, flatten_ir_pass(mod))
    TupleOptimization =>
      apply_ir_transformer_pass(ctx, mod, tuple_optimization_ir_pass(mod))
    OptimizeAddedConstants =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        optimize_added_constants_ir_pass(mod, options, false),
      )
    OptimizeAddedConstantsPropagate =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        optimize_added_constants_ir_pass(mod, options, true),
      )
    OptimizeInstructions =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        optimize_instructions_ir_pass(mod, options),
      )
    Precompute =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        precompute_ir_pass(mod, options, false),
      )
    PrecomputePropagate =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        precompute_ir_pass(mod, options, true),
      )
    RedundantSetElimination =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        redundant_set_elimination_ir_pass(mod),
      )
    PickLoadSigns =>
      apply_ir_transformer_pass(ctx, mod, pick_load_signs_ir_pass(mod))
    GUFA => apply_ir_transformer_pass(ctx, mod, gufa_ir_pass(mod, false))
    GUFAOptimizing =>
      match apply_ir_transformer_pass(ctx, mod, gufa_ir_pass(mod, false)) {
        Ok(gufa_mod) => {
          let after_dce = match
            apply_unit_transformer_pass(gufa_mod, dead_code_elimination_pass()) {
            Ok(new_mod) => new_mod
            Err(e) => return Err(e)
          }
          ctx.set_mod(after_dce)
          apply_ir_transformer_pass(
            ctx,
            after_dce,
            code_folding_ir_pass(after_dce),
          )
        }
        Err(e) => Err(e)
      }
    GUFACastAll => apply_ir_transformer_pass(ctx, mod, gufa_ir_pass(mod, true))
    Directize(initial_immutable) =>
      match directize_ir_pass(mod, initial_immutable) {
        Ok(ir_pass) => apply_ir_transformer_pass(ctx, mod, ir_pass)
        Err(e) => Err(e)
      }
    OptimizeCasts =>
      apply_ir_transformer_pass(ctx, mod, optimize_casts_ir_pass(mod))
    RemoveUnusedNames =>
      apply_ir_transformer_pass(ctx, mod, remove_unused_names_ir_pass(mod))
    SimplifyLocals =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        simplify_locals_ir_pass(mod, true, true, true),
      )
    SimplifyLocalsNoTee =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        simplify_locals_ir_pass(mod, false, true, true),
      )
    SimplifyLocalsNoStructure =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        simplify_locals_ir_pass(mod, true, false, true),
      )
    SimplifyLocalsNoTeeNoStructure =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        simplify_locals_ir_pass(mod, false, false, true),
      )
    SimplifyLocalsNoNesting =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        simplify_locals_ir_pass(mod, false, false, false),
      )
    Untee => apply_ir_transformer_pass(ctx, mod, untee_ir_pass(mod))
    Vacuum => apply_ir_transformer_pass(ctx, mod, vacuum_ir_pass(mod))
    ReorderLocals =>
      apply_ir_transformer_pass(ctx, mod, reorder_locals_ir_pass(mod))
    ReorderGlobals =>
      apply_ir_transformer_pass(ctx, mod, reorder_globals_ir_pass(mod, false))
    ReorderGlobalsAlways =>
      apply_ir_transformer_pass(ctx, mod, reorder_globals_ir_pass(mod, true))
    _ => Err("optimize scheduler bug: expected IRContext transformer pass")
  }
}

///|
fn run_unit_transformer_scheduler_pass(
  mod : Module,
  pass : ModulePass,
) -> Result[Module, String] {
  match pass {
    DeadCodeElimination =>
      apply_unit_transformer_pass(mod, dead_code_elimination_pass())
    _ => Err("optimize scheduler bug: expected Unit transformer pass")
  }
}

///|
fn run_module_runner_scheduler_pass(
  mod : Module,
  pass : ModulePass,
  options : OptimizeOptions,
) -> Result[Module, String] {
  match pass {
    SignatureRefining =>
      apply_module_runner_pass(mod, fn(mod) { signature_refining(mod) })
    DuplicateImportElimination =>
      apply_module_runner_pass(mod, fn(mod) {
        duplicate_import_elimination(mod)
      })
    GlobalRefining =>
      apply_module_runner_pass(mod, fn(mod) { global_refining(mod) })
    GlobalStructInference =>
      apply_module_runner_pass(mod, fn(mod) {
        run_global_struct_inference(mod, false)
      })
    GlobalStructInferenceDescCast =>
      apply_module_runner_pass(mod, fn(mod) {
        run_global_struct_inference(mod, true)
      })
    GlobalTypeOptimization =>
      apply_module_runner_pass(mod, fn(mod) { global_type_optimization(mod) })
    TypeRefining =>
      apply_module_runner_pass(mod, fn(mod) { type_refining(mod) })
    TypeGeneralizing =>
      apply_module_runner_pass(mod, fn(mod) { type_generalizing(mod) })
    Inlining =>
      apply_module_runner_pass(mod, fn(mod) { inlining(mod, options, false) })
    InliningOptimizing =>
      apply_module_runner_pass(mod, fn(mod) { inlining(mod, options, true) })
    InlineMain =>
      apply_module_runner_pass(mod, fn(mod) { inline_main(mod, options) })
    LocalSubtyping =>
      apply_module_runner_pass(mod, fn(mod) { local_subtyping(mod) })
    MergeSimilarFunctions =>
      apply_module_runner_pass(mod, fn(mod) { merge_similar_functions(mod) })
    OnceReduction =>
      apply_module_runner_pass(mod, fn(mod) { once_reduction(mod) })
    Asyncify(props) =>
      apply_module_runner_pass(mod, fn(mod) {
        asyncify(mod, props~, optimize_level=options.optimize_level)
      })
    MinimizeRecGroups =>
      apply_module_runner_pass(mod, fn(mod) { minimize_rec_groups(mod) })
    Monomorphize =>
      apply_module_runner_pass(mod, fn(mod) {
        monomorphize(mod, options~, always=false)
      })
    MonomorphizeAlways =>
      apply_module_runner_pass(mod, fn(mod) {
        monomorphize(mod, options~, always=true)
      })
    MemoryPacking(props) =>
      apply_module_runner_pass(mod, fn(mod) { memory_packing(mod, props) })
    I64ToI32Lowering =>
      apply_module_runner_pass(mod, fn(mod) { i64_to_i32_lowering(mod) })
    DuplicateFunctionElimination =>
      apply_module_runner_pass(mod, fn(mod) {
        duplicate_function_elimination(mod, options)
      })
    DeNaN => apply_module_runner_pass(mod, fn(mod) { run_denam(mod) })
    RemoveUnusedBrs =>
      apply_module_runner_pass(mod, fn(mod) { remove_unused_brs(mod, options~) })
    ReorderTypes =>
      apply_module_runner_pass(mod, fn(mod) { reorder_types(mod) })
    ReorderFunctions =>
      apply_module_runner_pass(mod, fn(mod) { reorder_functions(mod) })
    ReorderFunctionsByName =>
      apply_module_runner_pass(mod, fn(mod) { reorder_functions_by_name(mod) })
    RemoveUnusedTypes =>
      apply_module_runner_pass(mod, fn(mod) { remove_unused_types(mod) })
    RemoveUnused =>
      apply_module_runner_pass(mod, fn(mod) { remove_unused(mod) })
    RemoveUnusedModuleElements =>
      apply_module_runner_pass(mod, fn(mod) {
        remove_unused_non_function_elements(mod)
      })
    RemoveUnusedNonFunctionElements =>
      apply_module_runner_pass(mod, fn(mod) {
        remove_unused_non_function_elements(mod)
      })
    _ => Err("optimize scheduler bug: expected module-runner pass")
  }
}

///|
pub fn optimize_module(
  mod : Module,
  passes : Array[ModulePass],
) -> Result[Module, String] {
  optimize_module_with_options(mod, passes, OptimizeOptions::new())
}

///|
pub fn optimize_module_with_options(
  mod : Module,
  passes : Array[ModulePass],
  options : OptimizeOptions,
) -> Result[Module, String] {
  let mut mod = mod
  let ctx = IRContext::new()
  ctx.set_mod(mod)
  mod = match apply_unit_transformer_pass(mod, lift_to_texpr_pass()) {
    Ok(new_mod) => new_mod
    Err(e) => return Err(e)
  }
  ctx.set_mod(mod)
  for pass in passes {
    ctx.set_mod(mod)
    mod = match module_pass_context_kind(pass) {
      IRContextTransformerPass =>
        match
          run_ir_context_transformer_scheduler_pass(ctx, mod, pass, options) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      UnitTransformerPass =>
        match run_unit_transformer_scheduler_pass(mod, pass) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      ModuleRunnerPass =>
        match run_module_runner_scheduler_pass(mod, pass, options) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
    }
    ctx.set_mod(mod)
  }
  Ok(mod)
}

///|
fn default_opts_has_gc_aggregates(mod : Module) -> Bool {
  match mod.type_sec {
    Some(TypeSec(recs)) => {
      for rec in recs {
        match rec {
          SingleRecType(st) =>
            match st.get_comptype() {
              StructCompType(_) | ArrayCompType(_) => return true
              _ => ()
            }
          GroupRecType(sts) =>
            for st in sts {
              match st.get_comptype() {
                StructCompType(_) | ArrayCompType(_) => return true
                _ => ()
              }
            }
        }
      }
      false
    }
    None => false
  }
}

///|
fn default_opts_has_multivalue(mod : Module) -> Bool {
  match mod.type_sec {
    Some(TypeSec(recs)) => {
      for rec in recs {
        match rec {
          SingleRecType(st) =>
            match st.get_comptype() {
              FuncCompType(_, results) if results.length() > 1 => return true
              _ => ()
            }
          GroupRecType(sts) =>
            for st in sts {
              match st.get_comptype() {
                FuncCompType(_, results) if results.length() > 1 => return true
                _ => ()
              }
            }
        }
      }
      false
    }
    None => false
  }
}

///|
pub fn default_function_optimization_passes(
  mod : Module,
  options : OptimizeOptions,
) -> Array[ModulePass] {
  // Intentionally mirrors Binaryen's no-DWARF path.
  let has_gc = default_opts_has_gc_aggregates(mod)
  let has_multivalue = default_opts_has_multivalue(mod)
  let passes : Array[ModulePass] = []

  if options.optimize_level >= 3 || options.shrink_level >= 1 {
    // Binaryen parity mode: ssa-nomerge.
    // Fallback to SSA dataflow simplification in this IR pipeline.
    passes.push(DataflowOptimization)
  }
  if options.optimize_level >= 4 {
    // Binaryen parity mode: flatten.
    passes.push(Flatten)
    passes.push(LocalCSE)
    // Binaryen parity mode: rereloop.
    // Run an early structural merge step to re-canonicalize control flow.
    passes.push(MergeBlocks)
  }

  passes.push(DeadCodeElimination)
  passes.push(RemoveUnusedNames)
  passes.push(RemoveUnusedBrs)
  passes.push(RemoveUnusedNames)
  passes.push(OptimizeInstructions)
  if has_gc {
    passes.push(HeapStoreOptimization)
  }
  if options.optimize_level >= 2 || options.shrink_level >= 2 {
    passes.push(PickLoadSigns)
  }
  if options.optimize_level >= 3 || options.shrink_level >= 2 {
    passes.push(PrecomputePropagate)
  } else {
    passes.push(Precompute)
  }
  if options.low_memory_unused {
    if options.optimize_level >= 3 || options.shrink_level >= 1 {
      passes.push(OptimizeAddedConstantsPropagate)
    } else {
      passes.push(OptimizeAddedConstants)
    }
  }
  if options.optimize_level >= 2 || options.shrink_level >= 2 {
    passes.push(CodePushing)
  }
  if has_multivalue {
    // Binaryen parity mode: tuple-optimization.
    passes.push(TupleOptimization)
  }
  passes.push(SimplifyLocalsNoStructure)
  passes.push(Vacuum)
  passes.push(ReorderLocals)
  passes.push(RemoveUnusedBrs)
  if options.optimize_level > 1 && has_gc {
    passes.push(Heap2Local)
  }
  if options.optimize_level >= 3 || options.shrink_level >= 2 {
    passes.push(MergeLocals)
  }
  if options.optimize_level > 1 && has_gc {
    passes.push(OptimizeCasts)
    passes.push(LocalSubtyping)
  }
  passes.push(CoalesceLocals)
  if options.optimize_level >= 3 || options.shrink_level >= 1 {
    passes.push(LocalCSE)
  }
  passes.push(SimplifyLocals)
  passes.push(Vacuum)
  passes.push(ReorderLocals)
  passes.push(CoalesceLocals)
  passes.push(ReorderLocals)
  passes.push(Vacuum)
  if options.optimize_level >= 3 || options.shrink_level >= 1 {
    passes.push(CodeFolding)
  }
  passes.push(MergeBlocks)
  passes.push(RemoveUnusedBrs)
  passes.push(RemoveUnusedNames)
  passes.push(MergeBlocks)
  if options.optimize_level >= 3 || options.shrink_level >= 2 {
    passes.push(PrecomputePropagate)
  } else {
    passes.push(Precompute)
  }
  passes.push(OptimizeInstructions)
  if has_gc {
    passes.push(HeapStoreOptimization)
  }
  if options.optimize_level >= 2 || options.shrink_level >= 1 {
    passes.push(RedundantSetElimination)
  }
  passes.push(Vacuum)
  passes
}

///|
pub fn default_global_optimization_pre_passes(
  mod : Module,
  options : OptimizeOptions,
  closed_world? : Bool = true,
) -> Array[ModulePass] {
  // Intentionally mirrors Binaryen's no-DWARF path.
  let has_gc = default_opts_has_gc_aggregates(mod)
  let passes : Array[ModulePass] = []

  passes.push(DuplicateFunctionElimination)
  if options.optimize_level >= 2 {
    if closed_world {
      passes.push(RemoveUnused)
    } else {
      passes.push(RemoveUnusedModuleElements)
    }
  }
  passes.push(MemoryPacking(MemoryPackingPassProps::new()))
  if options.optimize_level >= 2 {
    passes.push(OnceReduction)
  }

  if has_gc && options.optimize_level >= 2 {
    if closed_world {
      passes.push(TypeRefining)
      passes.push(SignaturePruning)
      passes.push(SignatureRefining)
    }
    passes.push(GlobalRefining)
    if closed_world {
      passes.push(GlobalTypeOptimization)
    }
    if closed_world {
      passes.push(RemoveUnused)
    } else {
      passes.push(RemoveUnusedModuleElements)
    }
    if closed_world {
      passes.push(RemoveUnusedTypes)
      if options.optimize_level >= 3 {
        // Binaryen parity mode: cfp-reftest.
        // The current CFP implementation already handles ref.test patterns.
      }
      passes.push(ConstantFieldPropagation)
    }
    passes.push(GlobalStructInference)
    if closed_world {
      passes.push(
        AbstractTypeRefining(
          AbstractTypeRefiningPassProps::new(traps_never_happen=false),
        ),
      )
      // Binaryen parity mode: unsubtyping.
      // Use recursion-group minimization as the current conservative fallback.
      passes.push(MinimizeRecGroups)
    }
  }

  // Binaryen parity mode: generate-global-effects.
  // Use global propagation as the current conservative fallback.
  passes.push(PropagateGlobalsGlobally)
  passes
}

///|
fn default_count_module_passes(
  passes : Array[ModulePass],
  pred : (ModulePass) -> Bool,
) -> Int {
  let mut count = 0
  for pass in passes {
    if pred(pass) {
      count += 1
    }
  }
  count
}

///|
fn default_first_module_pass_index(
  passes : Array[ModulePass],
  pred : (ModulePass) -> Bool,
) -> Int {
  let mut idx = 0
  for pass in passes {
    if pred(pass) {
      return idx
    }
    idx += 1
  }
  -1
}

///|
fn opt_scheduler_remove_unused_dispatch_module() -> Module {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let keep_a = Func::t_func([], TExpr::new([TInstr::nop()]))
  let keep_b = Func::t_func([], TExpr::new([TInstr::nop()]))
  Module::new()
  .with_type_sec(TypeSec::new([t_void]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
  .with_code_sec(CodeSec::new([keep_a, keep_b]))
  .with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(ValType::i32(), false),
        Expr::new([Instruction::i32_const(I32(7))]),
      ),
    ]),
  )
}

///|
fn opt_scheduler_denan_dispatch_module() -> Module {
  let nan_bits : UInt = 0x7FC00000
  let nan = @lib.F32(Float::reinterpret_from_uint(nan_bits))
  Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], TExpr::new([TInstr::f32_const(nan)]))]),
  )
}

///|
fn opt_scheduler_type_generalizing_dispatch_module() -> Module {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  Module::new()
  .with_type_sec(TypeSec::new([t_void]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::ref_null(HeapType::new(TypeIdx::new(0)))],
        TExpr::new([TInstr::nop()]),
      ),
    ]),
  )
}

///|
fn opt_scheduler_func_count(mod : Module) -> Int {
  match mod.func_sec {
    Some(FuncSec(funcs)) => funcs.length()
    None => 0
  }
}

///|
fn opt_scheduler_global_count(mod : Module) -> Int {
  match mod.global_sec {
    Some(GlobalSec(globals)) => globals.length()
    None => 0
  }
}

///|
fn assert_pass_context_kind(
  pass : ModulePass,
  expected : SchedulerPassContextKind,
) -> Bool {
  match (module_pass_context_kind(pass), expected) {
    (IRContextTransformerPass, IRContextTransformerPass)
    | (UnitTransformerPass, UnitTransformerPass)
    | (ModuleRunnerPass, ModuleRunnerPass) => true
    _ => false
  }
}

///|
test "default function optimization passes gate low-level and gc-only passes" {
  let passes = default_function_optimization_passes(
    Module::new(),
    OptimizeOptions::new(),
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        Precompute => true
        _ => false
      }
    }),
    2,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        PrecomputePropagate => true
        _ => false
      }
    }),
    0,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        PickLoadSigns => true
        _ => false
      }
    }),
    0,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        HeapStoreOptimization => true
        _ => false
      }
    }),
    0,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        Vacuum => true
        _ => false
      }
    }),
    4,
  )
}

///|
test "default function optimization passes include propagate and gc passes when enabled" {
  let gc_mod = Module::new().with_type_sec(
    TypeSec::new([
      single_rec_type(
        comp_type_sub_type(
          struct_comp_type([
            FieldType::new(StorageType::val_type(ValType::i32()), Var),
          ]),
        ),
      ),
      single_rec_type(comp_type_sub_type(func_comp_type([], [ValType::i32()]))),
      single_rec_type(
        comp_type_sub_type(func_comp_type([], [ValType::i32(), ValType::i32()])),
      ),
    ]),
  )
  let options = OptimizeOptions::new(
    optimize_level=3,
    shrink_level=2,
    low_memory_unused=true,
  )
  let passes = default_function_optimization_passes(gc_mod, options)

  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        PrecomputePropagate => true
        _ => false
      }
    }),
    2,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        Precompute => true
        _ => false
      }
    }),
    0,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        OptimizeAddedConstantsPropagate => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        HeapStoreOptimization => true
        _ => false
      }
    }),
    2,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        Heap2Local => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        OptimizeCasts => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        LocalSubtyping => true
        _ => false
      }
    }),
    1,
  )
}

///|
test "default function optimization passes map ssa-nomerge mode to dataflow optimization" {
  let passes = default_function_optimization_passes(
    Module::new(),
    OptimizeOptions::new(optimize_level=3),
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        DataflowOptimization => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_first_module_pass_index(passes, fn(pass) {
      match pass {
        DataflowOptimization => true
        _ => false
      }
    }),
    0,
  )
}

///|
test "default function optimization passes map flatten mode at optimize_level=4" {
  let passes = default_function_optimization_passes(
    Module::new(),
    OptimizeOptions::new(optimize_level=4),
  )
  let flatten_idx = default_first_module_pass_index(passes, fn(pass) {
    match pass {
      Flatten => true
      _ => false
    }
  })
  let cse_idx = default_first_module_pass_index(passes, fn(pass) {
    match pass {
      LocalCSE => true
      _ => false
    }
  })
  assert_true(flatten_idx >= 0)
  assert_true(cse_idx >= 0)
  assert_true(flatten_idx < cse_idx)
}

///|
test "default function optimization passes map rereloop mode to early merge-blocks" {
  let passes = default_function_optimization_passes(
    Module::new(),
    OptimizeOptions::new(optimize_level=4),
  )
  let merge_idx = default_first_module_pass_index(passes, fn(pass) {
    match pass {
      MergeBlocks => true
      _ => false
    }
  })
  let dce_idx = default_first_module_pass_index(passes, fn(pass) {
    match pass {
      DeadCodeElimination => true
      _ => false
    }
  })
  assert_true(merge_idx >= 0)
  assert_true(dce_idx >= 0)
  assert_true(merge_idx < dce_idx)
}

///|
test "default function optimization passes map tuple-optimization mode for multivalue modules" {
  let multivalue_mod = Module::new().with_type_sec(
    TypeSec::new([
      single_rec_type(comp_type_sub_type(func_comp_type([], [ValType::i32()]))),
      single_rec_type(
        comp_type_sub_type(func_comp_type([], [ValType::i32(), ValType::i32()])),
      ),
    ]),
  )
  let passes = default_function_optimization_passes(
    multivalue_mod,
    OptimizeOptions::new(optimize_level=2),
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        TupleOptimization => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        DataflowOptimization => true
        _ => false
      }
    }),
    0,
  )
  let tuple_opt_idx = default_first_module_pass_index(passes, fn(pass) {
    match pass {
      TupleOptimization => true
      _ => false
    }
  })
  let simplify_no_structure_idx = default_first_module_pass_index(passes, fn(
    pass,
  ) {
    match pass {
      SimplifyLocalsNoStructure => true
      _ => false
    }
  })
  assert_true(tuple_opt_idx >= 0)
  assert_true(simplify_no_structure_idx >= 0)
  assert_true(tuple_opt_idx < simplify_no_structure_idx)
}

///|
test "default global optimization pre passes for non-gc module stay minimal" {
  let passes = default_global_optimization_pre_passes(
    Module::new(),
    OptimizeOptions::new(optimize_level=0),
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        DuplicateFunctionElimination => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        MemoryPacking(_) => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        RemoveUnused => true
        _ => false
      }
    }),
    0,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        OnceReduction => true
        _ => false
      }
    }),
    0,
  )
}

///|
test "default global optimization pre passes map cfp-reftest mode to constant field propagation" {
  let gc_mod = Module::new().with_type_sec(
    TypeSec::new([
      single_rec_type(
        comp_type_sub_type(
          struct_comp_type([
            FieldType::new(StorageType::val_type(ValType::i32()), Var),
          ]),
        ),
      ),
    ]),
  )
  let passes = default_global_optimization_pre_passes(
    gc_mod,
    OptimizeOptions::new(optimize_level=3),
  )
  let remove_unused_types_idx = default_first_module_pass_index(passes, fn(
    pass,
  ) {
    match pass {
      RemoveUnusedTypes => true
      _ => false
    }
  })
  let cfp_idx = default_first_module_pass_index(passes, fn(pass) {
    match pass {
      ConstantFieldPropagation => true
      _ => false
    }
  })
  assert_true(remove_unused_types_idx >= 0)
  assert_true(cfp_idx >= 0)
  assert_true(remove_unused_types_idx < cfp_idx)
}

///|
test "default global optimization pre passes map unsubtyping mode to minimize rec groups" {
  let gc_mod = Module::new().with_type_sec(
    TypeSec::new([
      single_rec_type(
        comp_type_sub_type(
          struct_comp_type([
            FieldType::new(StorageType::val_type(ValType::i32()), Var),
          ]),
        ),
      ),
    ]),
  )
  let passes = default_global_optimization_pre_passes(
    gc_mod,
    OptimizeOptions::new(optimize_level=2),
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        MinimizeRecGroups => true
        _ => false
      }
    }),
    1,
  )
  let abstract_idx = default_first_module_pass_index(passes, fn(pass) {
    match pass {
      AbstractTypeRefining(_) => true
      _ => false
    }
  })
  let unsubtyping_idx = default_first_module_pass_index(passes, fn(pass) {
    match pass {
      MinimizeRecGroups => true
      _ => false
    }
  })
  assert_true(abstract_idx >= 0)
  assert_true(unsubtyping_idx >= 0)
  assert_true(abstract_idx < unsubtyping_idx)
}

///|
test "default global optimization pre passes include generate-global-effects mode" {
  let passes = default_global_optimization_pre_passes(
    Module::new(),
    OptimizeOptions::new(optimize_level=0),
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        PropagateGlobalsGlobally => true
        _ => false
      }
    }),
    1,
  )
}

///|
test "default global optimization pre passes include closed-world gc passes" {
  let gc_mod = Module::new().with_type_sec(
    TypeSec::new([
      single_rec_type(
        comp_type_sub_type(
          struct_comp_type([
            FieldType::new(StorageType::val_type(ValType::i32()), Var),
          ]),
        ),
      ),
    ]),
  )
  let passes = default_global_optimization_pre_passes(
    gc_mod,
    OptimizeOptions::new(optimize_level=2),
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        RemoveUnused => true
        _ => false
      }
    }),
    2,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        TypeRefining => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        SignaturePruning => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        SignatureRefining => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        GlobalTypeOptimization => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        RemoveUnusedTypes => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        ConstantFieldPropagation => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        AbstractTypeRefining(_) => true
        _ => false
      }
    }),
    1,
  )
}

///|
test "default global optimization pre passes honor closed_world=false gating" {
  let gc_mod = Module::new().with_type_sec(
    TypeSec::new([
      single_rec_type(
        comp_type_sub_type(
          struct_comp_type([
            FieldType::new(StorageType::val_type(ValType::i32()), Var),
          ]),
        ),
      ),
    ]),
  )
  let passes = default_global_optimization_pre_passes(
    gc_mod,
    OptimizeOptions::new(optimize_level=2),
    closed_world=false,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        TypeRefining => true
        _ => false
      }
    }),
    0,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        SignaturePruning => true
        _ => false
      }
    }),
    0,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        SignatureRefining => true
        _ => false
      }
    }),
    0,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        GlobalTypeOptimization => true
        _ => false
      }
    }),
    0,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        RemoveUnusedModuleElements => true
        _ => false
      }
    }),
    2,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        RemoveUnusedNonFunctionElements => true
        _ => false
      }
    }),
    0,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        RemoveUnused => true
        _ => false
      }
    }),
    0,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        RemoveUnusedTypes => true
        _ => false
      }
    }),
    0,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        ConstantFieldPropagation => true
        _ => false
      }
    }),
    0,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        AbstractTypeRefining(_) => true
        _ => false
      }
    }),
    0,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        GlobalRefining => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        GlobalStructInference => true
        _ => false
      }
    }),
    1,
  )
}

///|
test "optimize scheduler classifies module pass context kinds" {
  assert_true(
    assert_pass_context_kind(RemoveUnusedNames, IRContextTransformerPass),
  )
  assert_true(assert_pass_context_kind(Flatten, IRContextTransformerPass))
  assert_true(
    assert_pass_context_kind(DeadCodeElimination, UnitTransformerPass),
  )
  assert_true(assert_pass_context_kind(DeNaN, ModuleRunnerPass))
  assert_true(assert_pass_context_kind(TypeGeneralizing, ModuleRunnerPass))
}

///|
test "optimize_module dispatches IRContext and Unit transformer pass kinds" {
  assert_true(
    assert_pass_context_kind(RemoveUnusedNames, IRContextTransformerPass),
  )
  assert_true(
    assert_pass_context_kind(DeadCodeElimination, UnitTransformerPass),
  )

  let ir_mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::block(
                BlockType::void_(),
                TExpr::new([TInstr::i32_const(I32(5))]),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )
  let ir_optimized = match optimize_module(ir_mod, [RemoveUnusedNames]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match ir_optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TBlock(_, TExpr([TI32Const(I32(5))]))]))])) =>
      ()
    _ => fail("expected RemoveUnusedNames to run through IRContext dispatch")
  }

  let unit_mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::unreachable_(),
          TInstr::drop(TInstr::i32_const(I32(1))),
        ]),
      ),
    ]),
  )
  let unit_optimized = match optimize_module(unit_mod, [DeadCodeElimination]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match unit_optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TUnreachable]))])) => ()
    _ => fail("expected DeadCodeElimination to run through Unit dispatch")
  }
}

///|
test "optimize_module dispatches DeNaN through module-runner kind" {
  assert_true(assert_pass_context_kind(DeNaN, ModuleRunnerPass))
  let mod = opt_scheduler_denan_dispatch_module()
  let optimized = match optimize_module(mod, [DeNaN]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TF32Const(F32(v))]))])) => assert_eq(v, 0.0)
    _ => fail("expected DeNaN to sanitize NaN constants via module-runner path")
  }
}

///|
test "optimize_module dispatches TypeGeneralizing through module-runner kind" {
  assert_true(assert_pass_context_kind(TypeGeneralizing, ModuleRunnerPass))
  let mod = opt_scheduler_type_generalizing_dispatch_module()
  let optimized = match optimize_module(mod, [TypeGeneralizing]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc([vt], _)])) => assert_eq(vt, ValType::funcref())
    _ => fail("expected TypeGeneralizing to run through module-runner dispatch")
  }
}

///|
test "optimize_module dispatches closed-world vs open-world remove_unused modes" {
  assert_true(assert_pass_context_kind(RemoveUnused, ModuleRunnerPass))
  assert_true(
    assert_pass_context_kind(RemoveUnusedModuleElements, ModuleRunnerPass),
  )
  assert_true(
    assert_pass_context_kind(RemoveUnusedNonFunctionElements, ModuleRunnerPass),
  )
  let mod = opt_scheduler_remove_unused_dispatch_module()
  let closed_world = match optimize_module(mod, [RemoveUnused]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  let open_world = match optimize_module(mod, [RemoveUnusedModuleElements]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  let open_world_legacy = match
    optimize_module(mod, [RemoveUnusedNonFunctionElements]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  assert_eq(opt_scheduler_func_count(closed_world), 0)
  assert_eq(opt_scheduler_global_count(closed_world), 0)
  assert_eq(opt_scheduler_func_count(open_world), 2)
  assert_eq(opt_scheduler_global_count(open_world), 0)
  assert_eq(opt_scheduler_func_count(open_world_legacy), 2)
  assert_eq(opt_scheduler_global_count(open_world_legacy), 0)
}

///|
test "optimize_module runs AvoidReinterprets pass" {
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::unary(
        UnaryOp::i32_reinterpret_f32(),
        TInstr::load(
          LoadOp::f32_load(),
          MemArg::new(0, None, 0),
          TInstr::i32_const(I32(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let optimized = match optimize_module(mod, [AvoidReinterprets]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  let CodeSec(funcs) = optimized.code_sec.unwrap()
  match funcs[0] {
    TFunc(_, TExpr(instrs)) =>
      match instrs[0] {
        TLoad(LoadOp::I32LoadOp, _, _) => ()
        _ => fail("expected reinterpret(load) to become i32.load")
      }
    _ => fail("expected TFunc")
  }
}

///|
test "optimize_module runs DeadArgumentElimination pass" {
  let caller = Func::t_func(
    [],
    TExpr::new([TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(9))])]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        single_rec_type(
          comp_type_sub_type(func_comp_type([ValType::i32()], [ValType::i32()])),
        ),
        single_rec_type(
          comp_type_sub_type(func_comp_type([], [ValType::i32()])),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = match optimize_module(mod, [DeadArgumentElimination]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr(instrs)), _])) => {
      let mut found = false
      for instr in instrs {
        match instr {
          TCall(_, args) => {
            found = true
            assert_eq(args.length(), 0)
          }
          _ => ()
        }
      }
      assert_true(found)
    }
    _ => fail("expected rewritten call")
  }
}

///|
test "optimize_module runs SignaturePruning pass" {
  let caller = Func::t_func(
    [],
    TExpr::new([TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(9))])]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        single_rec_type(
          comp_type_sub_type(func_comp_type([ValType::i32()], [ValType::i32()])),
        ),
        single_rec_type(
          comp_type_sub_type(func_comp_type([], [ValType::i32()])),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = match optimize_module(mod, [SignaturePruning]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr(instrs)), _])) => {
      let mut found = false
      for instr in instrs {
        match instr {
          TCall(_, args) => {
            found = true
            assert_eq(args.length(), 0)
          }
          _ => ()
        }
      }
      assert_true(found)
    }
    _ => fail("expected rewritten call")
  }
}

///|
test "optimize_module runs SignatureRefining pass" {
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        single_rec_type(
          comp_type_sub_type(func_comp_type([non_null_funcref], [])),
        ),
        single_rec_type(
          comp_type_sub_type(func_comp_type([nullable_funcref], [])),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = match optimize_module(mod, [SignatureRefining]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  let env = Env::new().with_module(optimized)
  let ft = match env.resolve_functype(TypeIdx::new(1)) {
    Some(ft) => ft
    None => fail("expected refined function type")
  }
  match ft {
    FuncType(params, _) => {
      assert_eq(params.length(), 1)
      assert_true(params[0] != nullable_funcref)
      assert_true(Match::matches(params[0], nullable_funcref, env))
    }
  }
}

///|
test "optimize_module runs TypeRefining pass" {
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::return_([])]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        single_rec_type(
          comp_type_sub_type(func_comp_type([non_null_funcref], [])),
        ),
        single_rec_type(
          comp_type_sub_type(func_comp_type([nullable_funcref], [])),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = match optimize_module(mod, [TypeRefining]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.func_sec {
    Some(FuncSec([_, TypeIdx(2)])) => ()
    _ => fail("expected callee to receive refined appended type")
  }
}

///|
test "optimize_module runs RemoveUnusedTypes pass" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        single_rec_type(comp_type_sub_type(func_comp_type([], []))),
        single_rec_type(comp_type_sub_type(struct_comp_type([]))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
    )
  let optimized = match optimize_module(mod, [RemoveUnusedTypes]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.type_sec {
    Some(TypeSec(recs)) => assert_eq(recs.length(), 1)
    None => fail("expected type section")
  }
}

///|
test "optimize_module runs DeadCodeElimination pass" {
  let func = Func::t_func(
    [],
    TExpr::new([TInstr::unreachable_(), TInstr::i32_const(I32(7))]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let optimized = match optimize_module(mod, [DeadCodeElimination]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TUnreachable]))])) => ()
    _ => fail("expected dead tail after unreachable to be removed")
  }
}

///|
test "optimize_module runs DuplicateFunctionElimination pass" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let root = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), []),
      TInstr::call(FuncIdx::new(2), []),
    ]),
  )
  let dup_a = Func::t_func([], TExpr::new([TInstr::nop()]))
  let dup_b = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(CodeSec::new([root, dup_a, dup_b]))
  let optimized = match optimize_module(mod, [DuplicateFunctionElimination]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
}

///|
test "optimize_module runs DuplicateImportElimination pass" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("foo"),
          ExternType::func(TypeIdx::new(0)),
        ),
        Import::new(
          Name::new("env"),
          Name::new("foo"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(1), [])])),
      ]),
    )
  let optimized = match optimize_module(mod, [DuplicateImportElimination]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.import_sec {
    Some(ImportSec(imps)) => assert_eq(imps.length(), 1)
    None => fail("expected import section")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCall(FuncIdx(i), [])]))])) =>
      assert_eq(i, 0U)
    _ => fail("expected call index remapped to canonical import")
  }
}

///|
test "optimize_module runs GlobalRefining pass" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::anyref(), false),
          Expr::new([Instruction::ref_func(FuncIdx::new(0))]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("g"), ExternIdx::global(GlobalIdx::new(0))),
      ]),
    )
    .with_code_sec(
      CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
    )
  let optimized = match optimize_module(mod, [GlobalRefining]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.global_sec {
    Some(GlobalSec([Global(GlobalType(vt, is_mut), _)])) => {
      assert_false(is_mut)
      assert_eq(
        vt,
        ValType::ref_type(RefType::new(false, HeapType::new(TypeIdx::new(0)))),
      )
    }
    _ => fail("expected one refined global")
  }
}

///|
test "optimize_module runs GlobalStructInference pass" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ty = single_rec_type(comp_type_sub_type(struct_comp_type([field])))
  let global_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(42)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [global_ref],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                U32(0),
                TInstr::local_get(LocalIdx::new(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match optimize_module(mod, [GlobalStructInference]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr(
              [
                TDrop(
                  TBlock(_, TExpr([TDrop(TRefAsNonNull(_)), TI32Const(I32(v))]))
                ),
              ]
            )
          ),
        ]
      )
    ) => assert_eq(v, 42)
    _ => fail("expected struct.get rewrite in pipeline")
  }
}

///|
test "optimize_module runs GlobalStructInferenceDescCast pass" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ty = single_rec_type(comp_type_sub_type(struct_comp_type([field])))
  let global_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(42)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [global_ref],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                U32(0),
                TInstr::local_get(LocalIdx::new(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match optimize_module(mod, [GlobalStructInferenceDescCast]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr(
              [
                TDrop(
                  TBlock(_, TExpr([TDrop(TRefAsNonNull(_)), TI32Const(I32(v))]))
                ),
              ]
            )
          ),
        ]
      )
    ) => assert_eq(v, 42)
    _ => fail("expected struct.get rewrite in desc-cast pipeline variant")
  }
}

///|
test "optimize_module GlobalStructInferenceDescCast rewrites ref.cast to ref.cast_desc_eq" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ty = single_rec_type(comp_type_sub_type(struct_comp_type([field])))
  let global_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(3)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::anyref()],
          TExpr::new([
            TInstr::drop(
              TInstr::ref_cast(
                false,
                HeapType::new(TypeIdx::new(0)),
                TInstr::local_get(LocalIdx::new(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match optimize_module(mod, [GlobalStructInferenceDescCast]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr([TDrop(TRefCastDescEq(false, HeapType(TypeIdx(i)), _))])
          ),
        ]
      )
    ) => assert_eq(i.reinterpret_as_int(), 0)
    _ => fail("expected ref.cast_desc_eq rewrite in desc-cast pipeline variant")
  }
}

///|
test "optimize_module GlobalStructInferenceDescCast rewrites ref.get_desc with select grouping" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let super_st = SubType::comp_type(struct_comp_type([field]))
  let sub_st = SubType::new(false, [TypeIdx::new(0)], struct_comp_type([field]))
  let super_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let sub_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(1))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([RecType::new(super_st), RecType::new(sub_st)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(sub_ref, false),
          Expr::new([
            Instruction::i32_const(I32(1)),
            Instruction::struct_new(TypeIdx::new(1)),
          ]),
        ),
        Global::new(
          GlobalType::new(super_ref, false),
          Expr::new([
            Instruction::i32_const(I32(2)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [super_ref],
          TExpr::new([
            TInstr::drop(
              TInstr::ref_get_desc(TInstr::local_get(LocalIdx::new(0))),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match optimize_module(mod, [GlobalStructInferenceDescCast]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr(
              [
                TDrop(
                  TSelect(
                    Some([NumTypeValType(I32NumType)]),
                    TRefEq(_, _),
                    TRefGetDesc(_),
                    TRefGetDesc(_)
                  )
                ),
              ]
            )
          ),
        ]
      )
    ) => ()
    _ =>
      fail("expected ref.get_desc select rewrite in desc-cast pipeline variant")
  }
}

///|
test "optimize_module runs GlobalTypeOptimization pass" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let func_type = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type, func_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                @lib.U32(1),
                TInstr::struct_new(TypeIdx::new(0), [
                  TInstr::i32_const(I32(11)),
                  TInstr::i32_const(I32(22)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match optimize_module(mod, [GlobalTypeOptimization]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.type_sec {
    Some(TypeSec([SingleRecType(st), _])) =>
      match st.get_comptype() {
        StructCompType(fields) => assert_eq(fields.length(), 1)
        _ => fail("expected optimized struct type")
      }
    _ => fail("expected type section")
  }
}

///|
test "optimize_module runs Heap2Local pass" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [local_ref],
          TExpr::new([
            TInstr::local_set(
              LocalIdx::new(0),
              TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
            ),
            TInstr::struct_set(
              TypeIdx::new(0),
              @lib.U32(0),
              TInstr::local_get(LocalIdx::new(0)),
              TInstr::i32_const(I32(3)),
            ),
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                @lib.U32(0),
                TInstr::local_get(LocalIdx::new(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match optimize_module(mod, [Heap2Local]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(h2l_count_gc_ops(body), 0)
    _ => fail("expected optimized function")
  }
}

///|
test "optimize_module runs HeapStoreOptimization pass" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [local_ref],
          TExpr::new([
            TInstr::local_set(
              LocalIdx::new(0),
              TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
            ),
            TInstr::struct_set(
              TypeIdx::new(0),
              @lib.U32(0),
              TInstr::local_get(LocalIdx::new(0)),
              TInstr::i32_const(I32(9)),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match optimize_module(mod, [HeapStoreOptimization]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(hso_count_struct_sets(body), 0)
    _ => fail("expected optimized function")
  }
}

///|
test "optimize_module runs PickLoadSigns pass" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(
        loc,
        TInstr::load(
          LoadOp::i32_load16s(),
          MemArg::new(0, None, 0),
          TInstr::i32_const(I32(0)),
        ),
      ),
      TInstr::drop(
        TInstr::binary(
          BinaryOp::i32_and(),
          TInstr::local_get(loc),
          TInstr::i32_const(I32(65535)),
        ),
      ),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let optimized = match optimize_module(mod, [PickLoadSigns]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec([TFunc(_, TExpr([TLocalSet(_, TLoad(I32Load16UOp, _, _)), _]))])
    ) => ()
    _ => fail("expected i32.load16_s to become i32.load16_u")
  }
}

///|
test "optimize_module runs GUFA pass" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let root = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::ref_eq(
          TInstr::ref_func(FuncIdx::new(1)),
          TInstr::ref_func(FuncIdx::new(2)),
        ),
      ),
    ]),
  )
  let f1 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let f2 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(CodeSec::new([root, f1, f2]))
  let optimized = match optimize_module(mod, [GUFA]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TBlock(_, TExpr(seq)))])), _, _])) =>
      match seq[seq.length() - 1] {
        TI32Const(I32(v)) => assert_eq(v, 0)
        _ => fail("expected ref.eq replacement to end with i32.const 0")
      }
    _ => fail("expected transformed root function")
  }
}

///|
test "optimize_module runs GUFAOptimizing followup DCE" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let body = TExpr::new([
    TInstr::drop(
      TInstr::ref_cast(
        false,
        HeapType::abs(AbsHeapType::func()),
        TInstr::ref_null(HeapType::abs(AbsHeapType::func())),
      ),
    ),
    TInstr::i32_const(I32(7)),
  ])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let optimized = match optimize_module(mod, [GUFAOptimizing]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr(instrs))])) => {
      assert_eq(instrs.length(), 1)
      match instrs[0] {
        TUnreachable => ()
        TDrop(TBlock(_, TExpr(seq))) =>
          match seq[seq.length() - 1] {
            TUnreachable => ()
            _ => fail("expected impossible cast to become unreachable")
          }
        TBlock(_, TExpr(seq)) =>
          match seq[seq.length() - 1] {
            TUnreachable => ()
            _ => fail("expected impossible cast to become unreachable")
          }
        _ => fail("expected GUFAOptimizing to keep only unreachable prefix")
      }
    }
    _ => fail("expected transformed function body")
  }
}

///|
test "optimize_module runs GUFACastAll pass" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let body = TExpr::new([TInstr::drop(TInstr::global_get(GlobalIdx::new(0)))])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::funcref(), false),
          Expr::new([Instruction::ref_func(FuncIdx::new(0))]),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let optimized = match optimize_module(mod, [GUFACastAll]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(instr)]))])) =>
      match instr {
        TRefCast(false, HeapType(TypeIdx(i)), TGlobalGet(GlobalIdx(g))) => {
          assert_eq(i.reinterpret_as_int(), 0)
          assert_eq(g.reinterpret_as_int(), 0)
        }
        TRefCast(false, HeapType(TypeIdx(i)), TRefFunc(FuncIdx(f))) => {
          assert_eq(i.reinterpret_as_int(), 0)
          assert_eq(f.reinterpret_as_int(), 0)
        }
        TRefFunc(FuncIdx(f)) => assert_eq(f.reinterpret_as_int(), 0)
        _ => fail("expected GUFACastAll to insert cast around global.get")
      }
    _ => fail("expected transformed function body")
  }
}

///|
test "optimize_module runs I64ToI32Lowering pass" {
  let ty = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i64()], [ValType::i64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i64()],
          TExpr::new([
            TInstr::binary(
              BinaryOp::i64_add(),
              TInstr::local_get(LocalIdx::new(0)),
              TInstr::i64_const(I64(1L)),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match optimize_module(mod, [I64ToI32Lowering]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.type_sec {
    Some(
      TypeSec([SingleRecType(CompTypeSubType(FuncCompType(params, results)))])
    ) => {
      assert_eq(params, [ValType::i32(), ValType::i32()])
      assert_eq(results, [ValType::i32()])
    }
    _ => fail("expected lowered i64 signature")
  }
  match optimized.global_sec {
    Some(GlobalSec(gs)) => assert_true(gs.length() >= 1)
    _ => fail("expected return-high global")
  }
}

///|
test "optimize_module runs DataflowOptimization pass" {
  let body = TExpr::new([
    TInstr::local_set(
      LocalIdx::new(0),
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::i32_const(I32(40)),
        TInstr::i32_const(I32(2)),
      ),
    ),
    TInstr::return_([TInstr::local_get(LocalIdx::new(0))]),
  ])
  let func = Func::t_func([ValType::i32()], body)
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let optimized = match optimize_module(mod, [DataflowOptimization]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr(instrs))])) => {
      let mut found = false
      for instr in instrs {
        match instr {
          TLocalSet(_, TI32Const(I32(42))) => found = true
          _ => ()
        }
      }
      assert_true(found)
    }
    _ => fail("expected optimized TFunc")
  }
}

///|
test "optimize_module_with_options controls DuplicateFunctionElimination iterations" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let a1 = Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(2), [])]))
  let a2 = Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(3), [])]))
  let b1 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let b2 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(0),
      ]),
    )
    .with_code_sec(CodeSec::new([a1, a2, b1, b2]))
  let low = match
    optimize_module_with_options(
      mod,
      [DuplicateFunctionElimination],
      OptimizeOptions::new(optimize_level=0, shrink_level=0),
    ) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module_with_options error: \{e}")
  }
  match low.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 3)
    None => fail("expected code section")
  }
  let high = match
    optimize_module_with_options(
      mod,
      [DuplicateFunctionElimination],
      OptimizeOptions::new(optimize_level=2, shrink_level=0),
    ) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module_with_options error: \{e}")
  }
  match high.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
}

///|
test "optimize_module runs Inlining pass" {
  let t0 = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i32()])),
  )
  let t1 = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i32()], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0, t1]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(5))]),
          ]),
        ),
        Func::t_func([], TExpr::new([TInstr::local_get(LocalIdx::new(0))])),
      ]),
    )
  let optimized = match optimize_module(mod, [Inlining]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _])) => {
      let mut direct_calls = 0
      let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
        self,
        _,
        instr,
      ) {
        match instr {
          TCall(FuncIdx(raw), _) =>
            if raw.reinterpret_as_int() == 1 {
              direct_calls += 1
            }
          _ => ()
        }
        self.walk_tinstruction_default((), instr)
      })
      ignore(walker.walk_texpr((), body))
      assert_eq(direct_calls, 0)
    }
    _ => fail("expected rewritten caller")
  }
}

///|
test "optimize_module runs InlineMain pass" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
        Export::new(
          Name::new("__original_main"),
          ExternIdx::func(FuncIdx::new(1)),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(1), [])])),
        Func::t_func([], TExpr::new([TInstr::nop()])),
      ]),
    )
  let optimized = match optimize_module(mod, [InlineMain]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _])) => {
      let mut direct_calls = 0
      let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
        self,
        _,
        instr,
      ) {
        match instr {
          TCall(FuncIdx(raw), _) =>
            if raw.reinterpret_as_int() == 1 {
              direct_calls += 1
            }
          _ => ()
        }
        self.walk_tinstruction_default((), instr)
      })
      ignore(walker.walk_texpr((), body))
      assert_eq(direct_calls, 0)
    }
    _ => fail("expected rewritten main")
  }
}

///|
test "optimize_module runs LocalCSE pass" {
  let repeated = TInstr::binary(
    BinaryOp::i32_add(),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::i32_const(I32(1)),
  )
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32()],
        TExpr::new([TInstr::drop(repeated), TInstr::drop(repeated)]),
      ),
    ]),
  )
  let optimized = match optimize_module(mod, [LocalCSE]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_true(count_local_tees(body) >= 1)
    _ => fail("expected transformed function body")
  }
}

///|
test "optimize_module runs RedundantSetElimination pass" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32()],
        TExpr::new([
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(5))),
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(5))),
        ]),
      ),
    ]),
  )
  let optimized = match optimize_module(mod, [RedundantSetElimination]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TLocalSet(_, _), TDrop(_)]))])) => ()
    _ => fail("expected second redundant set to be removed")
  }
}

///|
test "optimize_module runs Untee pass" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32()],
        TExpr::new([
          TInstr::drop(
            TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(6))),
          ),
        ]),
      ),
    ]),
  )
  let optimized = match optimize_module(mod, [Untee]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(count_local_tees(body), 0)
    _ => fail("expected transformed function body")
  }
}

///|
test "optimize_module runs Vacuum pass" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func([], TExpr::new([TInstr::drop(TInstr::i32_const(I32(3)))])),
    ]),
  )
  let optimized = match optimize_module(mod, [Vacuum]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TNop]))])) => ()
    _ => fail("expected vacuum to remove pure dropped const")
  }
}

///|
test "optimize_module runs LocalSubtyping pass" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([single_rec_type(comp_type_sub_type(func_comp_type([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::funcref()],
          TExpr::new([
            TInstr::local_set(
              LocalIdx::new(0),
              TInstr::ref_as_non_null(
                TInstr::ref_null(HeapType::new(TypeIdx::new(0))),
              ),
            ),
            TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
          ]),
        ),
      ]),
    )
  let optimized = match optimize_module(mod, [LocalSubtyping]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc([RefTypeValType(rt)], _)])) =>
      assert_false(rt.is_nullable())
    _ => fail("expected refined local type")
  }
}

///|
test "optimize_module runs LoopInvariantCodeMotion pass" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32(), ValType::i32()],
        TExpr::new([
          TInstr::loop_(
            BlockType::void_(),
            TExpr::new([
              TInstr::local_set(
                LocalIdx::new(1),
                TInstr::binary(
                  BinaryOp::i32_add(),
                  TInstr::local_get(LocalIdx::new(0)),
                  TInstr::i32_const(I32(1)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )
  let optimized = match optimize_module(mod, [LoopInvariantCodeMotion]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TBlock(_, TExpr(items))]))])) =>
      match items {
        [TLocalSet(_, _), TLoop(_, _)] => ()
        _ => fail("expected LICM preheader block shape")
      }
    _ => fail("expected transformed loop")
  }
}

///|
test "optimize_module runs MergeBlocks pass" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([TInstr::i32_const(I32(9)), TInstr::nop()]),
          ),
        ]),
      ),
    ]),
  )
  let optimized = match optimize_module(mod, [MergeBlocks]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TI32Const(I32(9))), TNop]))])) => ()
    _ => fail("expected merged block body")
  }
}

///|
test "optimize_module runs Flatten pass" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([single_rec_type(comp_type_sub_type(func_comp_type([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          TExpr::new([
            TInstr::drop(
              TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(3))),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match optimize_module(mod, [Flatten]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(fl_count_local_tees(body), 0)
    _ => fail("expected flattened typed function")
  }
}

///|
test "optimize_module runs MinimizeRecGroups pass" {
  let t0 = RecType::new(
    SubType::comp_type(
      CompType::struct_([
        FieldType::new(StorageType::val_type(ValType::i32()), Const),
      ]),
    ),
  )
  let t1 = RecType::new(
    SubType::comp_type(
      CompType::struct_([
        FieldType::new(StorageType::val_type(ValType::i32()), Const),
      ]),
    ),
  )
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0, t1, t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(2)]))
    .with_code_sec(
      CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
    )
  let optimized = match optimize_module(mod, [MinimizeRecGroups]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.type_sec {
    Some(TypeSec(recs)) => {
      let mut total = 0
      for rec in recs {
        match rec {
          SingleRecType(_) => total += 1
          GroupRecType(sts) => total += sts.length()
        }
      }
      assert_true(total >= 3)
    }
    None => fail("expected type section")
  }
}

///|
test "optimize_module runs MergeSimilarFunctions pass" {
  let t = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i32()], [ValType::i32()])),
  )
  let f0 = Func::t_func(
    [],
    TExpr::new([
      TInstr::return_([
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::binary(
            BinaryOp::i32_mul(),
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::i32_const(I32(42)),
          ),
          TInstr::binary(
            BinaryOp::i32_add(),
            TInstr::i32_const(I32(10)),
            TInstr::i32_const(I32(7)),
          ),
        ),
      ]),
    ]),
  )
  let f1 = Func::t_func(
    [],
    TExpr::new([
      TInstr::return_([
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::binary(
            BinaryOp::i32_mul(),
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::i32_const(I32(43)),
          ),
          TInstr::binary(
            BinaryOp::i32_add(),
            TInstr::i32_const(I32(10)),
            TInstr::i32_const(I32(7)),
          ),
        ),
      ]),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([f0, f1]))
  let optimized = match optimize_module(mod, [MergeSimilarFunctions]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 3)
    _ => fail("expected shared function append")
  }
}

///|
test "optimize_module runs MemoryPacking pass" {
  let data = Data::new(
    DataMode::passive(),
    b"\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02",
  )
  let body = TExpr::new([
    TInstr::memory_init(
      DataIdx::new(0),
      MemIdx::new(0),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(32)),
    ),
  ])
  let mod = Module::new()
    .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
    .with_data_sec(DataSec::new([data]))
    .with_type_sec(
      TypeSec::new([single_rec_type(comp_type_sub_type(func_comp_type([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let optimized = match
    optimize_module(mod, [
      MemoryPacking(MemoryPackingPassProps::new(zero_filled_memory=true)),
    ]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.data_sec {
    Some(DataSec(datas)) => assert_eq(datas.length(), 2)
    _ => fail("expected data section")
  }
}

///|
test "optimize_module runs Precompute and PrecomputePropagate passes" {
  let x = LocalIdx::new(0)
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32()],
        TExpr::new([
          TInstr::local_set(x, TInstr::i32_const(I32(9))),
          TInstr::binary(
            BinaryOp::i32_add(),
            TInstr::local_get(x),
            TInstr::i32_const(I32(1)),
          ),
        ]),
      ),
    ]),
  )
  let optimized = match
    optimize_module(mod, [PrecomputePropagate, Precompute]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TLocalSet(_, _), TI32Const(I32(v))]))])) =>
      assert_eq(v, 10)
    _ => fail("expected propagated+precomputed constant expression")
  }
}

///|
test "optimize_module runs RemoveUnusedBrs pass" {
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([TInstr::i32_const(I32(1)), TInstr::br(LabelIdx::new(0), [])]),
      ),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let optimized = match optimize_module(mod, [RemoveUnusedBrs]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TBlock(_, TExpr([TI32Const(I32(1))]))]))])) =>
      ()
    _ => fail("expected RemoveUnusedBrs to remove trailing br 0")
  }
}

///|
test "optimize_module runs RemoveUnusedNames pass" {
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([TInstr::i32_const(I32(5))]),
          ),
        ]),
      ),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let optimized = match optimize_module(mod, [RemoveUnusedNames]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TBlock(_, TExpr([TI32Const(I32(5))]))]))])) =>
      ()
    _ => fail("expected RemoveUnusedNames to merge single-child blocks")
  }
}

///|
test "optimize_module runs SimplifyLocals pass" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32()],
        TExpr::new([
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(42))),
          TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
        ]),
      ),
    ]),
  )
  let optimized = match optimize_module(mod, [SimplifyLocals]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr(instrs))])) =>
      match instrs {
        [TDrop(TI32Const(I32(v)))] => assert_eq(v, 42)
        _ =>
          fail("expected local.set/local.get pair to simplify into direct drop")
      }
    _ => fail("expected SimplifyLocals to run on typed function")
  }
}

///|
test "optimize_module runs ReorderFunctions pass" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let root = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(2), []),
      TInstr::call(FuncIdx::new(2), []),
    ]),
  )
  let most_used = Func::t_func([], TExpr::new([TInstr::nop()]))
  let less_used = Func::t_func(
    [],
    TExpr::new([TInstr::drop(TInstr::i32_const(I32(7)))]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("imp"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(CodeSec::new([root, most_used, less_used]))
    .with_start_sec(StartSec::new(FuncIdx::new(3)))
  let optimized = match optimize_module(mod, [ReorderFunctions]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TNop])), _, _])) => ()
    _ => fail("expected ReorderFunctions to move highest-used function first")
  }
  match optimized.start_sec {
    Some(StartSec(FuncIdx(i))) => assert_eq(i, 2U)
    _ => fail("expected ReorderFunctions to rewrite start index")
  }
}

///|
test "optimize_module runs ReorderLocals pass" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32(), ValType::i64()],
        TExpr::new([
          TInstr::drop(TInstr::local_get(LocalIdx::new(1))),
          TInstr::drop(TInstr::local_get(LocalIdx::new(1))),
        ]),
      ),
    ]),
  )
  let optimized = match optimize_module(mod, [ReorderLocals]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(locals, TExpr(instrs))])) => {
      assert_eq(locals, [ValType::i64()])
      match instrs {
        [TDrop(TLocalGet(LocalIdx(i0))), TDrop(TLocalGet(LocalIdx(i1)))] => {
          assert_eq(i0, 0U)
          assert_eq(i1, 0U)
        }
        _ => fail("expected local indices to be remapped after local reorder")
      }
    }
    _ => fail("expected ReorderLocals to drop and remap locals")
  }
}

///|
test "optimize_module runs ReorderTypes pass" {
  let private_types : Array[SubType] = []
  for _ in 0..<130 {
    private_types.push(SubType::comp_type(CompType::struct_([])))
  }
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::group(private_types), rt_single_void_type()]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(130)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(TInstr::struct_new(TypeIdx::new(129), [])),
            TInstr::drop(TInstr::struct_new(TypeIdx::new(129), [])),
          ]),
        ),
      ]),
    )
  let optimized = match optimize_module(mod, [ReorderTypes]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TStructNew(TypeIdx(i0), [])), ..]))])) =>
      assert_true(i0 < 128U)
    _ => fail("expected ReorderTypes to remap hot type below LEB boundary")
  }
}

///|
test "optimize_module runs ReorderGlobalsAlways pass" {
  let imported = Import::new(
    Name::new("env"),
    Name::new("gimp"),
    ExternType::global(GlobalType::new(ValType::i32(), true)),
  )
  let g0 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::i32_const(I32(1))]),
  )
  let g1 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::global_get(GlobalIdx::new(1))]),
  )
  let g2 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::i32_const(I32(2))]),
  )
  let mod = Module::new()
    .with_import_sec(ImportSec::new([imported]))
    .with_global_sec(GlobalSec::new([g0, g1, g2]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(TInstr::global_get(GlobalIdx::new(3))),
            TInstr::drop(TInstr::global_get(GlobalIdx::new(3))),
          ]),
        ),
      ]),
    )
  let optimized = match optimize_module(mod, [ReorderGlobalsAlways]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.global_sec {
    Some(GlobalSec(globals)) => {
      assert_eq(globals.length(), 3)
      match globals[0] {
        Global(_, Expr([I32Const(I32(v))])) => assert_eq(v, 2)
        _ => fail("expected first reordered global to be the most-used one")
      }
    }
    _ => fail("expected ReorderGlobalsAlways to move most-used global first")
  }
}

///|
test "optimize_module runs SimplifyGlobals pass" {
  let mod = Module::new()
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), true),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::global_set(GlobalIdx::new(0), TInstr::i32_const(I32(9))),
          ]),
        ),
      ]),
    )
  let optimized = match optimize_module(mod, [SimplifyGlobals]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TI32Const(I32(v)))]))])) =>
      assert_eq(v, 9)
    _ => fail("expected SimplifyGlobals to remove dead global.set")
  }
}

///|
fn opt_assert_valid_module(mod : Module, label : String) -> Unit raise {
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) => fail("\{label}: expected module to validate after pass: \{e}")
  }
}

///|
fn opt_assert_pass_invariant(
  mod : Module,
  pass : ModulePass,
  label : String,
  validate? : Bool = true,
) -> Module raise {
  let once = match optimize_module(mod, [pass]) {
    Ok(m) => m
    Err(e) => fail("\{label}: unexpected optimize_module error: \{e}")
  }
  if validate {
    opt_assert_valid_module(once, label)
  }
  let twice = match optimize_module(mod, [pass]) {
    Ok(m) => m
    Err(e) => fail("\{label}: unexpected repeated optimize_module error: \{e}")
  }
  if validate {
    opt_assert_valid_module(twice, label)
  }
  assert_eq(once, twice)
  once
}

///|
test "pass invariant: heap2local validates and remap is stable" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        struct_type,
        single_rec_type(comp_type_sub_type(func_comp_type([], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [local_ref],
          TExpr::new([
            TInstr::local_set(
              LocalIdx::new(0),
              TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
            ),
            TInstr::struct_set(
              TypeIdx::new(0),
              @lib.U32(0),
              TInstr::local_get(LocalIdx::new(0)),
              TInstr::i32_const(I32(4)),
            ),
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                @lib.U32(0),
                TInstr::local_get(LocalIdx::new(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let out = opt_assert_pass_invariant(mod, Heap2Local, "heap2local")
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(h2l_count_gc_ops(body), 0)
    _ => fail("heap2local: expected transformed typed function")
  }
}

///|
test "pass invariant: merge_blocks validates and remap is stable" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([TInstr::i32_const(I32(9)), TInstr::nop()]),
          ),
        ]),
      ),
    ]),
  )
  let mod = mod
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  let out = opt_assert_pass_invariant(mod, MergeBlocks, "merge_blocks")
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TI32Const(I32(9))), TNop]))])) => ()
    _ => fail("merge_blocks: expected merged block body")
  }
}

///|
test "pass invariant: asyncify validates and remap is stable" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("sleep"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(0), [])])),
      ]),
    )
  let out = opt_assert_pass_invariant(
    mod,
    Asyncify(AsyncifyPassProps::new()),
    "asyncify",
    validate=false,
  )
  match out.code_sec {
    Some(CodeSec(funcs)) => assert_true(funcs.length() >= 1)
    _ => fail("asyncify: expected code section after rewrite")
  }
}

///|
test "pass invariant: i64_to_i32_lowering validates and remap is stable" {
  let ty = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i64()], [ValType::i64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i64()],
          TExpr::new([
            TInstr::binary(
              BinaryOp::i64_add(),
              TInstr::local_get(LocalIdx::new(0)),
              TInstr::i64_const(I64(1L)),
            ),
          ]),
        ),
      ]),
    )
  let out = opt_assert_pass_invariant(
    mod,
    I64ToI32Lowering,
    "i64_to_i32_lowering",
  )
  match out.type_sec {
    Some(
      TypeSec([SingleRecType(CompTypeSubType(FuncCompType(params, results)))])
    ) => {
      assert_eq(params, [ValType::i32(), ValType::i32()])
      assert_eq(results, [ValType::i32()])
    }
    _ => fail("i64_to_i32_lowering: expected lowered i64 function signature")
  }
}

///|
test "pass invariant: global_type_optimization validates and remap is stable" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let func_type = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type, func_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                @lib.U32(1),
                TInstr::struct_new(TypeIdx::new(0), [
                  TInstr::i32_const(I32(11)),
                  TInstr::i32_const(I32(22)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let out = opt_assert_pass_invariant(
    mod,
    GlobalTypeOptimization,
    "global_type_optimization",
  )
  match out.type_sec {
    Some(TypeSec([SingleRecType(st), _])) =>
      match st.get_comptype() {
        StructCompType(fields) => assert_eq(fields.length(), 1)
        _ => fail("global_type_optimization: expected optimized struct type")
      }
    _ => fail("global_type_optimization: expected type section")
  }
}

///|
test "pass invariant: minimize_rec_groups validates and remap is stable" {
  let t0 = RecType::new(
    SubType::comp_type(
      CompType::struct_([
        FieldType::new(StorageType::val_type(ValType::i32()), Const),
      ]),
    ),
  )
  let t1 = RecType::new(
    SubType::comp_type(
      CompType::struct_([
        FieldType::new(StorageType::val_type(ValType::i32()), Const),
      ]),
    ),
  )
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0, t1, t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(2)]))
    .with_code_sec(
      CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
    )
  let out = opt_assert_pass_invariant(
    mod,
    MinimizeRecGroups,
    "minimize_rec_groups",
  )
  match out.type_sec {
    Some(TypeSec(recs)) => assert_true(recs.length() >= 1)
    _ => fail("minimize_rec_groups: expected type section")
  }
}

///|
test "pass invariant: remove_unused validates and remap is stable" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], TExpr::new([TInstr::nop()])),
        Func::t_func([], TExpr::new([TInstr::nop()])),
      ]),
    )
  let out = opt_assert_pass_invariant(mod, RemoveUnused, "remove_unused")
  match out.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 1)
    _ => fail("remove_unused: expected unused function pruning")
  }
}

///|
test "pass invariant: local_cse validates and remap is stable" {
  let t_i32_void = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i32()], [])),
  )
  let repeated = TInstr::binary(
    BinaryOp::i32_add(),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::i32_const(I32(1)),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          TExpr::new([TInstr::drop(repeated), TInstr::drop(repeated)]),
        ),
      ]),
    )
  let out = opt_assert_pass_invariant(mod, LocalCSE, "local_cse")
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_true(count_local_tees(body) >= 1)
    _ => fail("local_cse: expected repeated expression reuse")
  }
}

///|
test "pass invariant: optimize_instructions validates and remap is stable" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), true),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::global_set(
              GlobalIdx::new(0),
              TInstr::global_get(GlobalIdx::new(0)),
            ),
          ]),
        ),
      ]),
    )
  let out = opt_assert_pass_invariant(
    mod,
    OptimizeInstructions,
    "optimize_instructions",
  )
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TNop]))])) => ()
    _ =>
      fail(
        "optimize_instructions: expected global.set(global.get same idx) to fold",
      )
  }
}

///|
test "pass invariant: precompute validates and remap is stable" {
  let t_ret_i32 = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ret_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::binary(
              BinaryOp::i32_add(),
              TInstr::i32_const(I32(1)),
              TInstr::i32_const(I32(2)),
            ),
          ]),
        ),
      ]),
    )
  let out = opt_assert_pass_invariant(mod, Precompute, "precompute")
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TI32Const(I32(v))]))])) => assert_eq(v, 3)
    _ => fail("precompute: expected simple constant fold")
  }
}
