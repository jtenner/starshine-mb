///|
fn oi_control_cleanup_branchless_candidate(
  body : Array[@lib.Instruction],
  env : @validate.Env,
) -> Int {
  // Bit 0: the body has no control transfer. Bit 1: a nested block can flatten.
  let mut branchless = true
  let mut candidate = false
  for instr in body {
    match instr {
      @lib.Block(block_type, @lib.Expr(child)) => {
        let child_state = oi_control_cleanup_branchless_candidate(child, env)
        let child_branchless = (child_state & 1) != 0
        candidate = candidate || (child_state & 2) != 0
        if child_branchless {
          match env.expand_blocktype(block_type) {
            Ok((params, _)) if params.is_empty() => candidate = true
            _ => ()
          }
        }
        branchless = branchless && child_branchless
      }
      @lib.Loop(_, @lib.Expr(child)) => {
        let child_state = oi_control_cleanup_branchless_candidate(child, env)
        candidate = candidate || (child_state & 2) != 0
        branchless = branchless && (child_state & 1) != 0
      }
      @lib.TryTable(_, _, @lib.Expr(child)) => {
        let child_state = oi_control_cleanup_branchless_candidate(child, env)
        candidate = candidate || (child_state & 2) != 0
        branchless = false
      }
      @lib.If(_, yes, no) => {
        let yes_state = oi_control_cleanup_branchless_candidate(yes, env)
        candidate = candidate || (yes_state & 2) != 0
        branchless = branchless && (yes_state & 1) != 0
        match no {
          Some(child) => {
            let no_state = oi_control_cleanup_branchless_candidate(child, env)
            candidate = candidate || (no_state & 2) != 0
            branchless = branchless && (no_state & 1) != 0
          }
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(child), catches, _) => {
        let child_state = oi_control_cleanup_branchless_candidate(child, env)
        candidate = candidate || (child_state & 2) != 0
        for catch_ in catches {
          let child = match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(child))
            | @lib.LegacyCatchAll(@lib.Expr(child)) => child
          }
          let catch_state = oi_control_cleanup_branchless_candidate(child, env)
          candidate = candidate || (catch_state & 2) != 0
        }
        branchless = false
      }
      _ => if pass_lower_instr_transfers_control(instr) { branchless = false }
    }
  }
  (if branchless { 1 } else { 0 }) | (if candidate { 2 } else { 0 })
}

///|
fn oi_cleanup_control(
  mod_ : @lib.Module,
  touched? : Array[Bool]? = None,
  flatten_attempts? : Array[Int]? = None,
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
    let candidate_state = oi_control_cleanup_branchless_candidate(body, env)
    let mut has_root_unreachable_tail = false
    for i = 0; i + 1 < body.length(); i = i + 1 {
      if body[i] is @lib.Unreachable {
        has_root_unreachable_tail = true
        break
      }
    }
    if (candidate_state & 2) == 0 && !has_root_unreachable_tail {
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
    match flatten_attempts {
      Some(attempts) => attempts[0] += 1
      None => ()
    }
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
