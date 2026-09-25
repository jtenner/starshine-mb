///|
fn oc_child_walk_perf_fixture(count : Int) -> (@ir.HotFunc, Int) {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32(), @lib.ValType::i32()]),
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

///|
fn oc_retarget_child_walk_perf_ctx() -> HotPassContext {
  HotPassContext::new(
    optimize_casts_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
}

///|
test "OptimizeCasts retarget walk changes each matching local get" {
  let (func, root) = oc_child_walk_perf_fixture(8)
  assert_eq(
    oc_retarget_local_gets(oc_retarget_child_walk_perf_ctx(), func, root, 0, 1),
    8,
  )
  assert_eq(oc_count_local_gets(func, root, 0), 0)
  assert_eq(oc_count_local_gets(func, root, 1), 8)
}

///|
fn oc_retarget_child_walk_perf_bench(it : @bench.T, count : Int) -> Unit {
  let (func, root) = oc_child_walk_perf_fixture(count)
  let ctx = oc_retarget_child_walk_perf_ctx()
  if oc_retarget_local_gets(ctx, func, root, 1, 0) != 0 {
    abort("OptimizeCasts no-match retarget benchmark changed locals")
  }
  it.bench(fn() { it.keep(oc_retarget_local_gets(ctx, func, root, 1, 0)) })
}

///|
test "bench OptimizeCasts no-match retarget count=256" (it : @bench.T) {
  oc_retarget_child_walk_perf_bench(it, 256)
}

///|
test "bench OptimizeCasts no-match retarget count=512" (it : @bench.T) {
  oc_retarget_child_walk_perf_bench(it, 512)
}
