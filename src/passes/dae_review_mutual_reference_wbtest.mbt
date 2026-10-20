///|
/// Pre-review body-rescan control for the dedicated performance lane.
fn dae_review_mutual_reference(
  mod_ : @lib.Module,
  first_roots~ : Array[Int32]? = None,
) -> Array[Bool] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, false)
  }
  let flags = Array::make(defined, false)
  let counted_stamp = Array::make(defined, -1)
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let callee_abs = imported + def_idx
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    let targets : Array[Int32] = []
    dae_collect_dead_suffix_direct_targets(
      body,
      imported,
      defined,
      targets,
      known_first_root=dae_original_first_root_index(body, first_roots, def_idx),
    )
    for target in targets {
      if target != def_idx && counted_stamp[target] != def_idx {
        counted_stamp[target] = def_idx
        if target >= 0 && target < funcs.length() {
          let @lib.Func(_, @lib.Expr(other_body)) = funcs[target]
          if dae_count_direct_call_anywhere_to(other_body, callee_abs) > 0 {
            flags[def_idx] = true
          }
        }
      }
    }
    def_idx += 1
  }
  flags
}
