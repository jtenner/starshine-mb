///|
fn row_ref_dae_mark_dead_suffix_same_result_operand_targets(
  instrs : Array[@lib.Instruction],
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  imported : Int32,
  defined : Int32,
  flags : Array[Bool],
) -> Unit {
  let stack_sources : Array[Int32] = []
  let mut in_suffix = false
  let mut idx = 0
  while idx < instrs.length() {
    let instr = instrs[idx]
    if !in_suffix {
      if dae_instr_is_unreachable_root(instr) {
        in_suffix = true
      }
      idx += 1
      continue
    }
    match instr {
      @lib.Call(func_idx) => {
        let slot = dae_func_idx_slot(func_idx)
        let def_idx = slot - imported
        let source = if slot >= imported && def_idx >= 0 && def_idx < defined {
          def_idx
        } else {
          -1
        }
        if source >= 0 && source < flags.length() {
          match dae_resolve_func_type(mod_, type_indices, slot) {
            Some(@lib.FuncType(params, _)) =>
              if dae_stack_int_has_operand_value(
                  stack_sources,
                  params.length(),
                  source,
                ) {
                flags[source] = true
              }
            None => ()
          }
        }
        ignore(
          dae_stack_int_apply_instr_effect(
            stack_sources, instr, mod_, type_indices, source,
          ),
        )
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) => {
        row_ref_dae_mark_dead_suffix_same_result_operand_targets(
          body, mod_, type_indices, imported, defined, flags,
        )
        ignore(
          dae_stack_int_apply_instr_effect(
            stack_sources, instr, mod_, type_indices, -1,
          ),
        )
      }
      @lib.If(_, then_body, Some(else_body)) => {
        row_ref_dae_mark_dead_suffix_same_result_operand_targets(
          then_body, mod_, type_indices, imported, defined, flags,
        )
        row_ref_dae_mark_dead_suffix_same_result_operand_targets(
          else_body, mod_, type_indices, imported, defined, flags,
        )
        ignore(
          dae_stack_int_apply_instr_effect(
            stack_sources, instr, mod_, type_indices, -1,
          ),
        )
      }
      @lib.If(_, then_body, None) => {
        row_ref_dae_mark_dead_suffix_same_result_operand_targets(
          then_body, mod_, type_indices, imported, defined, flags,
        )
        ignore(
          dae_stack_int_apply_instr_effect(
            stack_sources, instr, mod_, type_indices, -1,
          ),
        )
      }
      _ =>
        ignore(
          dae_stack_int_apply_instr_effect(
            stack_sources, instr, mod_, type_indices, -1,
          ),
        )
    }
    idx += 1
  }
}

///|
fn row_ref_dae_mark_dead_suffix_escaped_result_operand_targets(
  instrs : Array[@lib.Instruction],
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
  imported : Int32,
  defined : Int32,
  flags : Array[Bool],
) -> Unit {
  let stack_from_escaped_call : Array[Bool] = []
  let mut in_suffix = false
  let mut idx = 0
  while idx < instrs.length() {
    let instr = instrs[idx]
    if !in_suffix {
      if dae_instr_is_unreachable_root(instr) {
        in_suffix = true
      }
      idx += 1
      continue
    }
    match instr {
      @lib.Call(func_idx) => {
        let slot = dae_func_idx_slot(func_idx)
        let def_idx = slot - imported
        if def_idx >= 0 && def_idx < defined && def_idx < flags.length() {
          match dae_resolve_func_type(mod_, type_indices, slot) {
            Some(@lib.FuncType(params, _)) =>
              if dae_stack_bool_has_true_operand(
                  stack_from_escaped_call,
                  params.length(),
                ) {
                flags[def_idx] = true
              }
            None => ()
          }
        }
        let from_escaped = slot >= 0 && slot < escaped.length() && escaped[slot]
        ignore(
          dae_stack_bool_apply_instr_effect(
            stack_from_escaped_call, instr, mod_, type_indices, from_escaped,
          ),
        )
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) => {
        row_ref_dae_mark_dead_suffix_escaped_result_operand_targets(
          body, mod_, type_indices, escaped, imported, defined, flags,
        )
        ignore(
          dae_stack_bool_apply_instr_effect(
            stack_from_escaped_call, instr, mod_, type_indices, false,
          ),
        )
      }
      @lib.If(_, then_body, Some(else_body)) => {
        row_ref_dae_mark_dead_suffix_escaped_result_operand_targets(
          then_body, mod_, type_indices, escaped, imported, defined, flags,
        )
        row_ref_dae_mark_dead_suffix_escaped_result_operand_targets(
          else_body, mod_, type_indices, escaped, imported, defined, flags,
        )
        ignore(
          dae_stack_bool_apply_instr_effect(
            stack_from_escaped_call, instr, mod_, type_indices, false,
          ),
        )
      }
      @lib.If(_, then_body, None) => {
        row_ref_dae_mark_dead_suffix_escaped_result_operand_targets(
          then_body, mod_, type_indices, escaped, imported, defined, flags,
        )
        ignore(
          dae_stack_bool_apply_instr_effect(
            stack_from_escaped_call, instr, mod_, type_indices, false,
          ),
        )
      }
      _ =>
        ignore(
          dae_stack_bool_apply_instr_effect(
            stack_from_escaped_call, instr, mod_, type_indices, false,
          ),
        )
    }
    idx += 1
  }
}

///|
fn row_ref_dae_collect_original_private_result_same_operand_call_counts_with_escaped(
  mod_ : @lib.Module,
  escaped : Array[Bool],
) -> Array[Int32] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let type_indices = dae_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_is_private_result = match
      dae_resolve_func_type(mod_, type_indices, caller_abs) {
      Some(@lib.FuncType(_, results)) => results.length() > 0
      None => false
    }
    if caller_is_private_result && !escaped[caller_abs] {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let flags = Array::make(defined, false)
      row_ref_dae_mark_dead_suffix_same_result_operand_targets(
        body, mod_, type_indices, imported, defined, flags,
      )
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def && flags[callee_def] {
          counts[callee_def] = counts[callee_def] + 1
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn row_ref_dae_collect_original_escaped_result_operand_call_facts_with_escaped(
  mod_ : @lib.Module,
  escaped : Array[Bool],
  dead_suffix_escaped_result_calls : DaeOriginalDeadSuffixEscapedResultCallFacts,
) -> DaeOriginalEscapedResultOperandCallFacts {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let dead_suffix_escaped_result_operand_call_counts = Array::make(defined, 0)
  let private_result_escaped_operand_call_counts = Array::make(defined, 0)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None =>
      return {
        dead_suffix_escaped_result_operand_call_counts,
        private_result_escaped_operand_call_counts,
      }
  }
  let type_indices = dae_collect_func_type_indices(mod_)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_is_escaped = escaped[caller_abs]
    let caller_has_result = match
      dae_resolve_func_type(mod_, type_indices, caller_abs) {
      Some(@lib.FuncType(_, results)) => results.length() > 0
      None => false
    }
    let caller_is_private_result = !caller_is_escaped && caller_has_result
    if caller_is_escaped || caller_is_private_result {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let flags = Array::make(defined, false)
      row_ref_dae_mark_dead_suffix_escaped_result_operand_targets(
        body, mod_, type_indices, escaped, imported, defined, flags,
      )
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def && flags[callee_def] {
          if caller_is_escaped {
            dead_suffix_escaped_result_operand_call_counts[callee_def] = dead_suffix_escaped_result_operand_call_counts[callee_def] +
              1
          }
          if caller_is_private_result &&
            callee_def < dead_suffix_escaped_result_calls.dropped_calls.length() &&
            dead_suffix_escaped_result_calls.dropped_calls[callee_def] {
            private_result_escaped_operand_call_counts[callee_def] = private_result_escaped_operand_call_counts[callee_def] +
              1
          }
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  {
    dead_suffix_escaped_result_operand_call_counts,
    private_result_escaped_operand_call_counts,
  }
}

///|
fn row_ref_dae_collect_original_boundary_snapshot(
  mod_ : @lib.Module,
) -> DaeOriginalBoundarySnapshot {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let type_indices = dae_collect_func_type_indices(mod_)
  let exposure = dae_collect_original_exposure(mod_, total, type_indices)
  let escaped = dae_exposure_to_escaped(exposure)
  let param_counts = dae_collect_original_param_counts_with_type_indices(
    mod_, type_indices,
  )
  let call_summary = dae_collect_original_call_summary_with_context(
    mod_, imported, defined, type_indices, escaped,
  )
  // This temporary belongs only to the borrowed bodies of this invocation.
  // Discover roots lazily so the existing predicate and failure order stays.
  let first_roots : Array[Int32]? = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) if funcs.length() == defined =>
      Some(Array::make(defined, -2))
    _ => None
  }
  let private_result_dead_suffix_call_counts = dae_collect_original_private_result_dead_suffix_call_counts_with_escaped(
    mod_,
    call_summary.call_counts,
    escaped,
    first_roots~,
  )
  let private_result_same_operand_call_counts = row_ref_dae_collect_original_private_result_same_operand_call_counts_with_escaped(
    mod_, escaped,
  )
  let dead_suffix_escaped_result_call_facts = dae_collect_original_dead_suffix_escaped_result_call_facts_with_escaped(
    mod_,
    escaped,
    first_roots~,
  )
  let escaped_result_operand_call_facts = row_ref_dae_collect_original_escaped_result_operand_call_facts_with_escaped(
    mod_, escaped, dead_suffix_escaped_result_call_facts,
  )
  let private_result_dead_suffix_calls_from_escaped_operand_callees = dae_collect_original_private_result_dead_suffix_calls_from_escaped_operand_callees(
    mod_,
    escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts,
    first_roots~,
  )
  let escaped_dead_suffix_call_counts = dae_collect_original_escaped_dead_suffix_call_counts_with_escaped(
    mod_,
    escaped,
    first_roots~,
  )
  let escaped_undropped_dead_suffix_call_counts = dae_collect_original_escaped_undropped_dead_suffix_call_counts_with_escaped(
    mod_,
    escaped,
    first_roots~,
  )
  let dead_suffix_other_calls = dae_collect_original_dead_suffix_other_calls(
    mod_,
    first_roots~,
  )
  let dead_suffix_undropped_self_calls = dae_collect_original_dead_suffix_undropped_self_calls(
    mod_,
    first_roots~,
  )
  let dead_suffix_dropped_self_calls = dae_collect_original_dead_suffix_dropped_self_calls(
    mod_,
    first_roots~,
  )
  let dead_suffix_block_undropped_self_calls = dae_collect_original_dead_suffix_block_undropped_self_calls(
    mod_,
  )
  let dead_suffix_dropped_self_call_full_param_forwards = dae_collect_original_dead_suffix_dropped_self_call_full_param_forwards(
    mod_,
  )
  let dead_suffix_result_calls_from_undropped_self_callers = dae_collect_original_dead_suffix_result_calls_from_undropped_self_callers_with_escaped(
    mod_,
    call_summary.nonself_undropped_call_counts,
    escaped,
    first_roots~,
  )
  let dead_suffix_result_calls_from_no_param_undropped_self_callers = dae_collect_original_dead_suffix_result_calls_from_no_param_undropped_self_callers(
    mod_,
    first_roots~,
  )
  let dead_suffix_undropped_calls_from_parameterized_dropped_self_callers = dae_collect_original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers(
    mod_,
    first_roots~,
  )
  let dead_suffix_dropped_calls_from_parameterized_self_callers = dae_collect_original_dead_suffix_dropped_calls_from_parameterized_self_callers(
    mod_,
    first_roots~,
  )
  let dead_suffix_dropped_calls_from_no_param_result_callers = dae_collect_original_dead_suffix_dropped_calls_from_no_param_result_callers(
    mod_,
    first_roots~,
  )
  let dead_suffix_mixed_dropped_undropped_call_counts = dae_collect_original_dead_suffix_mixed_dropped_undropped_call_counts_with_escaped(
    mod_,
    escaped,
    first_roots~,
  )
  let dead_suffix_dropped_earlier_result_calls = dae_collect_original_dead_suffix_dropped_earlier_result_calls(
    mod_,
    first_roots~,
  )
  let later_dead_suffix_dropped_call_counts = dae_collect_original_later_dead_suffix_dropped_call_counts(
    mod_,
    first_roots~,
  )
  let dead_suffix_same_self_result_operand_calls = dae_collect_original_dead_suffix_same_self_result_operand_calls(
    mod_,
  )
  let dead_suffix_undropped_self_call_param_operands = dae_collect_original_dead_suffix_undropped_self_call_param_operands(
    mod_,
    first_roots~,
  )
  let dead_suffix_result_other_calls = dae_collect_original_dead_suffix_result_other_calls_with_escaped(
    mod_,
    escaped,
    first_roots~,
  )
  let dead_suffix_self_recursive_void_side_calls = dae_collect_original_dead_suffix_self_recursive_void_side_calls(
    mod_,
    first_roots~,
    original_self_call_counts=Some(call_summary.self_call_counts),
  )
  let dead_suffix_self_recursive_result_side_calls = dae_collect_original_dead_suffix_self_recursive_result_side_calls(
    mod_,
    first_roots~,
  )
  let dead_suffix_mutual_calls = dae_collect_original_dead_suffix_mutual_calls(
    mod_,
    first_roots~,
  )
  let dead_suffix_calls_from_param_operand_self_result_callers = dae_collect_original_dead_suffix_calls_from_param_operand_self_result_callers(
    mod_,
    param_counts,
    call_summary.call_counts,
    call_summary.active_nonself_call_counts,
    call_summary.active_parameterized_nonself_call_counts,
    call_summary.nonself_undropped_call_counts,
    call_summary.self_call_counts,
    escaped_dead_suffix_call_counts,
    dead_suffix_undropped_self_calls,
    dead_suffix_undropped_self_call_param_operands,
    dead_suffix_result_other_calls,
    dead_suffix_mutual_calls,
    first_roots~,
  )
  {
    imported,
    defined,
    total,
    type_indices,
    escaped,
    exposure,
    param_counts,
    large_unreachable_prefixes: dae_collect_original_large_unreachable_prefixes(
      mod_,
    ),
    call_summary,
    private_result_dead_suffix_call_counts,
    private_result_same_operand_call_counts,
    escaped_result_operand_call_facts,
    private_result_dead_suffix_calls_from_escaped_operand_callees,
    escaped_dead_suffix_call_counts,
    escaped_undropped_dead_suffix_call_counts,
    dead_suffix_other_calls,
    dead_suffix_undropped_self_calls,
    dead_suffix_dropped_self_calls,
    dead_suffix_block_undropped_self_calls,
    dead_suffix_dropped_self_call_full_param_forwards,
    dead_suffix_result_calls_from_undropped_self_callers,
    dead_suffix_result_calls_from_no_param_undropped_self_callers,
    dead_suffix_undropped_calls_from_parameterized_dropped_self_callers,
    dead_suffix_dropped_calls_from_parameterized_self_callers,
    dead_suffix_dropped_calls_from_no_param_result_callers,
    dead_suffix_mixed_dropped_undropped_call_counts,
    dead_suffix_dropped_earlier_result_calls,
    later_dead_suffix_dropped_call_counts,
    dead_suffix_same_self_result_operand_calls,
    dead_suffix_undropped_self_call_param_operands,
    dead_suffix_calls_from_param_operand_self_result_callers,
    dead_suffix_result_other_calls,
    dead_suffix_self_recursive_void_side_calls,
    dead_suffix_self_recursive_result_side_calls,
    dead_suffix_escaped_result_call_facts,
    dead_suffix_mutual_calls,
  }
}

///|
fn row_ref_dae_run_core(
  mod_ : @lib.Module,
  trace : (String) -> Unit,
  optimize~ : Bool = false,
  perf~ : HotPerfSession? = None,
  single_caller_throttle_consumed~ : Bool = false,
  traps_never_happen~ : Bool = false,
  results_only~ : Bool = false,
  no_callback_trace~ : DaeNoCallbackTrace? = None,
  scalar_validation_work~ : DaeScalarValidationWork? = None,
  numeric_result_validation_work~ : DaeScalarValidationWork? = None,
) -> DaeCoreRunResult {
  let no_callback_trace = match no_callback_trace {
    Some(proof) if perf is None && physical_equal(trace, proof.callback) =>
      Some(proof)
    _ => None
  }
  let mut current = mod_
  let mut touched : Array[Bool] = []
  let mut changed = false
  let setup_start_us = perf_start_timer_opt(perf, "detail:dae:core:setup")
  let original_boundary_snapshot = row_ref_dae_collect_original_boundary_snapshot(
    mod_,
  )
  let original_imported = original_boundary_snapshot.imported
  let original_defined = original_boundary_snapshot.defined
  let mut effects = dae_commit_effects_empty(original_defined)
  let diagnostics = dae_diagnostics_new()
  let original_total = original_boundary_snapshot.total
  let original_param_counts = original_boundary_snapshot.param_counts
  let original_call_summary = original_boundary_snapshot.call_summary
  let original_call_counts = original_call_summary.call_counts
  let original_active_nonself_call_counts = original_call_summary.active_nonself_call_counts
  let original_active_parameterized_nonself_call_counts = original_call_summary.active_parameterized_nonself_call_counts
  let original_nonself_undropped_call_counts = original_call_summary.nonself_undropped_call_counts
  let original_self_call_counts = original_call_summary.self_call_counts
  let original_dead_suffix_escaped_result_call_facts = original_boundary_snapshot.dead_suffix_escaped_result_call_facts
  let original_escaped_result_operand_call_facts = original_boundary_snapshot.escaped_result_operand_call_facts
  let original_dead_suffix_escaped_result_operand_call_counts = original_escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts
  let original_private_result_dead_suffix_calls_from_escaped_operand_callees = original_boundary_snapshot.private_result_dead_suffix_calls_from_escaped_operand_callees
  let original_escaped_dead_suffix_call_counts = original_boundary_snapshot.escaped_dead_suffix_call_counts
  let original_dead_suffix_undropped_self_calls = original_boundary_snapshot.dead_suffix_undropped_self_calls
  let original_dead_suffix_dropped_self_calls = original_boundary_snapshot.dead_suffix_dropped_self_calls
  let original_dead_suffix_block_undropped_self_calls = original_boundary_snapshot.dead_suffix_block_undropped_self_calls
  let original_dead_suffix_result_calls_from_undropped_self_callers = original_boundary_snapshot.dead_suffix_result_calls_from_undropped_self_callers
  let original_dead_suffix_result_calls_from_no_param_undropped_self_callers = original_boundary_snapshot.dead_suffix_result_calls_from_no_param_undropped_self_callers
  let original_dead_suffix_dropped_calls_from_parameterized_self_callers = original_boundary_snapshot.dead_suffix_dropped_calls_from_parameterized_self_callers
  let original_dead_suffix_same_self_result_operand_calls = original_boundary_snapshot.dead_suffix_same_self_result_operand_calls
  let original_dead_suffix_undropped_self_call_param_operands = original_boundary_snapshot.dead_suffix_undropped_self_call_param_operands
  let original_dead_suffix_result_other_calls = original_boundary_snapshot.dead_suffix_result_other_calls
  let original_dead_suffix_mutual_calls = original_boundary_snapshot.dead_suffix_mutual_calls
  let original_dead_suffix_calls_from_param_operand_self_result_callers = original_boundary_snapshot.dead_suffix_calls_from_param_operand_self_result_callers
  perf_stop_timer_opt(perf, "detail:dae:core:setup", setup_start_us)
  let mut dropped_result_post_graph : DaeCurrentBoundaryGraph? = None
  if !optimize && original_defined >= 1024 {
    let mut dropped_result_batch_wave = 0
    while true {
      let application = dae_apply_dropped_result_batch_transaction(
        original_boundary_snapshot,
        current,
        touched,
        changed,
        retain_post_graph=true,
      )
      if !application.applied {
        break
      }
      current = application.mod_out
      touched = application.touched
      changed = application.changed
      dropped_result_post_graph = application.post_graph
      effects = dae_commit_effects_merge(effects, application.effects)
      dae_diagnostics_record_commit_effects(diagnostics, application.effects)
      dae_diagnostics_record_applied_effects(diagnostics, application.effects)
      trace(
        "pass[dae]:dropped-result-batch wave=\{dropped_result_batch_wave} first_def=\{application.primary_def}",
      )
      dropped_result_batch_wave += 1
    }
  }
  if optimize {
    let unread_batch_start_us = perf_start_timer_opt(
      perf, "detail:dae:core:unread-param-batch",
    )
    let mut unread_batch_wave = 0
    if original_defined >= 1024 && !single_caller_throttle_consumed {
      while true {
        let application = dae_apply_unread_param_batch_transaction(
          original_boundary_snapshot, current, touched, changed,
        )
        if !application.applied {
          break
        }
        current = application.mod_out
        touched = application.touched
        changed = application.changed
        effects = dae_commit_effects_merge(effects, application.effects)
        dae_diagnostics_record_commit_effects(diagnostics, application.effects)
        dae_diagnostics_record_applied_effects(diagnostics, application.effects)
        trace(
          "pass[dae-optimizing]:unread-param-batch wave=\{unread_batch_wave} first_def=\{application.primary_def}",
        )
        unread_batch_wave += 1
      }
    } else if single_caller_throttle_consumed {
      trace(
        "pass[dae-optimizing]:unread-param-batch skip=single-caller-throttle-consumed",
      )
    } else {
      trace(
        "pass[dae-optimizing]:unread-param-batch skip=small-module-acceleration optional=true defined=\{original_defined}",
      )
    }
    perf_stop_timer_opt(
      perf, "detail:dae:core:unread-param-batch", unread_batch_start_us,
    )
    let dropped_result_batch_start_us = perf_start_timer_opt(
      perf, "detail:dae:core:dropped-result-batch",
    )
    let mut dropped_result_batch_wave = 0
    if original_defined >= 1024 {
      while true {
        let application = dae_apply_dropped_result_batch_transaction(
          original_boundary_snapshot, current, touched, changed,
        )
        if !application.applied {
          break
        }
        current = application.mod_out
        touched = application.touched
        changed = application.changed
        effects = dae_commit_effects_merge(effects, application.effects)
        dae_diagnostics_record_commit_effects(diagnostics, application.effects)
        dae_diagnostics_record_applied_effects(diagnostics, application.effects)
        trace(
          "pass[dae-optimizing]:dropped-result-batch wave=\{dropped_result_batch_wave} first_def=\{application.primary_def}",
        )
        dropped_result_batch_wave += 1
      }
    } else {
      trace(
        "pass[dae-optimizing]:dropped-result-batch skip=small-module-acceleration optional=true defined=\{original_defined}",
      )
    }
    perf_stop_timer_opt(
      perf, "detail:dae:core:dropped-result-batch", dropped_result_batch_start_us,
    )
    let direct_gc_batch_start_us = perf_start_timer_opt(
      perf, "detail:dae:core:direct-gc-batch",
    )
    let mut direct_gc_batch_wave = 0
    let mut direct_gc_active_defs : Array[Bool]? = None
    while true {
      let application = dae_apply_direct_gc_batch_transaction(
        original_boundary_snapshot,
        current,
        touched,
        changed,
        active_defs=direct_gc_active_defs,
      )
      let batch_touched = application.effects.structurally_touched
      if !application.applied {
        break
      }
      current = application.mod_out
      touched = application.touched
      changed = application.changed
      effects = dae_commit_effects_merge(effects, application.effects)
      dae_diagnostics_record_commit_effects(diagnostics, application.effects)
      dae_diagnostics_record_applied_effects(diagnostics, application.effects)
      trace(
        "pass[dae-optimizing]:direct-gc-batch wave=\{direct_gc_batch_wave} first_def=\{application.primary_def}",
      )
      let next_active = Array::make(original_defined, false)
      let current_call_facts = dae_collect_current_call_facts(
        current, original_total,
      )
      match current.code_sec {
        Some(@lib.CodeSec(funcs)) => {
          let mut changed_def = 0
          while changed_def < batch_touched.length() &&
                changed_def < funcs.length() {
            if batch_touched[changed_def] {
              next_active[changed_def] = true
              let changed_abs = original_imported + changed_def
              if changed_abs >= 0 &&
                changed_abs < current_call_facts.direct_callers.length() {
                for caller_def in current_call_facts.direct_callers[changed_abs] {
                  if caller_def >= 0 && caller_def < next_active.length() {
                    next_active[caller_def] = true
                  }
                }
              }
              let @lib.Func(_, @lib.Expr(body)) = funcs[changed_def]
              let outgoing : Array[Int32] = []
              dae_collect_direct_call_targets_anywhere(
                body, original_imported, original_defined, outgoing,
              )
              for callee_def in outgoing {
                if callee_def >= 0 && callee_def < next_active.length() {
                  next_active[callee_def] = true
                }
              }
            }
            changed_def += 1
          }
        }
        None => ()
      }
      direct_gc_active_defs = Some(next_active)
      direct_gc_batch_wave += 1
    }
    perf_stop_timer_opt(
      perf, "detail:dae:core:direct-gc-batch", direct_gc_batch_start_us,
    )
  }
  let current_boundary_graph = match dropped_result_post_graph {
    Some(graph) => graph
    None => dae_current_boundary_graph_new(current)
  }
  let fixed_loop_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:fixed-loop",
  )
  let scalar_validation_chain = match
    (no_callback_trace, scalar_validation_work, numeric_result_validation_work) {
    (None, None, None) => None
    _ => Some(dae_scalar_validation_chain_new(trace, perf, no_callback_trace))
  }
  let mut iter = 0
  // Boundary availability is monotonic under the core's signature/result
  // reductions, but it is not definition-order local: rewriting one boundary
  // can expose work in its callers, callees, or itself. Seed every definition
  // once, then requeue only the dependency neighborhood invalidated by a
  // committed transaction. Queue membership prevents duplicate pending work;
  // termination follows from an empty queue rather than an iteration budget.
  let no_already_rewritten_defs : Array[Bool] = []
  let core_worklist = dae_boundary_worklist_all(original_defined)
  let mut current_dependencies = dae_boundary_dependency_graph_empty()
  let mut scalar_plan_code_snapshot_current = dae_scalar_plan_code_snapshot_is_current(
    current, current_boundary_graph,
  )
  let mut has_current_dropped_result_candidate = dae_current_graph_has_dropped_result_candidate(
    original_boundary_snapshot, current_boundary_graph,
  )
  let mut current_call_counts_anywhere = match current.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      dae_collect_module_call_counts_anywhere(
        funcs, original_imported, original_defined,
      )
    None => Array::make(original_defined, 0)
  }
  let mut unprofitable_removal_iters = if single_caller_throttle_consumed {
    1
  } else {
    0
  }
  while core_worklist.cursor < core_worklist.queue.length() {
    // Keep Binaryen's one-wave profitability boundary while making discovery
    // dependency-driven: work enqueued by this frontier is processed in the
    // next frontier, after the source-backed single-caller stop is classified.
    let wave_end = core_worklist.queue.length()
    let mut wave_param_removals = 0
    let mut wave_single_caller_param_removals = 0
    while core_worklist.cursor < wave_end {
      let def_idx = match dae_boundary_worklist_take(core_worklist) {
        Some(value) => value
        None => break
      }
      diagnostics.boundaries_analyzed += 1
      // A fresh frontier is usually a contiguous definition range. Analyze that
      // range with one core setup instead of rebuilding the same boundary
      // contexts once per definition. Stop at the first committed candidate;
      // dependency invalidation can then requeue any earlier definitions whose
      // facts changed.
      let mut batch_end_exclusive = def_idx + 1
      let mut batch_queue_end = core_worklist.cursor
      while batch_queue_end < wave_end &&
            core_worklist.queue[batch_queue_end] == batch_end_exclusive {
        batch_end_exclusive += 1
        batch_queue_end += 1
      }
      let before_call_facts = current_boundary_graph.snapshot.call_facts
      let call_epoch = current_boundary_graph.call_epoch
      let boundary_facts = current_boundary_graph.snapshot.boundary_facts
      let producer_effects_report : Array[DaeCommitEffects] = []
      let committed_application_report : Array[DaeCoreResultApplication] = []
      let checked_candidate_report : Array[(@lib.Module, @lib.Module)]? = match
        no_callback_trace {
        Some(_) => Some([])
        None => None
      }
      let result = dae_run_core_once(
        current,
        no_already_rewritten_defs,
        current_call_counts_anywhere,
        optimize,
        unprofitable_removal_iters > 0,
        original_boundary_snapshot,
        current_boundary_graph,
        expected_call_epoch=call_epoch,
        max_def_exclusive=batch_end_exclusive,
        start_def_inclusive=def_idx,
        boundary_facts_override=Some(boundary_facts),
        dependencies=Some(current_dependencies),
        producer_effects_report~,
        committed_application_report~,
        checked_candidate_report~,
        scalar_validation_chain~,
        scalar_validation_work~,
        numeric_result_validation_work~,
        scalar_plan_code_snapshot_current~,
        has_current_dropped_result_candidate~,
        traps_never_happen~,
      )
      dae_scalar_validation_retain_exact(
        scalar_validation_chain,
        result.mod_out,
      )
      if !committed_application_report.is_empty() {
        dae_numeric_result_validation_retain_report(
          scalar_validation_chain,
          result,
          committed_application_report[0],
        )
      }
      let consumed_end_exclusive = if result.changed &&
        result.primary_def >= def_idx &&
        result.primary_def < batch_end_exclusive {
        result.primary_def + 1
      } else {
        batch_end_exclusive
      }
      while core_worklist.cursor < batch_queue_end &&
            core_worklist.queue[core_worklist.cursor] < consumed_end_exclusive {
        ignore(dae_boundary_worklist_take(core_worklist))
        diagnostics.boundaries_analyzed += 1
      }
      let scanned = consumed_end_exclusive - def_idx
      if scanned > 1 {
        trace(
          "pass[dae]:core-worklist-batch start=\{def_idx} primary_def=\{result.primary_def} scanned=\{scanned}",
        )
        for _i = 1; _i < scanned; _i = _i + 1 {
          dae_diagnostics_record_reason(diagnostics, DaeNoStrictImprovement)
        }
      }
      let before_primary_param_count = if result.primary_def >= 0 {
        let before_type_indices = dae_collect_func_type_indices(current)
        match
          dae_resolve_func_type(
            current,
            before_type_indices,
            original_imported + result.primary_def,
          ) {
          Some(@lib.FuncType(params, _)) => params.length()
          None => -1
        }
      } else {
        -1
      }
      if !result.changed {
        dae_diagnostics_record_reason(diagnostics, DaeNoStrictImprovement)
        continue
      }
      let producer_effects = match producer_effects_report.get(0) {
        Some(value) => value
        None => {
          dae_diagnostics_record_reason(diagnostics, DaeNoStrictImprovement)
          continue
        }
      }
      let family = dae_work_family_for_commit_effects(
        producer_effects,
        result.primary_def,
      )
      let item = dae_work_item_new(
        current_boundary_graph,
        current_dependencies,
        result.primary_def,
        family,
      )
      let application = match committed_application_report.get(0) {
        Some(application) => application
        None => {
          let outcome = match checked_candidate_report {
            Some(report) =>
              dae_process_core_precomputed_signature_with_report(
                original_boundary_snapshot, current, touched, changed, current_boundary_graph,
                item, result, producer_effects, trace, no_callback_trace, report,
              )
            None =>
              dae_process_precomputed_signature_work_item(
                original_boundary_snapshot, current, touched, changed, current_boundary_graph,
                item, result, producer_effects,
              )
          }
          match outcome {
            DaeWorkCommitted(value) => value
            DaeWorkNoChange(_) | DaeWorkDeferred(_) | DaeWorkRequeue(_) => {
              dae_scalar_validation_barrier_opt(scalar_validation_chain)
              dae_diagnostics_record_reason(diagnostics, DaeNoStrictImprovement)
              continue
            }
          }
        }
      }
      dae_scalar_validation_retain_exact(
        scalar_validation_chain,
        application.mod_out,
      )
      dae_diagnostics_record_commit_effects(diagnostics, application.effects)
      dae_diagnostics_record_applied_effects(diagnostics, application.effects)
      if application.primary_def >= 0 && before_primary_param_count >= 0 {
        let after_type_indices = dae_collect_func_type_indices(
          application.mod_out,
        )
        let after_param_count = match
          dae_resolve_func_type(
            application.mod_out,
            after_type_indices,
            original_imported + application.primary_def,
          ) {
          Some(@lib.FuncType(params, _)) => params.length()
          None => before_primary_param_count
        }
        if after_param_count < before_primary_param_count {
          wave_param_removals += 1
          let callee_abs = original_imported + application.primary_def
          if callee_abs >= 0 &&
            callee_abs < before_call_facts.direct_calls.length() &&
            before_call_facts.direct_calls[callee_abs] == 1 {
            wave_single_caller_param_removals += 1
          }
        }
      }
      let before_dependencies = dae_boundary_dependency_graph_new(
        current_boundary_graph,
      )
      dae_current_boundary_graph_refresh(
        current_boundary_graph,
        application.mod_out,
        forced_changed_defs=Some(application.effects.structurally_touched),
      )
      scalar_plan_code_snapshot_current = dae_scalar_plan_code_snapshot_is_current(
        application.mod_out,
        current_boundary_graph,
      )
      has_current_dropped_result_candidate = dae_current_graph_has_dropped_result_candidate(
        original_boundary_snapshot, current_boundary_graph,
      )
      let after_dependencies = dae_boundary_dependency_graph_new(
        current_boundary_graph,
      )
      let invalidated = dae_boundary_dependency_invalidations(
        before_dependencies,
        after_dependencies,
        application.touched,
        application.primary_def,
        application.effects,
      )
      current_dependencies = after_dependencies
      current = application.mod_out
      touched = application.touched
      changed = application.changed
      effects = dae_commit_effects_merge(effects, application.effects)
      current_call_counts_anywhere = match current.code_sec {
        Some(@lib.CodeSec(funcs)) =>
          dae_collect_module_call_counts_anywhere(
            funcs, original_imported, original_defined,
          )
        None => Array::make(original_defined, 0)
      }
      diagnostics.candidate_requeues += dae_boundary_worklist_requeue(
        core_worklist, invalidated,
      )
      trace(
        "pass[dae-optimizing]:core-worklist iter=\{iter} primary_def=\{application.primary_def}",
      )
      iter += 1
    }
    let unprofitable_param_wave = wave_param_removals == 1 &&
      wave_single_caller_param_removals == 1
    if unprofitable_param_wave && unprofitable_removal_iters == 0 {
      unprofitable_removal_iters += 1
      trace(
        "pass[dae-optimizing]:core-worklist skip=further-param-removal unprofitable_iters=\{unprofitable_removal_iters} removals=1 single_callers=1",
      )
    }
  }
  dae_scalar_validation_barrier_opt(scalar_validation_chain)
  perf_stop_timer_opt(perf, "detail:dae:core:fixed-loop", fixed_loop_start_us)
  if results_only {
    trace("pass[dae]:results-only-fallback stop=after-core-worklist")
    return {
      mod_out: current,
      touched: if changed {
        touched
      } else {
        []
      },
      changed,
      primary_def: -1,
      effects,
      diagnostics,
      single_caller_throttle_consumed: unprofitable_removal_iters > 0,
    }
  }
  let mut current_boundary_graph_stale = false
  if dae_should_run_computed_unread_dependency_worklist(
      original_defined,
      optimize~,
    ) {
    let computed_application = dae_run_computed_unread_param_dependency_worklist(
      original_boundary_snapshot,
      current,
      touched,
      changed,
      unprofitable_removal_iters > 0,
      trace,
    )
    current = computed_application.mod_out
    if computed_application.effects.candidates_applied > 0 {
      current_boundary_graph_stale = true
    }
    touched = computed_application.touched
    changed = computed_application.changed
    effects = dae_commit_effects_merge(effects, computed_application.effects)
  }
  let selected_lanes_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes",
  )
  let reverse_exact_literal_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:reverse-exact-literal",
  )
  let restored_application = dae_apply_dead_suffix_self_operand_restore_transaction(
    mod_,
    current,
    touched,
    changed,
    candidate_defs=if touched.length() == original_defined {
      Some(touched)
    } else {
      None
    },
  )
  if restored_application.applied {
    current = restored_application.mod_out
    current_boundary_graph_stale = true
    touched = restored_application.touched
    changed = restored_application.changed
    effects = dae_commit_effects_merge(effects, restored_application.effects)
  }
  // Reuse one selected-def singleton scratch across the artifact-specific lanes
  // that set at most one bit at a time. Each call clears the bit immediately
  // after use, so later lanes observe the same all-false starting state they had
  // with separate freshly allocated bitmaps.
  let selected_scratch_defs = Array::make(original_defined, false)
  let mut reverse_iter = 0
  if dae_should_run_broad_uniform_parameter_flow(original_defined, optimize~) {
    let broad_uniform = dae_run_broad_uniform_parameter_flow(
      current, mod_, touched, changed,
    )
    current = broad_uniform.mod_out
    if broad_uniform.productive_defs.length() > 0 {
      current_boundary_graph_stale = true
    }
    touched = broad_uniform.touched
    changed = broad_uniform.changed
    effects = dae_commit_effects_merge(effects, broad_uniform.effects)
    for primary_def in broad_uniform.productive_defs {
      trace("pass[dae]:broad-exact-uniform primary_def=\{primary_def}")
    }
  }
  if dae_should_run_reverse_exact_literal_phase(original_defined, optimize~) {
    while true {
      let reverse_graph = dae_current_boundary_graph_new(current)
      let reverse_result = dae_try_rewrite_reverse_exact_literal_once(
        current,
        original_param_counts,
        original_call_counts,
        original_active_nonself_call_counts,
        original_active_parameterized_nonself_call_counts,
        original_nonself_undropped_call_counts,
        original_self_call_counts,
        original_private_result_dead_suffix_calls_from_escaped_operand_callees,
        original_escaped_dead_suffix_call_counts,
        original_dead_suffix_undropped_self_calls,
        original_dead_suffix_dropped_self_calls,
        original_dead_suffix_block_undropped_self_calls,
        original_dead_suffix_result_calls_from_undropped_self_callers,
        original_dead_suffix_result_calls_from_no_param_undropped_self_callers,
        original_dead_suffix_same_self_result_operand_calls,
        original_dead_suffix_undropped_self_call_param_operands,
        original_dead_suffix_result_other_calls,
        original_dead_suffix_escaped_result_call_facts,
        original_dead_suffix_mutual_calls,
        original_dead_suffix_calls_from_param_operand_self_result_callers,
        original_dead_suffix_escaped_result_operand_call_counts,
        original_dead_suffix_dropped_calls_from_parameterized_self_callers,
        supplied_graph=Some(reverse_graph),
      )
      if !reverse_result.changed || reverse_result.primary_def < 0 {
        break
      }
      let reverse_effects = if reverse_result.changed &&
        reverse_result.primary_def >= 0 {
        Some(
          dae_work_item_candidate_effects(
            current,
            reverse_graph,
            dae_work_item_new(
              reverse_graph,
              dae_boundary_dependency_graph_new(reverse_graph),
              reverse_result.primary_def,
              DaeUniformActualWork,
            ),
            reverse_result,
          ),
        )
      } else {
        None
      }
      let reverse_application = match reverse_effects {
        Some(producer_effects) =>
          match
            dae_process_precomputed_signature_work_item(
              original_boundary_snapshot,
              current,
              touched,
              changed,
              reverse_graph,
              dae_work_item_new(
                reverse_graph,
                dae_boundary_dependency_graph_new(reverse_graph),
                reverse_result.primary_def,
                DaeUniformActualWork,
              ),
              reverse_result,
              producer_effects,
            ) {
            DaeWorkCommitted(value) => value
            _ => break
          }
        None => break
      }
      current = reverse_application.mod_out
      current_boundary_graph_stale = true
      touched = reverse_application.touched
      changed = reverse_application.changed
      effects = dae_commit_effects_merge(effects, reverse_application.effects)
      trace(
        "pass[dae-optimizing]:reverse-exact-literal iter=\{reverse_iter} primary_def=\{reverse_application.primary_def}",
      )
      reverse_iter += 1
    }
  }
  // Phase-local profitability replay uses semantic candidate evidence rather
  // than a module-size admission threshold. Each wave still commits at most one
  // validated candidate, preserving the existing source-order frontier.
  let mut low_revisit_iter = 0
  while dae_should_run_forwarded_constant_revisit(original_defined, optimize~) {
    let low_revisit_graph = dae_current_boundary_graph_new(current)
    let low_revisit_result = dae_try_rewrite_reverse_exact_literal_once(
      current,
      original_param_counts,
      original_call_counts,
      original_active_nonself_call_counts,
      original_active_parameterized_nonself_call_counts,
      original_nonself_undropped_call_counts,
      original_self_call_counts,
      original_private_result_dead_suffix_calls_from_escaped_operand_callees,
      original_escaped_dead_suffix_call_counts,
      original_dead_suffix_undropped_self_calls,
      original_dead_suffix_dropped_self_calls,
      original_dead_suffix_block_undropped_self_calls,
      original_dead_suffix_result_calls_from_undropped_self_callers,
      original_dead_suffix_result_calls_from_no_param_undropped_self_callers,
      original_dead_suffix_same_self_result_operand_calls,
      original_dead_suffix_undropped_self_call_param_operands,
      original_dead_suffix_result_other_calls,
      original_dead_suffix_escaped_result_call_facts,
      original_dead_suffix_mutual_calls,
      original_dead_suffix_calls_from_param_operand_self_result_callers,
      original_dead_suffix_escaped_result_operand_call_counts,
      original_dead_suffix_dropped_calls_from_parameterized_self_callers,
      supplied_graph=Some(low_revisit_graph),
      reverse=false,
      max_def_exclusive=original_defined,
    )
    if !low_revisit_result.changed || low_revisit_result.primary_def < 0 {
      break
    }
    let low_revisit_effects = if low_revisit_result.changed &&
      low_revisit_result.primary_def >= 0 {
      Some(
        dae_work_item_candidate_effects(
          current,
          low_revisit_graph,
          dae_work_item_new(
            low_revisit_graph,
            dae_boundary_dependency_graph_new(low_revisit_graph),
            low_revisit_result.primary_def,
            DaeUniformActualWork,
          ),
          low_revisit_result,
        ),
      )
    } else {
      None
    }
    let low_revisit_application = match low_revisit_effects {
      Some(producer_effects) =>
        match
          dae_process_precomputed_signature_work_item(
            original_boundary_snapshot,
            current,
            touched,
            changed,
            low_revisit_graph,
            dae_work_item_new(
              low_revisit_graph,
              dae_boundary_dependency_graph_new(low_revisit_graph),
              low_revisit_result.primary_def,
              DaeUniformActualWork,
            ),
            low_revisit_result,
            producer_effects,
          ) {
          DaeWorkCommitted(value) => value
          _ => break
        }
      None => break
    }
    current = low_revisit_application.mod_out
    current_boundary_graph_stale = true
    touched = low_revisit_application.touched
    changed = low_revisit_application.changed
    effects = dae_commit_effects_merge(effects, low_revisit_application.effects)
    trace(
      "pass[dae-optimizing]:low-forwarded-const-revisit iter=\{low_revisit_iter} primary_def=\{low_revisit_application.primary_def}",
    )
    low_revisit_iter += 1
  }
  // Exact type/call-fact admission is independent of parameter count and shape.
  // Run it after the ordinary reverse phase so it cannot preempt that proof.
  // Modules can contain profitable exact/default candidates that the fixed
  // eight-iteration core never reaches. Build the ordered worklist
  // once from one current caller-fact snapshot, then revalidate and apply each
  // candidate against the evolving module. Signature and operand rewrites do
  // not change direct-call edges, so the snapshot remains valid for this batch.
  let low_exact_literal_candidates = if dae_should_collect_low_exact_literal_candidates(
      optimize,
      restored_application.applied,
      scalar_plan_code_snapshot_current,
    ) {
    let low_exact_literal_call_facts = dae_collect_current_call_facts(
      current, original_total,
    )
    dae_collect_post_revisit_exact_literal_candidates(
      current, low_exact_literal_call_facts, original_defined,
    )
  } else {
    []
  }
  let low_exact_literal_application = if !optimize &&
    !restored_application.applied {
    dae_run_exact_literal_candidate_worklist_with_facts(
      current,
      touched,
      changed,
      low_exact_literal_candidates,
      original=if low_exact_literal_candidates.is_empty() {
        None
      } else {
        Some(row_ref_dae_collect_original_boundary_snapshot(current))
      },
      graph=Some(current_boundary_graph),
      dependencies=Some(current_dependencies),
    )
  } else {
    dae_run_exact_literal_candidate_worklist_with_facts(
      current, touched, changed, low_exact_literal_candidates,
    )
  }
  current = low_exact_literal_application.mod_out
  if low_exact_literal_application.productive_defs.length() > 0 {
    current_boundary_graph_stale = true
  }
  touched = low_exact_literal_application.touched
  changed = low_exact_literal_application.changed
  effects = dae_commit_effects_merge(
    effects,
    low_exact_literal_application.effects,
  )
  for iter, primary_def in low_exact_literal_application.productive_defs {
    trace(
      "pass[dae-optimizing]:low-exact-literal-worklist iter=\{iter} primary_def=\{primary_def}",
    )
  }
  let low_exact_cleanup_defs = Array::make(original_defined, false)
  for productive_def in low_exact_literal_application.productive_defs {
    if productive_def >= 0 && productive_def < low_exact_cleanup_defs.length() {
      low_exact_cleanup_defs[productive_def] = true
    }
  }
  let low_exact_null_if_cleanup = dae_try_fold_selected_ref_null_is_null_ifs_once(
    current, low_exact_cleanup_defs,
  )
  let low_exact_null_if_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, low_exact_null_if_cleanup,
    diagnostics,
  )
  if low_exact_null_if_application.applied {
    current = low_exact_null_if_application.mod_out
    current_boundary_graph_stale = true
    touched = low_exact_null_if_application.touched
    changed = low_exact_null_if_application.changed
    effects = dae_commit_effects_merge(
      effects,
      low_exact_null_if_application.effects,
    )
    trace(
      "pass[dae-optimizing]:low-exact-null-if-cleanup primary_def=\{low_exact_null_if_application.primary_def}",
    )
  }
  let low_exact_terminal_locals = dae_try_inline_selected_terminal_call_local_sets_once(
    current, low_exact_cleanup_defs,
  )
  let low_exact_terminal_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, low_exact_terminal_locals,
    diagnostics,
  )
  if low_exact_terminal_application.applied {
    current = low_exact_terminal_application.mod_out
    current_boundary_graph_stale = true
    touched = low_exact_terminal_application.touched
    changed = low_exact_terminal_application.changed
    effects = dae_commit_effects_merge(
      effects,
      low_exact_terminal_application.effects,
    )
    trace(
      "pass[dae-optimizing]:low-exact-terminal-call-locals primary_def=\{low_exact_terminal_application.primary_def}",
    )
  }
  let low_exact_result_application = dae_run_direct_gc_result_refinement_dependency_closure(
    current,
    touched,
    changed,
    low_exact_literal_application.productive_defs,
  )
  current = low_exact_result_application.mod_out
  if low_exact_result_application.productive_defs.length() > 0 {
    current_boundary_graph_stale = true
  }
  touched = low_exact_result_application.touched
  changed = low_exact_result_application.changed
  effects = dae_commit_effects_merge(
    effects,
    low_exact_result_application.effects,
  )
  for iter, primary_def in low_exact_result_application.productive_defs {
    trace(
      "pass[dae-optimizing]:low-exact-result-worklist iter=\{iter} primary_def=\{primary_def}",
    )
  }
  if optimize {
    // Discover only direct call targets whose final immediate actual
    // is already a materializable literal, null/string constant, or immutable
    // global, then reuse the complete value-slice, ownership, escape, write,
    // and call-count proof in the existing rewrite.
    let large_global_defs = dae_collect_large_uniform_const_revisit_defs(
      current,
    )
    let all_large_defs = Array::make(original_defined, true)
    // Each candidate enters the common epoch-bearing uniform-value work item.
    // The current graph refreshes after every commit, so newly exposed direct
    // callees can join the same deterministic frontier without a selected-only
    // scan-and-mutate path.
    for candidate_def = 0
        candidate_def < large_global_defs.length()
        candidate_def = candidate_def + 1 {
      if !large_global_defs[candidate_def] {
        continue
      }
      trace(
        "pass[dae-optimizing]:large-uniform-const-candidate primary_def=\{candidate_def}",
      )
      let global_application = dae_run_exact_literal_candidate_worklist_with_facts(
        current,
        touched,
        changed,
        [candidate_def],
        allow_immutable_global_get=true,
        allow_immediate_i32_suffix_fallback=true,
        original=Some(original_boundary_snapshot),
      )
      if global_application.productive_defs.length() > 0 {
        current = global_application.mod_out
        current_boundary_graph_stale = true
        touched = global_application.touched
        changed = global_application.changed
        effects = dae_commit_effects_merge(effects, global_application.effects)
        trace(
          "pass[dae-optimizing]:large-uniform-const-revisit primary_def=\{global_application.productive_defs[0]}",
        )
        // Materializing this boundary can expose an immediate literal in a
        // forwarded direct callee. Admit only those newly visible call targets;
        // the same exact call-slice/ownership transaction remains authoritative.
        match current.code_sec {
          Some(@lib.CodeSec(funcs)) => {
            let primary_def = global_application.productive_defs[0]
            if primary_def >= 0 && primary_def < funcs.length() {
              let @lib.Func(_, @lib.Expr(body)) = funcs[primary_def]
              dae_collect_immediate_materializable_call_targets_instrs(
                current,
                body,
                dae_imported_func_count(current),
                all_large_defs,
                large_global_defs,
              )
            }
          }
          None => ()
        }
      } else {
        trace(
          "pass[dae-optimizing]:large-uniform-const-rejected primary_def=\{candidate_def}",
        )
      }
    }
  }
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:reverse-exact-literal", reverse_exact_literal_start_us,
  )
  let low_wrapper_callees_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:low-wrapper-callees",
  )
  // Keep the phase-local forwarding seed, but derive targets from exact current
  // wrapper shape rather than a fixed wrapper-definition list.
  let boundary_callee_order = if dae_should_run_low_wrapper_callee_phase(
      optimize~,
    ) {
    dae_collect_shifted_forward_wrapper_callee_order(
      current, 0, original_defined,
    )
  } else {
    []
  }
  let mut boundary_graph_opt : DaeCurrentBoundaryGraph? = None
  let mut boundary_dependencies_opt : DaeBoundaryDependencyGraph? = None
  for boundary_callee_def in boundary_callee_order {
    let boundary_graph = match boundary_graph_opt {
      Some(graph) => graph
      None => {
        let graph = dae_current_boundary_graph_new(current)
        boundary_graph_opt = Some(graph)
        graph
      }
    }
    let boundary_dependencies = match boundary_dependencies_opt {
      Some(dependencies) => dependencies
      None => {
        let dependencies = dae_boundary_dependency_graph_new(boundary_graph)
        boundary_dependencies_opt = Some(dependencies)
        dependencies
      }
    }
    if boundary_callee_def < 0 ||
      boundary_callee_def >= selected_scratch_defs.length() {
      continue
    }
    selected_scratch_defs[boundary_callee_def] = true
    let boundary_effects : Array[DaeCommitEffects] = []
    let boundary_result = dae_try_rewrite_selected_defs_unread_params_with_facts_once(
      current,
      selected_scratch_defs,
      boundary_graph.snapshot.call_facts,
      original=Some(original_boundary_snapshot),
      graph=Some(boundary_graph),
      producer_effects_report=boundary_effects,
    )
    selected_scratch_defs[boundary_callee_def] = false
    let boundary_application = match boundary_effects.get(0) {
      Some(producer_effects) =>
        match
          dae_process_precomputed_signature_work_item(
            original_boundary_snapshot,
            current,
            touched,
            changed,
            boundary_graph,
            dae_work_item_new(
              boundary_graph,
              boundary_dependencies,
              boundary_result.primary_def,
              dae_work_family_for_commit_effects(
                producer_effects,
                boundary_result.primary_def,
              ),
            ),
            boundary_result,
            producer_effects,
          ) {
          DaeWorkCommitted(value) => Some(value)
          _ => None
        }
      None => None
    }
    match boundary_application {
      Some(boundary_application) => {
        current = boundary_application.mod_out
        current_boundary_graph_stale = true
        dae_current_boundary_graph_refresh(boundary_graph, current)
        boundary_dependencies_opt = Some(
          dae_boundary_dependency_graph_new(boundary_graph),
        )
        touched = boundary_application.touched
        changed = boundary_application.changed
        effects = dae_commit_effects_merge(
          effects,
          boundary_application.effects,
        )
        dae_diagnostics_record_commit_effects(
          diagnostics,
          boundary_application.effects,
        )
        dae_diagnostics_record_applied_effects(
          diagnostics,
          boundary_application.effects,
        )
        trace(
          "pass[dae-optimizing]:boundary-wrapper-callee-core primary_def=\{boundary_application.primary_def}",
        )
      }
      None => ()
    }
  }
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:low-wrapper-callees", low_wrapper_callees_start_us,
  )
  let early_shapes_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:early-shapes",
  )
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:early-shapes", early_shapes_start_us,
  )
  let dropped_results_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:dropped-results",
  )
  let dropped_result_selected_defs_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:dropped-results:selected-defs",
  )
  let mut fact_dropped_result_wave = 0
  while dae_should_run_fact_dropped_result_revisit(optimize~) {
    let fact_dropped_result_call_facts_start_us = perf_start_timer_opt(
      perf, "detail:dae:core:selected-lanes:dropped-results:call-facts",
    )
    let fact_dropped_result_call_facts = dae_collect_current_call_facts(
      current, original_total,
    )
    perf_stop_timer_opt(
      perf, "detail:dae:core:selected-lanes:dropped-results:call-facts", fact_dropped_result_call_facts_start_us,
    )
    let selected = dae_collect_fact_dropped_result_candidate_defs(
      current, fact_dropped_result_call_facts,
    )
    let candidate_defs = dae_order_selected_candidates_caller_first(
      current, selected,
    )
    let fact_dropped_result = dae_run_dropped_result_candidate_worklist_with_facts(
      current, touched, changed, candidate_defs,
    )
    if fact_dropped_result.productive_defs.length() == 0 {
      break
    }
    current = fact_dropped_result.mod_out
    current_boundary_graph_stale = true
    touched = fact_dropped_result.touched
    changed = fact_dropped_result.changed
    effects = dae_commit_effects_merge(effects, fact_dropped_result.effects)
    for primary_def in fact_dropped_result.productive_defs {
      trace(
        "pass[dae-optimizing]:fact-dropped-result wave=\{fact_dropped_result_wave} primary_def=\{primary_def}",
      )
    }
    fact_dropped_result_wave += 1
  }
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:dropped-results:selected-defs", dropped_result_selected_defs_start_us,
  )
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:dropped-results", dropped_results_start_us,
  )
  let literal_unread_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:literal-unread",
  )
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:literal-unread", literal_unread_start_us,
  )
  let late_shapes_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:late-shapes",
  )
  let late_shapes_input = current
  let mut late_shapes_changed = false
  let const_local_candidates = dae_collect_single_const_local_call_candidates(
    mod_,
  )
  let mut const_local_iteration = 0
  while true {
    let const_local_result = dae_try_inline_selected_i32_const_local_sets_once(
      current, const_local_candidates,
    )
    let const_local_application = dae_apply_body_only_family_result_transaction(
      original_boundary_snapshot, current, touched, changed, const_local_result,
      diagnostics,
    )
    if !const_local_application.applied {
      break
    }
    current = const_local_application.mod_out
    current_boundary_graph_stale = true
    late_shapes_changed = true
    touched = const_local_application.touched
    changed = const_local_application.changed
    effects = dae_commit_effects_merge(effects, const_local_application.effects)
    trace(
      "pass[dae-optimizing]:semantic-const-locals iter=\{const_local_iteration} primary_def=\{const_local_application.primary_def}",
    )
    const_local_iteration += 1
  }
  let pair_if_candidates = touched.copy()
  let pair_if_result = dae_try_rewrite_selected_func408_pair_if_carrier_once(
    current, pair_if_candidates,
  )
  let pair_if_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, pair_if_result, diagnostics,
  )
  if pair_if_application.applied {
    current = pair_if_application.mod_out
    current_boundary_graph_stale = true
    late_shapes_changed = true
    touched = pair_if_application.touched
    changed = pair_if_application.changed
    effects = dae_commit_effects_merge(effects, pair_if_application.effects)
    trace(
      "pass[dae-optimizing]:touched-pair-if-carrier primary_def=\{pair_if_application.primary_def}",
    )
  }
  let terminal_args311_candidates = dae_collect_terminal_call_arg_cleanup_candidates(
    mod_, current, 4, 24,
  )
  let terminal_args311_result = dae_try_rewrite_selected_func311_terminal_call_args_once(
    current, terminal_args311_candidates, trace,
  )
  let terminal_args311_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, terminal_args311_result,
    diagnostics,
  )
  if terminal_args311_application.applied {
    current = terminal_args311_application.mod_out
    current_boundary_graph_stale = true
    late_shapes_changed = true
    touched = terminal_args311_application.touched
    changed = terminal_args311_application.changed
    effects = dae_commit_effects_merge(
      effects,
      terminal_args311_application.effects,
    )
    trace(
      "pass[dae-optimizing]:changed-terminal-call-args-a primary_def=\{terminal_args311_application.primary_def}",
    )
  }
  let terminal_args313_candidates = dae_collect_terminal_call_arg_cleanup_candidates(
    mod_, current, 7, 2,
  )
  let terminal_args313_result = dae_try_rewrite_selected_func313_terminal_call_args_once(
    current, terminal_args313_candidates, trace,
  )
  let terminal_args313_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, terminal_args313_result,
    diagnostics,
  )
  if terminal_args313_application.applied {
    current = terminal_args313_application.mod_out
    current_boundary_graph_stale = true
    late_shapes_changed = true
    touched = terminal_args313_application.touched
    changed = terminal_args313_application.changed
    effects = dae_commit_effects_merge(
      effects,
      terminal_args313_application.effects,
    )
    trace(
      "pass[dae-optimizing]:changed-terminal-call-args-b primary_def=\{terminal_args313_application.primary_def}",
    )
  }
  let global_suffix_candidates = dae_collect_direct_callee_defs_from_selected_callers(
    current, touched,
  )
  while true {
    let global_suffix_application = dae_apply_selected_func323_global_suffix_transaction(
      mod_,
      current,
      touched,
      changed,
      global_suffix_candidates,
      trace,
      original_snapshot=Some(original_boundary_snapshot),
      boundary_snapshot=if !current_boundary_graph_stale {
        Some(current_boundary_graph.snapshot)
      } else {
        None
      },
    )
    if !global_suffix_application.applied {
      break
    }
    current = global_suffix_application.mod_out
    current_boundary_graph_stale = true
    late_shapes_changed = true
    touched = global_suffix_application.touched
    changed = global_suffix_application.changed
    effects = dae_commit_effects_merge(
      effects,
      global_suffix_application.effects,
    )
    dae_diagnostics_record_commit_effects(
      diagnostics,
      global_suffix_application.effects,
    )
    dae_diagnostics_record_applied_effects(
      diagnostics,
      global_suffix_application.effects,
    )
    trace(
      "pass[dae-optimizing]:single-caller-global-suffix primary_def=\{global_suffix_application.primary_def}",
    )
  }
  // Shape cleanup can expose uniform operands only at direct callees of bodies
  // changed by this phase. Seed that exact invalidation frontier instead of
  // rescanning/admitting every module definition.
  let post_shape_uniform = if dae_should_run_changed_direct_callee_uniform_frontier(
      late_shapes_changed,
    ) {
    dae_run_changed_direct_callee_uniform_frontier(
      late_shapes_input, current, touched, changed,
    )
  } else {
    {
      mod_out: current,
      touched,
      changed,
      productive_defs: [],
      effects: dae_commit_effects_empty(original_defined),
    }
  }
  current = post_shape_uniform.mod_out
  touched = post_shape_uniform.touched
  changed = post_shape_uniform.changed
  effects = dae_commit_effects_merge(effects, post_shape_uniform.effects)
  for primary_def in post_shape_uniform.productive_defs {
    trace("pass[dae-optimizing]:post-shape-uniform primary_def=\{primary_def}")
  }
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:late-shapes", late_shapes_start_us,
  )
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes", selected_lanes_start_us,
  )
  let raw_cleanup_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:raw-cleanup",
  )
  let module_raw_cleanup = dae_strip_module_nops_and_dropped_pure_leaf_once(
    current,
    touched,
    return_touched=false,
  )
  let module_raw_cleanup_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, module_raw_cleanup, diagnostics,
  )
  if module_raw_cleanup_application.applied {
    current = module_raw_cleanup_application.mod_out
    touched = module_raw_cleanup_application.touched
    effects = dae_commit_effects_merge(
      effects,
      module_raw_cleanup_application.effects,
    )
    // The module raw cleanup rewrites bodies but does not discover new DAE
    // candidate functions; preserve the existing scheduler-owned bitmap.
    trace(
      "pass[dae-optimizing]:module-raw-cleanup primary_def=\{module_raw_cleanup_application.primary_def}",
    )
    changed = module_raw_cleanup_application.changed
  }
  perf_stop_timer_opt(perf, "detail:dae:core:raw-cleanup", raw_cleanup_start_us)
  let post_raw_selected_lanes_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:post-raw-selected-lanes",
  )
  let changed_terminal_cleanup_input = current
  let mut changed_terminal_phase_changed = false
  let changed_terminal_candidates = dae_collect_terminal_callers_of_changed_boundaries(
    mod_, current,
  )
  while true {
    let const_if_result = dae_try_simplify_selected_const_if_defs_once(
      current, changed_terminal_candidates,
    )
    let const_if_application = dae_apply_body_only_family_result_transaction(
      original_boundary_snapshot, current, touched, changed, const_if_result, diagnostics,
    )
    if !const_if_application.applied {
      break
    }
    current = const_if_application.mod_out
    changed_terminal_phase_changed = true
    touched = const_if_application.touched
    changed = const_if_application.changed
    effects = dae_commit_effects_merge(effects, const_if_application.effects)
    trace(
      "pass[dae-optimizing]:changed-terminal-const-if primary_def=\{const_if_application.primary_def}",
    )
  }
  while true {
    let terminal_local_result = dae_try_inline_selected_terminal_call_local_sets_once(
      current, changed_terminal_candidates,
    )
    let terminal_local_application = dae_apply_body_only_family_result_transaction(
      original_boundary_snapshot, current, touched, changed, terminal_local_result,
      diagnostics,
    )
    if !terminal_local_application.applied {
      break
    }
    current = terminal_local_application.mod_out
    changed_terminal_phase_changed = true
    touched = terminal_local_application.touched
    changed = terminal_local_application.changed
    effects = dae_commit_effects_merge(
      effects,
      terminal_local_application.effects,
    )
    trace(
      "pass[dae-optimizing]:changed-terminal-call-locals primary_def=\{terminal_local_application.primary_def}",
    )
  }
  let default_wrapper_result = dae_try_cleanup_selected_func327_default_wrappers_once(
    current, changed_terminal_candidates,
  )
  let default_wrapper_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, default_wrapper_result,
    diagnostics,
  )
  if default_wrapper_application.applied {
    current = default_wrapper_application.mod_out
    changed_terminal_phase_changed = true
    touched = default_wrapper_application.touched
    changed = default_wrapper_application.changed
    effects = dae_commit_effects_merge(
      effects,
      default_wrapper_application.effects,
    )
    trace(
      "pass[dae-optimizing]:changed-terminal-default-wrappers primary_def=\{default_wrapper_application.primary_def}",
    )
  }
  let changed_terminal_uniform = if dae_should_run_changed_direct_callee_uniform_frontier(
      changed_terminal_phase_changed,
    ) {
    dae_run_changed_direct_callee_uniform_frontier(
      changed_terminal_cleanup_input, current, touched, changed,
    )
  } else {
    {
      mod_out: current,
      touched,
      changed,
      productive_defs: [],
      effects: dae_commit_effects_empty(original_defined),
    }
  }
  current = changed_terminal_uniform.mod_out
  touched = changed_terminal_uniform.touched
  changed = changed_terminal_uniform.changed
  effects = dae_commit_effects_merge(effects, changed_terminal_uniform.effects)
  for primary_def in changed_terminal_uniform.productive_defs {
    trace(
      "pass[dae-optimizing]:post-changed-terminal-uniform primary_def=\{primary_def}",
    )
  }
  let final_return_suffix_cleanup = dae_strip_module_root_return_suffix_once(
    current, touched,
  )
  let final_return_suffix_cleanup_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, final_return_suffix_cleanup,
    diagnostics,
  )
  if final_return_suffix_cleanup_application.applied {
    current = final_return_suffix_cleanup_application.mod_out
    touched = final_return_suffix_cleanup_application.touched
    effects = dae_commit_effects_merge(
      effects,
      final_return_suffix_cleanup_application.effects,
    )
    trace(
      "pass[dae-optimizing]:final-return-suffix-cleanup primary_def=\{final_return_suffix_cleanup_application.primary_def}",
    )
    changed = final_return_suffix_cleanup_application.changed
  }
  perf_stop_timer_opt(
    perf, "detail:dae:core:post-raw-selected-lanes", post_raw_selected_lanes_start_us,
  )
  {
    mod_out: current,
    touched,
    changed,
    primary_def: -1,
    effects,
    diagnostics,
    single_caller_throttle_consumed: unprofitable_removal_iters > 0,
  }
}

///|
fn row_ref_dae_run_module_pass_with_trap_policy(
  mod_ : @lib.Module,
  optimize~ : Bool = false,
  trace~ : ((String) -> Unit)? = None,
  traps_never_happen~ : Bool = false,
  perf~ : HotPerfSession? = None,
  skip_param_removal~ : Bool = false,
  no_callback_trace~ : DaeNoCallbackTrace? = None,
) -> @lib.Module {
  if pass_module_has_offset_sensitive_metadata(mod_) {
    return mod_
  }
  let trace_fn = match trace {
    Some(cb) => cb
    None => fn(_line : String) { () }
  }
  let no_callback_trace = if trace is None && perf is None {
    Some({ callback: trace_fn, })
  } else {
    no_callback_trace
  }
  let result = row_ref_dae_run_core(
    mod_,
    trace_fn,
    optimize~,
    perf~,
    single_caller_throttle_consumed=skip_param_removal,
    traps_never_happen~,
    results_only=skip_param_removal,
    no_callback_trace~,
  )
  dae_trace_diagnostics(
    trace_fn,
    if optimize {
      "dae-optimizing"
    } else {
      "dead-argument-elimination"
    },
    result.diagnostics,
  )
  let (debris_cleaned, debris_changed) = dae_cleanup_dropped_unreachable_debris(
    result.mod_out,
  )
  if debris_changed {
    trace_fn("pass[dae]:cleanup-dropped-unreachable-debris")
  }
  let cleaned = dae_run_nested_cleanup(
    debris_cleaned,
    result.touched,
    trace_fn,
    optimize,
    traps_never_happen,
  )
  dae_prune_unused_simple_func_types(cleaned)
}

///|
fn row_ref_dae_run_module_pass(
  mod_ : @lib.Module,
  optimize~ : Bool = false,
  trace~ : ((String) -> Unit)? = None,
) -> @lib.Module {
  row_ref_dae_run_module_pass_with_trap_policy(mod_, optimize~, trace~)
}

///|
fn row_ref_run_hot_pipeline_apply_dae_optimizing_module_pass(
  mod_ : @lib.Module,
  options : HotPipelineOptions,
  single_caller_throttle_consumed~ : Bool = false,
  single_caller_throttle_report~ : Array[Bool] = [],
) -> Result[@lib.Module, String] {
  if o4z_size_candidate_has_unsafe_emscripten_main_runtime(mod_) {
    pipeline_trace_hook(
      options.trace,
      "dae-optimizing",
      "fallback-noop",
      payload="reason=emscripten-main-stateful-runtime-dae-noop",
    )
    return Ok(mod_)
  }
  if run_hot_pipeline_module_has_assemblyscript_startup_exported_memory(mod_) {
    pipeline_trace_hook(
      options.trace,
      "dae-optimizing",
      "fallback-noop",
      payload="reason=assemblyscript-startup-exported-memory-dae-noop",
    )
    return Ok(mod_)
  }
  if run_hot_pipeline_module_has_assemblyscript_json_exported_memory_runtime(
      mod_,
    ) ||
    run_hot_pipeline_module_has_assemblyscript_run_exported_memory_runtime(mod_) {
    pipeline_trace_hook(
      options.trace,
      "dae-optimizing",
      "fallback-noop",
      payload="reason=assemblyscript-exported-memory-dae-noop",
    )
    return Ok(mod_)
  }
  if dae_defined_func_count(mod_) >= 32 &&
    run_hot_pipeline_module_has_typeidx_loop(mod_) {
    pipeline_trace_hook(
      options.trace,
      "dae-optimizing",
      "fallback-typed-loop-safe-batch",
      payload="reason=typed-loop-param-control",
    )
    let (bounded, _, changed, cleanup_touched) = dae_run_typed_loop_safe_batch_result(
      mod_,
      options.trace,
      perf=options.perf,
      cleanup_dropped_pure_leaves=true,
    )
    if !changed {
      return Ok(mod_)
    }
    let simplify_local_touched = Array::make(cleanup_touched.length(), false)
    let coalesce_local_touched = Array::make(cleanup_touched.length(), false)
    let high_local_touched = Array::make(cleanup_touched.length(), false)
    match bounded.code_sec {
      Some(@lib.CodeSec(funcs)) =>
        for def_idx = 0; def_idx < funcs.length(); def_idx = def_idx + 1 {
          if def_idx < cleanup_touched.length() && cleanup_touched[def_idx] {
            let @lib.Func(locals, _) = funcs[def_idx]
            if locals.length() >= 384 {
              simplify_local_touched[def_idx] = true
            }
            if locals.length() >= 32 && locals.length() <= 512 {
              coalesce_local_touched[def_idx] = true
            }
            if locals.length() >= 128 {
              high_local_touched[def_idx] = true
            }
          }
        }
      None => ()
    }
    pipeline_trace_hook(
      options.trace,
      "dae-optimizing",
      "nested-pass",
      payload="name=simplify-locals-nostructure touched=\{dae_count_touched(simplify_local_touched)} min-body-locals=384",
    )
    let simplify_start_us = perf_start_timer_opt(
      options.perf,
      "detail:dae:typed-loop-safe:simplify-locals-nostructure",
    )
    let simplified = match
      run_hot_pipeline_apply_hot_pass_to_touched(
        bounded,
        simplify_locals_nostructure_descriptor(),
        simplify_local_touched,
        options,
      ) {
      Ok(next) => next
      Err(err) => {
        perf_stop_timer_opt(
          options.perf,
          "detail:dae:typed-loop-safe:simplify-locals-nostructure",
          simplify_start_us,
        )
        return Err(err)
      }
    }
    perf_stop_timer_opt(
      options.perf,
      "detail:dae:typed-loop-safe:simplify-locals-nostructure",
      simplify_start_us,
    )
    pipeline_trace_hook(
      options.trace,
      "dae-optimizing",
      "nested-pass",
      payload="name=coalesce-locals touched=\{dae_count_touched(coalesce_local_touched)} min-body-locals=32 max-body-locals=512",
    )
    let coalesce_start_us = perf_start_timer_opt(
      options.perf,
      "detail:dae:typed-loop-safe:coalesce-locals",
    )
    let coalesced = match
      run_hot_pipeline_apply_coalesce_locals_to_touched(
        simplified, coalesce_local_touched,
      ) {
      Ok(next) => next
      Err(err) => {
        perf_stop_timer_opt(
          options.perf,
          "detail:dae:typed-loop-safe:coalesce-locals",
          coalesce_start_us,
        )
        return Err(err)
      }
    }
    perf_stop_timer_opt(
      options.perf,
      "detail:dae:typed-loop-safe:coalesce-locals",
      coalesce_start_us,
    )
    pipeline_trace_hook(
      options.trace,
      "dae-optimizing",
      "nested-pass",
      payload="name=reorder-locals touched=\{dae_count_touched(high_local_touched)} min-body-locals=128",
    )
    return run_hot_pipeline_apply_reorder_locals_to_touched(
      coalesced, high_local_touched,
    )
  }
  let core_start_us = perf_start_timer_opt(options.perf, "detail:dae:core")
  let result = row_ref_dae_run_core(
    mod_,
    options.trace,
    optimize=true,
    perf=options.perf,
    single_caller_throttle_consumed~,
    traps_never_happen=options.traps_never_happen,
    no_callback_trace=hot_pipeline_dae_no_callback_trace(options),
  )
  let mut core_effects = result.effects
  let throttle_consumed = result.single_caller_throttle_consumed ||
    dae_modules_form_single_caller_param_wave(mod_, result.mod_out)
  perf_stop_timer_opt(options.perf, "detail:dae:core", core_start_us)
  let (core_repaired, core_repair_changed) = dae_cleanup_dropped_unreachable_debris_touched(
    result.mod_out,
    result.touched,
  )
  if core_repair_changed {
    pipeline_trace_hook(
      options.trace,
      "dae-optimizing",
      "mandatory-boundary-repair",
      payload="reason=unreachable-tail-after-signature-change",
    )
  }
  let mut core_mod = core_repaired
  let mut core_touched = result.touched
  let call_sink_uniform = dae_run_call_sink_uniform_parameter_flow(
    core_mod,
    mod_,
    core_touched,
    result.changed,
  )
  core_mod = call_sink_uniform.mod_out
  core_touched = call_sink_uniform.touched
  core_effects = dae_commit_effects_merge(
    core_effects,
    call_sink_uniform.effects,
  )
  let call_sink_frontier = dae_collect_applied_call_sink_uniform_defs(
    mod_, core_mod,
  )
  for primary_def in call_sink_uniform.productive_defs {
    (options.trace)(
      "pass[dae-optimizing]:call-sink-uniform primary_def=\{primary_def}",
    )
  }
  let broad_adjacent = dae_run_broad_exact_param_adjacent_cleanup_root(
    mod_,
    core_mod,
    call_sink_frontier,
    core_touched,
    result.changed,
    options.trace,
  )
  core_mod = broad_adjacent.mod_out
  core_touched = broad_adjacent.touched
  core_effects = dae_commit_effects_merge(core_effects, broad_adjacent.effects)
  match broad_adjacent.candidate {
    Some(candidate) =>
      (options.trace)(
        "pass[dae-optimizing]:broad-exact-param-adjacent root_def=\{candidate.root_def} defs=[\{candidate.first_def}, \{candidate.second_def}] payoff=\{candidate.payoff}",
      )
    None => ()
  }
  // Forwarding SCC/component work is owned by the epoch-bearing effect
  // frontier after the shared nested roster; do not run a pre-roster phase loop.
  let broad_uniform = dae_run_broad_uniform_parameter_flow(
    core_mod,
    mod_,
    core_touched,
    result.changed,
  )
  core_mod = broad_uniform.mod_out
  core_touched = broad_uniform.touched
  core_effects = dae_commit_effects_merge(core_effects, broad_uniform.effects)
  for primary_def in broad_uniform.productive_defs {
    (options.trace)(
      "pass[dae-optimizing]:broad-exact-uniform primary_def=\{primary_def}",
    )
  }
  let payoff_chain = dae_run_broad_dropped_result_payoff_chain(
    core_mod,
    core_touched,
    result.changed,
    perf=options.perf,
  )
  core_mod = payoff_chain.mod_out
  core_touched = payoff_chain.touched
  core_effects = dae_commit_effects_merge(core_effects, payoff_chain.effects)
  let payoff_cleanup_candidates = dae_collect_dropped_result_payoff_cleanup_candidates(
    mod_, core_mod,
  )
  let payoff_final_reorder_defs : Array[Int32] = []
  for candidate in payoff_cleanup_candidates {
    payoff_final_reorder_defs.push(candidate.callee_def)
  }
  let payoff_literal = run_hot_pipeline_apply_dae_payoff_direct_callee_exact_literal(
    mod_, core_mod, payoff_final_reorder_defs, core_touched, options,
  )
  core_mod = payoff_literal.mod_out
  core_touched = payoff_literal.touched
  core_effects = dae_commit_effects_merge(core_effects, payoff_literal.effects)
  if payoff_literal.applied {
    let post_literal_direct_gc = dae_apply_direct_gc_batch_transaction(
      row_ref_dae_collect_original_boundary_snapshot(mod_),
      core_mod,
      core_touched,
      true,
    )
    if post_literal_direct_gc.applied {
      core_mod = post_literal_direct_gc.mod_out
      core_touched = post_literal_direct_gc.touched
      core_effects = dae_commit_effects_merge(
        core_effects,
        post_literal_direct_gc.effects,
      )
      (options.trace)(
        "pass[dae-optimizing]:payoff-post-literal-direct-gc primary_def=\{post_literal_direct_gc.primary_def}",
      )
    }
    let post_literal_adjacent = dae_run_broad_exact_param_adjacent_cleanup_root(
      mod_,
      core_mod,
      payoff_final_reorder_defs,
      core_touched,
      true,
      options.trace,
    )
    core_mod = post_literal_adjacent.mod_out
    core_touched = post_literal_adjacent.touched
    core_effects = dae_commit_effects_merge(
      core_effects,
      post_literal_adjacent.effects,
    )
    match post_literal_adjacent.candidate {
      Some(candidate) =>
        (options.trace)(
          "pass[dae-optimizing]:payoff-post-literal-adjacent root_def=\{candidate.root_def} defs=[\{candidate.first_def}, \{candidate.second_def}] payoff=\{candidate.payoff}",
        )
      None => ()
    }
  }
  // Finish the committed boundary's local read/write debris on its touched
  // functions. This erases unread storage without running a private pass
  // roster or moving effectful producers, including callers that correctly
  // do not qualify for the more expensive nested optimization roster.
  core_mod = dae_cleanup_touched_unread_locals(core_mod, core_touched)
  // Payoff/result producers already publish exact worth and touched effects.
  // The shared roster below is the sole nested cleanup owner; do not replay
  // simplify/vacuum/coalesce/reorder in a payoff-private fixed-round loop.
  // Feed producer-owned worth directly to the sole shared cleanup roster.
  // Any body cleanup it exposes is detected from the shared before/after
  // product and drives the boundary effect frontier below.
  let worth_optimizing_touched = run_hot_pipeline_dae_worth_optimizing_touched(
    mod_,
    core_mod,
    core_touched,
    producer_effects=Some(core_effects),
  )
  let pre_cleanup_dependencies = dae_boundary_dependency_graph_new(
    dae_current_boundary_graph_new(core_mod),
  )
  let cleaned = match
    run_hot_pipeline_apply_dae_nested_cleanup(
      core_mod,
      worth_optimizing_touched,
      options,
      diagnostics=Some(result.diagnostics),
    ) {
    Ok(next) => next
    Err(err) => return Err(err)
  }
  let broad_cleanup_touched = worth_optimizing_touched
  // Shared nested cleanup feeds all newly exposed boundaries to the common
  // epoch-bearing effect frontier below. Do not recursively invoke row_ref_dae_run_core
  // or apply a post-roster DAE-private body cleanup phase.
  let post_cleanup_touched : Array[Bool] = []
  dae_trace_diagnostics(options.trace, "dae-optimizing", result.diagnostics)
  let post_cleanup_stripped = cleaned
  let prune_start_us = perf_start_timer_opt(
    options.perf,
    "detail:dae:prune-unused-simple-func-types",
  )
  let pruned = dae_prune_unused_simple_func_types(post_cleanup_stripped)
  perf_stop_timer_opt(
    options.perf,
    "detail:dae:prune-unused-simple-func-types",
    prune_start_us,
  )
  // Final cleanup may expose another owned boundary, but convergence must stay
  // on the producer-owned dependency frontier. Do not recursively replay the
  // whole DAEO pipeline. Drain all represented boundary families for the exact
  // worth/cleanup seed, run the shared nested cleanup only for committed
  // effects, and retain each wave only when it validates and strictly shrinks.
  let original = row_ref_dae_collect_original_boundary_snapshot(mod_)
  let mut converged = pruned
  let mut frontier_seed = dae_merge_touched(
    broad_cleanup_touched, worth_optimizing_touched,
  )
  frontier_seed = dae_merge_touched(frontier_seed, post_cleanup_touched)
  let forwarding_graph = dae_current_boundary_graph_new(converged)
  let forwarding_dependencies = dae_boundary_dependency_graph_new(
    forwarding_graph,
  )
  frontier_seed = run_hot_pipeline_dae_expand_frontier_seed_callees(
    frontier_seed, pre_cleanup_dependencies, forwarding_dependencies,
  )
  for members in forwarding_dependencies.forwarding_component_members {
    if members.length() < 2 {
      continue
    }
    for def_idx in members {
      if def_idx >= 0 && def_idx < frontier_seed.length() {
        frontier_seed[def_idx] = true
      }
    }
  }
  let mut convergence_wave = 0
  while true {
    (options.trace)(
      "pass[dae-optimizing]:effect-frontier wave=\{convergence_wave} throttle_consumed=\{throttle_consumed} seeds=\{dae_count_touched(frontier_seed)}",
    )
    let frontier = dae_run_effect_frontier_worklist(
      original,
      converged,
      frontier_seed,
      !throttle_consumed,
      options.trace,
    )
    dae_trace_diagnostics(
      options.trace,
      "dae-optimizing-effect-frontier",
      frontier.diagnostics,
    )
    if !frontier.changed {
      (options.trace)(
        "pass[dae-optimizing]:effect-frontier-result wave=\{convergence_wave} accepted=false reason=empty",
      )
      run_hot_pipeline_dae_report_single_caller_throttle(
        single_caller_throttle_report, throttle_consumed,
      )
      return Ok(converged)
    }
    let (repaired, _) = dae_cleanup_dropped_unreachable_debris_touched(
      frontier.mod_out,
      frontier.touched,
    )
    let frontier_worth = run_hot_pipeline_dae_worth_optimizing_touched(
      converged,
      repaired,
      frontier.touched,
      producer_effects=Some(frontier.effects),
    )
    let frontier_cleaned = match
      run_hot_pipeline_apply_dae_nested_cleanup(
        repaired, frontier_worth, options,
      ) {
      Ok(next) => next
      Err(err) => {
        (options.trace)(
          "pass[dae-optimizing]:effect-frontier-result wave=\{convergence_wave} accepted=false reason=nested-error err=\{err}",
        )
        run_hot_pipeline_dae_report_single_caller_throttle(
          single_caller_throttle_report, throttle_consumed,
        )
        return Ok(converged)
      }
    }
    let candidate = dae_prune_unused_simple_func_types(frontier_cleaned)
    match
      (
        run_hot_pipeline_dae_encoded_size(converged),
        run_hot_pipeline_dae_encoded_size(candidate),
        @validate.validate_module(candidate),
      ) {
      (Some(before), Some(after), Ok(_)) if after < before => {
        (options.trace)(
          "pass[dae-optimizing]:effect-frontier-result wave=\{convergence_wave} accepted=true before=\{before} after=\{after} defs=\{dae_count_touched(frontier_worth)}",
        )
        converged = candidate
        frontier_seed = frontier_worth
        convergence_wave += 1
      }
      (before, after, validation) => {
        let reason = match validation {
          Ok(_) => "non-smaller-or-unencodable"
          Err(_) => "validation"
        }
        (options.trace)(
          "pass[dae-optimizing]:effect-frontier-result wave=\{convergence_wave} accepted=false reason=\{reason} before=\{before.to_string()} after=\{after.to_string()}",
        )
        run_hot_pipeline_dae_report_single_caller_throttle(
          single_caller_throttle_report, throttle_consumed,
        )
        return Ok(converged)
      }
    }
  }
  Ok(converged)
}
