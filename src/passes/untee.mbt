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
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  for instr in instrs {
    let (current, current_changed) = untee_rewrite_instr(instr, preserve_initialization)
    if current_changed {
      changed = true
    }
    match current {
      @lib.LocalTee(local_idx) => {
        changed = true
        match out.last() {
          Some(@lib.Unreachable) if !preserve_initialization => ()
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
    // Definite initialization is checked even in polymorphic unreachable code.
    let mut preserve_initialization = false
    for idx in 0..<locals.length() {
      if locals[idx] is @lib.RefTypeValType(ref_type) && ref_type.is_non_nullable() {
        preserve_initialization = true
      }
    }
    let (next_body, func_changed) = untee_rewrite_instrs(body, preserve_initialization)
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
