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
  pass_rewrite_structured_instr(instr, ar_rewrite_instrs)
}

///|
fn ar_rewrite_instrs(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Bool) {
  let mut out : Array[@lib.Instruction]? = None
  let mut i = 0
  while i < instrs.length() {
    let (current, current_changed) = ar_rewrite_instr(instrs[i])
    let mut replacement : @lib.Instruction? = None
    if i + 1 < instrs.length() {
      match ar_rewrite_load_reinterpret_pair(current, instrs[i + 1]) {
        Some(next) => replacement = Some(next)
        None => ()
      }
    }
    if current_changed || replacement is Some(_) {
      let buffer = match out {
        Some(buffer) => buffer
        None => {
          let buffer : Array[@lib.Instruction] = []
          for prefix = 0; prefix < i; prefix = prefix + 1 {
            buffer.push(instrs[prefix])
          }
          out = Some(buffer)
          buffer
        }
      }
      buffer.push(
        match replacement {
          Some(next) => next
          None => current
        },
      )
    } else {
      match out {
        Some(buffer) => buffer.push(current)
        None => ()
      }
    }
    if replacement is Some(_) {
      i += 2
    } else {
      i += 1
    }
  }
  match out {
    Some(buffer) => (buffer, true)
    None => (instrs, false)
  }
}

///|
pub fn avoid_reinterprets_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  if pass_module_has_offset_sensitive_metadata(mod_) {
    return mod_
  }
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
