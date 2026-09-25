///|
fn simplify_locals_use_count_perf_bench(
  it : @bench.T,
  trailing_nodes : Int,
  unique? : Bool = false,
) -> Unit {
  let func = @ir.HotFunc::new()
  let target = @ir.hot_build_const_i32(func, @lib.I32(1))
  if unique {
    @ir.hot_root_append(func, @ir.hot_build_drop(func, target))
  } else {
    @ir.hot_root_append(func, @ir.hot_build_compare(func, target, target))
  }
  for idx in 0..<trailing_nodes {
    @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(idx)))
  }
  if simplify_locals_child_use_count_capped_at_two(func, target) !=
    (if unique { 1 } else { 2 }) {
    abort("child-use benchmark count changed")
  }
  it.bench(fn() {
    it.keep(simplify_locals_child_use_count_capped_at_two(func, target))
  })
}

///|
test "SimplifyLocals child-use threshold distinguishes zero, one, and multiple" {
  let func = @ir.HotFunc::new()
  let target = @ir.hot_build_const_i32(func, @lib.I32(1))
  assert_eq(simplify_locals_child_use_count_capped_at_two(func, target), 0)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, target))
  assert_eq(simplify_locals_child_use_count_capped_at_two(func, target), 1)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, target))
  assert_eq(simplify_locals_child_use_count_capped_at_two(func, target), 2)
}

///|
test "bench SimplifyLocals shared-child use count trailing=1024" (it : @bench.T) {
  simplify_locals_use_count_perf_bench(it, 1024)
}

///|
test "bench SimplifyLocals shared-child use count trailing=4096" (it : @bench.T) {
  simplify_locals_use_count_perf_bench(it, 4096)
}

///|
test "bench SimplifyLocals unique-child use count trailing=1024" (it : @bench.T) {
  simplify_locals_use_count_perf_bench(it, 1024, unique=true)
}

///|
test "bench SimplifyLocals unique-child use count trailing=4096" (it : @bench.T) {
  simplify_locals_use_count_perf_bench(it, 4096, unique=true)
}
