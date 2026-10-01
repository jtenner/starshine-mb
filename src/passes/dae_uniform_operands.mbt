///|
/// Recover operands within this exact instruction scope. No facts survive a
/// changed body, callee signature or control entry stack.
fn dae_uniform_callsite_operands_at(
  mod_ : @lib.Module,
  scope : Array[@lib.Instruction],
  call_idx : Int,
  param_count : Int,
  entry_stack_values : Int,
  func_type_indices : Array[@lib.TypeIdx],
) -> DaeUniformCallsiteOperands? {
  let direct_actual_start = dae_callsite_contiguous_single_root_actual_start(
    scope, call_idx, param_count, mod_, func_type_indices,
  )
  let evidence = match direct_actual_start {
    Some(_) => None
    None =>
      match
        dae_callsite_value_slice_evidence(
          scope, call_idx, param_count, entry_stack_values, mod_, func_type_indices,
        ) {
        Some(evidence) => Some(evidence)
        None => return None
      }
  }
  Some({ param_count, scope, direct_actual_start, evidence, })
}
