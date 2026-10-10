///|
// Run after all writeback repair: restored functions still use original indices.
fn oi_cleanup_module_encoding(
  mod_ : @lib.Module,
  touched? : Array[Bool]? = None,
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
  touched? : Array[Bool]? = None,
  function_comparisons? : Array[Int]? = None,
  perf? : HotPerfSession? = None,
  legacy_guard_scans? : Array[Int]? = None,
) -> @lib.Module {
  if !oi_numeric_group_has_declaration_candidate(mod_, touched) {
    return mod_
  }
  match legacy_guard_scans {
    Some(scans) => scans[0] += 1
    None => ()
  }
  if pass_module_has_legacy_try(mod_) ||
    oi_local_group_has_offset_metadata(mod_) {
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
  if physical_equal(grouped, mod_) {
    return mod_
  }
  let size_baseline = if mod_.compiler_fact_custom_section is Some(_) {
    mod_.without_compiler_fact_custom_section()
  } else {
    mod_
  }
  let size_start = perf_start_timer_opt(
    perf, "detail:simplify-locals:encoding-local-group-size",
  )
  let sizes = @binary.encoded_module_sizes(size_baseline, grouped)
  perf_stop_timer_opt(
    perf, "detail:simplify-locals:encoding-local-group-size", size_start,
  )
  match sizes {
    Ok((old_size, new_size)) if new_size < old_size =>
      if oi_validate_local_group_changed_bodies(mod_, grouped, perf~) {
        return grouped
      }
    _ => ()
  }
  mod_
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
  perf? : HotPerfSession? = None,
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
