///|
fn oi_control_cleanup_has_block(body : Array[@lib.Instruction]) -> Bool {
  for instr in body {
    match instr {
      @lib.Block(_, _) => return true
      @lib.Loop(_, @lib.Expr(child)) | @lib.TryTable(_, _, @lib.Expr(child)) =>
        if oi_control_cleanup_has_block(child) {
          return true
        }
      @lib.If(_, yes, no) => {
        if oi_control_cleanup_has_block(yes) {
          return true
        }
        match no {
          Some(child) => if oi_control_cleanup_has_block(child) { return true }
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(child), catches, _) => {
        if oi_control_cleanup_has_block(child) {
          return true
        }
        for catch_ in catches {
          let child = match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(child))
            | @lib.LegacyCatchAll(@lib.Expr(child)) => child
          }
          if oi_control_cleanup_has_block(child) {
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
fn oi_cleanup_control(
  mod_ : @lib.Module,
  touched? : Array[Bool]? = None,
) -> @lib.Module {
  // Undecoded label names cannot be safely renumbered.
  if mod_.name_sec is None && mod_.raw_name_sec_payload is Some(_) {
    return mod_
  }
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let env = @validate.Env::new().with_module(mod_)
  let remaps : Array[Array[Int]?] = []
  let mut changed = false
  let rewritten = funcs.mapi(fn(index, func) {
    if touched is Some(selected) &&
      (index >= selected.length() || !selected[index]) {
      remaps.push(None)
      return func
    }
    let @lib.Func(locals, @lib.Expr(body)) = func
    if !oi_control_cleanup_has_block(body) &&
      !body.any(fn(instr) { instr is @lib.Unreachable }) {
      remaps.push(None)
      return func
    }
    // Only a root unreachable makes every following root instruction dead.
    let mut end = body.length()
    for i = 0; i < body.length(); i = i + 1 {
      if body[i] is @lib.Unreachable {
        end = i + 1
        break
      }
    }
    let trimmed = end < body.length()
    let prefix = if trimmed { body[0:end].to_array() } else { body }
    let keep : Array[Bool] = []
    let (next, rewritten, _) = pass_lower_flatten_branchless_blocks(
      prefix,
      env,
      label_keep=Some(keep),
    )
    if !rewritten && !trimmed {
      remaps.push(None)
      return func
    }
    if trimmed {
      let dead_labels = ls_label_count(body[end:].to_array()).to_int()
      for i = 0; i < dead_labels; i = i + 1 {
        keep.push(false)
      }
    }
    changed = true
    let mut next_label = 0
    let remap = keep.map(fn(live) {
      if live {
        let label = next_label
        next_label += 1
        label
      } else {
        -1
      }
    })
    remaps.push(Some(remap))
    @lib.Func::new(locals, @lib.Expr::new(next))
  })
  if !changed {
    return mod_
  }
  let candidate = mod_.with_code_sec(@lib.CodeSec::new(rewritten))
  match mod_.name_sec {
    Some(names) => {
      // Label ordinals use the same per-function name-map layout as locals.
      let label_names = rl_rewrite_local_names(
        names.label_names,
        run_hot_pipeline_imported_func_count(mod_),
        remaps,
      )
      candidate.with_name_sec(
        @lib.NameSec::new(
          module_name=names.module_name,
          func_names=names.func_names,
          local_names=names.local_names,
          label_names~,
          type_names=names.type_names,
          table_names=names.table_names,
          memory_names=names.memory_names,
          global_names=names.global_names,
          elem_names=names.elem_names,
          data_names=names.data_names,
          field_names=names.field_names,
          tag_names=names.tag_names,
        ),
      )
    }
    None => candidate
  }
}
