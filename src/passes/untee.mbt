///|
pub fn untee_summary() -> String {
  "Expand local.tee operations into explicit local.set plus local.get pairs."
}

///|
fn untee_rewrite_instr(
  instr : @lib.Instruction,
  preserve_initialization : Array[Bool],
) -> (@lib.Instruction, Bool) {
  pass_rewrite_structured_instr(instr, fn(body) {
    untee_rewrite_instrs(body, preserve_initialization)
  })
}

///|
fn untee_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  preserve_initialization : Array[Bool],
) -> (Array[@lib.Instruction], Bool) {
  let mut out : Array[@lib.Instruction]? = None
  for idx in 0..<instrs.length() {
    let (current, current_changed) = untee_rewrite_instr(
      instrs[idx],
      preserve_initialization,
    )
    match current {
      @lib.LocalTee(local_idx) => {
        let target = match out {
          Some(existing) => existing
          None => {
            let prefix : Array[@lib.Instruction] = []
            for prior in 0..<idx {
              prefix.push(instrs[prior])
            }
            out = Some(prefix)
            prefix
          }
        }
        let @lib.LocalIdx(raw_local) = local_idx
        let local_id = raw_local.reinterpret_as_int()
        let preserve_target_initialization = local_id >= 0 &&
          local_id < preserve_initialization.length() &&
          preserve_initialization[local_id]
        match target.last() {
          Some(@lib.Unreachable) if !preserve_target_initialization => ()
          _ => {
            target.push(@lib.Instruction::local_set(local_idx))
            target.push(@lib.Instruction::local_get(local_idx))
          }
        }
      }
      _ =>
        match out {
          Some(existing) => existing.push(current)
          None if current_changed => {
            let prefix : Array[@lib.Instruction] = []
            for prior in 0..<idx {
              prefix.push(instrs[prior])
            }
            prefix.push(current)
            out = Some(prefix)
          }
          None => ()
        }
    }
  }
  match out {
    Some(rewritten) => (rewritten, true)
    None => (instrs, false)
  }
}

///|
pub fn untee_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  if pass_module_has_offset_sensitive_metadata(mod_) {
    return mod_
  }
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  if funcs.is_empty() {
    return mod_
  }
  let mut rewritten : Array[@lib.Func]? = None
  let params_by_func : Array[Array[@lib.ValType]] = match
    (mod_.type_sec, mod_.func_sec) {
    (Some(_), Some(_)) => cl_defined_func_param_cache(mod_)
    _ => Array::make(funcs.length(), [])
  }
  for func_idx = 0; func_idx < funcs.length(); func_idx = func_idx + 1 {
    let func = funcs[func_idx]
    let @lib.Func(locals, @lib.Expr(body)) = func
    // Definite initialization is checked even in polymorphic unreachable code.
    let params = params_by_func[func_idx]
    let preserve_initialization = Array::make(
      params.length() + locals.length(),
      false,
    )
    for body_local = 0
        body_local < locals.length()
        body_local = body_local + 1 {
      match locals.get(body_local) {
        @lib.RefTypeValType(ref_type) if ref_type.is_non_nullable() =>
          preserve_initialization[params.length() + body_local] = true
        _ => ()
      }
    }
    let (next_body, func_changed) = untee_rewrite_instrs(
      body, preserve_initialization,
    )
    if func_changed {
      let target = match rewritten {
        Some(existing) => existing
        None => {
          let prefix : Array[@lib.Func] = []
          for prior in 0..<func_idx {
            prefix.push(funcs[prior])
          }
          rewritten = Some(prefix)
          prefix
        }
      }
      target.push(@lib.Func::new(locals, @lib.Expr::new(next_body)))
    } else {
      match rewritten {
        Some(existing) => existing.push(func)
        None => ()
      }
    }
  }
  match rewritten {
    Some(funcs) => mod_.with_code_sec(@lib.CodeSec::new(funcs))
    None => mod_
  }
}
