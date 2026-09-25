///|
fn vacuum_label_guard_perf_bench(it : @bench.T, count : Int) -> Unit {
  let wat = StringBuilder::new()
  wat.write_string("(module (func (param i32)")
  for _ in 0..<count {
    wat.write_string(
      " local.get 0 if (result i32) i32.const 1 else i32.const 2 end drop",
    )
  }
  wat.write_string("))")
  let func = @ir.ir_test_build_hot_from_wat(wat.to_string()).hot_func
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("vacuum", requires=[], invalidates=[]),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let roots = @ir.HotRegionRef::root()
  if @ir.hot_region_root_count(func, roots) != count {
    abort("Vacuum label guard fixture root count changed")
  }
  let if_nodes : Array[Int] = []
  for idx in 0..<count {
    let drop = @ir.hot_region_get(func, roots, idx)
    if_nodes.push(@ir.hot_child_get(func, drop, 0))
  }
  it.bench(fn() {
    for idx in 0..<count {
      if hot_pass_vacuum_sink_drop_into_unreachable_if_arm(
          ctx,
          func,
          roots,
          idx,
          if_nodes[idx],
        ) {
        abort("Vacuum label guard fixture unexpectedly transformed")
      }
    }
    it.keep(func)
  })
}

///|
test "bench Vacuum rejected result-if sink count=128" (it : @bench.T) {
  vacuum_label_guard_perf_bench(it, 128)
}

///|
test "bench Vacuum rejected result-if sink count=256" (it : @bench.T) {
  vacuum_label_guard_perf_bench(it, 256)
}
