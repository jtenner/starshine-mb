///| 
/// Copyright 2023 WebAssembly Community Group participants
/// 
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
/// 
///     http://www.apache.org/licenses/LICENSE-2.0
/// 
/// Unless required by applicable law or agreed to in writing, software
/// distributed under the License is distributed on an "AS IS" BASIS,
/// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/// See the License for the specific language governing permissions and
/// limitations under the License.
///

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
  DeadArgumentEliminationOptimizing
  SignaturePruning
  SignatureRefining
  DuplicateImportElimination
  GlobalRefining
  GlobalStructInference
  GlobalStructInferenceDescCast
  GlobalTypeOptimization
  SimplifyGlobals
  SimplifyGlobalsOptimizing
  GlobalEffects
  PropagateGlobalsGlobally
  TypeRefining
  TypeGeneralizing
  TypeFinalizing
  TypeUnFinalizing
  Unsubtyping
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
  ReReloop
  TupleOptimization
  OnceReduction
  Asyncify(AsyncifyPassProps)
  MinimizeRecGroups
  TypeMerging
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
} derive(Show, Eq)

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
pub fn InliningOptions::new(
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
  traps_never_happen : Bool
}

///|
fn AbstractTypeRefiningPassProps::new(
  traps_never_happen? : Bool = false,
) -> AbstractTypeRefiningPassProps {
  { traps_never_happen, }
}

///|
pub fn OptimizeOptions::new(
  optimize_level? : Int = 0,
  shrink_level? : Int = 0,
  inlining? : InliningOptions = InliningOptions::new(),
  monomorphize_min_benefit? : Int = 5,
  low_memory_unused? : Bool = false,
  low_memory_bound? : UInt64 = 1024UL,
  traps_never_happen? : Bool = false,
) -> OptimizeOptions {
  {
    optimize_level,
    shrink_level,
    inlining,
    monomorphize_min_benefit,
    low_memory_unused,
    low_memory_bound,
    traps_never_happen,
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
    | TypeFinalizing
    | TypeUnFinalizing
    | Unsubtyping
    | DeadArgumentElimination
    | DeadArgumentEliminationOptimizing
    | TypeMerging
    | Monomorphize
    | MonomorphizeAlways
    | MemoryPacking(_)
    | I64ToI32Lowering
    | DuplicateFunctionElimination
    | RemoveUnusedBrs
    | ReorderTypes
    | ReorderFunctions
    | ReorderFunctionsByName
    | RemoveUnusedTypes => ModuleRunnerPass
    _ => IRContextTransformerPass
  }
}

///|
fn run_ir_context_transformer_scheduler_pass(
  ctx : IRContext,
  mod : Module,
  pass : ModulePass,
  options : OptimizeOptions,
  trace : (String) -> Unit,
  trace_pass_details : Bool,
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
      apply_ir_transformer_pass(
        ctx,
        mod,
        code_folding_ir_pass_with_trace(
          mod,
          trace=fn(msg) { trace("code_folding:\{msg}") },
          trace_all_funcs=trace_pass_details,
        ),
      )
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
      apply_ir_transformer_pass(
        ctx,
        mod,
        dataflow_optimization_pass(
          mod,
          trace=fn(msg) { trace("dataflow:\{msg}") },
          trace_all_funcs=trace_pass_details,
        ),
      )
    SignaturePruning =>
      apply_ir_transformer_pass(ctx, mod, signature_pruning_ir_pass(mod))
    SimplifyGlobals =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        simplify_globals_ir_pass(
          mod,
          false,
          trace=fn(msg) { trace("simplify_globals:\{msg}") },
          trace_all_funcs=trace_pass_details,
        ),
      )
    SimplifyGlobalsOptimizing =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        simplify_globals_ir_pass(
          mod,
          true,
          trace=fn(msg) { trace("simplify_globals:\{msg}") },
          trace_all_funcs=trace_pass_details,
        ),
      )
    PropagateGlobalsGlobally =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        propagate_globals_globally_ir_pass(mod),
      )
    GlobalEffects =>
      apply_ir_transformer_pass(ctx, mod, global_effects_ir_pass(mod))
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
    ReReloop => apply_ir_transformer_pass(ctx, mod, re_reloop_ir_pass(mod))
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
        optimize_instructions_ir_pass(
          mod,
          options,
          trace=fn(msg) { trace("optimize_instructions:\{msg}") },
          trace_all_funcs=trace_pass_details,
        ),
      )
    Precompute => {
      if trace_pass_details {
        trace("precompute:start propagate=false")
      }
      let result = apply_ir_transformer_pass(
        ctx,
        mod,
        precompute_ir_pass(
          mod,
          options,
          false,
          trace=fn(msg) { trace("precompute:\{msg}") },
          trace_all_funcs=trace_pass_details,
        ),
      )
      if trace_pass_details {
        match result {
          Ok(_) => trace("precompute:done propagate=false")
          Err(e) => trace("precompute:error propagate=false \{e}")
        }
      }
      result
    }
    PrecomputePropagate => {
      if trace_pass_details {
        trace("precompute:start propagate=true")
      }
      let result = apply_ir_transformer_pass(
        ctx,
        mod,
        precompute_ir_pass(
          mod,
          options,
          true,
          trace=fn(msg) { trace("precompute:\{msg}") },
          trace_all_funcs=trace_pass_details,
        ),
      )
      if trace_pass_details {
        match result {
          Ok(_) => trace("precompute:done propagate=true")
          Err(e) => trace("precompute:error propagate=true \{e}")
        }
      }
      result
    }
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
	            apply_unit_transformer_pass(
	              gufa_mod,
	              dead_code_elimination_pass_with_trace(
	                trace=fn(msg) { trace("dead_code_elimination:\{msg}") },
	                trace_all_funcs=trace_pass_details,
	              ),
	            ) {
	            Ok(new_mod) => new_mod
	            Err(e) => return Err(e)
	          }
          ctx.set_mod(after_dce)
          apply_ir_transformer_pass(
            ctx,
            after_dce,
            code_folding_ir_pass_with_trace(
              after_dce,
              trace=fn(msg) { trace("code_folding:\{msg}") },
              trace_all_funcs=trace_pass_details,
            ),
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
    DeNaN => apply_ir_transformer_pass(ctx, mod, de_nan_ir_pass(mod))
    RemoveUnusedNames =>
      apply_ir_transformer_pass(ctx, mod, remove_unused_names_ir_pass(mod))
    RemoveUnused =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        remove_unused_ir_pass(mod, trace=fn(msg) {
          trace("remove_unused:\{msg}")
        }),
      )
    RemoveUnusedModuleElements =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        remove_unused_ir_pass(mod, root_all_functions=true, trace=fn(msg) {
          trace("remove_unused:\{msg}")
        }),
      )
    RemoveUnusedNonFunctionElements =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        remove_unused_ir_pass(mod, root_all_functions=true, trace=fn(msg) {
          trace("remove_unused:\{msg}")
        }),
      )
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
    Vacuum =>
      apply_ir_transformer_pass(
        ctx,
        mod,
        vacuum_ir_pass_with_trace(
          mod,
          fn(msg) { trace("vacuum:\{msg}") },
          trace_all_funcs=trace_pass_details,
        ),
      )
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
  trace : (String) -> Unit,
  trace_pass_details : Bool,
) -> Result[Module, String] {
  match pass {
    DeadCodeElimination =>
      apply_unit_transformer_pass(
        mod,
        dead_code_elimination_pass_with_trace(
          trace=fn(msg) { trace("dead_code_elimination:\{msg}") },
          trace_all_funcs=trace_pass_details,
        ),
      )
    _ => Err("optimize scheduler bug: expected Unit transformer pass")
  }
}

///|
fn run_module_runner_scheduler_pass(
  mod : Module,
  pass : ModulePass,
  options : OptimizeOptions,
  trace : (String) -> Unit,
  trace_pass_details : Bool,
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
    TypeFinalizing =>
      apply_module_runner_pass(mod, fn(mod) {
        type_finalizing(mod, finalize=true)
      })
    TypeUnFinalizing =>
      apply_module_runner_pass(mod, fn(mod) { type_unfinalizing(mod) })
    Unsubtyping =>
      apply_module_runner_pass(mod, fn(mod) {
        unsubtyping(mod, traps_never_happen=options.traps_never_happen)
      })
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
      apply_module_runner_pass(mod, fn(mod) {
        once_reduction(mod, trace=fn(msg) { trace("once_reduction:\{msg}") })
      })
    Asyncify(props) =>
      apply_module_runner_pass(mod, fn(mod) {
        asyncify(mod, props~, optimize_level=options.optimize_level)
      })
    DeadArgumentElimination =>
      apply_module_runner_pass(mod, fn(mod) {
        Ok(
          run_dead_argument_elim_with_trace(
            mod,
            fn(msg) { trace("dead_argument_elim:\{msg}") },
            trace_all_funcs=trace_pass_details,
          ),
        )
      })
    DeadArgumentEliminationOptimizing =>
      apply_module_runner_pass(mod, fn(mod) {
        let dae_mod = run_dead_argument_elim_with_trace(
          mod,
          fn(msg) { trace("dead_argument_elim:\{msg}") },
          trace_all_funcs=trace_pass_details,
        )
        let cleanup_profile = optimize_cleanup_cost_profile(dae_mod)
        if optimize_should_skip_expensive_cleanup(cleanup_profile) {
          trace(
            "dead_argument_elim_cleanup:skip reason=module_size funcs=\{cleanup_profile.func_count} top_instrs=\{cleanup_profile.top_instr_sum}",
          )
          return Ok(dae_mod)
        }
        trace(
          "dead_argument_elim_cleanup:dce:start funcs=\{cleanup_profile.func_count} top_instrs=\{cleanup_profile.top_instr_sum}",
        )
        let after_dce = match
          apply_unit_transformer_pass(
            dae_mod,
            dead_code_elimination_pass_with_trace(
              trace=fn(msg) { trace("dead_code_elimination:\{msg}") },
              trace_all_funcs=trace_pass_details,
            ),
          ) {
          Ok(new_mod) => {
            let dce_profile = optimize_cleanup_cost_profile(new_mod)
            trace(
              "dead_argument_elim_cleanup:dce:done funcs=\{dce_profile.func_count} top_instrs=\{dce_profile.top_instr_sum}",
            )
            new_mod
          }
          Err(e) => return Err(e)
        }
        let vacuum_profile = optimize_cleanup_cost_profile(after_dce)
        trace(
          "dead_argument_elim_cleanup:vacuum:start funcs=\{vacuum_profile.func_count} top_instrs=\{vacuum_profile.top_instr_sum}",
        )
        let cleanup_ctx = IRContext::new()
        cleanup_ctx.set_mod(after_dce)
        let after_vacuum = match
          apply_ir_transformer_pass(
            cleanup_ctx,
            after_dce,
            vacuum_ir_pass_with_trace(
              after_dce,
              fn(msg) { trace("vacuum:\{msg}") },
              trace_all_funcs=trace_pass_details,
            ),
          ) {
          Ok(new_mod) => {
            let vacuum_done_profile = optimize_cleanup_cost_profile(new_mod)
            trace(
              "dead_argument_elim_cleanup:vacuum:done funcs=\{vacuum_done_profile.func_count} top_instrs=\{vacuum_done_profile.top_instr_sum}",
            )
            new_mod
          }
          Err(e) => return Err(e)
        }
        cleanup_ctx.set_mod(after_vacuum)
        let code_folding_profile = optimize_cleanup_cost_profile(after_vacuum)
        trace(
          "dead_argument_elim_cleanup:code_folding:start funcs=\{code_folding_profile.func_count} top_instrs=\{code_folding_profile.top_instr_sum}",
        )
        match
          apply_ir_transformer_pass(
            cleanup_ctx,
            after_vacuum,
            code_folding_ir_pass_with_trace(
              after_vacuum,
              trace=fn(msg) { trace("code_folding:\{msg}") },
              trace_all_funcs=trace_pass_details,
            ),
          ) {
          Ok(new_mod) => {
            let code_folding_done_profile = optimize_cleanup_cost_profile(
              new_mod,
            )
            trace(
              "dead_argument_elim_cleanup:code_folding:done funcs=\{code_folding_done_profile.func_count} top_instrs=\{code_folding_done_profile.top_instr_sum}",
            )
            Ok(new_mod)
          }
          Err(e) => Err(e)
        }
      })
    MinimizeRecGroups =>
      apply_module_runner_pass(mod, fn(mod) { minimize_rec_groups(mod) })
    TypeMerging =>
      apply_module_runner_pass(mod, fn(mod) {
        type_merging(mod, traps_never_happen=options.traps_never_happen)
      })
    Monomorphize =>
      apply_module_runner_pass(mod, fn(mod) {
        monomorphize(mod, options~, always=false)
      })
    MonomorphizeAlways =>
      apply_module_runner_pass(mod, fn(mod) {
        monomorphize(mod, options~, always=true)
      })
    MemoryPacking(props) =>
      apply_module_runner_pass(mod, fn(mod) {
        memory_packing(mod, props, trace=fn(msg) {
          trace("memory_packing:\{msg}")
        })
      })
    I64ToI32Lowering =>
      match i64_to_i32_lowering_prepare(mod) {
        Ok(prepared) =>
          apply_module_runner_pass(mod, fn(_) {
            i64_to_i32_lowering_from_prepared(prepared)
          })
        Err(e) =>
          Err(
            "optimize scheduler: i64_to_i32_lowering precondition failed: \{e}",
          )
      }
    DuplicateFunctionElimination =>
      apply_module_runner_pass(mod, fn(mod) {
        duplicate_function_elimination(mod, options, trace=fn(msg) {
          trace("duplicate_function_elimination:\{msg}")
        })
      })
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
fn optimize_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn optimize_trace_normalize_env_now_ms(raw : UInt64) -> UInt64 {
  if raw >= 100000000000000000UL {
    // Likely nanoseconds.
    raw / 1000000UL
  } else if raw >= 100000000000000UL {
    // Likely microseconds.
    raw / 1000UL
  } else {
    // Already milliseconds.
    raw
  }
}

///|
#cfg(target="native")
#borrow(tv)
extern "c" fn optimize_native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="native")
fn optimize_trace_read_u64_le(bytes : Bytes, start : Int) -> UInt64 {
  let mut out = 0UL
  let mut i = 0
  while i < 8 {
    out = out | (bytes[start + i].to_uint64() << (i * 8))
    i += 1
  }
  out
}

///|
#cfg(target="native")
fn optimize_trace_now_ms() -> UInt64 {
  // struct timeval { long tv_sec; long tv_usec; } on current native targets.
  let tv = Bytes::new(16)
  if optimize_native_gettimeofday(tv, 0UL) != 0 {
    return optimize_trace_normalize_env_now_ms(@env.now())
  }
  let sec = optimize_trace_read_u64_le(tv, 0)
  let usec = optimize_trace_read_u64_le(tv, 8)
  sec * 1000UL + usec / 1000UL
}

///|
#cfg(target="wasm-gc")
fn optimize_trace_now_ms() -> UInt64 {
  optimize_trace_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="wasm")
fn optimize_trace_now_ms() -> UInt64 {
  optimize_trace_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="js")
fn optimize_trace_now_ms() -> UInt64 {
  optimize_trace_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="llvm")
fn optimize_trace_now_ms() -> UInt64 {
  optimize_trace_normalize_env_now_ms(@env.now())
}

///|
fn optimize_trace_elapsed_ms(start_ms : UInt64) -> UInt64 {
  let end_ms = optimize_trace_now_ms()
  if end_ms >= start_ms {
    end_ms - start_ms
  } else {
    0UL
  }
}

///|
fn optimize_trace_context_label(kind : SchedulerPassContextKind) -> String {
  match kind {
    IRContextTransformerPass => "ir-transformer"
    UnitTransformerPass => "unit-transformer"
    ModuleRunnerPass => "module-runner"
  }
}

///|
fn optimize_module_with_options_internal(
  mod : Module,
  passes : Array[ModulePass],
  options : OptimizeOptions,
  trace : (String) -> Unit,
  trace_enabled : Bool,
  trace_pass_details : Bool,
  _trace_module_stats : Bool,
) -> Result[Module, String] {
  let optimize_start_ms = optimize_trace_now_ms()
  if trace_enabled {
    trace("start passes=\{passes.length()}")
  }
  if passes.length() == 0 {
    if trace_enabled {
      trace("done elapsed_ms=\{optimize_trace_elapsed_ms(optimize_start_ms)}")
    }
    return Ok(mod)
  }
  let mut mod = mod
  let ctx = IRContext::new()
  ctx.set_mod(mod)
  let lift_start_ms = optimize_trace_now_ms()
  if trace_enabled {
    trace("lift_to_texpr:start")
  }
  let lift_trace = if trace_enabled && trace_pass_details {
    fn(msg) { trace("lift_to_texpr:\{msg}") }
  } else {
    optimize_trace_noop
  }
  mod = match lift_to_texpr_module_with_trace(mod, lift_trace) {
    Ok(new_mod) => {
      if trace_enabled {
        trace(
          "lift_to_texpr:done elapsed_ms=\{optimize_trace_elapsed_ms(lift_start_ms)}",
        )
      }
      new_mod
    }
    Err(e) => {
      if trace_enabled {
        trace(
          "lift_to_texpr:error elapsed_ms=\{optimize_trace_elapsed_ms(lift_start_ms)} \{e}",
        )
      }
      return Err(e)
    }
  }
  ctx.set_mod(mod)
  let mut pass_index = 0
  for pass in passes {
    let pass_start_ms = optimize_trace_now_ms()
    pass_index += 1
    let kind = module_pass_context_kind(pass)
    if trace_enabled {
      trace(
        "pass[\{pass_index}/\{passes.length()}]:start pass=\{pass} kind=\{optimize_trace_context_label(kind)}",
      )
    }
    ctx.set_mod(mod)
    let pass_trace = if trace_enabled && trace_pass_details {
      fn(msg) { trace("pass[\{pass_index}/\{passes.length()}]:\{msg}") }
    } else {
      optimize_trace_noop
    }
    mod = match kind {
      IRContextTransformerPass =>
        match
          run_ir_context_transformer_scheduler_pass(
            ctx,
            mod,
            pass,
            options,
            pass_trace,
            trace_enabled && trace_pass_details,
          ) {
          Ok(new_mod) => new_mod
          Err(e) => {
            if trace_enabled {
              trace(
                "pass[\{pass_index}/\{passes.length()}]:error elapsed_ms=\{optimize_trace_elapsed_ms(pass_start_ms)} \{e}",
              )
            }
            return Err(e)
          }
        }
      UnitTransformerPass =>
        match
          run_unit_transformer_scheduler_pass(
            mod,
            pass,
            pass_trace,
            trace_enabled && trace_pass_details,
          ) {
          Ok(new_mod) => new_mod
          Err(e) => {
            if trace_enabled {
              trace(
                "pass[\{pass_index}/\{passes.length()}]:error elapsed_ms=\{optimize_trace_elapsed_ms(pass_start_ms)} \{e}",
              )
            }
            return Err(e)
          }
        }
      ModuleRunnerPass =>
        match
          run_module_runner_scheduler_pass(
            mod,
            pass,
            options,
            pass_trace,
            trace_enabled && trace_pass_details,
          ) {
          Ok(new_mod) => new_mod
          Err(e) => {
            if trace_enabled {
              trace(
                "pass[\{pass_index}/\{passes.length()}]:error elapsed_ms=\{optimize_trace_elapsed_ms(pass_start_ms)} \{e}",
              )
            }
            return Err(e)
          }
        }
    }
    if trace_enabled {
      trace(
        "pass[\{pass_index}/\{passes.length()}]:returned pass=\{pass} elapsed_ms=\{optimize_trace_elapsed_ms(pass_start_ms)}",
      )
      trace("pass[\{pass_index}/\{passes.length()}]:commit:start pass=\{pass}")
    }
    ctx.set_mod(mod)
    if trace_enabled {
      trace("pass[\{pass_index}/\{passes.length()}]:commit:done pass=\{pass}")
      trace(
        "pass[\{pass_index}/\{passes.length()}]:done pass=\{pass} elapsed_ms=\{optimize_trace_elapsed_ms(pass_start_ms)}",
      )
    }
  }
  if trace_enabled {
    trace("done elapsed_ms=\{optimize_trace_elapsed_ms(optimize_start_ms)}")
  }
  Ok(mod)
}

///|
pub fn optimize_module_with_options(
  mod : Module,
  passes : Array[ModulePass],
  options : OptimizeOptions,
) -> Result[Module, String] {
  optimize_module_with_options_internal(
    mod, passes, options, optimize_trace_noop, false, false, false,
  )
}

///|
pub fn optimize_module_with_options_trace(
  mod : Module,
  passes : Array[ModulePass],
  options : OptimizeOptions,
  trace : (String) -> Unit,
  trace_pass_details? : Bool = true,
  trace_module_stats? : Bool = false,
) -> Result[Module, String] {
  ignore(trace_module_stats)
  optimize_module_with_options_internal(
    mod, passes, options, trace, true, trace_pass_details, trace_module_stats,
  )
}

///|
priv struct OptimizeCleanupCostProfile {
  func_count : Int
  top_instr_sum : Int
}

///|
fn optimize_cleanup_cost_profile(mod : Module) -> OptimizeCleanupCostProfile {
  let mut func_count = 0
  let mut top_instr_sum = 0
  match mod.code_sec {
    Some(CodeSec(funcs)) => {
      func_count = funcs.length()
      for func in funcs {
        match func {
          TFunc(_, body) => top_instr_sum += body.instrs.length()
          _ => ()
        }
      }
    }
    None => ()
  }
  { func_count, top_instr_sum }
}

///|
fn optimize_should_skip_expensive_cleanup(
  profile : OptimizeCleanupCostProfile,
) -> Bool {
  profile.func_count >= 1200 ||
  (profile.func_count >= 300 && profile.top_instr_sum >= 120000)
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
fn default_opts_skip_second_optimize_instructions(mod : Module) -> Bool {
  optimize_should_skip_expensive_cleanup(optimize_cleanup_cost_profile(mod))
}

///|
pub fn default_function_optimization_passes(
  mod : Module,
  options : OptimizeOptions,
) -> Array[ModulePass] {
  // Intentionally mirrors Binaryen's no-DWARF path.
  let has_gc = default_opts_has_gc_aggregates(mod)
  let has_multivalue = default_opts_has_multivalue(mod)
  let skip_second_optimize_instructions = default_opts_skip_second_optimize_instructions(
    mod,
  )
  let passes : Array[ModulePass] = []

  if options.optimize_level >= 3 || options.shrink_level >= 1 {
    // Binaryen parity mode: ssa-nomerge.
    // Fallback to SSA dataflow simplification in this IR pipeline.
    passes.push(DataflowOptimization)
  }
  if options.optimize_level >= 4 {
    // Binaryen parity mode: flatten.
    passes.push(Flatten)
    // Binaryen parity mode: simplify-locals-notee-nostructure before local-cse.
    passes.push(SimplifyLocalsNoTeeNoStructure)
    passes.push(LocalCSE)
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
  if !skip_second_optimize_instructions {
    passes.push(OptimizeInstructions)
  }
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
          AbstractTypeRefiningPassProps::new(
            traps_never_happen=options.traps_never_happen,
          ),
        ),
      )
      // Binaryen parity mode: unsubtyping.
      passes.push(Unsubtyping)
    }
  }

  passes
}

///|
pub fn default_global_optimization_post_passes(
  mod : Module,
  options : OptimizeOptions,
) -> Array[ModulePass] {
  ignore(mod)
  let passes : Array[ModulePass] = []
  if options.optimize_level >= 2 || options.shrink_level >= 1 {
    passes.push(DeadArgumentEliminationOptimizing)
  }
  if options.optimize_level >= 2 || options.shrink_level >= 2 {
    // Binaryen parity mode: inlining-optimizing (currently skipped because
    // high optimization levels still have known inlining option mismatches on
    // some valid modules).
  }

  passes.push(DuplicateFunctionElimination)
  passes.push(DuplicateImportElimination)

  if options.shrink_level >= 2 {
    passes.push(MergeSimilarFunctions)
  }
  if options.optimize_level >= 2 || options.shrink_level >= 2 {
    passes.push(SimplifyGlobalsOptimizing)
  } else {
    passes.push(SimplifyGlobals)
  }
  passes.push(RemoveUnusedModuleElements)
  if options.optimize_level >= 2 {
    // Binaryen parity mode: string-gathering (not yet implemented).
  }
  if options.optimize_level >= 2 || options.shrink_level >= 1 {
    passes.push(ReorderGlobals)
  }
  // Binaryen's default pass uses directize with initial table contents
  // considered immutable.
  passes.push(Directize(true))
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
fn default_extract_atr_traps_never_happen(passes : Array[ModulePass]) -> Bool? {
  for pass in passes {
    match pass {
      AbstractTypeRefining(props) => return Some(props.traps_never_happen)
      _ => ()
    }
  }
  None
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
fn opt_scheduler_type_merging_dispatch_module() -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([
      single_rec_type(sub_type(false, [], struct_comp_type([]))),
      single_rec_type(sub_type(false, [TypeIdx::new(0)], struct_comp_type([]))),
      single_rec_type(comp_type_sub_type(func_comp_type([], []))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(2)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([TInstr::drop(TInstr::struct_new(TypeIdx::new(1), []))]),
      ),
    ]),
  )
}

///|
fn opt_scheduler_type_merging_trap_sensitive_module() -> Module {
  let func_super = single_rec_type(sub_type(false, [], func_comp_type([], [])))
  let func_sub = single_rec_type(
    sub_type(false, [TypeIdx::new(1)], func_comp_type([], [])),
  )
  Module::new()
  .with_type_sec(
    TypeSec::new([
      single_rec_type(sub_type(false, [], struct_comp_type([]))),
      func_super,
      func_sub,
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(2)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::call_indirect(
            TypeIdx::new(2),
            TableIdx::new(0),
            [],
            TInstr::i32_const(I32(0)),
          ),
        ]),
      ),
      Func::t_func([], TExpr::new([TInstr::nop()])),
    ]),
  )
}

///|
fn opt_scheduler_type_finalizing_dispatch_module() -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([
      single_rec_type(sub_type(false, [], struct_comp_type([]))),
      single_rec_type(sub_type(false, [TypeIdx::new(0)], struct_comp_type([]))),
      single_rec_type(comp_type_sub_type(func_comp_type([], []))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(2)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::ref_null(HeapType::new(TypeIdx::new(0)))],
        TExpr::new([
          TInstr::local_set(
            LocalIdx::new(0),
            TInstr::struct_new(TypeIdx::new(1), []),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn opt_scheduler_descriptor_target_retention_module() -> Module {
  let unused_struct = single_rec_type(comp_type_sub_type(struct_comp_type([])))
  let descriptor_target = single_rec_type(
    comp_type_sub_type(struct_comp_type([])),
  )
  let void_ft = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let typed = Func::t_func(
    [ValType::anyref()],
    TExpr::new([
      TInstr::drop(
        TInstr::ref_test_desc(
          true,
          HeapType::new(TypeIdx::new(1)),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
      TInstr::call(FuncIdx::new(1), []),
    ]),
  )
  let untyped = Func::new(
    [],
    Expr::new([
      Instruction::ref_null(HeapType::abs(AbsHeapType::any())),
      Instruction::ref_cast_desc_eq(true, HeapType::new(TypeIdx::new(1))),
      Instruction::drop(),
    ]),
  )
  Module::new()
  .with_type_sec(TypeSec::new([unused_struct, descriptor_target, void_ft]))
  .with_func_sec(FuncSec::new([TypeIdx::new(2), TypeIdx::new(2)]))
  .with_code_sec(CodeSec::new([typed, untyped]))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
    ]),
  )
}

///|
fn opt_scheduler_type_unfinalizing_dispatch_module() -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([
      single_rec_type(comp_type_sub_type(struct_comp_type([]))),
      single_rec_type(comp_type_sub_type(func_comp_type([], []))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
  .with_code_sec(CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]))
}

///|
fn opt_scheduler_unsubtyping_dispatch_module() -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([
      single_rec_type(sub_type(false, [], struct_comp_type([]))),
      single_rec_type(sub_type(false, [TypeIdx::new(0)], struct_comp_type([]))),
      single_rec_type(sub_type(false, [TypeIdx::new(1)], struct_comp_type([]))),
      single_rec_type(comp_type_sub_type(func_comp_type([], []))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(3)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::ref_null(HeapType::new(TypeIdx::new(0)))],
        TExpr::new([
          TInstr::local_set(
            LocalIdx::new(0),
            TInstr::struct_new(TypeIdx::new(2), []),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn opt_scheduler_run_type_merging_with_traps_never_happen(
  mod : Module,
  traps_never_happen : Bool,
) -> Module raise {
  let options = OptimizeOptions::new(traps_never_happen~)
  match optimize_module_with_options(mod, [TypeMerging], options) {
    Ok(out) => out
    Err(e) => fail("unexpected optimize_module_with_options error: \{e}")
  }
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
fn opt_scheduler_count_descriptor_target_uses(
  mod : Module,
  target : UInt,
) -> Int {
  let mut count = 0
  let walker = ModuleTransformer::new()
    .on_tinstruction_evt(fn(self, _, instr) {
      match instr.kind {
        TInstrKind::TRefTestDesc(_, HeapType(TypeIdx(i)), _)
        | TInstrKind::TRefCastDescEq(_, HeapType(TypeIdx(i)), _) =>
          if i == target {
            count += 1
          }
        _ => ()
      }
      self.walk_tinstruction_default((), instr)
    })
    .on_instruction_evt(fn(self, _, instr) {
      match instr {
        RefTestDesc(_, HeapType(TypeIdx(i)))
        | RefCastDescEq(_, HeapType(TypeIdx(i))) =>
          if i == target {
            count += 1
          }
        _ => ()
      }
      self.walk_instruction_default((), instr)
    })
  ignore(walker.walk_module((), mod))
  count
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
test "default function optimization passes omit rereloop mode at optimize_level=4" {
  let passes = default_function_optimization_passes(
    Module::new(),
    OptimizeOptions::new(optimize_level=4),
  )
  let rereloop_idx = default_first_module_pass_index(passes, fn(pass) {
    match pass {
      ReReloop => true
      _ => false
    }
  })
  let dce_idx = default_first_module_pass_index(passes, fn(pass) {
    match pass {
      DeadCodeElimination => true
      _ => false
    }
  })
  assert_eq(rereloop_idx, -1)
  assert_true(dce_idx >= 0)
}

///|
test "default function optimization passes preserve flatten simplify-local-cse order at optimize_level=4" {
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
  let simplify_idx = default_first_module_pass_index(passes, fn(pass) {
    match pass {
      SimplifyLocalsNoTeeNoStructure => true
      _ => false
    }
  })
  assert_true(flatten_idx >= 0)
  assert_true(cse_idx >= 0)
  assert_true(simplify_idx >= 0)
  assert_true(flatten_idx < cse_idx)
  assert_true(flatten_idx < simplify_idx)
  assert_true(simplify_idx < cse_idx)
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
test "default global optimization pre passes include memory packing when multiple data segments exist" {
  let mod = Module::new().with_data_sec(
    DataSec::new([
      Data::new(DataMode::passive(), b"\x00"),
      Data::new(DataMode::passive(), b"\x01"),
    ]),
  )
  let passes = default_global_optimization_pre_passes(
    mod,
    OptimizeOptions::new(optimize_level=0),
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
}

///|
test "default global optimization pre passes include once reduction at optimize_level=2" {
  let mod = Module::new()
  let passes = default_global_optimization_pre_passes(
    mod,
    OptimizeOptions::new(optimize_level=2),
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        OnceReduction => true
        _ => false
      }
    }),
    1,
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
test "default global optimization pre passes map unsubtyping mode to unsubtyping pass" {
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
        Unsubtyping => true
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
      Unsubtyping => true
      _ => false
    }
  })
  assert_true(abstract_idx >= 0)
  assert_true(unsubtyping_idx >= 0)
  assert_true(abstract_idx < unsubtyping_idx)
}

///|
test "default global optimization pre passes thread traps_never_happen into AbstractTypeRefining props" {
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
  let default_passes = default_global_optimization_pre_passes(
    gc_mod,
    OptimizeOptions::new(optimize_level=2, traps_never_happen=false),
  )
  assert_eq(default_extract_atr_traps_never_happen(default_passes), Some(false))

  let tnh_passes = default_global_optimization_pre_passes(
    gc_mod,
    OptimizeOptions::new(optimize_level=2, traps_never_happen=true),
  )
  assert_eq(default_extract_atr_traps_never_happen(tnh_passes), Some(true))
}

///|
test "default global optimization pre passes omit generate-global-effects mode" {
  let passes = default_global_optimization_pre_passes(
    Module::new(),
    OptimizeOptions::new(optimize_level=0),
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        GlobalEffects => true
        _ => false
      }
    }),
    0,
  )
}

///|
test "default global optimization post passes include binaryen-parity defaults" {
  let passes = default_global_optimization_post_passes(
    Module::new(),
    OptimizeOptions::new(optimize_level=2, shrink_level=2),
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        DeadArgumentElimination => true
        _ => false
      }
    }),
    0,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        DeadArgumentEliminationOptimizing => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        InliningOptimizing => true
        _ => false
      }
    }),
    0,
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
        DuplicateImportElimination => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        MergeSimilarFunctions => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        SimplifyGlobalsOptimizing => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        RemoveUnusedModuleElements => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        ReorderGlobals => true
        _ => false
      }
    }),
    1,
  )
  assert_eq(
    default_count_module_passes(passes, fn(pass) {
      match pass {
        Directize(true) => true
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
  assert_true(assert_pass_context_kind(ReReloop, IRContextTransformerPass))
  assert_true(assert_pass_context_kind(GlobalEffects, IRContextTransformerPass))
  assert_true(
    assert_pass_context_kind(DeadCodeElimination, UnitTransformerPass),
  )
  assert_true(assert_pass_context_kind(DeNaN, IRContextTransformerPass))
  assert_true(assert_pass_context_kind(RemoveUnused, IRContextTransformerPass))
  assert_true(
    assert_pass_context_kind(
      RemoveUnusedModuleElements,
      IRContextTransformerPass,
    ),
  )
  assert_true(
    assert_pass_context_kind(
      RemoveUnusedNonFunctionElements,
      IRContextTransformerPass,
    ),
  )
  assert_true(assert_pass_context_kind(TypeGeneralizing, ModuleRunnerPass))
  assert_true(assert_pass_context_kind(TypeFinalizing, ModuleRunnerPass))
  assert_true(assert_pass_context_kind(TypeUnFinalizing, ModuleRunnerPass))
  assert_true(assert_pass_context_kind(Unsubtyping, ModuleRunnerPass))
  assert_true(assert_pass_context_kind(TypeMerging, ModuleRunnerPass))
}

///|
test "optimize_module_with_options_trace skips lift_to_texpr when pass list is empty" {
  let trace_logs : Array[String] = []
  let mod = Module::new()
  let out = match
    optimize_module_with_options_trace(mod, [], OptimizeOptions::new(), fn(
      msg,
    ) {
      trace_logs.push(msg)
    }) {
    Ok(v) => v
    Err(e) => fail("unexpected optimize_module_with_options_trace error: \{e}")
  }
  assert_eq(out, mod)
  let mut saw_lift = false
  for msg in trace_logs {
    if msg.contains("lift_to_texpr") {
      saw_lift = true
    }
  }
  assert_true(!saw_lift)
}

///|
test "optimize_module_with_options_trace emits dead argument elimination details" {
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
  let trace_logs : Array[String] = []
  ignore(
    match
      optimize_module_with_options_trace(
        mod,
        [DeadArgumentElimination],
        OptimizeOptions::new(),
        fn(msg) { trace_logs.push(msg) },
        trace_pass_details=true,
        trace_module_stats=false,
      ) {
      Ok(v) => v
      Err(e) =>
        fail(
          "unexpected optimize_module_with_options_trace dead argument elimination error: \{e}",
        )
    },
  )
  let mut saw_iter = false
  let mut saw_hotspots = false
  let mut saw_analysis_phase = false
  let mut saw_rewrite_phase = false
  for msg in trace_logs {
    if msg.contains("dead_argument_elim:iter=0") {
      saw_iter = true
    }
    if msg.contains("dead_argument_elim:iter=0 slow_analysis_funcs=") {
      saw_hotspots = true
    }
    if msg.contains("dead_argument_elim:iter=0 phase=analysis:start") {
      saw_analysis_phase = true
    }
    if msg.contains("dead_argument_elim:iter=0 phase=rewrite:done") {
      saw_rewrite_phase = true
    }
  }
  assert_true(saw_iter)
  assert_true(saw_hotspots)
  assert_true(saw_analysis_phase)
  assert_true(saw_rewrite_phase)
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
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TBlock(
                    _,
                    {
                      instrs: [{ kind: TInstrKind::TI32Const(I32(5)), .. }],
                      ..,
                    }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
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
    Some(
      CodeSec(
        [TFunc(_, { instrs: [{ kind: TInstrKind::TUnreachable, .. }], .. })]
      )
    ) => ()
    _ => fail("expected DeadCodeElimination to run through Unit dispatch")
  }
}

///|
test "optimize_module dispatches DeNaN through IRContext kind" {
  assert_true(assert_pass_context_kind(DeNaN, IRContextTransformerPass))
  let mod = opt_scheduler_denan_dispatch_module()
  let optimized = match optimize_module(mod, [DeNaN]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            { instrs: [{ kind: TInstrKind::TF32Const(F32(v)), .. }], .. }
          ),
        ]
      )
    ) => assert_eq(v, 0.0)
    _ => fail("expected DeNaN to sanitize NaN constants via IRContext dispatch")
  }
}

///|
test "optimize_module runs GlobalEffects pass through IRContext kind" {
  assert_true(assert_pass_context_kind(GlobalEffects, IRContextTransformerPass))
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(0), [])])),
    ]),
  )
  let optimized = match optimize_module(mod, [GlobalEffects]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            { instrs: [{ kind: TInstrKind::TCall(FuncIdx(i), []), .. }], .. }
          ),
        ]
      )
    ) => assert_eq(i, 0U)
    _ => fail("expected GlobalEffects to preserve module body")
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
test "optimize_module dispatches TypeFinalizing through module-runner kind" {
  assert_true(assert_pass_context_kind(TypeFinalizing, ModuleRunnerPass))
  let mod = opt_scheduler_type_finalizing_dispatch_module()
  let optimized = match optimize_module(mod, [TypeFinalizing]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.type_sec {
    Some(
      TypeSec(
        [
          SingleRecType(SubType(root_final, _, _)),
          SingleRecType(SubType(child_final, _, _)),
          ..,
        ]
      )
    ) => {
      assert_false(root_final)
      assert_true(child_final)
    }
    _ => fail("expected TypeFinalizing to finalize private leaf types")
  }
}

///|
test "optimize_module dispatches TypeUnFinalizing through module-runner kind" {
  assert_true(assert_pass_context_kind(TypeUnFinalizing, ModuleRunnerPass))
  let mod = opt_scheduler_type_unfinalizing_dispatch_module()
  let optimized = match optimize_module(mod, [TypeUnFinalizing]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.type_sec {
    Some(TypeSec([SingleRecType(SubType(final_, _, _)), ..])) =>
      assert_false(final_)
    _ => fail("expected TypeUnFinalizing to open private final types")
  }
}

///|
test "optimize_module dispatches Unsubtyping through module-runner kind" {
  assert_true(assert_pass_context_kind(Unsubtyping, ModuleRunnerPass))
  let mod = opt_scheduler_unsubtyping_dispatch_module()
  let optimized = match optimize_module(mod, [Unsubtyping]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.type_sec {
    Some(TypeSec([_, _, SingleRecType(SubType(_, [TypeIdx(i)], _)), ..])) =>
      assert_eq(i, 0U)
    _ => fail("expected Unsubtyping to bypass unneeded intermediate supertypes")
  }
}

///|
test "optimize_module dispatches TypeMerging through module-runner kind" {
  assert_true(assert_pass_context_kind(TypeMerging, ModuleRunnerPass))
  let mod = opt_scheduler_type_merging_dispatch_module()
  let optimized = match optimize_module(mod, [TypeMerging]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    { kind: TInstrKind::TStructNew(TypeIdx(0), []), .. }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
    _ => fail("expected TypeMerging to run through module-runner dispatch")
  }
}

///|
test "optimize_module_with_options threads traps_never_happen into TypeMerging" {
  let mod = opt_scheduler_type_merging_trap_sensitive_module()
  let out_default = opt_scheduler_run_type_merging_with_traps_never_happen(
    mod, false,
  )
  match out_default.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                { kind: TInstrKind::TCallIndirect(TypeIdx(2), _, _, _), .. },
              ],
              ..,
            }
          ),
          ..,
        ]
      )
    ) => ()
    _ => fail("expected call_indirect type to remain when traps may happen")
  }

  let out_tnh = opt_scheduler_run_type_merging_with_traps_never_happen(
    mod, true,
  )
  let mut merged_type_idx : UInt? = None
  match out_tnh.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                { kind: TInstrKind::TCallIndirect(TypeIdx(i), _, _, _), .. },
              ],
              ..,
            }
          ),
          ..,
        ]
      )
    ) => merged_type_idx = Some(i)
    _ =>
      fail(
        "expected call_indirect to remain present after scheduler TypeMerging",
      )
  }
  match (out_tnh.func_sec, merged_type_idx) {
    (Some(FuncSec([TypeIdx(main_i), TypeIdx(callee_i)])), Some(call_i)) => {
      assert_eq(main_i, callee_i)
      assert_eq(call_i, main_i)
      assert_true(call_i != 2U)
    }
    _ =>
      fail(
        "expected scheduler TypeMerging to merge call_indirect type when traps_never_happen",
      )
  }
}

///|
test "optimize_module dispatches closed-world vs open-world remove_unused modes" {
  assert_true(assert_pass_context_kind(RemoveUnused, IRContextTransformerPass))
  assert_true(
    assert_pass_context_kind(
      RemoveUnusedModuleElements,
      IRContextTransformerPass,
    ),
  )
  assert_true(
    assert_pass_context_kind(
      RemoveUnusedNonFunctionElements,
      IRContextTransformerPass,
    ),
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
test "optimize_module keeps descriptor-target-only types through remove-unused scheduling with mixed typed and untyped inputs" {
  let mod = opt_scheduler_descriptor_target_retention_module()
  let after_remove_unused = match optimize_module(mod, [RemoveUnused]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module remove_unused error: \{e}")
  }
  match after_remove_unused.type_sec {
    Some(TypeSec([SingleRecType(st0), SingleRecType(st1)])) => {
      match st0.get_comptype() {
        StructCompType(_) => ()
        _ => fail("expected remapped descriptor target type to stay at index 0")
      }
      match st1.get_comptype() {
        FuncCompType(_, _) => ()
        _ =>
          fail("expected function signature type to be remapped after struct")
      }
    }
    Some(TypeSec(recs)) => assert_eq(recs.length(), 2)
    None => fail("expected type section after RemoveUnused")
  }
  assert_eq(
    opt_scheduler_count_descriptor_target_uses(after_remove_unused, 0U),
    2,
  )
  assert_eq(
    opt_scheduler_count_descriptor_target_uses(after_remove_unused, 1U),
    0,
  )
  let optimized = match
    optimize_module(mod, [RemoveUnused, RemoveUnusedTypes]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.type_sec {
    Some(TypeSec(recs)) => assert_eq(recs.length(), 2)
    None => fail("expected type section after remove-unused scheduling")
  }
  match optimized.func_sec {
    Some(FuncSec([TypeIdx(main_ty), TypeIdx(helper_ty)])) => {
      assert_eq(main_ty, 1U)
      assert_eq(helper_ty, 1U)
    }
    _ => fail("expected function signature indices to be remapped")
  }
  assert_eq(opt_scheduler_count_descriptor_target_uses(optimized, 0U), 2)
  match validate_module(optimized) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected remove-unused scheduler descriptor-target retention output to validate: \{e}",
      )
  }
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
    TFunc(_, { instrs, .. }) =>
      match instrs[0].kind {
        TInstrKind::TLoad(LoadOp::I32LoadOp, _, _) => ()
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
    Some(CodeSec([TFunc(_, { instrs, .. }), _])) => {
      let mut found = false
      for instr in instrs {
        match instr.kind {
          TInstrKind::TCall(_, args) => {
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
test "optimize_module runs DeadArgumentEliminationOptimizing cleanup" {
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(TInstr::call(FuncIdx::new(1), [])),
      TInstr::return_([]),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        single_rec_type(comp_type_sub_type(func_comp_type([], []))),
        single_rec_type(
          comp_type_sub_type(func_comp_type([], [ValType::i32()])),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = match
    optimize_module(mod, [DeadArgumentEliminationOptimizing]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([_, TFunc(_, { instrs, .. })])) =>
      match instrs {
        [{ kind: TInstrKind::TNop, .. }] => ()
        _ => fail("expected optimizing DAE to clean up pure dropped result")
      }
    _ => fail("expected transformed callee body")
  }
}

///|
test "optimize_module_with_options_trace skips DAE optimizing cleanup on large modules" {
  let void_type = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let func_types : Array[TypeIdx] = []
  let funcs : Array[Func] = []
  for _ in 0..<1200 {
    func_types.push(TypeIdx::new(0))
    funcs.push(Func::t_func([], TExpr::new([TInstr::nop()])))
  }
  let mod = Module::new()
    .with_type_sec(TypeSec::new([void_type]))
    .with_func_sec(FuncSec::new(func_types))
    .with_code_sec(CodeSec::new(funcs))
  let trace_logs : Array[String] = []
  ignore(
    match
      optimize_module_with_options_trace(
        mod,
        [DeadArgumentEliminationOptimizing],
        OptimizeOptions::new(),
        fn(msg) { trace_logs.push(msg) },
        trace_pass_details=true,
        trace_module_stats=false,
      ) {
      Ok(v) => v
      Err(e) =>
        fail(
          "unexpected optimize_module_with_options_trace DAE optimizing error: \{e}",
        )
    },
  )
  let mut saw_skip = false
  let mut saw_dce_start = false
  let mut saw_vacuum = false
  for msg in trace_logs {
    if msg.contains("dead_argument_elim_cleanup:skip reason=module_size") {
      saw_skip = true
    }
    if msg.contains("dead_argument_elim_cleanup:dce:start") {
      saw_dce_start = true
    }
    if msg.contains("vacuum:") {
      saw_vacuum = true
    }
  }
  assert_true(saw_skip)
  assert_true(!saw_dce_start)
  assert_true(!saw_vacuum)
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
    Some(CodeSec([TFunc(_, { instrs, .. }), _])) => {
      let mut found = false
      for instr in instrs {
        match instr.kind {
          TInstrKind::TCall(_, args) => {
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
    Some(
      CodeSec(
        [TFunc(_, { instrs: [{ kind: TInstrKind::TUnreachable, .. }], .. })]
      )
    ) => ()
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
    Some(
      CodeSec(
        [
          TFunc(
            _,
            { instrs: [{ kind: TInstrKind::TCall(FuncIdx(i), []), .. }], .. }
          ),
        ]
      )
    ) => assert_eq(i, 0U)
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
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    {
                      kind: TInstrKind::TBlock(
                        _,
                        {
                          instrs: [
                            {
                              kind: TInstrKind::TDrop(
                                { kind: TInstrKind::TRefAsNonNull(_), .. }
                              ),
                              ..,
                            },
                            { kind: TInstrKind::TI32Const(I32(v)), .. },
                          ],
                          ..,
                        }
                      ),
                      ..,
                    }
                  ),
                  ..,
                },
              ],
              ..,
            }
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
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    {
                      kind: TInstrKind::TBlock(
                        _,
                        {
                          instrs: [
                            {
                              kind: TInstrKind::TDrop(
                                { kind: TInstrKind::TRefAsNonNull(_), .. }
                              ),
                              ..,
                            },
                            { kind: TInstrKind::TI32Const(I32(v)), .. },
                          ],
                          ..,
                        }
                      ),
                      ..,
                    }
                  ),
                  ..,
                },
              ],
              ..,
            }
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
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    {
                      kind: TInstrKind::TRefCastDescEq(
                        false,
                        HeapType(TypeIdx(i)),
                        _
                      ),
                      ..,
                    }
                  ),
                  ..,
                },
              ],
              ..,
            }
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
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    {
                      kind: TInstrKind::TSelect(
                        Some([NumTypeValType(I32NumType)]),
                        { kind: TInstrKind::TRefEq(_, _), .. },
                        { kind: TInstrKind::TRefGetDesc(_), .. },
                        { kind: TInstrKind::TRefGetDesc(_), .. }
                      ),
                      ..,
                    }
                  ),
                  ..,
                },
              ],
              ..,
            }
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
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TLocalSet(
                    _,
                    { kind: TInstrKind::TLoad(I32Load16UOp, _, _), .. }
                  ),
                  ..,
                },
                _,
              ],
              ..,
            }
          ),
        ]
      )
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
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    { kind: TInstrKind::TBlock(_, { instrs: seq, .. }), .. }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
          _,
          _,
        ]
      )
    ) =>
      match seq[seq.length() - 1].kind {
        TInstrKind::TI32Const(I32(v)) => assert_eq(v, 0)
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
    Some(CodeSec([TFunc(_, { instrs, .. })])) => {
      assert_eq(instrs.length(), 1)
      match instrs[0].kind {
        TInstrKind::TUnreachable => ()
        TInstrKind::TDrop(
          { kind: TInstrKind::TBlock(_, { instrs: seq, .. }), .. }
        ) =>
          match seq[seq.length() - 1].kind {
            TInstrKind::TUnreachable => ()
            _ => fail("expected impossible cast to become unreachable")
          }
        TInstrKind::TBlock(_, { instrs: seq, .. }) =>
          match seq[seq.length() - 1].kind {
            TInstrKind::TUnreachable => ()
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
    Some(
      CodeSec(
        [TFunc(_, { instrs: [{ kind: TInstrKind::TDrop(instr), .. }], .. })]
      )
    ) =>
      match instr.kind {
        TInstrKind::TRefCast(
          false,
          HeapType(TypeIdx(i)),
          { kind: TInstrKind::TGlobalGet(GlobalIdx(g)), .. }
        ) => {
          assert_eq(i.reinterpret_as_int(), 0)
          assert_eq(g.reinterpret_as_int(), 0)
        }
        TInstrKind::TRefCast(
          false,
          HeapType(TypeIdx(i)),
          { kind: TInstrKind::TRefFunc(FuncIdx(f)), .. }
        ) => {
          assert_eq(i.reinterpret_as_int(), 0)
          assert_eq(f.reinterpret_as_int(), 0)
        }
        TInstrKind::TRefFunc(FuncIdx(f)) => assert_eq(f.reinterpret_as_int(), 0)
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
test "optimize_module I64ToI32Lowering precondition gates imported i64 globals" {
  let mod = Module::new().with_import_sec(
    ImportSec::new([
      Import::new(
        Name::new("m"),
        Name::new("g"),
        ExternType::global(GlobalType::new(ValType::i64(), false)),
      ),
    ]),
  )
  match optimize_module(mod, [I64ToI32Lowering]) {
    Ok(_) => fail("expected optimize scheduler i64 precondition error")
    Err(e) => {
      assert_true(
        e.contains(
          "optimize scheduler: i64_to_i32_lowering precondition failed",
        ),
      )
      assert_true(e.contains("imported i64 globals are unsupported"))
    }
  }
}

///|
test "optimize_module I64ToI32Lowering precondition gates multi-value i64 results" {
  let ty = single_rec_type(
    comp_type_sub_type(
      func_comp_type([ValType::i32()], [ValType::i64(), ValType::i32()]),
    ),
  )
  let mod = Module::new().with_type_sec(TypeSec::new([ty]))
  match optimize_module(mod, [I64ToI32Lowering]) {
    Ok(_) => fail("expected optimize scheduler i64 precondition error")
    Err(e) => {
      assert_true(
        e.contains(
          "optimize scheduler: i64_to_i32_lowering precondition failed",
        ),
      )
      assert_true(e.contains("multi-value i64 results"))
    }
  }
}

///|
test "optimize_module I64ToI32Lowering precondition gates unsupported i64 global init roots" {
  let mod = Module::new().with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(ValType::i64(), false),
        Expr::new([
          Instruction::i64_const(I64(1L)),
          Instruction::i64_const(I64(2L)),
          Instruction::i64_add(),
        ]),
      ),
    ]),
  )
  match optimize_module(mod, [I64ToI32Lowering]) {
    Ok(_) => fail("expected optimize scheduler i64 precondition error")
    Err(e) => {
      assert_true(
        e.contains(
          "optimize scheduler: i64_to_i32_lowering precondition failed",
        ),
      )
      assert_true(e.contains("unsupported i64 global init"))
    }
  }
}

///|
test "optimize_module I64ToI32Lowering avoids duplicate global precondition rewrite scans" {
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
  i64l_test_reset_rewrite_globals_counter()
  match optimize_module(mod, [I64ToI32Lowering]) {
    Ok(_) => ()
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  assert_eq(i64l_test_get_rewrite_globals_counter(), 1)
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
    Some(CodeSec([TFunc(_, { instrs, .. })])) => {
      let mut found = false
      for instr in instrs {
        match instr.kind {
          TInstrKind::TLocalSet(_, { kind: TInstrKind::TI32Const(I32(42)), .. }) =>
            found = true
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
        match instr.kind {
          TInstrKind::TCall(FuncIdx(raw), _) =>
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
        match instr.kind {
          TInstrKind::TCall(FuncIdx(raw), _) =>
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
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                { kind: TInstrKind::TLocalSet(_, _), .. },
                { kind: TInstrKind::TDrop(_), .. },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
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
    Some(CodeSec([TFunc(_, { instrs: [{ kind: TInstrKind::TNop, .. }], .. })])) =>
      ()
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
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                { kind: TInstrKind::TBlock(_, { instrs: items, .. }), .. },
              ],
              ..,
            }
          ),
        ]
      )
    ) =>
      match items {
        [
          { kind: TInstrKind::TLocalSet(_, _), .. },
          { kind: TInstrKind::TLoop(_, _), .. },
        ] => ()
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
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    { kind: TInstrKind::TI32Const(I32(9)), .. }
                  ),
                  ..,
                },
                { kind: TInstrKind::TNop, .. },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
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
test "optimize_module runs ReReloop pass" {
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
  let optimized = match optimize_module(mod, [ReReloop]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    { kind: TInstrKind::TI32Const(I32(9)), .. }
                  ),
                  ..,
                },
                { kind: TInstrKind::TNop, .. },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
    _ => fail("expected rerelooped function body")
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
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TLocalSet(
                    LocalIdx(i),
                    { kind: TInstrKind::TI32Const(I32(set_v)), .. }
                  ),
                  ..,
                },
                {
                  kind: TInstrKind::TBinary(
                    I32AddOp,
                    { kind: TInstrKind::TLocalGet(LocalIdx(get_i)), .. },
                    { kind: TInstrKind::TI32Const(I32(add_v)), .. }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => {
      assert_eq(i, 0U)
      assert_eq(set_v, 9)
      assert_eq(get_i, 0U)
      assert_eq(add_v, 1)
    }
    _ =>
      fail(
        "expected tiny-body strict gating to preserve local_set + local_get add",
      )
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
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TBlock(
                    _,
                    {
                      instrs: [{ kind: TInstrKind::TI32Const(I32(1)), .. }],
                      ..,
                    }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
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
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TBlock(
                    _,
                    {
                      instrs: [{ kind: TInstrKind::TI32Const(I32(5)), .. }],
                      ..,
                    }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
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
    Some(CodeSec([TFunc(_, { instrs, .. })])) =>
      match instrs {
        [
          {
            kind: TInstrKind::TDrop({ kind: TInstrKind::TI32Const(I32(v)), .. }),
            ..,
          },
        ] => assert_eq(v, 42)
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
    Some(
      CodeSec(
        [TFunc(_, { instrs: [{ kind: TInstrKind::TNop, .. }], .. }), _, _]
      )
    ) => ()
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
    Some(CodeSec([TFunc(locals, { instrs, .. })])) => {
      assert_eq(locals, [ValType::i64()])
      match instrs {
        [
          {
            kind: TInstrKind::TDrop(
              { kind: TInstrKind::TLocalGet(LocalIdx(i0)), .. }
            ),
            ..,
          },
          {
            kind: TInstrKind::TDrop(
              { kind: TInstrKind::TLocalGet(LocalIdx(i1)), .. }
            ),
            ..,
          },
        ] => {
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
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    { kind: TInstrKind::TStructNew(TypeIdx(i0), []), .. }
                  ),
                  ..,
                },
                ..,
              ],
              ..,
            }
          ),
        ]
      )
    ) => assert_true(i0 < 128U)
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
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    { kind: TInstrKind::TI32Const(I32(v)), .. }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => assert_eq(v, 9)
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
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    { kind: TInstrKind::TI32Const(I32(9)), .. }
                  ),
                  ..,
                },
                { kind: TInstrKind::TNop, .. },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
    _ => fail("merge_blocks: expected merged block body")
  }
}

///|
test "pass invariant: re_reloop validates and remap is stable" {
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
  let out = opt_assert_pass_invariant(mod, ReReloop, "re_reloop")
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    { kind: TInstrKind::TI32Const(I32(9)), .. }
                  ),
                  ..,
                },
                { kind: TInstrKind::TNop, .. },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
    _ => fail("re_reloop: expected rerelooped body")
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
    Some(CodeSec([TFunc(_, { instrs: [{ kind: TInstrKind::TNop, .. }], .. })])) =>
      ()
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
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TBinary(
                    I32AddOp,
                    { kind: TInstrKind::TI32Const(I32(a)), .. },
                    { kind: TInstrKind::TI32Const(I32(b)), .. }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => {
      assert_eq(a, 1)
      assert_eq(b, 2)
    }
    _ => fail("precompute: expected strict gating to preserve tiny body")
  }
}
