///|
fn if_exit_value_bench(
  it : @bench.T,
  count : Int,
  ref_result : Bool,
  stopped : Bool,
) -> Unit {
  let ty = if ref_result { ValType::i31ref() } else { ValType::i32() }
  let results = Array::make(count, ty)
  let env = empty_env()
  let entry = make_state(env, [])
  let branch = tc_state_new(
    env,
    results,
    !stopped,
    if stopped {
      BranchTcEscape(3)
    } else {
      NoTcEscape
    },
  )
  let checked = tc_state_finish_if(entry, entry, branch, branch, results).unwrap()
  if checked.reachable == stopped {
    abort("if exit benchmark changed reachability")
  }
  entry.stack.clear()
  it.bench(fn() {
    entry.stack.clear()
    let out = tc_state_finish_if(entry, entry, branch, branch, results).unwrap()
    it.keep(out.reachable)
    it.keep(out.escape)
    it.keep(out.stack.length())
  })
}

///|
test "bench if exit value void fallthrough" (it : @bench.T) {
  if_exit_value_bench(it, 0, false, false)
}

///|
test "bench if exit value scalar tuple" (it : @bench.T) {
  if_exit_value_bench(it, 64, false, false)
}

///|
test "bench if exit value reference tuple" (it : @bench.T) {
  if_exit_value_bench(it, 64, true, false)
}

///|
test "bench if exit value nonfallthrough branches" (it : @bench.T) {
  if_exit_value_bench(it, 0, false, true)
}
