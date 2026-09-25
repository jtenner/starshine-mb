///|
pub fn untee_summary() -> String {
  "Expand local.tee operations into explicit local.set plus local.get pairs."
}

///|
fn untee_rewrite_instr(
  instr : @lib.Instruction,
  preserve_initialization : Bool,
) -> (@lib.Instruction, Bool) {
  pass_rewrite_structured_instr(instr, fn(body) {
    untee_rewrite_instrs(body, preserve_initialization)
  })
}

///|
fn untee_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  preserve_initialization : Bool,
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
        match target.last() {
          Some(@lib.Unreachable) if !preserve_initialization => ()
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
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  if funcs.is_empty() {
    return mod_
  }
  let mut rewritten : Array[@lib.Func]? = None
  for func_idx = 0; func_idx < funcs.length(); func_idx = func_idx + 1 {
    let func = funcs[func_idx]
    let @lib.Func(locals, @lib.Expr(body)) = func
    // Definite initialization is checked even in polymorphic unreachable code.
    let mut preserve_initialization = false
    for run in locals.runs() {
      if run.count() != 0U &&
        run.val_type() is @lib.RefTypeValType(ref_type) &&
        ref_type.is_non_nullable() {
        preserve_initialization = true
        break
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
