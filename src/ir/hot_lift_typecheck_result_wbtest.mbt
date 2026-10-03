///|
// Frozen validator-to-lift Result adapter retained only for test/perf controls.
fn hot_lift_impl_typecheck(
  instr : Instruction,
  tc_state : TcState,
) -> Result[TcState, HotLiftError] {
  match Typecheck::typecheck(instr, tc_state) {
    Ok(next) => Ok(next)
    Err(err) => Err(hot_lift_impl_fail_typecheck(instr, err))
  }
}

///|
test "lift typecheck immediate result preserves states and first errors" {
  for
    (instr, types) in [
      (@lib.Instruction::nop(), []),
      (@lib.Instruction::i32_const(@lib.I32(7)), []),
      (
        @lib.Instruction::i32_add(),
        [@lib.ValType::f64(), @lib.ValType::i32(), @lib.ValType::i32()],
      ),
      (@lib.Instruction::unreachable_(), [@lib.ValType::i32()]),
      // Intentionally invalid concrete stack and underflow retain first errors.
      (@lib.Instruction::i32_add(), [@lib.ValType::f32(), @lib.ValType::i32()]),
      (@lib.Instruction::i32_add(), []),
    ] {
    let env = @validate.empty_env()
    let old_state = @validate.make_state(env, types)
    let new_state = @validate.make_state(env, types)
    let old = hot_lift_impl_typecheck(instr, old_state)
    let new = hot_lift_impl_check_instruction(instr, new_state)
    match old {
      Ok(expected) => {
        assert_true(new.error is None)
        assert_eq(new.state.stack, expected.stack)
        assert_eq(new.state.reachable, expected.reachable)
        assert_eq(new.state.escape, expected.escape)
        assert_eq(
          new.state.reachable_escape_depths,
          expected.reachable_escape_depths,
        )
        assert_eq(new.state.initialized_locals, expected.initialized_locals)
        assert_eq(
          physical_equal(new.state, new_state),
          physical_equal(expected, old_state),
        )
      }
      Err(error) => {
        assert_eq(new.error, Some(error))
        assert_true(physical_equal(new.state, new_state))
        assert_eq(new_state.stack, old_state.stack)
      }
    }
  }
}

///|
test "lift typecheck immediate result retains mixed call result types" {
  let input = @wast.wast_to_binary_module(
    "(module (type $s (struct (field i32))) (func (result (ref $s) i64) i32.const 7 struct.new $s i64.const 9))",
  ).unwrap()
  let env = @validate.Env::new().with_module(input)
  let instr = @lib.Instruction::call(@lib.FuncIdx::new(0U))
  let old_state = @validate.make_state(env, [])
  let new_state = @validate.make_state(env, [])
  let expected = hot_lift_impl_typecheck(instr, old_state).unwrap()
  let result = hot_lift_impl_check_instruction(instr, new_state)
  assert_true(result.error is None)
  assert_eq(result.state.stack, expected.stack)
  assert_eq(result.state.stack.length(), 2)
  assert_true(physical_equal(result.state, new_state))
  result.state.stack.clear()
  assert_eq(expected.stack.length(), 2)
}
