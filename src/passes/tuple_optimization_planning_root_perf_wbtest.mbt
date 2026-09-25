///|
fn tuple_planning_root_perf_fixture(
  count : Int,
) -> (@ir.HotFunc, @ir.HotUseDef, Array[Int], Array[Int]) {
  let func = @ir.HotFunc::new()
  let child_hosts : Array[Int] = []
  let root_hosts : Array[Int] = []
  for idx in 0..<count {
    let child = @ir.hot_build_const_i32(func, @lib.I32(idx))
    @ir.hot_append_root(func, @ir.hot_build_drop(func, child))
    child_hosts.push(child)
    let root = @ir.hot_build_nop(func)
    @ir.hot_append_root(func, root)
    root_hosts.push(root)
  }
  (func, @ir.use_def_build(func), child_hosts, root_hosts)
}

///|
fn tuple_planning_root_perf_bench(
  it : @bench.T,
  count : Int,
  roots : Bool,
) -> Unit {
  let (func, use_def, child_hosts, root_hosts) = tuple_planning_root_perf_fixture(
    count,
  )
  let targets = if roots { root_hosts } else { child_hosts }
  for target in targets {
    if tuple_optimization_has_root_site_in_fresh_use_def(func, use_def, target) !=
      roots {
      abort("tuple planning root membership preflight failed")
    }
  }
  it.bench(fn() {
    let mut root_count = 0
    for target in targets {
      if tuple_optimization_has_root_site_in_fresh_use_def(
          func, use_def, target,
        ) {
        root_count = root_count + 1
      }
    }
    it.keep(root_count)
  })
}

///|
test "tuple split-local planning finds only true root hosts" {
  let (func, use_def, child_hosts, root_hosts) = tuple_planning_root_perf_fixture(
    3,
  )
  for target in child_hosts {
    assert_false(
      tuple_optimization_has_root_site_in_fresh_use_def(func, use_def, target),
    )
  }
  for target in root_hosts {
    assert_true(
      tuple_optimization_has_root_site_in_fresh_use_def(func, use_def, target),
    )
  }
}

///|
test "bench tuple planning child-only hosts count=128" (it : @bench.T) {
  tuple_planning_root_perf_bench(it, 128, false)
}

///|
test "bench tuple planning child-only hosts count=256" (it : @bench.T) {
  tuple_planning_root_perf_bench(it, 256, false)
}

///|
test "bench tuple planning root hosts count=256" (it : @bench.T) {
  tuple_planning_root_perf_bench(it, 256, true)
}
