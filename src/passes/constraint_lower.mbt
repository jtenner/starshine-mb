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
            // A loop label is an entry, not a result-producing exit. Its body
            // has no normal fallthrough, so trailing drops only consume phantom
            // declared results. Retain its original result signature.
            out.push(instr)
            i += arity + 2
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
fn ca_lower_refinalize(func : @lib.Func, mod_ : @lib.Module) -> @lib.Func {
  let @lib.Func(locals, @lib.Expr(body)) = func
  @lib.Func::new(
    locals,
    @lib.Expr::new(
      ca_lower_refinalize_body(body, @validate.Env::new().with_module(mod_)),
    ),
  )
}
