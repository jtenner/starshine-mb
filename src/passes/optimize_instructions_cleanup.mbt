///|
// Run after all writeback repair: restored functions still use original indices.
fn oi_cleanup_module_encoding(mod_ : @lib.Module) -> @lib.Module {
  let mut changed = false
  let candidate = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let next = funcs.map(fn(func) {
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
  dfe_cleanup_simple_type_encoding(
    pass_cleanup_unused_type_groups(
      oi_cleanup_declarative_elements(oi_cleanup_control(candidate)),
    ),
  )
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
