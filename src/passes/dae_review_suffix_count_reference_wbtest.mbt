///|
/// Retained per-callee rescan control.
fn dae_review_suffix_count_reference(
  mod_ : @lib.Module,
  original_param_counts : Array[Int32],
  original_call_counts : Array[Int32],
  original_active_nonself_call_counts : Array[Int32],
  original_active_parameterized_nonself_call_counts : Array[Int32],
  original_nonself_undropped_call_counts : Array[Int32],
  original_self_call_counts : Array[Int32],
  original_escaped_dead_suffix_call_counts : Array[Int32],
  original_dead_suffix_undropped_self_calls : Array[Bool],
  original_dead_suffix_undropped_self_call_param_operands : Array[Bool],
  original_dead_suffix_result_other_calls : Array[Bool],
  original_dead_suffix_mutual_calls : Array[Bool],
  first_roots~ : Array[Int32]? = None,
) -> Array[Int32] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    if dae_should_preserve_undropped_self_result_from_no_param_dropped_caller(
        caller_def, original_param_counts, original_call_counts, original_active_nonself_call_counts,
        original_active_parameterized_nonself_call_counts, original_nonself_undropped_call_counts,
        original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
        original_dead_suffix_undropped_self_call_param_operands, original_dead_suffix_result_other_calls,
        original_dead_suffix_mutual_calls,
      ) {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def {
          counts[callee_def] = counts[callee_def] +
            dae_count_dead_suffix_direct_call_to(
              body,
              imported + callee_def,
              known_first_root=dae_original_first_root_index(
                body, first_roots, caller_def,
              ),
            )
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}
