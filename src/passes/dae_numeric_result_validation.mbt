///|
/// Only simple numeric/vector values enter this private producer scope.
fn dae_numeric_result_value(value : @lib.ValType) -> Bool {
  match value {
    @lib.NumTypeValType(_) | @lib.VecTypeValType => true
    _ => false
  }
}

///|
/// The final candidate must independently remove one numeric result only.
fn dae_numeric_result_signature_change(
  old : @lib.FuncType,
  next : @lib.FuncType,
) -> Bool {
  let @lib.FuncType(old_params, old_results) = old
  let @lib.FuncType(next_params, next_results) = next
  old_params == next_params &&
  old_params.all(dae_numeric_result_value) &&
  old_results.length() == 1 &&
  dae_numeric_result_value(old_results[0]) &&
  next_results.is_empty()
}

///| Plan checks admit only the audited result constructor. They do not replace

///|
/// the independent module, context, body and dependency checks at the gate.
fn dae_numeric_result_validation_plan(plan : DaeRewritePlan) -> Bool {
  let @lib.TypeSec(old_types) = plan.type_section_rewrite.expected
  let @lib.TypeSec(next_types) = plan.type_section_rewrite.replacement
  physical_equal(old_types, next_types) &&
  plan.parameter_actions.all(fn(action) { action == DaeKeepParameter }) &&
  plan.result_actions.length() == 1 &&
  plan.result_actions[0] == DaeRemoveResult &&
  dae_numeric_result_signature_change(
    plan.old_signature,
    plan.replacement_signature,
  )
}

///| Preserve a source only before the audited numeric result COW constructor.

///|
/// Unsupported signatures still end the scope before any producer runs.
fn dae_numeric_result_validation_before_producer(
  chain : DaeScalarValidationChain?,
  graph : DaeCurrentBoundaryGraph,
  target_def : Int32,
) -> Unit {
  let allowed = match chain {
    Some(chain) if chain.no_callback is Some(_) &&
      chain.numeric_result_source &&
      target_def >= 0 &&
      target_def < graph.snapshot.defined => {
      let target_abs = graph.snapshot.imported + target_def
      if target_abs < 0 || target_abs >= graph.snapshot.function_types.length() {
        false
      } else {
        let calls = graph.snapshot.call_facts
        let direct = dae_call_boundary_count_at(calls.direct_calls, target_abs)
        let all_dropped = direct > 0 &&
          dae_call_boundary_count_at(calls.dropped_calls, target_abs) == direct
        match graph.snapshot.function_types[target_abs] {
          Some(@lib.FuncType(params, results)) =>
            all_dropped &&
            params.all(dae_numeric_result_value) &&
            results.length() == 1 &&
            dae_numeric_result_value(results[0])
          None => false
        }
      }
    }
    _ => false
  }
  if !allowed {
    dae_scalar_validation_barrier_opt(chain)
  }
}

///|
/// Validate the final reconstructed commit, never a producer touch mask.
fn dae_numeric_result_validation_check_candidate(
  chain : DaeScalarValidationChain,
  source : @lib.Module,
  candidate : @lib.Module,
  plan : DaeRewritePlan,
  work~ : DaeScalarValidationWork? = None,
) -> Result[Unit, @validate.ValidationError] {
  if dae_numeric_result_validation_plan(plan) {
    return dae_scalar_validation_check_candidate(
      chain,
      source,
      candidate,
      work~,
      allow_numeric_result_removal=true,
    )
  }
  // Appended/replaced types, references and all other plans use the full gate.
  // Do not carry that unsupported producer's checked source to a later offer.
  dae_scalar_validation_barrier(chain)
  let result = dae_scalar_validation_check_candidate(
    chain,
    source,
    candidate,
    work~,
  )
  dae_scalar_validation_barrier(chain)
  result
}
