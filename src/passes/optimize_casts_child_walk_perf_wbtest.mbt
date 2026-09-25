///|
fn oc_child_walk_perf_fixture(count : Int) -> (@ir.HotFunc, Int) {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let mut value = @ir.hot_build_const_i32(func, @lib.I32(0))
  for _ in 0..<count {
    value = @ir.hot_build_select(
      func,
      @lib.ValType::i32(),
      value,
      @ir.hot_build_local_get(func, 0),
      @ir.hot_build_const_i32(func, @lib.I32(1)),
    )
  }
  (func, value)
}

///|
fn oc_child_walk_perf_bench(it : @bench.T, count : Int) -> Unit {
  let (func, root) = oc_child_walk_perf_fixture(count)
  if oc_count_local_gets(func, root, 0) != count {
    abort("OptimizeCasts child-walk fixture count is wrong")
  }
  it.bench(fn() { it.keep(oc_count_local_gets(func, root, 0)) })
}

///|
test "bench OptimizeCasts child walk count=256" (it : @bench.T) {
  oc_child_walk_perf_bench(it, 256)
}

///|
test "bench OptimizeCasts child walk count=512" (it : @bench.T) {
  oc_child_walk_perf_bench(it, 512)
}
