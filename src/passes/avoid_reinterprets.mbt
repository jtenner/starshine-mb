///|
pub fn avoid_reinterprets_summary() -> String {
  "Replace full-width numeric load plus reinterpret pairs with equivalent typed loads."
}

///|
fn ar_rewrite_load_reinterpret_pair(
  load : @lib.Instruction,
  reinterpret : @lib.Instruction,
) -> @lib.Instruction? {
  match (load, reinterpret) {
    (@lib.F32Load(memarg), @lib.I32ReinterpretF32) =>
      Some(@lib.Instruction::i32_load(memarg))
    (@lib.F64Load(memarg), @lib.I64ReinterpretF64) =>
      Some(@lib.Instruction::i64_load(memarg))
    (@lib.I32Load(memarg), @lib.F32ReinterpretI32) =>
      Some(@lib.Instruction::f32_load(memarg))
    (@lib.I64Load(memarg), @lib.F64ReinterpretI64) =>
      Some(@lib.Instruction::f64_load(memarg))
    _ => None
  }
}

///|
fn ar_rewrite_instr(instr : @lib.Instruction) -> (@lib.Instruction, Bool) {
  match instr {
    @lib.Block(block_type, @lib.Expr(body)) => {
      let (next_body, changed) = ar_rewrite_instrs(body)
      if changed {
        (@lib.Instruction::block(block_type, @lib.Expr::new(next_body)), true)
      } else {
        (instr, false)
      }
    }
    @lib.Loop(block_type, @lib.Expr(body)) => {
      let (next_body, changed) = ar_rewrite_instrs(body)
      if changed {
        (@lib.Instruction::loop_(block_type, @lib.Expr::new(next_body)), true)
      } else {
        (instr, false)
      }
    }
    @lib.If(block_type, then_body, else_body) => {
      let (next_then, then_changed) = ar_rewrite_instrs(then_body)
      let (next_else, else_changed) = match else_body {
        Some(body) => {
          let (next, changed) = ar_rewrite_instrs(body)
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
      let (next_body, changed) = ar_rewrite_instrs(body)
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
fn ar_rewrite_instrs(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Bool) {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  let mut i = 0
  while i < instrs.length() {
    let (current, current_changed) = ar_rewrite_instr(instrs[i])
    if current_changed {
      changed = true
    }
    if i + 1 < instrs.length() {
      match ar_rewrite_load_reinterpret_pair(current, instrs[i + 1]) {
        Some(replacement) => {
          out.push(replacement)
          changed = true
          i = i + 2
          continue
        }
        None => ()
      }
    }
    out.push(current)
    i = i + 1
  }
  (out, changed)
}

///|
pub fn avoid_reinterprets_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let rewritten : Array[@lib.Func] = []
  let mut changed = false
  for func in funcs {
    let @lib.Func(locals, @lib.Expr(body)) = func
    let (next_body, func_changed) = ar_rewrite_instrs(body)
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
