///|
fn numeric_group_context_reference_module(
  mod_ : @lib.Module,
  touched? : Array[Bool]? = None,
) -> @lib.Module {
  // Opaque name bytes cannot be safely permuted without decoding them.
  if mod_.name_sec is None && mod_.raw_name_sec_payload is Some(_) {
    return mod_
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let imported_func_count = run_hot_pipeline_imported_func_count(mod_)
      let module_ctx = @ir.hot_module_context_from_module(mod_)
      let next_funcs : Array[@lib.Func] = Array::new(capacity=funcs.length())
      let remaps : Array[Array[Int]?] = []
      let mut changed = false
      for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
        if touched is Some(selected) &&
          (code_idx >= selected.length() || !selected[code_idx]) {
          next_funcs.push(funcs[code_idx])
          remaps.push(None)
          continue
        }
        let func_idx = @lib.FuncIdx::new(
          (imported_func_count + code_idx).reinterpret_as_uint(),
        )
        let params = run_hot_pipeline_required_func_params(module_ctx, func_idx)
        let (grouped, remap) = run_hot_pipeline_raw_group_body_locals_by_type_func(
          funcs[code_idx],
          params,
        )
        next_funcs.push(grouped)
        remaps.push(remap)
        if remap is Some(_) {
          changed = true
        }
      }
      if changed {
        let candidate = mod_.with_code_sec(@lib.CodeSec::new(next_funcs))
        match rl_rewrite_name_sec(mod_.name_sec, imported_func_count, remaps) {
          Some(names) => candidate.with_name_sec(names)
          None if mod_.name_sec is Some(_) => candidate.without_name_sec()
          None => candidate
        }
      } else {
        mod_
      }
    }
    None => mod_
  }
}
