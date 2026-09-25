///|
fn ge_body_cannot_suspend(body : @lib.Expr) -> Bool {
  let @lib.Expr(instrs) = body
  for instr in instrs {
    match instr {
      @lib.Call(_)
      | @lib.CallIndirect(_, _)
      | @lib.CallRef(_)
      | @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_)
      | @lib.Suspend(_)
      | @lib.Resume(_, _)
      | @lib.ResumeThrow(_, _, _)
      | @lib.ResumeThrowRef(_, _)
      | @lib.StackSwitch(_, _) => return false
      @lib.Block(_, child) | @lib.Loop(_, child) =>
        if !ge_body_cannot_suspend(child) {
          return false
        }
      @lib.If(_, then_body, else_body) => {
        if !ge_body_cannot_suspend(@lib.Expr::new(then_body)) {
          return false
        }
        match else_body {
          Some(body) =>
            if !ge_body_cannot_suspend(@lib.Expr::new(body)) {
              return false
            }
          None => ()
        }
      }
      @lib.Try(_, _, _, _) | @lib.TryTable(_, _, _) => return false
      _ => ()
    }
  }
  true
}

///|
fn ge_target_cannot_suspend(
  funcs : Array[@lib.Func],
  defined_idx : Int,
  summaries : Array[Bool?],
) -> Bool {
  match summaries[defined_idx] {
    Some(result) => result
    None => {
      let @lib.Func(_, body) = funcs[defined_idx]
      let result = ge_body_cannot_suspend(body)
      summaries[defined_idx] = Some(result)
      result
    }
  }
}

///|
fn ge_body_has_rewritable_resume(body : @lib.Expr) -> Bool {
  let @lib.Expr(instrs) = body
  for instr in instrs {
    match instr {
      @lib.Resume(_, _) => return true
      @lib.Block(_, nested) | @lib.Loop(_, nested) =>
        if ge_body_has_rewritable_resume(nested) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ge_body_has_rewritable_resume(@lib.Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(nested) =>
            if ge_body_has_rewritable_resume(@lib.Expr::new(nested)) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn ge_rewrite_fresh_resumes(
  body : @lib.Expr,
  funcs : Array[@lib.Func],
  summaries : Array[Bool?],
  imported_funcs : Int,
  changed : Array[Bool],
) -> @lib.Expr {
  let @lib.Expr(instrs) = body
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.Resume(type_idx, handlers) if handlers.is_empty() &&
        out.length() >= 2 => {
        let n = out.length()
        match (out[n - 2], out[n - 1]) {
          (@lib.RefFunc(target), @lib.ContNew(new_type)) if new_type == type_idx => {
            let @lib.FuncIdx(raw) = target
            let defined_idx = raw.to_int() - imported_funcs
            if defined_idx >= 0 && defined_idx < funcs.length() {
              if ge_target_cannot_suspend(funcs, defined_idx, summaries) {
                ignore(out.pop())
                ignore(out.pop())
                out.push(@lib.Instruction::call(target))
                changed[0] = true
              } else {
                out.push(instr)
              }
            } else {
              out.push(instr)
            }
          }
          _ => out.push(instr)
        }
      }
      @lib.Block(block_type, nested) =>
        out.push(
          @lib.Instruction::block(
            block_type,
            ge_rewrite_fresh_resumes(
              nested, funcs, summaries, imported_funcs, changed,
            ),
          ),
        )
      @lib.Loop(block_type, nested) =>
        out.push(
          @lib.Instruction::loop_(
            block_type,
            ge_rewrite_fresh_resumes(
              nested, funcs, summaries, imported_funcs, changed,
            ),
          ),
        )
      @lib.If(block_type, then_body, else_body) => {
        let @lib.Expr(next_then) = ge_rewrite_fresh_resumes(
          @lib.Expr::new(then_body),
          funcs,
          summaries,
          imported_funcs,
          changed,
        )
        let next_else = match else_body {
          Some(body) => {
            let @lib.Expr(next_body) = ge_rewrite_fresh_resumes(
              @lib.Expr::new(body),
              funcs,
              summaries,
              imported_funcs,
              changed,
            )
            Some(next_body)
          }
          None => None
        }
        out.push(@lib.Instruction::if_(block_type, next_then, next_else))
      }
      _ => out.push(instr)
    }
  }
  @lib.Expr::new(out)
}

///|
fn global_effects_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  if !funcs.any(fn(func) {
      let @lib.Func(_, body) = func
      ge_body_has_rewritable_resume(body)
    }) {
    return mod_
  }
  let mut imported_funcs = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        if import_ is @lib.Import(_, _, @lib.FuncExternType(_)) {
          imported_funcs += 1
        }
      }
    None => ()
  }
  let changed = [false]
  let summaries : Array[Bool?] = Array::make(funcs.length(), None)
  let rewritten : Array[@lib.Func] = []
  for func in funcs {
    let @lib.Func(locals, body) = func
    if !ge_body_has_rewritable_resume(body) {
      rewritten.push(func)
      continue
    }
    rewritten.push(
      @lib.Func::new(
        locals,
        ge_rewrite_fresh_resumes(
          body, funcs, summaries, imported_funcs, changed,
        ),
      ),
    )
  }
  if !changed[0] {
    return mod_
  }
  let candidate = mod_.with_code_sec(@lib.CodeSec::new(rewritten))
  if @validate.validate_module(candidate).is_ok() {
    candidate
  } else {
    mod_
  }
}
