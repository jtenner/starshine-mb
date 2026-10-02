///|
// Expr typechecking is a left-to-right fold over Instruction. Once a prefix
// fails, extending it cannot repair that earlier error. Keep the state only
// within this scan; no cached result survives an instruction or environment edit.
// Return an absolute end, or start when no complete statement is admitted.
fn run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
  allow_escape : Bool,
  start? : Int = 0,
  typed_instructions? : Array[Int]? = None,
  typed_seed? : SlStatementTypeSeed? = None,
  flat_only? : Bool = false,
) -> Int {
  // Balanced local forwarding rejects any completed statement containing
  // structured control or an early terminator. Reject that same candidate
  // before recursively typechecking it, including unused error rendering.
  // Other prefix clients retain the complete structured typecheck path.
  if flat_only &&
    start >= 0 &&
    start < instrs.length() &&
    sl_statement_prefix_rejects_control(instrs[start]) {
    return start
  }
  let mut state = match typed_seed {
    Some(seed) => seed.fresh_state()
    None => @validate.make_state_owned(env, [])
  }
  for index = start; index < instrs.length(); index = index + 1 {
    if flat_only && sl_statement_prefix_rejects_control(instrs[index]) {
      return start
    }
    match typed_instructions {
      Some(count) => count[0] += 1
      None => ()
    }
    state = match @validate.Typecheck::typecheck(instrs[index], state) {
      Ok(next) => next
      Err(_) => return start
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
  start
}

///|
fn sl_statement_prefix_rejects_control(instr : @lib.Instruction) -> Bool {
  run_hot_pipeline_raw_simplify_locals_instr_is_structured(instr) ||
  run_hot_pipeline_raw_simplify_locals_instr_is_early_terminator(instr)
}

///|
// Own only the complete statement; callers do not need a copied remaining tail.
fn sl_statement_at(
  instrs : Array[@lib.Instruction],
  start : Int,
  env : @validate.Env,
  allow_escape? : Bool = false,
) -> Array[@lib.Instruction] {
  let end = run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
    instrs,
    env,
    allow_escape,
    start~,
  )
  Array::makei(end - start, fn(index) { instrs[start + index] })
}
