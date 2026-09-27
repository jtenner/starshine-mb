///|
// Expr typechecking is a left-to-right fold over Instruction. Once a prefix
// fails, extending it cannot repair that earlier error. Keep the state only
// within this scan; no cached result survives an instruction or environment edit.
fn run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
  allow_escape : Bool,
  typed_instructions? : Array[Int]? = None,
) -> Int {
  let mut state = @validate.make_state(env, [])
  for index = 0; index < instrs.length(); index = index + 1 {
    match typed_instructions {
      Some(count) => count[0] += 1
      None => ()
    }
    state = match @validate.Typecheck::typecheck(instrs[index], state) {
      Ok(next) => next
      Err(_) => return 0
    }
    let end = index + 1
    let reaches = state.reachable && state.escape == @validate.tc_escape_none()
    let boundary = if allow_escape {
      state.stack.length() == 0 ||
      (end == instrs.length() && reaches && state.stack.length() > 0)
    } else {
      reaches && state.stack.length() == 0
    }
    if boundary {
      return end
    }
  }
  0
}
