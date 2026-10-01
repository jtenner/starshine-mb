///|
/// Recover operands within this exact instruction scope. No facts survive a
/// changed body, callee signature or control entry stack.
fn dae_uniform_operands_sliced_reference_at(
  mod_ : @lib.Module,
  scope : Array[@lib.Instruction],
  call_idx : Int,
  param_count : Int,
  entry_stack_values : Int,
  func_type_indices : Array[@lib.TypeIdx],
) -> DaeUniformCallsiteOperands? {
  let evidence = match
    dae_callsite_value_slice_evidence(
      scope, call_idx, param_count, entry_stack_values, mod_, func_type_indices,
    ) {
    Some(evidence) => evidence
    None => return None
  }
  Some({
    param_count,
    scope,
    direct_actual_start: None,
    evidence: Some(evidence),
  })
}
