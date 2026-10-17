// Frozen unchanged effect collector. Only its own function name changes.

///|
fn dae_effect_guard_frozen_candidate_effects(
  current : @lib.Module,
  graph : DaeCurrentBoundaryGraph,
  item : DaeWorkItem,
  candidate : DaePassResult,
) -> DaeCommitEffects {
  let defined = graph.snapshot.defined
  let effects = dae_commit_effects_empty(defined)
  if !dae_should_scan_work_item_candidate_effects(candidate) {
    return effects
  }
  // Effects need body ownership, signatures and aggregate call facts only.
  // Keep these inputs local; full graph records and epochs are unused here.
  let after_funcs = match candidate.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => []
  }
  let after_type_indices = dae_collect_func_type_indices(candidate.mod_out)
  let after_function_types = dae_snapshot_function_types(
    candidate.mod_out,
    after_type_indices,
  )
  let after_call_facts = dae_collect_current_call_facts(
    candidate.mod_out,
    after_type_indices.length(),
  )
  let mut any_body_changed = false
  let mut any_locals_changed = false
  let mut def_idx = 0
  while def_idx < defined {
    let structurally_touched = def_idx < candidate.touched.length() &&
      candidate.touched[def_idx]
    if structurally_touched {
      effects.structurally_touched[def_idx] = true
    }
    if def_idx < graph.snapshot.funcs.length() && def_idx < after_funcs.length() {
      let @lib.Func(before_locals, before_expr) = graph.snapshot.funcs[def_idx]
      let @lib.Func(after_locals, after_expr) = after_funcs[def_idx]
      if before_locals != after_locals {
        effects.local_projection_changed[def_idx] = true
        any_locals_changed = true
      }
      if !dae_snapshot_expr_unchanged(before_expr, after_expr) {
        any_body_changed = true
      }
    }
    def_idx += 1
  }
  let target = item.target_def
  let mut parameter_changed = false
  let mut parameter_refined = false
  let mut result_changed = false
  let mut result_removed = false
  if target >= 0 && target < defined {
    let target_abs = graph.snapshot.imported + target
    let before_signature = if target_abs >= 0 &&
      target_abs < graph.snapshot.function_types.length() {
      graph.snapshot.function_types[target_abs]
    } else {
      None
    }
    let after_signature = if target_abs >= 0 &&
      target_abs < after_function_types.length() {
      after_function_types[target_abs]
    } else {
      None
    }
    match (before_signature, after_signature) {
      (
        Some(@lib.FuncType(before_params, before_results)),
        Some(@lib.FuncType(after_params, after_results)),
      ) => {
        parameter_changed = before_params != after_params
        parameter_refined = before_params.length() == after_params.length() &&
          parameter_changed
        result_changed = before_results != after_results
        result_removed = after_results.length() < before_results.length()
      }
      _ => ()
    }
    effects.parameter_changed[target] = parameter_changed
    effects.parameter_type_refined[target] = parameter_refined
    effects.result_changed[target] = result_changed
    effects.result_removed[target] = result_removed
    effects.control_refinalization_required[target] = result_changed ||
      item.family == DaeControlReconstructionWork ||
      item.family == DaeTypeRepairRetryWork
    let target_productive = parameter_changed ||
      result_changed ||
      effects.local_projection_changed[target] ||
      (
        target < graph.snapshot.funcs.length() &&
        target < after_funcs.length() &&
        graph.snapshot.funcs[target] != after_funcs[target]
      )
    match item.family {
      DaeUnusedParameterWork
      | DaeUniformActualWork
      | DaeLocalizationRetryWork
      | DaeGcParameterRefinementWork
      | DaeGcResultRefinementWork
      | DaeDroppedResultWork
      | DaePostCleanupBoundaryRevisitWork => {
        effects.worth_decided[target] = true
        effects.worth_optimizing[target] = target_productive
      }
      DaeForwardingWork
      | DaeControlReconstructionWork
      | DaeTypeRepairRetryWork
      | DaeBodyCleanupWork => ()
    }
    if item.family == DaeUniformActualWork && parameter_changed {
      effects.body_materialized[target] = true
    }
  }
  def_idx = 0
  while def_idx < defined {
    let body_changed = def_idx < graph.snapshot.funcs.length() &&
      def_idx < after_funcs.length() &&
      graph.snapshot.funcs[def_idx] != after_funcs[def_idx]
    if def_idx != target && body_changed {
      match item.family {
        DaeLocalizationRetryWork => {
          effects.worth_decided[def_idx] = true
          effects.worth_optimizing[def_idx] = true
          effects.body_localized[def_idx] = true
        }
        DaeGcResultRefinementWork => {
          effects.worth_decided[def_idx] = true
          effects.worth_optimizing[def_idx] = true
        }
        DaeDroppedResultWork => {
          effects.worth_decided[def_idx] = true
          effects.worth_optimizing[def_idx] = true
          effects.caller_drop_removed[def_idx] = true
        }
        _ => ()
      }
    }
    def_idx += 1
  }
  let type_section_changed = current.type_sec != candidate.mod_out.type_sec
  let metadata_changed = current.name_sec != candidate.mod_out.name_sec
  let call_facts_changed = graph.snapshot.call_facts.direct_calls !=
    after_call_facts.direct_calls ||
    graph.snapshot.call_facts.tail_calls != after_call_facts.tail_calls ||
    graph.snapshot.call_facts.direct_callers != after_call_facts.direct_callers ||
    graph.snapshot.call_facts.dropped_calls != after_call_facts.dropped_calls ||
    graph.snapshot.call_facts.escaped != after_call_facts.escaped
  let invalidation_domains : Array[DaeInvalidationDomain] = []
  if call_facts_changed {
    invalidation_domains.push(DaeInvalidateCalls)
  }
  if parameter_changed || result_changed {
    invalidation_domains.push(DaeInvalidateSignature)
  }
  if result_changed {
    invalidation_domains.push(DaeInvalidateResult)
  }
  if any_body_changed {
    invalidation_domains.push(DaeInvalidateBody)
  }
  if any_locals_changed || parameter_changed {
    invalidation_domains.push(DaeInvalidateLocals)
  }
  if result_changed ||
    item.family == DaeControlReconstructionWork ||
    item.family == DaeTypeRepairRetryWork {
    invalidation_domains.push(DaeInvalidateControl)
  }
  if type_section_changed {
    invalidation_domains.push(DaeInvalidateTypes)
  }
  if metadata_changed {
    invalidation_domains.push(DaeInvalidateMetadata)
  }
  if any_body_changed {
    invalidation_domains.push(DaeInvalidateNestedCleanup)
  }
  let before_type_count = match current.type_sec {
    Some(type_sec) => dae_type_sec_flattened_length(type_sec)
    None => 0
  }
  let after_type_count = match candidate.mod_out.type_sec {
    Some(type_sec) => dae_type_sec_flattened_length(type_sec)
    None => 0
  }
  {
    ..effects,
    type_section_changed,
    metadata_changed,
    type_entries_reused: if (parameter_changed || result_changed) &&
      !type_section_changed {
      1
    } else {
      0
    },
    type_entries_appended: if after_type_count > before_type_count {
      after_type_count - before_type_count
    } else {
      0
    },
    invalidation_domains,
    decision_reasons: [DaeCandidateProduced],
  }
}
