///|
fn sl_prefix_reference(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
  allow_escape : Bool,
) -> Int {
  for end = 1; end <= instrs.length(); end = end + 1 {
    let prefix = Array::makei(end, fn(index) { instrs[index] })
    match
      @validate.Typecheck::typecheck(
        @lib.Expr::new(prefix),
        @validate.make_state(env, []),
      ) {
      Ok(state) => {
        let reaches = state.reachable &&
          state.escape == @validate.tc_escape_none()
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
      Err(_) => ()
    }
  }
  0
}

///|
fn sl_prefix_fixture(width : Int) -> Array[@lib.Instruction] {
  let body = Array::make(width, @lib.Instruction::i32_const(@lib.I32(1)))
  for _ in 0..<width {
    body.push(@lib.Instruction::drop())
  }
  body
}

///|
test "statement prefix checks each instruction once and retains exact split" {
  let body = sl_prefix_fixture(16)
  body.push(@lib.Instruction::nop())
  let env = @validate.Env::new()
  let visits = [0]
  let end = run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
    body,
    env,
    false,
    typed_instructions=Some(visits),
  )
  assert_eq(end, sl_prefix_reference(body, env, false))
  assert_eq(end, 32)
  assert_eq(visits[0], end)
  let (prefix, tail) = run_hot_pipeline_raw_simplify_locals_take_statement_prefix(
    body, env,
  )
  assert_eq(prefix.length(), end)
  assert_eq(tail, [@lib.Instruction::nop()])
}

///|
test "statement prefix preserves terminal and intentionally invalid-prefix handling" {
  let env = @validate.Env::new()
  for
    body in [
      [@lib.Instruction::unreachable_(), @lib.Instruction::nop()],
      [@lib.Instruction::i32_const(@lib.I32(7))],
      // Intentionally invalid: later producers cannot repair the first underflow.
      [@lib.Instruction::drop(), @lib.Instruction::i32_const(@lib.I32(7))],
      [],
    ] {
    for escape in [false, true] {
      assert_eq(
        run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
          body, env, escape,
        ),
        sl_prefix_reference(body, env, escape),
      )
    }
  }
}
