///|
fn oi_cleanup_control(mod_ : @lib.Module) -> @lib.Module {
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
  let rewritten = funcs.map(fn(func) {
    let @lib.Func(locals, @lib.Expr(body)) = func
    let keep : Array[Bool] = []
    let (next, rewritten, _) = pass_lower_flatten_branchless_blocks(
      body,
      env,
      label_keep=Some(keep),
    )
    if !rewritten {
      remaps.push(None)
      return func
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
