///|
fn lift_typecheck_result_bench(
  it : @bench.T,
  kind : Int,
  before : Bool,
) -> Unit raise {
  let env = @validate.empty_env()
  let instr = if kind == 0 {
    @lib.Instruction::nop()
  } else {
    @lib.Instruction::i32_add()
  }
  let types = if kind == 1 {
    [@lib.ValType::i32(), @lib.ValType::i32()]
  } else {
    []
  }
  it.bench(fn() {
    let state = @validate.make_state(env, types)
    if before {
      match hot_lift_impl_typecheck(instr, state) {
        Ok(next) => it.keep(next.stack.length())
        Err(_) => it.keep(-1)
      }
    } else {
      let checked = hot_lift_impl_check_instruction(instr, state)
      match checked.error {
        Some(_) => it.keep(-1)
        None => it.keep(checked.state.stack.length())
      }
    }
  })
}

///|
test "bench lift typecheck result empty before" (it : @bench.T) {
  lift_typecheck_result_bench(it, 0, true)
}

///|
test "bench lift typecheck result empty current" (it : @bench.T) {
  lift_typecheck_result_bench(it, 0, false)
}

///|
test "bench lift typecheck result scalar before" (it : @bench.T) {
  lift_typecheck_result_bench(it, 1, true)
}

///|
test "bench lift typecheck result scalar current" (it : @bench.T) {
  lift_typecheck_result_bench(it, 1, false)
}

///|
test "bench lift typecheck result invalid before" (it : @bench.T) {
  lift_typecheck_result_bench(it, 2, true)
}

///|
test "bench lift typecheck result invalid current" (it : @bench.T) {
  lift_typecheck_result_bench(it, 2, false)
}
