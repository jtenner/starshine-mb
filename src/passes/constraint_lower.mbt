///|
fn ca_lower_has_label_branch(
  instrs : Array[@lib.Instruction],
  depth : Int,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Br(@lib.LabelIdx(label))
      | @lib.BrIf(@lib.LabelIdx(label))
      | @lib.BrOnNull(@lib.LabelIdx(label))
      | @lib.BrOnNonNull(@lib.LabelIdx(label))
      | @lib.BrOnCast(@lib.LabelIdx(label), _, _, _)
      | @lib.BrOnCastFail(@lib.LabelIdx(label), _, _, _)
      | @lib.BrOnCastDescEq(@lib.LabelIdx(label), _, _)
      | @lib.BrOnCastDescEqFail(@lib.LabelIdx(label), _, _) =>
        if label.to_int() == depth {
          return true
        }
      @lib.BrTable(labels, @lib.LabelIdx(fallback)) => {
        if fallback.to_int() == depth {
          return true
        }
        for label in labels {
          let @lib.LabelIdx(index) = label
          if index.to_int() == depth {
            return true
          }
        }
      }
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if ca_lower_has_label_branch(body, depth + 1) {
          return true
        }
      @lib.If(_, yes, no) => {
        if ca_lower_has_label_branch(yes, depth + 1) {
          return true
        }
        if no is Some(body) && ca_lower_has_label_branch(body, depth + 1) {
          return true
        }
      }
      // Exception and continuation targets need their own label conventions.
      // Their presence prevents this result-annotation narrowing only.
      @lib.Try(_, _, _, _)
      | @lib.TryTable(_, _, _)
      | @lib.Resume(_, _)
      | @lib.ResumeThrow(_, _, _)
      | @lib.ResumeThrowRef(_, _) => return true
      _ => ()
    }
  }
  false
}

///|
fn ca_lower_ends_in_terminator(body : Array[@lib.Instruction]) -> Bool {
  if body.is_empty() {
    return false
  }
  match body[body.length() - 1] {
    @lib.Unreachable
    | @lib.Return
    | @lib.Br(_)
    | @lib.BrTable(_, _)
    | @lib.Throw(_)
    | @lib.ThrowRef
    | @lib.Rethrow(_)
    | @lib.ReturnCall(_)
    | @lib.ReturnCallIndirect(_, _)
    | @lib.ReturnCallRef(_) => true
    _ => false
  }
}

///|
fn ca_lower_refinalize_body(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  let mut i = 0
  while i < instrs.length() {
    let instr = pass_lower_map_children(instrs[i], fn(body) {
      ca_lower_refinalize_body(body, env)
    })
    let signature = match instr {
      @lib.If(bt, _, _) | @lib.Loop(bt, _) =>
        match env.expand_blocktype(bt) {
          Ok(types) => Some(types)
          Err(_) => None
        }
      _ => None
    }
    if signature is Some((params, results)) &&
      params.is_empty() &&
      !results.is_empty() {
      let arity = results.length()
      let mut discarded_bottom = i + arity + 1 < instrs.length() &&
        instrs[i + arity + 1] is @lib.Unreachable
      if discarded_bottom {
        for slot = 1; slot <= arity; slot = slot + 1 {
          if !(instrs[i + slot] is @lib.Drop) {
            discarded_bottom = false
          }
        }
      }
      if discarded_bottom {
        match instr {
          @lib.If(_, yes, Some(no)) if ca_lower_ends_in_terminator(yes) &&
            ca_lower_ends_in_terminator(no) &&
            !ca_lower_has_label_branch(yes, 0) &&
            !ca_lower_has_label_branch(no, 0) => {
            // Neither arm can supply an if result. Keep the following explicit
            // unreachable to preserve stack polymorphism in the outer region.
            out.push(
              @lib.Instruction::if_(@lib.BlockType::void_(), yes, Some(no)),
            )
            i += arity + 1
            continue
          }
          @lib.Loop(_, @lib.Expr(body)) if ca_lower_ends_in_terminator(body) &&
            i + arity + 2 == instrs.length() => {
            // The loop's declared results still exist on the outer validation
            // stack. Keep the explicit unreachable to close that stack even
            // though the loop has no dynamic fallthrough.
            out.push(instr)
            i += arity + 1
            continue
          }
          _ => ()
        }
      }
    }
    out.push(instr)
    i += 1
  }
  out
}

///|
fn ca_lower_refinalize(
  func : @lib.Func,
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
) -> @lib.Func {
  let @lib.Func(locals, @lib.Expr(body)) = func
  let env = @validate.Env::new().with_module(mod_)
  let body = ca_lower_refinalize_body(body, env)
  // A sole result loop starts with an empty outer stack. When its declared
  // outputs already match the function results, the function end consumes
  // them; an extra unreachable only makes canonical encoding add drops.
  // Other outer stacks still need the closure retained above.
  if body.length() == 2 && body[1] is @lib.Unreachable {
    match (body[0], env.get_functype_by_funcidx(func_idx)) {
      (@lib.Loop(bt, @lib.Expr(inner)), Some(@lib.FuncType(_, expected))) if ca_lower_ends_in_terminator(
          inner,
        ) =>
        match env.expand_blocktype(bt) {
          Ok((params, results)) if params.is_empty() && results == expected =>
            ignore(body.pop())
          _ => ()
        }
      _ => ()
    }
  }
  ca_lower_cleanup_raw(@lib.Func::new(locals, @lib.Expr::new(body)), mod_).0
}

///|
fn ca_lower_trim_terminal_local_roundtrip(
  func : @lib.Func,
) -> (@lib.Func, Bool) {
  let @lib.Func(locals, @lib.Expr(body)) = func
  let length = body.length()
  if length >= 2 {
    match (body[length - 2], body[length - 1]) {
      (@lib.LocalSet(write), @lib.LocalGet(read)) if write == read => {
        // Only at function exit: nested regions may expose this write later.
        // The producer stays on the stack and is evaluated exactly once.
        let trimmed = body.copy()
        ignore(trimmed.pop())
        ignore(trimmed.pop())
        return (@lib.Func::new(locals, @lib.Expr::new(trimmed)), true)
      }
      _ => ()
    }
  }
  (func, false)
}

///|
fn ca_lower_cleanup_raw(
  func : @lib.Func,
  mod_ : @lib.Module,
) -> (@lib.Func, Bool) {
  let (func, changed) = pass_lower_cleanup_branchless_blocks(func, mod_)
  let (output, terminal_changed) = ca_lower_trim_terminal_local_roundtrip(func)
  (output, changed || terminal_changed)
}
