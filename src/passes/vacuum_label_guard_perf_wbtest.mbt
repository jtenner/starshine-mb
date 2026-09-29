///|
fn vacuum_label_guard_perf_bench(it : @bench.T, count : Int) -> Unit {
  let wat = StringBuilder::new()
  wat.write_string("(module (func (param i32)")
  for _ in 0..<count {
    // A branch to the result owner intentionally excludes this demotion:
    // its carried value still needs the owner's result signature.
    wat.write_string(
      " local.get 0 if (result i32) i32.const 1 local.get 0 br_if 0 else i32.const 2 end drop",
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
      if hot_pass_vacuum_sink_drop_into_if_arms(
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
test "bench Vacuum rejected targeted result-if sink count=128" (it : @bench.T) {
  vacuum_label_guard_perf_bench(it, 128)
}

///|
test "bench Vacuum rejected targeted result-if sink count=256" (it : @bench.T) {
  vacuum_label_guard_perf_bench(it, 256)
}

///|
fn vacuum_nonempty_else_guard_perf_bench(it : @bench.T, count : Int) -> Unit {
  let wat = StringBuilder::new()
  wat.write_string("(module (func (param i32)")
  for _ in 0..<count {
    wat.write_string(" local.get 0 if else i32.const 1 drop end")
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
    abort("Vacuum nonempty else fixture root count changed")
  }
  it.bench(fn() {
    for idx in 0..<count {
      if hot_pass_vacuum_remove_empty_if(
          ctx,
          func,
          roots,
          idx,
          @ir.hot_region_get(func, roots, idx),
        ) {
        abort("Vacuum nonempty else fixture unexpectedly transformed")
      }
    }
    it.keep(func)
  })
}

///|
test "bench Vacuum nonempty else guard count=128" (it : @bench.T) {
  vacuum_nonempty_else_guard_perf_bench(it, 128)
}

///|
test "bench Vacuum nonempty else guard count=256" (it : @bench.T) {
  vacuum_nonempty_else_guard_perf_bench(it, 256)
}

///|
fn vacuum_concrete_arm_fixture(count : Int) -> @lib.Module {
  let wat = StringBuilder::new()
  wat.write_string(
    "(module (import \"e\" \"value\" (func $value (param i32) (result i32))) (func (param i32)",
  )
  for _ in 0..<count {
    wat.write_string(
      " local.get 0 if (result i32) local.get 0 call $value else local.get 0 call $value end drop",
    )
  }
  wat.write_string("))")
  pass_test_module_from_wat(wat.to_string())
}

///|
fn vacuum_concrete_arm_run(input : @lib.Module, count : Int) -> @ir.HotFunc {
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(1U))
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("vacuum", requires=[], invalidates=[]),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let roots = @ir.HotRegionRef::root()
  if @ir.hot_region_root_count(func, roots) != count {
    abort("concrete-arm fixture root count changed")
  }
  for idx in 0..<count {
    let drop = @ir.hot_region_get(func, roots, idx)
    if !hot_pass_vacuum_sink_drop_into_if_arms(
        ctx,
        func,
        roots,
        idx,
        @ir.hot_child_get(func, drop, 0),
      ) {
      abort("expected every concrete-arm drop to sink")
    }
  }
  func
}

///|
test "vacuum concrete-arm benchmark fixture performs the required transformation" {
  let input = vacuum_concrete_arm_fixture(4)
  let saved = @binary.encode_module(input).unwrap()
  let func = vacuum_concrete_arm_run(input, 4)
  @ir.hot_verify_all_or_abort(func)
  for idx in 0..<4 {
    let if_id = @ir.hot_root_get(func, idx)
    assert_true(@ir.hot_node_get(func, if_id).op is @ir.If)
    assert_eq(@ir.hot_node_result_arity(func, if_id), 0)
    for
      arm in [
        @ir.hot_region_then_ref(func, if_id),
        @ir.hot_region_else_ref(func, if_id).unwrap(),
      ] {
      let drop = @ir.hot_region_get(func, arm, 0)
      assert_true(@ir.hot_node_get(func, drop).op is @ir.Drop)
      assert_true(
        @ir.hot_node_get(func, @ir.hot_child_get(func, drop, 0)).op is @ir.Call,
      )
    }
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench Vacuum concrete-arm sink count=128" (it : @bench.T) {
  let input = vacuum_concrete_arm_fixture(128)
  it.bench(fn() { it.keep(vacuum_concrete_arm_run(input, 128)) })
}

///|
test "bench Vacuum concrete-arm sink count=256" (it : @bench.T) {
  let input = vacuum_concrete_arm_fixture(256)
  it.bench(fn() { it.keep(vacuum_concrete_arm_run(input, 256)) })
}
