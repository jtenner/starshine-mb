///|
fn hot_lift_mask_fork_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit {
  let env = @validate.empty_env().with_locals(
    @lib.Locals::single(width.to_uint(), @lib.ValType::i32()),
  )
  let entry = @validate.tc_state_new(env, [], true, @validate.tc_escape_none())
  let child_env = env.with_label([])
  it.bench(fn() {
    for _ in 0..<128 {
      it.keep(
        if reference {
          @validate.tc_state_new(child_env, [], entry.reachable, entry.escape)
        } else {
          hot_lift_impl_region_state(entry, child_env, [])
        },
      )
    }
  })
}

///|
test "bench HOT mask fork width=4 reference" (it : @bench.T) {
  hot_lift_mask_fork_bench(it, 4, true)
}

///|
test "bench HOT mask fork width=4 borrowed" (it : @bench.T) {
  hot_lift_mask_fork_bench(it, 4, false)
}

///|
test "bench HOT mask fork width=128 reference" (it : @bench.T) {
  hot_lift_mask_fork_bench(it, 128, true)
}

///|
test "bench HOT mask fork width=128 borrowed" (it : @bench.T) {
  hot_lift_mask_fork_bench(it, 128, false)
}

///|
test "bench HOT mask fork width=4096 reference" (it : @bench.T) {
  hot_lift_mask_fork_bench(it, 4096, true)
}

///|
test "bench HOT mask fork width=4096 borrowed" (it : @bench.T) {
  hot_lift_mask_fork_bench(it, 4096, false)
}
