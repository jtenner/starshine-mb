///|
pub fn flatten_summary() -> String {
  "Flatten adjacent local.set/local.get pairs while preserving local declarations."
}

///|
fn flatten_rewrite_instr(instr : @lib.Instruction) -> (@lib.Instruction, Bool) {
  pass_rewrite_structured_instr(instr, flatten_rewrite_instrs)
}

///|
fn flatten_rewrite_instrs(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Bool) {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  for instr in instrs {
    let (current, current_changed) = flatten_rewrite_instr(instr)
    if current_changed {
      changed = true
    }
    match current {
      @lib.LocalGet(get_idx) =>
        match out.last() {
          Some(@lib.LocalSet(set_idx)) if set_idx == get_idx => {
            ignore(out.pop())
            changed = true
          }
          _ => out.push(current)
        }
      _ => out.push(current)
    }
  }
  (out, changed)
}

///|
pub fn flatten_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let rewritten : Array[@lib.Func] = []
  let mut changed = false
  for func in funcs {
    let @lib.Func(locals, @lib.Expr(body)) = func
    let (next_body, func_changed) = flatten_rewrite_instrs(body)
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
