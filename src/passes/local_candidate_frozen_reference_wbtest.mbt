// Frozen pre-C3-validation-order cleanup for behavior and manual paired controls.

///|
fn oi_cleanup_module_encoding_frozen_c3(
  mod_ : @lib.Module,
  touched~ : Array[Bool]? = None,
) -> @lib.Module {
  let mut changed = false
  let candidate = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let next = funcs.mapi(fn(index, func) {
        if touched is Some(selected) &&
          (index >= selected.length() || !selected[index]) {
          return func
        }
        let @lib.Func(locals, @lib.Expr(body)) = func
        let (body, rewritten) = oi_remove_numeric_select_annotations(body)
        changed = changed || rewritten
        if rewritten {
          @lib.Func::new(locals, @lib.Expr::new(body))
        } else {
          func
        }
      })
      if changed {
        mod_.with_code_sec(@lib.CodeSec::new(next))
      } else {
        mod_
      }
    }
    None => mod_
  }
  let cleaned = dfe_cleanup_simple_type_encoding(
    pass_cleanup_unused_type_groups(
      oi_cleanup_declarative_elements(oi_cleanup_control(candidate, touched~)),
    ),
  )
  oi_group_numeric_locals_if_smaller_frozen_c3(cleaned, touched~)
}

///|
fn oi_group_numeric_locals_if_smaller_frozen_c3(
  mod_ : @lib.Module,
  touched~ : Array[Bool]? = None,
  function_comparisons~ : Array[Int32]? = None,
) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let mut has_body_locals = false
  for index in 0..<funcs.length() {
    if touched is Some(set) && (index >= set.length() || !set[index]) {
      continue
    }
    let @lib.Func(locals, _) = funcs[index]
    if locals.length() > 0 {
      has_body_locals = true
      break
    }
  }
  if !has_body_locals {
    return mod_
  }
  if pass_module_has_legacy_try(mod_) ||
    oi_local_group_has_offset_metadata(mod_) ||
    (mod_.name_sec is None && mod_.raw_name_sec_payload is Some(_)) {
    return mod_
  }
  let grouped = run_hot_pipeline_raw_group_body_locals_by_type_module(
    mod_,
    touched~,
  )
  ignore(function_comparisons)
  let size_baseline = if mod_.compiler_fact_custom_section is Some(_) {
    mod_.without_compiler_fact_custom_section()
  } else {
    mod_
  }
  let mut best = mod_
  if !physical_equal(grouped, mod_) {
    match @binary.encoded_module_sizes(size_baseline, grouped) {
      Ok((old_size, new_size)) if new_size < old_size =>
        if oi_validate_local_group_changed_bodies(mod_, grouped) {
          best = grouped
        }
      _ => ()
    }
  }
  // Frequency order can save more access bytes across a LEB boundary than
  // first-type grouping saves in declarations. Compare one existing candidate;
  // keep the numeric/touched admission boundary and the fixed parameter prefix.
  let params = rl_defined_func_param_cache(mod_)
  let mut selected : Array[Bool]? = None
  for index in 0..<funcs.length() {
    if touched is Some(set) && (index >= set.length() || !set[index]) {
      continue
    }
    let @lib.Func(locals, _) = funcs[index]
    if locals.length() == 0 {
      continue
    }
    let ps = match params.get(index) {
      Some(ps) => ps
      None => continue
    }
    if ps.length() + locals.length() > 128 &&
      ps.all(run_hot_pipeline_raw_numeric_local_type) &&
      locals
      .runs()
      .all(fn(run) { run_hot_pipeline_raw_numeric_local_type(run.vt) }) {
      if selected is None {
        selected = Some(Array::make(funcs.length(), false))
      }
      selected.unwrap()[index] = true
    }
  }
  let selected = match selected {
    Some(selected) => selected
    None => return best
  }
  match
    run_hot_pipeline_apply_reorder_locals_to_touched(
      mod_,
      selected,
      params_by_func=Some(params),
    ) {
    Ok(frequency) if !physical_equal(frequency, mod_) => {
      let baseline = if physical_equal(best, mod_) {
        size_baseline
      } else {
        best
      }
      match @binary.encoded_module_sizes(baseline, frequency) {
        Ok((old_size, new_size)) if new_size < old_size =>
          if oi_validate_local_group_changed_bodies(mod_, frequency) {
            return frequency
          }
        _ => ()
      }
    }
    _ => ()
  }
  best
}
