///|
fn vacuum_nested_unary_perf_fixture(depth : Int) -> @lib.Module {
  let wat = StringBuilder::new()
  wat.write_string(
    "(module (import \"env\" \"effect\" (func (result i32))) (func (drop ",
  )
  for _ in 0..<depth {
    wat.write_string("(i32.clz ")
  }
  wat.write_string("(call 0)")
  for _ in 0..<depth {
    wat.write_string(")")
  }
  wat.write_string(")))")
  pass_test_module_from_wat(wat.to_string())
}

///|
fn vacuum_nested_unary_perf_ctx() -> HotPassContext {
  HotPassContext::new(
    @ir.HotPassDescriptor::new("vacuum", requires=[], invalidates=[]),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::final_module_only(),
    false,
    fn(_) { () },
  )
}

///|
fn vacuum_nested_unary_perf_bench(it : @bench.T, depth : Int) -> Unit {
  let fixture = vacuum_nested_unary_perf_fixture(depth)
  let preflight = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(1U))
  let dropped = @ir.hot_root_get(preflight, 0)
  let top = @ir.hot_child_get(preflight, dropped, 0)
  match
    vacuum_dropped_parent_replacement(
      vacuum_nested_unary_perf_ctx(),
      preflight,
      top,
    ) {
    Some(replacement) => {
      if replacement.roots.length() != 1 ||
        replacement.detached.length() != depth {
        abort("Vacuum nested-unary replacement shape changed")
      }
      let retained = replacement.roots[0]
      if !(@ir.hot_node_get(preflight, retained).op is @ir.HotOp::Drop) ||
        !(@ir.hot_node_get(preflight, @ir.hot_child_get(preflight, retained, 0)).op
        is @ir.HotOp::Call) {
        abort("Vacuum nested-unary replacement lost effectful call")
      }
    }
    None => abort("Vacuum did not decompose nested unary wrappers")
  }
  let ctx = vacuum_nested_unary_perf_ctx()
  it.bench(fn() {
    let func = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(1U))
    let top = @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0)
    let result = vacuum_dropped_parent_replacement(ctx, func, top)
    it.keep(result)
  })
}

///|
test "Vacuum nested unary rewrite retains effectful terminal once" {
  let fixture = vacuum_nested_unary_perf_fixture(32)
  let func = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(1U))
  assert_true(
    hot_pass_vacuum_rewrite_dropped_parents_batch(
      vacuum_nested_unary_perf_ctx(),
      func,
      @ir.HotRegionRef::root(),
    ),
  )
  assert_eq(@ir.hot_root_count(func), 1)
  let drop = @ir.hot_root_get(func, 0)
  assert_true(@ir.hot_node_get(func, drop).op is @ir.HotOp::Drop)
  assert_true(
    @ir.hot_node_get(func, @ir.hot_child_get(func, drop, 0)).op
    is @ir.HotOp::Call,
  )
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail("nested-unary Vacuum HOT graph invalid: \{err}")
  }
}

///|
test "Vacuum nested pure unary chain removes dropped root" {
  let fixture = pass_test_module_from_wat(
    "(module (func (drop (i32.clz (i32.clz (i32.const 1))))))",
  )
  let func = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  assert_true(
    hot_pass_vacuum_rewrite_dropped_parents_batch(
      vacuum_nested_unary_perf_ctx(),
      func,
      @ir.HotRegionRef::root(),
    ),
  )
  assert_eq(@ir.hot_root_count(func), 0)
}

///|
test "bench Vacuum dropped nested unary depth=64" (it : @bench.T) {
  vacuum_nested_unary_perf_bench(it, 64)
}

///|
test "bench Vacuum dropped nested unary depth=128" (it : @bench.T) {
  vacuum_nested_unary_perf_bench(it, 128)
}

///|
test "bench Vacuum dropped nested unary depth=256" (it : @bench.T) {
  vacuum_nested_unary_perf_bench(it, 256)
}
