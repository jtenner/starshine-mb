///|
// Frozen pre-admission reference for identical semantic/output controls.
fn dae_restore_admission_reference(
  original : @lib.Module,
  current : @lib.Module,
  candidate_defs? : Array[Bool]? = None,
) -> DaePassResult {
  let imported = dae_imported_func_count(original)
  let original_funcs = match original.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None =>
      return { mod_out: current, touched: [], changed: false, primary_def: -1, }
  }
  let original_type_indices = dae_collect_func_type_indices(original)
  let original_escaped = dae_collect_escapes(
    original,
    original_type_indices.length(),
  )
  let current_type_indices = dae_collect_func_type_indices(current)
  let (current_type_idxs, current_funcs, current_type_sec) = match
    (current.func_sec, current.code_sec, current.type_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs)), Some(type_sec)) =>
      (type_idxs.copy(), funcs, type_sec)
    _ =>
      return { mod_out: current, touched: [], changed: false, primary_def: -1, }
  }
  let touched = Array::make(current_funcs.length(), false)
  let type_idxs = current_type_idxs
  let mut type_sec = current_type_sec
  let mut changed = false
  let mut def_idx = 0
  while def_idx < current_funcs.length() && def_idx < original_funcs.length() {
    match candidate_defs {
      Some(candidate_defs) if def_idx >= candidate_defs.length() ||
        !candidate_defs[def_idx] => {
        def_idx += 1
        continue
      }
      _ => ()
    }
    let callee_abs = imported + def_idx
    match dae_resolve_func_type(original, original_type_indices, callee_abs) {
      Some(@lib.FuncType(original_params, _)) if original_params.length() > 0 => {
        let keep = dae_collect_dead_suffix_self_operand_params(
          original_funcs[def_idx],
          callee_abs,
          original_params.length(),
          original,
          original_type_indices,
          original_escaped,
          false,
        )
        let restored_params = dae_filter_params(original_params, keep)
        if restored_params.length() == 1 &&
          restored_params[0] == @lib.ValType::f64() &&
          dae_func_is_unreachable_only(current_funcs[def_idx]) {
          match
            dae_resolve_func_type(current, current_type_indices, callee_abs) {
            Some(@lib.FuncType(current_params, current_results)) if current_params.length() ==
              0 => {
              let (next_type_sec, new_type_idx) = dae_update_defined_func_type(
                current, type_sec, type_idxs, def_idx, restored_params, current_results,
              )
              type_sec = next_type_sec
              type_idxs[def_idx] = new_type_idx
              touched[def_idx] = true
              changed = true
            }
            _ => ()
          }
        }
      }
      _ => ()
    }
    def_idx += 1
  }
  if !changed {
    return { mod_out: current, touched: [], changed: false, primary_def: -1, }
  }
  {
    mod_out: current
    .with_type_sec(type_sec)
    .with_func_sec(@lib.FuncSec::new(type_idxs))
    .without_name_sec(),
    touched,
    changed: true,
    primary_def: -1,
  }
}
