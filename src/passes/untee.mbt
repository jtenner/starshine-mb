///|
pub fn untee_summary() -> String {
  "Expand local.tee operations into explicit local.set plus local.get pairs."
}

///|
fn untee_rewrite_instr(instr : @lib.Instruction) -> (@lib.Instruction, Bool) {
  match instr {
    @lib.Block(block_type, @lib.Expr(body)) => {
      let (next_body, changed) = untee_rewrite_instrs(body)
      if changed {
        (@lib.Instruction::block(block_type, @lib.Expr::new(next_body)), true)
      } else {
        (instr, false)
      }
    }
    @lib.Loop(block_type, @lib.Expr(body)) => {
      let (next_body, changed) = untee_rewrite_instrs(body)
      if changed {
        (@lib.Instruction::loop_(block_type, @lib.Expr::new(next_body)), true)
      } else {
        (instr, false)
      }
    }
    @lib.If(block_type, then_body, else_body) => {
      let (next_then, then_changed) = untee_rewrite_instrs(then_body)
      let (next_else, else_changed) = match else_body {
        Some(body) => {
          let (next, changed) = untee_rewrite_instrs(body)
          (Some(next), changed)
        }
        None => (None, false)
      }
      if then_changed || else_changed {
        (@lib.Instruction::if_(block_type, next_then, next_else), true)
      } else {
        (instr, false)
      }
    }
    @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
      let (next_body, changed) = untee_rewrite_instrs(body)
      if changed {
        (
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(next_body),
          ),
          true,
        )
      } else {
        (instr, false)
      }
    }
    _ => (instr, false)
  }
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
