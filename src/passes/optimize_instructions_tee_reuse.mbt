///|
fn oi_tee_reuse_tail_matches(
  instrs : Array[@lib.Instruction],
  index : Int,
) -> Bool {
  if index < 2 {
    return false
  }
  match instrs[index] {
    @lib.I32And | @lib.I32Or | @lib.I64And | @lib.I64Or => ()
    _ => return false
  }
  match (instrs[index - 2], instrs[index - 1]) {
    (@lib.LocalTee(left), @lib.LocalGet(right)) => left == right
    _ => false
  }
}

///|
fn oi_tee_reuse_has_candidate(body : Array[@lib.Instruction]) -> Bool {
  let pending = [(body, 0)]
  let mut visited = 0
  let mut candidate = false
  while pending.length() > 0 {
    let (instrs, depth) = pending.pop().unwrap()
    if depth > 128 {
      return false
    }
    for index = 0; index < instrs.length(); index = index + 1 {
      visited += 1
      if visited > 200000 {
        return false
      }
      candidate = oi_tee_reuse_tail_matches(instrs, index) || candidate
      match instrs[index] {
        @lib.Block(_, @lib.Expr(nested))
        | @lib.Loop(_, @lib.Expr(nested))
        | @lib.TryTable(_, _, @lib.Expr(nested)) =>
          pending.push((nested, depth + 1))
        @lib.If(_, then_body, else_body) => {
          pending.push((then_body, depth + 1))
          if else_body is Some(nested) {
            pending.push((nested, depth + 1))
          }
        }
        @lib.Try(_, @lib.Expr(nested), catches, _) => {
          pending.push((nested, depth + 1))
          for catch_ in catches {
            match catch_ {
              @lib.LegacyCatch(_, @lib.Expr(catch_body))
              | @lib.LegacyCatchAll(@lib.Expr(catch_body)) =>
                pending.push((catch_body, depth + 1))
            }
          }
        }
        _ => ()
      }
    }
  }
  candidate
}

///|
fn oi_tee_reuse_rewrite_body(
  body : Array[@lib.Instruction],
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in body {
    let instr = pass_lower_map_children(instr, oi_tee_reuse_rewrite_body)
    out.push(instr)
    if oi_tee_reuse_tail_matches(out, out.length() - 1) {
      // The tee and its complete producer stay in their original position.
      // The immediately following get observes that write. Only integer
      // idempotence applies; floating-point equality and effects are untouched.
      ignore(out.pop())
      ignore(out.pop())
    }
  }
  out
}

///|
fn oi_tee_reuse_preclean(func : @lib.Func) -> (@lib.Func, Bool) {
  let @lib.Func(locals, @lib.Expr(body)) = func
  if !oi_tee_reuse_has_candidate(body) {
    return (func, false)
  }
  (
    @lib.Func::new(locals, @lib.Expr::new(oi_tee_reuse_rewrite_body(body))),
    true,
  )
}
