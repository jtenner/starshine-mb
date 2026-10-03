///|
// Frozen owned-result helper from 8e2106157; compare identical typechecking work.
fn lift_scalar_owned_reference(
  instr : Instruction,
  tc_state : TcState,
  concrete_before_types? : Array[ValType] = [],
) -> HotLiftDataCheck {
  // The region owns this stack. Known arity only needs its old length, so the
  // ordinary typechecker can consume it directly. Generic inference below
  // retains its snapshot because it replays suffix candidates.
  let before_count = tc_state.stack.length()
  match hot_lift_impl_known_pop_count(instr, tc_state.env) {
    Some(count) if count >= 0 && count <= before_count => {
      let after_state = match hot_lift_impl_typecheck(instr, tc_state) {
        Ok(next) => next
        Err(err) => return HotLiftDataCheck::failure(tc_state, err)
      }
      let pushed : Array[ValType] = []
      for index = before_count - count
          index < after_state.stack.length()
          index = index + 1 {
        pushed.push(after_state.stack[index])
      }
      return HotLiftDataCheck::success(after_state, count, pushed)
    }
    _ => ()
  }
  let before_types = tc_state.stack
  let before_state = tc_state
  let typecheck_state = tc_state_with_stack(tc_state, before_types)
  let after_state = match hot_lift_impl_typecheck(instr, typecheck_state) {
    Ok(next) => next
    Err(err) => return HotLiftDataCheck::failure(tc_state, err)
  }
  match hot_lift_impl_known_pop_count(instr, tc_state.env) {
    Some(count) if count <= before_types.length() =>
      HotLiftDataCheck::success(
        after_state,
        count,
        hot_lift_impl_pushed_types(before_types, after_state.stack, count),
      )
    _ =>
      match
        hot_lift_impl_resolve_generic_pop_count(
          instr, before_state, after_state, concrete_before_types,
        ) {
        Ok((child_count, pushed_types)) =>
          HotLiftDataCheck::success(after_state, child_count, pushed_types)
        Err(err) => HotLiftDataCheck::failure(tc_state, err)
      }
  }
}

///|
fn lift_scalar_results_bench(
  it : @bench.T,
  kind : Int,
  before : Bool,
) -> Unit raise {
  let env = if kind == 2 {
    @validate.Env::new().with_module(
      @wast.wast_to_binary_module(
        "(module (func (result i32 i64) i32.const 7 i64.const 9))",
      ).unwrap(),
    )
  } else {
    @validate.empty_env()
  }
  let instr = match kind {
    0 => @lib.Instruction::drop()
    2 => @lib.Instruction::call(@lib.FuncIdx::new(0U))
    _ => @lib.Instruction::i32_add()
  }
  fn state() -> TcState {
    if kind == 3 {
      @validate.tc_state_new(env, [], false, @validate.tc_escape_terminal())
    } else {
      @validate.make_state(
        env,
        match kind {
          0 => [@lib.ValType::i32()]
          1 => [@lib.ValType::i32(), @lib.ValType::i32()]
          _ => []
        },
      )
    }
  }
  let scratch : Array[@lib.ValType] = []
  let expected = lift_scalar_owned_reference(instr, state())
  let current = hot_lift_impl_typecheck_data_instruction(
    instr,
    state(),
    scalar_results=Some(scratch),
  )
  assert_eq(current.error, expected.error)
  assert_eq(current.pushed, expected.pushed)
  assert_eq(current.state.stack, expected.state.stack)
  assert_eq(current.state.reachable, expected.state.reachable)
  assert_eq(current.pop_count, expected.pop_count)
  it.bench(fn() {
    let checked = if before {
      lift_scalar_owned_reference(instr, state())
    } else {
      hot_lift_impl_typecheck_data_instruction(
        instr,
        state(),
        scalar_results=Some(scratch),
      )
    }
    match checked.error {
      Some(_) => it.keep(-1)
      None =>
        it.keep(
          checked.state.stack.length() +
          checked.pop_count +
          checked.pushed.length(),
        )
    }
  })
}

///|
test "bench lift scalar results empty before" (it : @bench.T) {
  lift_scalar_results_bench(it, 0, true)
}

///|
test "bench lift scalar results empty current" (it : @bench.T) {
  lift_scalar_results_bench(it, 0, false)
}

///|
test "bench lift scalar results scalar before" (it : @bench.T) {
  lift_scalar_results_bench(it, 1, true)
}

///|
test "bench lift scalar results scalar current" (it : @bench.T) {
  lift_scalar_results_bench(it, 1, false)
}

///|
test "bench lift scalar results multi before" (it : @bench.T) {
  lift_scalar_results_bench(it, 2, true)
}

///|
test "bench lift scalar results multi current" (it : @bench.T) {
  lift_scalar_results_bench(it, 2, false)
}

///|
test "bench lift scalar results polymorphic before" (it : @bench.T) {
  lift_scalar_results_bench(it, 3, true)
}

///|
test "bench lift scalar results polymorphic current" (it : @bench.T) {
  lift_scalar_results_bench(it, 3, false)
}

///|
test "bench lift scalar results error before" (it : @bench.T) {
  lift_scalar_results_bench(it, 4, true)
}

///|
test "bench lift scalar results error current" (it : @bench.T) {
  lift_scalar_results_bench(it, 4, false)
}
