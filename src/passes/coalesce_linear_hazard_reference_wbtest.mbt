///|
fn cl_linear_hazard_reference_compute(
  instrs : Array[@lib.Instruction],
  actions : Array[CLAction],
  liveness : CLLiveness,
  types : Array[@lib.ValType],
  param_count : Int32,
) -> CLBitMatrix {
  let interferences = cl_compute_interferences(
    actions, liveness, types, param_count,
  )
  cl_add_entry_value_interferences(actions, types, param_count, interferences)
  // Value-equivalent copy chains may share an abstract value, but a later
  // write still cannot reuse that slot while a copied destination remains
  // live. Make this semantic hazard authoritative before coloring.
  cl_add_source_write_dest_read_interferences(
    instrs,
    actions,
    liveness.effective,
    types,
    param_count,
    interferences,
  )
  cl_remove_read_only_default_interferences(
    actions, types, param_count, interferences,
  )
  interferences
}

///|
fn cl_linear_hazard_reference_rewrite(
  func : @lib.Func,
  params : Array[@lib.ValType],
) -> CLFuncRewrite {
  let @lib.Func(body_locals, body) = func
  let body_local_count = body_locals.length()
  if body_local_count == 0 {
    return { func, changed: false, }
  }
  let @lib.Expr(original_instrs) = body
  match cl_rewrite_single_body_local_param_fast(func, params).0 {
    Some(rewrite) => return rewrite
    None => ()
  }
  // Exact linear copy chains are common after lowering and can be rewritten
  // without the general all-unused scan or dense interference machinery.
  match cl_rewrite_linear_copy_chain_fast(func, params) {
    Some(rewrite) => return rewrite
    None => ()
  }
  match cl_rewrite_all_unused_func(func, params) {
    Some(rewrite) => return rewrite
    None => ()
  }
  if cl_instrs_have_legacy_try(original_instrs) {
    return cl_rewrite_legacy_func_safe(func, params)
  }
  // The flattened conservative liveness model is not path/iteration-sensitive
  // enough for loops. Non-loop structured control uses an extra plain-liveness
  // interference pass, so local.tee branch values may still share proven-dead
  // compatible slots without admitting path-sensitive overlap.
  if cl_instrs_have_loop_control(original_instrs) {
    return cl_cleanup_never_read_tees(
      cl_rewrite_loop_func_unused_locals(func, params),
      params.length(),
    )
  }
  if params.length() + body_local_count > cl_dense_coloring_local_limit() {
    return { func, changed: false, }
  }
  let has_structured_control = cl_instrs_have_structured_control(
    original_instrs,
  )
  if has_structured_control {
    if cl_should_use_dense_tee_structured_intervals(
        body_local_count, original_instrs,
      ) {
      return cl_rewrite_dense_tee_structured_intervals(func, params)
    }
    return cl_rewrite_func_structured_conservative(func, params)
  }
  let types = cl_all_local_types(params, body_locals)
  let total_locals = types.length()
  let actions : Array[CLAction] = []
  cl_collect_instrs(original_instrs, actions, total_locals)
  let liveness = cl_compute_liveness(actions, total_locals)
  let interferences = cl_linear_hazard_reference_compute(
    original_instrs,
    actions,
    liveness,
    types,
    params.length(),
  )
  let weights = cl_copy_weights(actions, liveness.effective, total_locals)
  let preferred = cl_preferred_compaction_flags(original_instrs, actions, types)
  let retained_copy_destinations = cl_retained_copy_destination_flags(
    actions,
    types,
    params.length(),
  )
  let structured_scalar_preferred = cl_structured_scalar_compaction_flags(
    original_instrs,
    actions,
    types,
    params.length(),
  )
  let coloring = cl_pick_coloring(
    types,
    params.length(),
    interferences,
    weights,
    preferred,
    retained_copy_destinations,
    structured_scalar_preferred,
  )
  let rewritten_locals = @lib.Locals::from_types(coloring.slot_types)
  let rewritten_instrs = original_instrs.copy()
  cl_rewrite_instrs_in_place(
    rewritten_instrs,
    coloring.old_to_new,
    liveness.effective,
    [0],
  )
  let ineffective_tee_changed = cl_remove_ineffective_tees(
    rewritten_instrs,
    original_instrs,
    liveness.effective,
    [0],
  )
  let rewrite_changed = rewritten_instrs != original_instrs
  let dead_tail_changed = cl_truncate_dead_tails(rewritten_instrs)
  let cleanup_changed = cl_remove_redundant_copy_pairs(rewritten_instrs)
  let changed = rewrite_changed ||
    ineffective_tee_changed ||
    dead_tail_changed ||
    cleanup_changed ||
    !cl_old_to_new_is_identity(coloring.old_to_new) ||
    rewritten_locals != body_locals
  if !changed {
    return { func, changed: false, }
  }
  {
    func: @lib.Func::new(rewritten_locals, @lib.Expr::new(rewritten_instrs)),
    changed: true,
  }
}

///|
fn cl_linear_hazard_reference_module(mod_ : @lib.Module) -> @lib.Module {
  if pass_module_has_offset_sensitive_metadata(mod_) {
    return mod_
  }
  ignore(cl_imported_func_count(mod_))
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      if funcs.is_empty() {
        return mod_
      }
      let defined_func_params = cl_defined_func_param_cache(mod_)
      let hot_context = @ir.hot_module_context_from_module(mod_)
      let imported_func_count = cl_imported_func_count(mod_)
      let observable_assemblyscript_memory = run_hot_pipeline_module_has_assemblyscript_json_exported_memory_runtime(
          mod_,
        ) ||
        run_hot_pipeline_module_has_assemblyscript_run_exported_memory_runtime(
          mod_,
        ) ||
        run_hot_pipeline_module_has_assemblyscript_startup_exported_memory(mod_)
      let rewritten_funcs : Array[@lib.Func] = Array(
        capacity=funcs.length(),
      )
      let changed_code_indices : Array[Int32] = []
      for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
        let params = match defined_func_params.get(code_idx) {
          Some(params) => params
          None => abort("coalesce-locals missing defined function params")
        }
        let @lib.Func(body_locals, @lib.Expr(instrs)) = funcs[code_idx]
        if !cl_func_may_have_coalesce_candidate(body_locals, instrs) {
          rewritten_funcs.push(funcs[code_idx])
          continue
        }
        let has_stack_carried_overwrite = run_hot_pipeline_raw_precompute_has_stack_carried_overwritten_local(
          instrs,
        )
        let has_stack_carried_tee_alias = cl_instrs_have_stack_carried_tee_parameter_alias(
          instrs,
          params.length(),
        )
        let has_snapshot_parameter_write = cl_snapshot_guard_preflight(
            instrs,
            params.length(),
          ) &&
          cl_instrs_have_local_snapshot_across_parameter_write(
            instrs,
            params.length(),
          )
        let has_observable_memory_mesh = observable_assemblyscript_memory &&
          cl_instrs_have_memory_size_tee_parameter_write(
            instrs,
            params.length(),
          )
        if has_stack_carried_overwrite ||
          has_stack_carried_tee_alias ||
          has_snapshot_parameter_write ||
          has_observable_memory_mesh {
          rewritten_funcs.push(funcs[code_idx])
          continue
        }
        if params.length() > 0 &&
          body_locals.length() <= 32 &&
          cl_locals_have_dense_v128_carriers(body_locals) &&
          cl_instrs_have_loop_control(instrs) {
          rewritten_funcs.push(funcs[code_idx])
          continue
        }
        if funcs.length() >= 32 &&
          params.length() > 0 &&
          body_locals.length() >= 16 &&
          cl_locals_have_nondefaultable_type(body_locals) &&
          cl_instrs_have_structured_control(instrs) {
          rewritten_funcs.push(funcs[code_idx])
          continue
        }
        let cfg_rewrite = if cl_instrs_have_loop_control(instrs) {
          cl_rewrite_loop_func_cfg(
            mod_,
            @lib.FuncIdx::new(
              (imported_func_count + code_idx).reinterpret_as_uint(),
            ),
            hot_context,
            funcs[code_idx],
            params,
          )
        } else {
          { func: funcs[code_idx], changed: false, }
        }
        let rewrite_input = if cfg_rewrite.changed {
          cfg_rewrite.func
        } else {
          funcs[code_idx]
        }
        let cleanup_rewrite = cl_cleanup_never_read_tees(
          cl_linear_hazard_reference_rewrite(rewrite_input, params),
          params.length(),
        )
        let rewrite : CLFuncRewrite = {
          func: cleanup_rewrite.func,
          changed: cfg_rewrite.changed || cleanup_rewrite.changed,
        }
        rewritten_funcs.push(rewrite.func)
        if rewrite.changed {
          changed_code_indices.push(code_idx)
        }
      }
      if changed_code_indices.length() == 0 {
        return mod_
      }
      let (checked_funcs, committed_code_indices) = cl_validate_rewritten_funcs_with_commits(
        mod_, funcs, rewritten_funcs, changed_code_indices,
      )
      if committed_code_indices.length() == 0 {
        return mod_
      }
      cl_rebuild_module(
        mod_,
        Some(@lib.CodeSec::new(checked_funcs)),
        cl_name_sec_without_local_names(mod_.name_sec),
      )
    }
    None => mod_
  }
}
