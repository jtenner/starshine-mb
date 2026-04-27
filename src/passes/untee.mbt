///|
pub fn untee_summary() -> String {
  "Expand local.tee operations into explicit local.set plus local.get pairs."
}

///|
fn untee_rewrite_instr(instr : @lib.Instruction) -> (@lib.Instruction, Bool) {
  pass_rewrite_structured_instr(instr, untee_rewrite_instrs)
}

///|
fn untee_rewrite_instrs(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Bool) {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  for instr in instrs {
    let (current, current_changed) = untee_rewrite_instr(instr)
    if current_changed {
      changed = true
    }
    match current {
      @lib.LocalTee(local_idx) => {
        changed = true
        match out.last() {
          Some(@lib.Unreachable) => ()
          _ => {
            out.push(@lib.Instruction::local_set(local_idx))
            out.push(@lib.Instruction::local_get(local_idx))
          }
        }
      }
      _ => out.push(current)
    }
  }
  (out, changed)
}

///|
pub fn untee_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let rewritten : Array[@lib.Func] = []
  let mut changed = false
  for func in funcs {
    let @lib.Func(locals, @lib.Expr(body)) = func
    let (next_body, func_changed) = untee_rewrite_instrs(body)
    if func_changed {
      changed = true
      rewritten.push(@lib.Func::new(locals, @lib.Expr::new(next_body)))
    } else {
      rewritten.push(func)
    }
  }
  if changed {
    mod_.with_code_sec(@lib.CodeSec::new(rewritten))
  } else {
    mod_
  }
}
