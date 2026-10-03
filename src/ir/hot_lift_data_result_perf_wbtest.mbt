///|
// Frozen prior helper; stack ownership, checks and pushed arrays are identical.
fn lift_data_boxed_reference(
  instr : Instruction,
  tc_state : TcState,
  concrete_before_types? : Array[ValType] = [],
) -> Result[(TcState, Int, Array[ValType]), HotLiftError] {
  // The region owns this stack. Known arity only needs its old length, so the
  // ordinary typechecker can consume it directly. Generic inference below
  // retains its snapshot because it replays suffix candidates.
  let before_count = tc_state.stack.length()
  match hot_lift_impl_known_pop_count(instr, tc_state.env) {
    Some(count) if count >= 0 && count <= before_count => {
      let after_state = match hot_lift_impl_typecheck(instr, tc_state) {
        Ok(next) => next
        Err(err) => return Err(err)
      }
      let pushed : Array[ValType] = []
      for index = before_count - count
          index < after_state.stack.length()
          index = index + 1 {
        pushed.push(after_state.stack[index])
      }
      return Ok((after_state, count, pushed))
    }
    _ => ()
  }
  let before_types = tc_state.stack
  let before_state = tc_state
  let typecheck_state = tc_state_with_stack(tc_state, before_types)
  let after_state = match hot_lift_impl_typecheck(instr, typecheck_state) {
    Ok(next) => next
    Err(err) => return Err(err)
  }
  match hot_lift_impl_known_pop_count(instr, tc_state.env) {
    Some(count) if count <= before_types.length() =>
      Ok(
        (
          after_state,
          count,
          hot_lift_impl_pushed_types(before_types, after_state.stack, count),
        ),
      )
    _ =>
      match
        hot_lift_impl_resolve_generic_pop_count(
          instr, before_state, after_state, concrete_before_types,
        ) {
        Ok((child_count, pushed_types)) =>
          Ok((after_state, child_count, pushed_types))
        Err(err) => Err(err)
      }
  }
}

///|
fn lift_data_result_bench(
  it : @bench.T,
  width : Int,
  unreachable : Bool,
  before : Bool,
) -> Unit raise {
  let types = if unreachable {
    []
  } else {
    Array::make(width + 2, @lib.ValType::i32())
  }
  let env = @validate.empty_env()
  let instruction = @lib.Instruction::i32_add()
  fn state() -> TcState {
    if unreachable {
      @validate.tc_state_new(env, [], false, @validate.tc_escape_terminal())
    } else {
      @validate.make_state(env, types)
    }
  }
  let (expected, count, pushed) = lift_data_boxed_reference(
    instruction,
    state(),
  ).unwrap()
  let checked = hot_lift_impl_typecheck_data_instruction(instruction, state())
  assert_true(checked.error is None)
  assert_eq(checked.state.stack, expected.stack)
  assert_eq(checked.state.reachable, expected.reachable)
  assert_eq(checked.pop_count, count)
  assert_eq(checked.pushed, pushed)
  it.bench(fn() {
    if before {
      let (after, count, pushed) = lift_data_boxed_reference(
        instruction,
        state(),
      ).unwrap()
      it.keep(after.stack.length() + count + pushed.length())
    } else {
      let checked = hot_lift_impl_typecheck_data_instruction(
        instruction,
        state(),
      )
      match checked.error {
        Some(_) => abort("unexpected benchmark type error")
        None =>
          it.keep(
            checked.state.stack.length() +
            checked.pop_count +
            checked.pushed.length(),
          )
      }
    }
  })
}

///|
test "bench lift data result scalar before" (it : @bench.T) {
  lift_data_result_bench(it, 0, false, true)
}

///|
test "bench lift data result scalar current" (it : @bench.T) {
  lift_data_result_bench(it, 0, false, false)
}

///|
test "bench lift data result prefix32 before" (it : @bench.T) {
  lift_data_result_bench(it, 32, false, true)
}

///|
test "bench lift data result prefix32 current" (it : @bench.T) {
  lift_data_result_bench(it, 32, false, false)
}

///|
test "bench lift data result polymorphic before" (it : @bench.T) {
  lift_data_result_bench(it, 0, true, true)
}

///|
test "bench lift data result polymorphic current" (it : @bench.T) {
  lift_data_result_bench(it, 0, true, false)
}
