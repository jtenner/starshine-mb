///| Keep scalar and composite parameter rewrites on the same callee cleanup

///|
/// contract. Other batch callers retain their existing cleanup mode.
fn dae_finalize_removed_parameter_callee(
  evidence : DaeRemovedParamCalleeRewriteEvidence,
  scalar_cleanup : Bool,
) -> @lib.Func {
  let written_locals = dae_collect_written_locals(
    evidence.body,
    evidence.kept_params.length() + evidence.locals.length(),
  )
  let body = dae_simplify_rewritten_add_zero_instrs(
    dae_simplify_rewritten_control_instrs(
      dae_simplify_default_zero_high_guard_instrs(
        evidence.body,
        evidence.kept_params.length(),
        written_locals,
      ),
      scalar_cleanup,
    ),
  )
  let body = if scalar_cleanup {
    dae_fold_const_eq_if_instrs_until_stable(body)
  } else {
    body
  }
  dae_simplify_to_unreachable_when_prefix_unobservable(
    @lib.Func::new(evidence.locals, @lib.Expr::new(body)),
  )
}

///|
fn dae_trim_parameter_rewrite_func(func : @lib.Func) -> @lib.Func {
  let @lib.Func(locals, @lib.Expr(body)) = func
  let (cleaned_body, _) = dae_trim_instrs_after_unreachable_tail(body)
  @lib.Func::new(locals, @lib.Expr::new(cleaned_body))
}

///| Commit the complete private candidate once. The family plan checks original

///| ownership for every changed signature, then verifies the source, epochs,

///|
/// call identities, and complete module validation before publication.
fn dae_commit_composite_parameter_batch(
  original : DaeOriginalBoundarySnapshot,
  current : @lib.Module,
  touched : Array[Bool],
  changed : Bool,
  graph : DaeCurrentBoundaryGraph,
  candidate : DaePassResult,
  materialized_defs : Array[Bool],
) -> DaeExactLiteralWorklistApplication {
  let defined = graph.snapshot.defined
  let unchanged : DaeExactLiteralWorklistApplication = {
    mod_out: current,
    touched,
    changed,
    productive_defs: [],
    effects: dae_commit_effects_empty(defined),
  }
  if !candidate.changed || candidate.touched.length() != defined {
    return unchanged
  }
  let candidate_funcs = match candidate.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) if funcs.length() == defined => funcs
    _ => return unchanged
  }
  let indices = dae_collect_func_type_indices(candidate.mod_out)
  let candidate_signatures = dae_collect_defined_function_types(
    candidate.mod_out,
    graph.snapshot.imported,
    defined,
    indices,
  )
  let facts = dae_boundary_facts_from_snapshots(original, graph)
  let effects = dae_commit_effects_empty(defined)
  let productive_defs : Array[Int32] = []
  let mut scratch_locals_added = 0
  let mut changed_type_index_targets = 0
  for def_idx in 0..<defined {
    let func_abs = graph.snapshot.imported + def_idx
    let before_signature = graph.snapshot.function_types[func_abs]
    let after_signature = candidate_signatures[def_idx]
    let fully_materialized = def_idx < materialized_defs.length() &&
      materialized_defs[def_idx]
    if fully_materialized {
      // A failed or partial member would need scalar work at its original
      // position. Publish the prefix only when every admitted member is done.
      match (before_signature, after_signature) {
        (Some(@lib.FuncType(before_params, _)), Some(@lib.FuncType([], _))) if !before_params.is_empty() =>
          ()
        _ => return unchanged
      }
    }
    if before_signature != after_signature {
      if !fully_materialized {
        return unchanged
      }
      if !dae_can_change_parameters(facts, func_abs) {
        return unchanged
      }
      match (before_signature, after_signature) {
        (
          Some(@lib.FuncType(before_params, before_results)),
          Some(@lib.FuncType(after_params, after_results)),
        ) if before_results == after_results &&
          after_params.length() < before_params.length() => ()
        _ => return unchanged
      }
      productive_defs.push(def_idx)
      if func_abs < indices.length() &&
        graph.snapshot.type_indices[func_abs] != indices[func_abs] {
        changed_type_index_targets += 1
      }
      effects.parameter_changed[def_idx] = true
      effects.local_projection_changed[def_idx] = true
      effects.worth_decided[def_idx] = true
      effects.worth_optimizing[def_idx] = true
      effects.body_materialized[def_idx] = def_idx < materialized_defs.length() &&
        materialized_defs[def_idx]
    }
    let @lib.Func(before_locals, _) = graph.snapshot.funcs[def_idx]
    let @lib.Func(after_locals, _) = candidate_funcs[def_idx]
    let body_changed = !dae_snapshot_func_unchanged(
      graph.snapshot.funcs[def_idx],
      candidate_funcs[def_idx],
    )
    effects.structurally_touched[def_idx] = body_changed ||
      before_signature != after_signature
    if before_locals != after_locals {
      effects.local_projection_changed[def_idx] = true
    }
    if after_locals.length() > before_locals.length() {
      scratch_locals_added += after_locals.length() - before_locals.length()
      effects.body_localized[def_idx] = true
      effects.worth_decided[def_idx] = true
      effects.worth_optimizing[def_idx] = true
    }
  }
  if productive_defs.is_empty() {
    return unchanged
  }
  let count = productive_defs.length()
  let before_type_count = match current.type_sec {
    Some(types) => dae_type_sec_flattened_length(types)
    None => return unchanged
  }
  let after_type_count = match candidate.mod_out.type_sec {
    Some(types) => dae_type_sec_flattened_length(types)
    None => return unchanged
  }
  let appended = after_type_count - before_type_count
  let reasons : Array[DaeDecisionReason] = []
  for _index in 0..<count {
    reasons.push(DaeCandidateProduced)
  }
  let effects = {
    ..effects,
    candidates_produced: count,
    scratch_locals_added,
    // An in-place signature replacement keeps its original index but is not
    // reuse. Changed indices consist of appended signatures and actual reuse.
    type_entries_reused: if appended >= 0 &&
      appended <= changed_type_index_targets {
      changed_type_index_targets - appended
    } else {
      0
    },
    type_entries_appended: if appended > 0 {
      appended
    } else {
      0
    },
    type_section_changed: current.type_sec != candidate.mod_out.type_sec,
    metadata_changed: current.name_sec != candidate.mod_out.name_sec,
    invalidation_domains: dae_invalidation_domains_for_work_family(
      DaeUniformActualWork,
    ),
    decision_reasons: reasons,
  }
  let normalized_candidate = {
    ..candidate,
    touched: effects.structurally_touched,
    primary_def: productive_defs[0],
  }
  let plan = match
    dae_build_family_rewrite_plan(
      original,
      current,
      graph,
      normalized_candidate.primary_def,
      normalized_candidate,
      effects=Some(effects),
    ) {
    Some(plan) => plan
    None => return unchanged
  }
  let application = dae_apply_family_rewrite_plan(current, graph, plan)
  if !application.applied {
    return unchanged
  }
  let applied_reasons : Array[DaeDecisionReason] = []
  for _index in 0..<count {
    applied_reasons.push(DaeCandidateProduced)
    applied_reasons.push(DaeCandidateApplied)
  }
  {
    mod_out: application.result.mod_out,
    touched: dae_merge_touched(touched.copy(), application.result.touched),
    changed: true,
    productive_defs,
    effects: {
      ..application.effects,
      candidates_produced: count,
      candidates_applied: count,
      decision_reasons: applied_reasons,
    },
  }
}

///| Batch a strictly ordered prefix of complete ordinary literal work at its

///| existing phase. Other work keeps its scalar path and its exact proofs.

///|
/// The caller must refresh its graph after a successful composite commit.
fn dae_apply_composite_exact_literal_batch(
  original : DaeOriginalBoundarySnapshot,
  current : @lib.Module,
  touched : Array[Bool],
  changed : Bool,
  graph : DaeCurrentBoundaryGraph,
  candidate_defs : Array[Int32],
) -> DaeExactLiteralWorklistApplication {
  let unchanged : DaeExactLiteralWorklistApplication = {
    mod_out: current,
    touched,
    changed,
    productive_defs: [],
    effects: dae_commit_effects_empty(dae_defined_func_count(current)),
  }
  let snapshot = graph.snapshot
  if original.imported != snapshot.imported ||
    original.defined != snapshot.defined ||
    candidate_defs.is_empty() {
    return unchanged
  }
  let mut previous_def = -1
  for def_idx in candidate_defs {
    if def_idx <= previous_def {
      // The producer applies plans in definition order. Other list orders and
      // repeated definitions must keep their existing scalar transaction order.
      return unchanged
    }
    previous_def = def_idx
  }
  let facts = dae_boundary_facts_from_snapshots(original, graph)
  let active = Array::make(snapshot.defined, false)
  let mut any = false
  for def_idx in candidate_defs {
    let callee_abs = snapshot.imported + def_idx
    if def_idx < 0 ||
      def_idx >= snapshot.defined ||
      !dae_can_change_parameters(facts, callee_abs) {
      break
    }
    let params = match snapshot.function_types[callee_abs] {
      Some(@lib.FuncType(params, _)) if !params.is_empty() => params
      _ => break
    }
    let @lib.Func(locals, _) = snapshot.funcs[def_idx]
    let local_use = dae_local_use_for_callee(
      snapshot.funcs[def_idx],
      params.length() + locals.length(),
      callee_abs,
      params.length(),
    )
    let mut ordinary_parameters = true
    for param_idx in 0..<params.length() {
      if !local_use.gets[param_idx] || local_use.writes[param_idx] {
        ordinary_parameters = false
        break
      }
    }
    if !ordinary_parameters {
      // The batch must not add unread-parameter work or change entry-liveness
      // handling while replacing an exact-literal phase.
      break
    }
    let values = match
      dae_collect_uniform_const_actuals_from_current_call_facts(
        current,
        callee_abs,
        params.length(),
        snapshot.type_indices,
        snapshot.boundary_facts,
        snapshot.function_infos,
        allow_immutable_global_get=true,
      ) {
      Some(values) => values
      None => break
    }
    let mut supported = values.length() == params.length()
    for value in values {
      match value {
        Some(value) =>
          if !dae_batchable_uniform_literal(value) {
            supported = false
            break
          }
        None => {
          supported = false
          break
        }
      }
    }
    if !supported {
      break
    }
    active[def_idx] = true
    any = true
  }
  if !any {
    return unchanged
  }
  let candidate = dae_try_apply_unread_param_batch(
    current,
    active_defs=Some(active),
    allow_uniform_params=true,
    scalar_callee_cleanup=true,
    boundary_snapshot=Some(snapshot),
  )
  dae_commit_composite_parameter_batch(
    original, current, touched, changed, graph, candidate, active,
  )
}

///| Retry the remaining ordered work after its first scalar commit. Admission

///|
/// and transaction checks remain those of the ordinary composite helper.
fn dae_apply_composite_literal_suffix_after_scalar(
  original : DaeOriginalBoundarySnapshot,
  current : @lib.Module,
  touched : Array[Bool],
  changed : Bool,
  graph : DaeCurrentBoundaryGraph,
  candidate_defs : Array[Int32],
  completed_index : Int32,
) -> DaeExactLiteralWorklistApplication {
  if completed_index < 0 || completed_index >= candidate_defs.length() - 2 {
    // One remaining scalar candidate has no transaction gate to combine.
    return {
      mod_out: current,
      touched,
      changed,
      productive_defs: [],
      effects: dae_commit_effects_empty(dae_defined_func_count(current)),
    }
  }
  let suffix = Array::makei(candidate_defs.length() - completed_index - 1, fn(
    index,
  ) {
    candidate_defs[completed_index + index + 1]
  })
  dae_apply_composite_exact_literal_batch(
    original, current, touched, changed, graph, suffix,
  )
}
