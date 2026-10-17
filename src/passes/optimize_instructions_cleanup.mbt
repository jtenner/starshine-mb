// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
// Run after all writeback repair: restored functions still use original indices.
fn oi_cleanup_module_encoding(
  mod_ : @lib.Module,
  touched~ : Array[Bool]? = None,
) -> @lib.Module {
  if pass_module_has_offset_sensitive_metadata(mod_) {
    return mod_
  }
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
  let control_cleaned = oi_cleanup_declarative_elements(
    oi_cleanup_control(candidate, touched~),
  )
  let type_cleaned = if pass_encoding_cleanup_may_remap_types(
      control_cleaned, touched,
    ) {
    dfe_cleanup_simple_type_encoding(
      pass_cleanup_unused_type_groups(control_cleaned),
    )
  } else {
    control_cleaned
  }
  let cleaned = oi_cleanup_descriptor_encoding(type_cleaned, touched~)
  oi_group_numeric_locals_if_smaller(cleaned, touched~)
}

///|
// Grouping can only change a function with a removable zero run or a repeated
// numeric declaration type. Distinct nonzero numeric runs are already in the
// bucket order that the grouping helper would produce.
fn oi_numeric_group_has_declaration_candidate(
  mod_ : @lib.Module,
  touched : Array[Bool]?,
) -> Bool {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return false
  }
  for index = 0; index < funcs.length(); index = index + 1 {
    if touched is Some(selected) &&
      (index >= selected.length() || !selected[index]) {
      continue
    }
    let @lib.Func(locals, _) = funcs[index]
    if locals.length() <= 1 {
      continue
    }
    let seen : Array[@lib.ValType] = []
    let mut candidate = false
    let mut supported = true
    for run in locals.runs() {
      if run.count() == 0U {
        candidate = true
        continue
      }
      let ty = run.val_type()
      if !run_hot_pipeline_raw_numeric_local_type(ty) {
        supported = false
        break
      }
      if seen.any(fn(existing) { existing == ty }) {
        candidate = true
      } else {
        seen.push(ty)
      }
    }
    if supported && candidate {
      return true
    }
  }
  false
}

///|
// Binaryen's OI writer groups scalar local declarations by type. Reuse the
// shared index and decoded-name remapper, but keep legacy EH and opaque names
// unchanged and commit only a validated whole-module byte saving.
fn oi_group_numeric_locals_if_smaller(
  mod_ : @lib.Module,
  touched~ : Array[Bool]? = None,
  allow_frequency~ : Bool = true,
  function_comparisons~ : Array[Int32]? = None,
  perf~ : HotPerfSession? = None,
  legacy_guard_scans~ : Array[Int32]? = None,
) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  if !oi_numeric_group_has_declaration_candidate(mod_, touched) {
    // Wide frequency cleanup can remove unused locals even when declaration
    // types are already grouped. Keep the cheap guard for other inputs.
    let mut wide_frequency_candidate = false
    if allow_frequency {
      let params = rl_defined_func_param_cache(mod_)
      for index in 0..<funcs.length() {
        if touched is Some(mask) && (index >= mask.length() || !mask[index]) {
          continue
        }
        let @lib.Func(locals, _) = funcs[index]
        if params.get(index) is Some(ps) &&
          locals.length() > 0 &&
          ps.length() + locals.length() > 128 &&
          ps.all(run_hot_pipeline_raw_numeric_local_type) &&
          locals
          .runs()
          .all(fn(run) { run_hot_pipeline_raw_numeric_local_type(run.vt) }) {
          wide_frequency_candidate = true
          break
        }
      }
    }
    if !wide_frequency_candidate {
      return mod_
    }
  }
  match legacy_guard_scans {
    Some(scans) => scans[0] += 1
    None => ()
  }
  if pass_module_has_legacy_try(mod_) ||
    oi_local_group_has_offset_metadata(mod_) ||
    (mod_.name_sec is None && mod_.raw_name_sec_payload is Some(_)) {
    return mod_
  }
  let grouping_start = perf_start_timer_opt(
    perf, "detail:simplify-locals:encoding-local-group-remap",
  )
  let grouped = run_hot_pipeline_raw_group_body_locals_by_type_module(
    mod_,
    touched~,
  )
  perf_stop_timer_opt(
    perf, "detail:simplify-locals:encoding-local-group-remap", grouping_start,
  )
  ignore(function_comparisons)
  // SL preserves body-local declarations and their names. Its boundary cleanup
  // groups types only; OI can also choose the existing unused-local removal.
  if !allow_frequency {
    return oi_select_local_group_candidate(mod_, grouped, None)
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
    None => return oi_select_local_group_candidate(mod_, grouped, None)
  }
  let frequency = match
    run_hot_pipeline_apply_reorder_locals_to_touched(
      mod_,
      selected,
      params_by_func=Some(params),
    ) {
    Ok(frequency) if !physical_equal(frequency, mod_) => Some(frequency)
    _ => None
  }
  oi_select_local_group_candidate(mod_, grouped, frequency)
}

///|
// Candidates retain the caller's numeric/touched and metadata admission.
// Rank complete encoded costs first, then validate only the candidate needed.
// A cheaper invalid candidate must not exclude a profitable valid fallback.
fn oi_select_local_group_candidate(
  before : @lib.Module,
  grouped : @lib.Module,
  frequency : @lib.Module?,
) -> @lib.Module {
  let baseline = if before.compiler_fact_custom_section is Some(_) {
    before.without_compiler_fact_custom_section()
  } else {
    before
  }
  let grouped_size = if physical_equal(grouped, before) {
    None
  } else {
    match @binary.encoded_module_sizes(baseline, grouped) {
      Ok((old_size, new_size)) if new_size < old_size => Some(new_size)
      _ => None
    }
  }
  let frequency_size = match frequency {
    Some(candidate) if !physical_equal(candidate, before) =>
      match @binary.encoded_module_sizes(baseline, candidate) {
        Ok((old_size, new_size)) if new_size < old_size => Some(new_size)
        _ => None
      }
    _ => None
  }
  let frequency_first = match (grouped_size, frequency_size) {
    (None, Some(_)) => true
    (Some(grouped_size), Some(frequency_size)) => frequency_size < grouped_size
    _ => false
  }
  if frequency_first {
    let candidate = frequency.unwrap()
    if oi_validate_local_group_changed_bodies(before, candidate) {
      return candidate
    }
  }
  if grouped_size is Some(_) &&
    oi_validate_local_group_changed_bodies(before, grouped) {
    return grouped
  }
  if !frequency_first && frequency_size is Some(_) {
    let candidate = frequency.unwrap()
    if oi_validate_local_group_changed_bodies(before, candidate) {
      return candidate
    }
  }
  before
}

///|
// The grouping helper changes only scalar body locals, their accesses, decoded
// local names and stale compiler facts. Every declaration and initializer stays
// in the same index space; unchanged bodies retain their already checked code.
// Validate every replaced body against that unchanged module environment. The
// pipeline's complete final-module validation remains independent of this guard.
fn oi_local_group_changed_bodies(
  before : @lib.Module,
  grouped : @lib.Module,
) -> Array[(@lib.FuncIdx, @lib.Func)] {
  let old = before.code_sec.unwrap().0
  let next = grouped.code_sec.unwrap().0
  let imported = run_hot_pipeline_imported_func_count(before)
  let changed : Array[(@lib.FuncIdx, @lib.Func)] = []
  for index in 0..<next.length() {
    if !physical_equal(old[index], next[index]) {
      changed.push(
        (@lib.FuncIdx::new((imported + index).to_uint()), next[index]),
      )
    }
  }
  changed
}

///|
fn oi_validate_local_group_changed_bodies(
  before : @lib.Module,
  grouped : @lib.Module,
  perf~ : HotPerfSession? = None,
) -> Bool {
  let start = perf_start_timer_opt(
    perf, "detail:simplify-locals:encoding-local-group-validate",
  )
  let result = match
    @validate.validate_defined_funcs_against_module(
      before,
      oi_local_group_changed_bodies(before, grouped),
    ) {
    Ok(errors) => errors.is_empty()
    Err(_) => false
  }
  perf_stop_timer_opt(
    perf, "detail:simplify-locals:encoding-local-group-validate", start,
  )
  result
}

///|
fn oi_local_group_has_offset_metadata(mod_ : @lib.Module) -> Bool {
  for custom in mod_.custom_secs {
    let @lib.CustomSec(@lib.Name(raw_name), _) = custom
    let name = raw_name.to_owned()
    if name.starts_with("metadata.code.") ||
      name.starts_with("reloc.") ||
      name == "linking" ||
      name == "sourceMappingURL" ||
      name == "external_debug_info" ||
      name.starts_with(".debug_") {
      return true
    }
  }
  false
}

///|
fn oi_has_numeric_select_annotation(body : Array[@lib.Instruction]) -> Bool {
  for instr in body {
    match instr {
      @lib.Select(Some(types)) if types.length() == 1 &&
        types[0] is @lib.NumTypeValType(_) => return true
      @lib.Block(_, @lib.Expr(child))
      | @lib.Loop(_, @lib.Expr(child))
      | @lib.TryTable(_, _, @lib.Expr(child)) =>
        if oi_has_numeric_select_annotation(child) {
          return true
        }
      @lib.If(_, yes, no) => {
        if oi_has_numeric_select_annotation(yes) {
          return true
        }
        match no {
          Some(child) =>
            if oi_has_numeric_select_annotation(child) {
              return true
            }
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(child), catches, _) => {
        if oi_has_numeric_select_annotation(child) {
          return true
        }
        for catch_ in catches {
          let child = match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(child))
            | @lib.LegacyCatchAll(@lib.Expr(child)) => child
          }
          if oi_has_numeric_select_annotation(child) {
            return true
          }
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn oi_remove_numeric_select_annotations(
  body : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Bool) {
  if !oi_has_numeric_select_annotation(body) {
    return (body, false)
  }
  let mut changed = false
  let next = body.map(fn(instr) {
    let instr = pass_lower_map_children(instr, fn(child) {
      let (next, rewritten) = oi_remove_numeric_select_annotations(child)
      changed = changed || rewritten
      next
    })
    match instr {
      @lib.Select(Some(types)) if types.length() == 1 &&
        types[0] is @lib.NumTypeValType(_) => {
        // Untyped select infers this scalar type from the same operands.
        // Reference and multi-value annotations retain their original meaning.
        changed = true
        @lib.Instruction::select()
      }
      _ => instr
    }
  })
  (next, changed)
}
