///|
// Run after all writeback repair: restored functions still use original indices.
fn oi_cleanup_module_encoding(
  mod_ : @lib.Module,
  touched? : Array[Bool]? = None,
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
  oi_group_numeric_locals_if_smaller(cleaned, touched~)
}

///|
// Binaryen's OI writer groups scalar local declarations by type. Reuse the
// shared index and decoded-name remapper, but keep legacy EH and opaque names
// unchanged and commit only a validated whole-module byte saving.
fn oi_group_numeric_locals_if_smaller(
  mod_ : @lib.Module,
  touched? : Array[Bool]? = None,
) -> @lib.Module {
  if pass_module_has_legacy_try(mod_) ||
    oi_local_group_has_offset_metadata(mod_) {
    return mod_
  }
  let grouped = run_hot_pipeline_raw_group_body_locals_by_type_module(
    mod_,
    touched~,
  )
  if grouped.code_sec == mod_.code_sec {
    return mod_
  }
  let size_baseline = if mod_.compiler_fact_custom_section is Some(_) {
    mod_.without_compiler_fact_custom_section()
  } else {
    mod_
  }
  match (@binary.encode_module(size_baseline), @binary.encode_module(grouped)) {
    (Ok(old_bytes), Ok(new_bytes)) if new_bytes.length() < old_bytes.length() =>
      if @validate.validate_module(grouped) is Ok(_) {
        return grouped
      }
    _ => ()
  }
  mod_
}

///|
fn oi_local_group_has_offset_metadata(mod_ : @lib.Module) -> Bool {
  for custom in mod_.custom_secs {
    let @lib.CustomSec(@lib.Name(raw_name), _) = custom
    let name = raw_name.to_owned()
    if name.starts_with("metadata.code.") ||
      name == "reloc.CODE" ||
      name.starts_with(".debug_") {
      return true
    }
  }
  match mod_.func_annotation_sec {
    Some(@lib.FuncAnnotationSec(entries)) =>
      for @lib.FuncAnnotationAssoc(_, annotations) in entries {
        if annotations.any(fn(annotation) {
            annotation.name == "metadata.code.branch_hint"
          }) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn oi_remove_numeric_select_annotations(
  body : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Bool) {
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
