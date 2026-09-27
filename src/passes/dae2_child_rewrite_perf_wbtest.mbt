///|
fn dae2_child_rewrite_bench(
  it : @bench.T,
  repetitions : Int,
  reference : Bool,
) -> Unit {
  it.bench(fn() {
    let (func, add, left, right) = dae2_child_fixture()
    let children = [left, right]
    for _ in 0..<repetitions {
      if reference {
        ignore(@ir.hot_replace_child_span(func, add, children))
      } else {
        ignore(dae2_replace_children_if_changed(func, add, children))
      }
    }
    it.keep(func)
  })
}

///|
test "bench DAE2 repeated child writes repetitions=64" (it : @bench.T) {
  dae2_child_rewrite_bench(it, 64, true)
}

///|
test "bench DAE2 retained child spans repetitions=64" (it : @bench.T) {
  dae2_child_rewrite_bench(it, 64, false)
}

///|
test "bench DAE2 repeated child writes repetitions=1024" (it : @bench.T) {
  dae2_child_rewrite_bench(it, 1024, true)
}

///|
test "bench DAE2 retained child spans repetitions=1024" (it : @bench.T) {
  dae2_child_rewrite_bench(it, 1024, false)
}
