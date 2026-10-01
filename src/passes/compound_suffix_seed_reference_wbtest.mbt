///|
fn sl_compound_suffix_reference(
  instrs : Array[@lib.Instruction],
  end : Int,
  count : Int,
  env : @validate.Env,
  typed_instructions? : Array[Int]? = None,
) -> Array[@lib.Instruction] {
  if count <= 0 {
    return []
  }
  // These one-instruction producers have exact typing without constructing a
  // full initialized-local mask. Compound/unknown suffixes keep full checking.
  if count == 1 && end > 0 {
    let last = instrs[end - 1]
    let complete_leaf = match last {
      @lib.I32Const(_)
      | @lib.I64Const(_)
      | @lib.F32Const(_)
      | @lib.F64Const(_) => true
      @lib.LocalGet(idx) => env.get_local_type(idx) is Some(_)
      _ => false
    }
    if complete_leaf {
      return [last]
    }
  }
  let mut required = 0
  let mut net = 0
  let mut known = true
  let mut start = end - 1
  while start >= 0 {
    if known {
      match sl_value_suffix_stack_effect(instrs[start], env) {
        Some((inputs, outputs)) => {
          required = Int::max(inputs, required + inputs - outputs)
          net += outputs - inputs
        }
        None => known = false
      }
      if known && (required != 0 || net != count) {
        start -= 1
        continue
      }
    }
    let suffix : Array[@lib.Instruction] = []
    for idx = start; idx < end; idx = idx + 1 {
      suffix.push(instrs[idx])
    }
    match typed_instructions {
      Some(visits) => visits[0] += suffix.length()
      None => ()
    }
    let init_state = @validate.make_state(env, [])
    match @validate.Typecheck::typecheck(@lib.Expr::new(suffix), init_state) {
      Ok(state) =>
        if state.reachable &&
          state.escape == @validate.tc_escape_none() &&
          state.stack.length() == count {
          return suffix
        }
      Err(_) => ()
    }
    start = start - 1
  }
  []
}
