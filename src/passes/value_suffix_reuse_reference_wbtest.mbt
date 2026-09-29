///|
fn sl_value_suffix_reference(
  instrs : Array[@lib.Instruction],
  count : Int,
  env : @validate.Env,
) -> (Array[@lib.Instruction], Array[@lib.Instruction]) {
  if count <= 0 {
    return (instrs.copy(), [])
  }
  let mut start = instrs.length() - 1
  while start >= 0 {
    let suffix : Array[@lib.Instruction] = []
    for idx = start; idx < instrs.length(); idx = idx + 1 {
      suffix.push(instrs[idx])
    }
    let init_state = @validate.make_state(env, [])
    match @validate.Typecheck::typecheck(@lib.Expr::new(suffix), init_state) {
      Ok(state) =>
        if state.reachable &&
          state.escape == @validate.tc_escape_none() &&
          state.stack.length() == count {
          let head : Array[@lib.Instruction] = []
          for idx = 0; idx < start; idx = idx + 1 {
            head.push(instrs[idx])
          }
          return (head, suffix)
        }
      Err(_) => ()
    }
    start = start - 1
  }
  (instrs.copy(), [])
}
