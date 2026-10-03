///|
fn hot_lift_stack_reuse_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit {
  let types = Array::make(width + 2, @lib.ValType::i32())
  let env = @validate.empty_env()
  let instruction = @lib.Instruction::i32_add()
  let initial = @validate.make_state(env, types)
  let (after, popped, pushed) = hot_lift_impl_typecheck_data_instruction(
      instruction, initial,
    )
    |> lift_data_check_unwrap
  if popped != 2 ||
    pushed != [@lib.ValType::i32()] ||
    after.stack.length() != width + 1 {
    abort("stack-reuse benchmark changed instruction arity")
  }
  it.bench(fn() {
    let state = @validate.make_state(env, types)
    if reference {
      let before = state.stack
      let next = hot_lift_impl_typecheck(
        instruction,
        @validate.tc_state_with_stack(state, before),
      ).unwrap()
      it.keep((next, 2, hot_lift_impl_pushed_types(before, next.stack, 2)))
    } else {
      it.keep(hot_lift_impl_typecheck_data_instruction(instruction, state))
    }
  })
}

///|
test "bench HOT data stack prefix=0 reference" (it : @bench.T) {
  hot_lift_stack_reuse_bench(it, 0, true)
}

///|
test "bench HOT data stack prefix=0 owned" (it : @bench.T) {
  hot_lift_stack_reuse_bench(it, 0, false)
}

///|
test "bench HOT data stack prefix=32 reference" (it : @bench.T) {
  hot_lift_stack_reuse_bench(it, 32, true)
}

///|
test "bench HOT data stack prefix=32 owned" (it : @bench.T) {
  hot_lift_stack_reuse_bench(it, 32, false)
}

///|
test "bench HOT data stack prefix=512 reference" (it : @bench.T) {
  hot_lift_stack_reuse_bench(it, 512, true)
}

///|
test "bench HOT data stack prefix=512 owned" (it : @bench.T) {
  hot_lift_stack_reuse_bench(it, 512, false)
}
