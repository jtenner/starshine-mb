///|
fn ca_lower_refinalize_reference(
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
  ca_lower_cleanup_raw_reference(
    @lib.Func::new(locals, @lib.Expr::new(body)),
    mod_,
  ).0
}

///|
fn ca_lower_cleanup_raw_reference(
  func : @lib.Func,
  mod_ : @lib.Module,
) -> (@lib.Func, Bool) {
  let (func, changed) = pass_lower_cleanup_branchless_blocks(func, mod_)
  let (output, terminal_changed) = ca_lower_trim_terminal_local_roundtrip(func)
  (output, changed || terminal_changed)
}
