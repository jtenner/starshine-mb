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
fn apply_ir_transformer_pass(
  ctx : IRContext,
  mod : Module,
  pass : ModuleTransformer[IRContext],
) -> Result[Module, String] {
  match pass.walk_module(ctx, mod) {
    Ok(Some((_, new_mod))) => Ok(new_mod)
    Ok(None) => Ok(mod)
    Err(e) => Err(e)
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
  mod = match
    apply_ir_transformer_pass(
      ctx,
      mod,
      wrap_unit_func_pass(lift_to_texpr_pass()),
    ) {
    Ok(new_mod) => new_mod
    Err(e) => return Err(e)
  }
  ctx.set_mod(mod)
  for pass in passes {
    ctx.set_mod(mod)
    mod = match pass {
      AbstractTypeRefining(props) =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            abstract_type_refining(mod, props.traps_never_happen),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      AlignmentLowering =>
        match
          apply_ir_transformer_pass(ctx, mod, alignment_lowering_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      AvoidReinterprets =>
        match
          apply_ir_transformer_pass(ctx, mod, avoid_reinterprets_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      CoalesceLocals =>
        match apply_ir_transformer_pass(ctx, mod, coalesce_locals_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      CodeFolding =>
        match apply_ir_transformer_pass(ctx, mod, code_folding_ir_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      CodePushing =>
        match apply_ir_transformer_pass(ctx, mod, code_pushing_ir_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      ConstHoisting =>
        match apply_ir_transformer_pass(ctx, mod, const_hoisting_ir_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      ConstantFieldPropagation =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            constant_field_propagation_ir_pass(mod),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      DataflowOptimization =>
        match
          apply_ir_transformer_pass(ctx, mod, dataflow_optimization_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      DeadCodeElimination =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            dead_code_elimination_ir_pass(mod),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      DeadArgumentElimination =>
        match
          apply_ir_transformer_pass(ctx, mod, dead_argument_elim_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      SignaturePruning =>
        match
          apply_ir_transformer_pass(ctx, mod, signature_pruning_ir_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      SignatureRefining =>
        match signature_refining(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      DuplicateImportElimination =>
        match duplicate_import_elimination(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      GlobalRefining =>
        match global_refining(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      GlobalStructInference =>
        match run_global_struct_inference(mod, false) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      GlobalStructInferenceDescCast =>
        match run_global_struct_inference(mod, true) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      GlobalTypeOptimization =>
        match global_type_optimization(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      SimplifyGlobals =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            simplify_globals_ir_pass(mod, false),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      SimplifyGlobalsOptimizing =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            simplify_globals_ir_pass(mod, true),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      PropagateGlobalsGlobally =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            propagate_globals_globally_ir_pass(mod),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      TypeRefining =>
        match type_refining(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      Heap2Local =>
        match apply_ir_transformer_pass(ctx, mod, heap2local_ir_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      HeapStoreOptimization =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            heap_store_optimization_ir_pass(mod),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      Inlining =>
        match inlining(mod, options, false) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      InliningOptimizing =>
        match inlining(mod, options, true) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      InlineMain =>
        match inline_main(mod, options) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      LocalCSE =>
        match
          apply_ir_transformer_pass(ctx, mod, local_cse_ir_pass(mod, options)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      LocalSubtyping =>
        match local_subtyping(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      LoopInvariantCodeMotion =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            loop_invariant_code_motion_ir_pass(mod),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      MergeLocals =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            merge_locals_ir_pass(mod, options~),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      MergeSimilarFunctions =>
        match merge_similar_functions(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      MergeBlocks =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            merge_blocks_ir_pass(mod, options~),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      OnceReduction =>
        match once_reduction(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      Asyncify(props) =>
        match asyncify(mod, props~, optimize_level=options.optimize_level) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      MinimizeRecGroups =>
        match minimize_rec_groups(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      Monomorphize =>
        match monomorphize(mod, options~, always=false) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      MonomorphizeAlways =>
        match monomorphize(mod, options~, always=true) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      MemoryPacking(props) =>
        match memory_packing(mod, props) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      OptimizeAddedConstants =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            optimize_added_constants_ir_pass(mod, options, false),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      OptimizeAddedConstantsPropagate =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            optimize_added_constants_ir_pass(mod, options, true),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      OptimizeInstructions =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            optimize_instructions_ir_pass(mod, options),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      Precompute =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            precompute_ir_pass(mod, options, false),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      PrecomputePropagate =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            precompute_ir_pass(mod, options, true),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      RedundantSetElimination =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            redundant_set_elimination_ir_pass(mod),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      PickLoadSigns =>
        match
          apply_ir_transformer_pass(ctx, mod, pick_load_signs_ir_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      GUFA =>
        match apply_ir_transformer_pass(ctx, mod, gufa_ir_pass(mod, false)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      GUFAOptimizing =>
        match apply_ir_transformer_pass(ctx, mod, gufa_ir_pass(mod, false)) {
          Ok(gufa_mod) => {
            ctx.set_mod(gufa_mod)
            let after_dce = match
              apply_ir_transformer_pass(
                ctx,
                gufa_mod,
                dead_code_elimination_ir_pass(gufa_mod),
              ) {
              Ok(new_mod) => new_mod
              Err(e) => return Err(e)
            }
            ctx.set_mod(after_dce)
            match
              apply_ir_transformer_pass(
                ctx,
                after_dce,
                code_folding_ir_pass(after_dce),
              ) {
              Ok(new_mod) => new_mod
              Err(e) => return Err(e)
            }
          }
          Err(e) => return Err(e)
        }
      GUFACastAll =>
        match apply_ir_transformer_pass(ctx, mod, gufa_ir_pass(mod, true)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      I64ToI32Lowering =>
        match i64_to_i32_lowering(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      DuplicateFunctionElimination =>
        match duplicate_function_elimination(mod, options) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      Directize(initial_immutable) =>
        match directize_ir_pass(mod, initial_immutable) {
          Ok(pass) =>
            match apply_ir_transformer_pass(ctx, mod, pass) {
              Ok(new_mod) => new_mod
              Err(e) => return Err(e)
            }
          Err(e) => return Err(e)
        }
      OptimizeCasts =>
        match apply_ir_transformer_pass(ctx, mod, optimize_casts_ir_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      DeNaN =>
        match run_denam(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      RemoveUnusedBrs =>
        match remove_unused_brs(mod, options~) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      RemoveUnusedNames =>
        match
          apply_ir_transformer_pass(ctx, mod, remove_unused_names_ir_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      SimplifyLocals =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            simplify_locals_ir_pass(mod, true, true, true),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      SimplifyLocalsNoTee =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            simplify_locals_ir_pass(mod, false, true, true),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      SimplifyLocalsNoStructure =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            simplify_locals_ir_pass(mod, true, false, true),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      SimplifyLocalsNoTeeNoStructure =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            simplify_locals_ir_pass(mod, false, false, true),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      SimplifyLocalsNoNesting =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            simplify_locals_ir_pass(mod, false, false, false),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      Untee =>
        match apply_ir_transformer_pass(ctx, mod, untee_ir_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      Vacuum =>
        match apply_ir_transformer_pass(ctx, mod, vacuum_ir_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      ReorderLocals =>
        match apply_ir_transformer_pass(ctx, mod, reorder_locals_ir_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      ReorderTypes =>
        match reorder_types(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      ReorderGlobals =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            reorder_globals_ir_pass(mod, false),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      ReorderGlobalsAlways =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            reorder_globals_ir_pass(mod, true),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      ReorderFunctions =>
        match reorder_functions(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      ReorderFunctionsByName =>
        match reorder_functions_by_name(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      RemoveUnusedTypes =>
        match remove_unused_types(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      RemoveUnused =>
        match remove_unused(mod) {
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
    // TODO(binaryen parity): ssa-nomerge is not implemented yet.
  }
  if options.optimize_level >= 4 {
    // TODO(binaryen parity): flatten is not implemented yet.
    passes.push(SimplifyLocalsNoTeeNoStructure)
    passes.push(LocalCSE)
    // TODO(binaryen parity): rereloop is not implemented yet.
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
    // TODO(binaryen parity): tuple-optimization is not implemented yet.
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
      // TODO(binaryen parity): expose open-world remove-unused-module-elements mode.
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
      // TODO(binaryen parity): expose open-world remove-unused-module-elements mode.
    }
    if closed_world {
      passes.push(RemoveUnusedTypes)
      if options.optimize_level >= 3 {
        // TODO(binaryen parity): cfp-reftest mode is not implemented; using cfp.
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
      // TODO(binaryen parity): unsubtyping is not implemented yet.
    }
  }

  // TODO(binaryen parity): generate-global-effects is not implemented yet.
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
