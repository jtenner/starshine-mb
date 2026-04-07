///|
fn tuple_optimization_test_analyze(
  text : String,
) -> HotTupleOptimizationAnalysis {
  let fixture = @ir.ir_test_build_hot_from_wat(text)
  let use_def = @ir.use_def_build(fixture.hot_func)
  tuple_optimization_analyze(fixture.hot_func, use_def)
}

///|
fn tuple_optimization_test_analyze_via_binary(
  text : String,
  func_idx : UInt,
) -> HotTupleOptimizationAnalysis {
  let mod_ = pass_test_module_from_wat(text)
  let encoded = match @binary.encode_module(mod_) {
    Ok(bytes) => bytes
    Err(err) =>
      abort(
        "unexpected tuple-optimization via-binary fixture encode failure: \{err}",
      )
  }
  let decoded = match @binary.decode_module(encoded) {
    Ok(decoded) => decoded
    Err(err) =>
      abort(
        "unexpected tuple-optimization via-binary fixture decode failure: \{err}",
      )
  }
  let hot_func = @ir.hot_lift_func(decoded, @lib.FuncIdx::new(func_idx))
  let use_def = @ir.use_def_build(hot_func)
  tuple_optimization_analyze(hot_func, use_def)
}

///|
fn tuple_optimization_test_ctx() -> HotPassContext {
  HotPassContext::new(
    @ir.HotPassDescriptor::new("tuple-optimization-test"),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
}

///|
fn tuple_optimization_test_rewrite(text : String) -> @ir.IrTestHotFixture {
  let fixture = @ir.ir_test_build_hot_from_wat(text)
  let ctx = tuple_optimization_test_ctx()
  let analysis = tuple_optimization_analyze(
    fixture.hot_func,
    @ir.use_def_build(fixture.hot_func),
  )
  if !tuple_optimization_rewrite_good_components(
      ctx,
      fixture.hot_func,
      analysis,
    ) {
    abort("expected tuple rewrite fixture to change")
  }
  match pass_verify_before_after(ctx, fixture.hot_func) {
    Ok(_) => ()
    Err(err) => abort("expected tuple rewrite verification success, got \{err}")
  }
  fixture
}

///|
fn tuple_optimization_test_pipeline_pretty(
  text : String,
  func_idx : UInt,
) -> String {
  let optimized = match pass_test_run_pipeline(text, ["tuple-optimization"]) {
    Ok(mod_) => mod_
    Err(err) =>
      abort("expected tuple-optimization pipeline success, got \{err}")
  }
  optimized.pretty_print_func(@lib.FuncIdx::new(func_idx))
}

///|
fn tuple_optimization_assert_local_traffic(
  use_def : @ir.HotUseDef,
  local_id : Int,
  writes : Int,
  reads : Int,
) -> Unit {
  let actual_writes = @ir.local_write_nodes_borrowed(use_def, local_id).length()
  let actual_reads = @ir.local_read_nodes_borrowed(use_def, local_id).length()
  if actual_writes != writes || actual_reads != reads {
    abort(
      "unexpected local traffic for \{local_id}: writes \{actual_writes} vs \{writes}, reads \{actual_reads} vs \{reads}",
    )
  }
}

///|
test "tuple-optimization no-op screen rejects scalar-only functions" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (func (result i32) i32.const 7))",
  )
  assert_false(tuple_optimization_may_have_candidates(fixture.hot_func))
  let analysis = tuple_optimization_analyze(
    fixture.hot_func,
    @ir.use_def_build(fixture.hot_func),
  )
  assert_eq(analysis.groups.length(), 0)
}

///|
test "tuple-optimization analysis detects a direct multivalue spill group" {
  let analysis = tuple_optimization_test_analyze(
    "(module (func (result i32) (local i32 i32 i32) block (result i32 i32 i32) i32.const 10 i32.const 20 i32.const 30 end local.set 2 local.set 1 local.set 0 local.get 0))",
  )

  assert_eq(analysis.groups.length(), 1)
  let group = analysis.groups[0]
  assert_eq(group.lane_locals, [0, 1, 2])
  assert_eq(group.copy_source, None)
  assert_eq(group.uses, 2)
  assert_eq(group.valid_uses, 2)
  assert_eq(group.neighbors, [])
  assert_false(group.bad)
}

///|
test "tuple-optimization rewrite carries direct spill bridges through a root local.set lane" {
  let fixture = tuple_optimization_test_rewrite(
    "(module (func (result i32) (local i32 i32 i32) block (result i32 i32 i32) i32.const 10 i32.const 20 i32.const 30 end local.set 2 local.set 1 local.set 0 local.get 0))",
  )
  let func = fixture.hot_func

  assert_eq(@ir.hot_local_count(func), 3)

  let bridge = @ir.hot_root_get(func, 0)
  assert_eq(@ir.hot_node_get(func, bridge).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, bridge).imm0, 0)

  let body = @ir.hot_child_get(func, bridge, 0)
  assert_eq(@ir.hot_node_get(func, body).op.to_string(), "Block")
  assert_eq(@ir.hot_node_result_arity(func, body), 1)

  let body_ref = @ir.hot_region_body_ref(func, body)
  assert_eq(@ir.hot_region_root_count(func, body_ref), 3)
  let lane2 = @ir.hot_region_get(func, body_ref, 0)
  let lane1 = @ir.hot_region_get(func, body_ref, 1)
  let lane0 = @ir.hot_region_get(func, body_ref, 2)
  assert_eq(@ir.hot_node_get(func, lane2).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, lane2).imm0, 2)
  assert_eq(@ir.hot_node_get(func, lane1).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, lane1).imm0, 1)
  assert_eq(@ir.hot_node_get(func, lane0).op.to_string(), "Block")

  assert_eq(@ir.hot_root_count(func), 2)
  let forwarded = @ir.hot_root_get(func, 1)
  assert_eq(@ir.hot_node_get(func, forwarded).op.to_string(), "LocalGet")
  assert_eq(@ir.hot_node_get(func, forwarded).imm0, 0)

  let use_def = @ir.use_def_build(func)
  tuple_optimization_assert_local_traffic(use_def, 0, 1, 1)
  tuple_optimization_assert_local_traffic(use_def, 1, 1, 0)
  tuple_optimization_assert_local_traffic(use_def, 2, 1, 0)
}

///|
test "tuple-optimization analysis rejects mixed bridge and non-bridge consumers" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (func (result i32) (local i32) block (result i32 i32) i32.const 1 i32.const 2 end local.set 0 drop local.get 0))",
  )
  assert_true(tuple_optimization_may_have_candidates(fixture.hot_func))
  let analysis = tuple_optimization_analyze(
    fixture.hot_func,
    @ir.use_def_build(fixture.hot_func),
  )
  assert_eq(analysis.groups.length(), 0)
}

///|
test "tuple-optimization analysis links pure lane-forwarding copy groups" {
  let analysis = tuple_optimization_test_analyze(
    "(module (func (result i32) (local i32 i32 i32 i32 i32 i32) block (result i32 i32 i32) i32.const 1 i32.const 2 i32.const 3 end local.set 2 local.set 1 local.set 0 block (result i32 i32 i32) local.get 0 local.get 1 local.get 2 end local.set 5 local.set 4 local.set 3 local.get 3))",
  )

  assert_eq(analysis.groups.length(), 2)

  let source = analysis.groups[0]
  assert_eq(source.lane_locals, [0, 1, 2])
  assert_eq(source.copy_source, None)
  assert_eq(source.uses, 2)
  assert_eq(source.valid_uses, 2)
  assert_eq(source.neighbors, [1])
  assert_false(source.bad)

  let copy = analysis.groups[1]
  assert_eq(copy.lane_locals, [3, 4, 5])
  assert_eq(copy.copy_source, Some(0))
  assert_eq(copy.uses, 2)
  assert_eq(copy.valid_uses, 2)
  assert_eq(copy.neighbors, [0])
  assert_false(copy.bad)
}

///|
test "tuple-optimization rewrite forwards good copy groups through scalar lane rematerialization" {
  let pretty = tuple_optimization_test_pipeline_pretty(
    "(module (func (result i32) (local i32 i32 i32 i32 i32 i32) block (result i32 i32 i32) i32.const 1 i32.const 2 i32.const 3 end local.set 2 local.set 1 local.set 0 block (result i32 i32 i32) local.get 0 local.get 1 local.get 2 end local.set 5 local.set 4 local.set 3 local.get 3))",
    0U,
  )

  assert_false(pretty.contains("tuple.make"), msg=pretty)
  assert_true(
    pretty.contains(
      "(local.get (Local 2))(local.set (Local 5))(local.get (Local 1))(local.set (Local 4))(local.get (Local 0))(local.set (Local 3))",
    ),
    msg=pretty,
  )
}

///|
test "tuple-optimization analysis propagates badness across copy-connected groups" {
  let analysis = tuple_optimization_test_analyze(
    "(module (func (result i32) (local i32 i32 i32 i32 i32 i32) block (result i32 i32 i32) i32.const 1 i32.const 2 i32.const 3 end local.set 2 local.set 1 local.set 0 block (result i32 i32 i32) local.get 0 local.get 1 local.get 2 end local.set 5 local.set 4 local.set 3 i32.const 9 local.set 4 local.get 3))",
  )

  assert_eq(analysis.groups.length(), 2)

  let source = analysis.groups[0]
  assert_eq(source.uses, 2)
  assert_eq(source.valid_uses, 2)
  assert_true(source.bad)

  let copy = analysis.groups[1]
  assert_eq(copy.uses, 3)
  assert_eq(copy.valid_uses, 2)
  assert_true(copy.bad)
}

///|
test "tuple-optimization analysis accepts multivalue spill bridges ending in local.tee" {
  let analysis = tuple_optimization_test_analyze(
    "(module (func (local i32 i32) block (result i32 i32) i32.const 1 i32.const 2 end local.set 1 local.tee 0 drop local.get 1 drop))",
  )

  assert_eq(analysis.groups.length(), 1)
  let group = analysis.groups[0]
  assert_eq(group.lane_locals, [0, 1])
  assert_eq(group.copy_source, None)
  assert_eq(group.uses, 3)
  assert_eq(group.valid_uses, 3)
  assert_eq(group.neighbors, [])
  assert_false(group.bad)
}

///|
test "tuple-optimization rewrite preserves host local.tee value flow with a scalar result block" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (local i32 i32) block (result i32 i32) i32.const 1 i32.const 2 end local.tee 1 drop local.set 0 local.get 0 drop))",
      ["tuple-optimization"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected host local.tee tuple-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("drop(local.tee"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 0))drop"), msg=pretty)
}

///|
test "tuple-optimization rewrite keeps exact host tee repro consumers on original lane locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32) i32.const 1 drop i32.const 10000 local.set 3 i32.const 42 local.get 3 call 0 local.set 2 local.set 1 local.tee 0 local.get 1 local.get 2 call 1))",
      ["tuple-optimization"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected host tee repro tuple-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("local.tee (Local 0)"), msg=pretty)
  assert_true(
    pretty.contains(
      "(local.tee (Local 0))(local.get (Local 1))(local.get (Local 2))(call (Func 1))",
    ),
    msg=pretty,
  )
  assert_false(
    pretty.contains(
      "(local.get (Local 4))(local.get (Local 1))(local.get (Local 2))(call (Func 1))",
    ),
    msg=pretty,
  )
}

///|
test "tuple-optimization analysis links exact scalar-forward compare-shape copy groups" {
  let analysis = tuple_optimization_test_analyze(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"trim\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 local.get 6 local.set 3 local.get 7 local.set 2 local.get 8 local.tee 1 local.get 2 local.get 3 call 1 local.set 0 local.get 0))",
  )

  assert_eq(analysis.groups.length(), 2)

  let source = analysis.groups[0]
  assert_eq(source.lane_locals, [4, 5, 6])
  assert_eq(source.copy_source, None)
  assert_eq(source.uses, 2)
  assert_eq(source.valid_uses, 2)
  assert_false(source.bad)

  let copy = analysis.groups[1]
  assert_eq(copy.lane_locals, [8, 7, 3])
  assert_eq(copy.copy_source, Some(0))
  assert_eq(copy.uses, 3)
  assert_eq(copy.valid_uses, 3)
  assert_eq(tuple_optimization_group_host_lane(copy), Some(0))
  assert_false(copy.bad)
}

///|
test "tuple-optimization pipeline rewrites compare-shape scalar forwarding bridges" {
  let source = "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"trim\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 local.get 6 local.set 3 local.get 7 local.set 2 local.get 8 local.tee 1 local.get 2 local.get 3 call 1 local.set 0 local.get 0))"
  let input_mod = pass_test_module_from_wat(source)
  let optimized = match pass_test_run_pipeline(source, ["tuple-optimization"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected compare-shape scalar forwarding tuple-optimization success, got \{err}",
      )
  }

  assert_not_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
    input_mod.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
}

///|
test "tuple-optimization rewrite keeps a staged host local.set root chain" {
  let fixture = tuple_optimization_test_rewrite(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"trim\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 local.get 6 local.set 3 local.get 7 local.set 2 local.get 8 local.tee 1 local.get 2 local.get 3 call 1 local.set 0 local.get 0))",
  )
  let func = fixture.hot_func

  assert_true(@ir.hot_local_count(func) > 9)

  let staged_root = @ir.hot_root_get(func, 0)
  assert_eq(@ir.hot_node_get(func, staged_root).op.to_string(), "LocalSet")
}

///|
test "tuple-optimization rewrite scalarizes exact copy groups through a root local.set lane" {
  let pretty = tuple_optimization_test_pipeline_pretty(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 2 local.set 1 local.set 0 local.get 0 local.get 1 local.get 2 call 1 local.set 9 local.get 9))",
    2U,
  )

  assert_false(pretty.contains("tuple.make"), msg=pretty)
  assert_true(
    pretty.contains(
      "(local.get (Local 6))(local.set (Local 2))(local.get (Local 7))(local.set (Local 1))(local.get (Local 8))(local.set (Local 0))(local.get (Local 0))(local.get (Local 1))(local.get (Local 2))(call (Func 1))",
    ),
    msg=pretty,
  )
}

///|
test "tuple-optimization analysis links nested exact copy groups through scalar result carriers" {
  let analysis = tuple_optimization_test_analyze(
    "(module (type (func (param i32 i64) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32) local.get 0 i64.const 1 call 0 local.set 5 local.set 4 local.set 3 block block block (result i32) block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 2 local.set 1 end local.set 0 end end local.get 0))",
  )

  assert_eq(analysis.groups.length(), 2)

  let source = analysis.groups[0]
  assert_eq(source.lane_locals, [3, 4, 5])
  assert_eq(source.copy_source, None)
  assert_false(source.bad)

  let copy = analysis.groups[1]
  assert_eq(copy.lane_locals, [0, 1, 2])
  assert_eq(copy.copy_source, Some(0))
  assert_eq(copy.copy_payload_locals, Some([3, 4, 5]))
  assert_eq(tuple_optimization_group_host_lane(copy), None)
  assert_false(copy.bad)
  assert_true(tuple_optimization_group_should_rewrite(copy))
}

///|
test "tuple-optimization rewrite scalarizes single-use exact copy groups from a host tee source" {
  let pretty = tuple_optimization_test_pipeline_pretty(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 11 local.set 9 local.set 10 local.get 9 local.get 10 local.get 11 call 1))",
    2U,
  )
  assert_false(pretty.contains("tuple.make"), msg=pretty)
  assert_true(
    pretty.contains(
      "(local.get (Local 14))(local.set (Local 11))(local.get (Local 13))(local.set (Local 9))(local.get (Local 12))(local.set (Local 10))(local.get (Local 9))(local.get (Local 10))(local.get (Local 11))(call (Func 1))",
    ),
    msg=pretty,
  )
}

///|
test "tuple-optimization rewrite scalarizes lane-ordered scrambled exact copy groups" {
  let pretty = tuple_optimization_test_pipeline_pretty(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 11 local.set 9 local.set 10 local.get 10 local.get 9 local.get 11 call 1))",
    2U,
  )
  assert_false(pretty.contains("tuple.make"), msg=pretty)
  assert_true(
    pretty.contains(
      "(local.get (Local 14))(local.set (Local 11))(local.get (Local 13))(local.set (Local 9))(local.get (Local 12))(local.set (Local 10))(local.get (Local 10))(local.get (Local 9))(local.get (Local 11))(call (Func 1))",
    ),
    msg=pretty,
  )
}

///|
test "tuple-optimization rewrite scalarizes overlapping exact copy groups from a host tee source" {
  let pretty = tuple_optimization_test_pipeline_pretty(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 6 local.set 10 local.set 9 local.get 9 local.get 10 local.get 6 call 1))",
    2U,
  )
  assert_false(pretty.contains("tuple.make"), msg=pretty)
  assert_true(
    pretty.contains(
      "(local.get (Local 13))(local.set (Local 6))(local.get (Local 12))(local.set (Local 10))(local.get (Local 11))(local.set (Local 9))(local.get (Local 9))(local.get (Local 10))(local.get (Local 6))(call (Func 1))",
    ),
    msg=pretty,
  )
}

///|
test "tuple-optimization lowered no-host exact-copy chains from materialized lanes stay scalar" {
  let fixture = tuple_optimization_test_rewrite(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.set 6 block (result i32 i32 i32) local.get 6 local.get 7 local.get 8 end local.set 5 local.set 4 local.set 3 block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 2 local.set 1 local.set 0 local.get 0 local.get 1 local.get 2 call 1))",
  )
  let lowered = @ir.ir_test_assert_verify_and_lower(fixture)
  let pretty = lowered.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(pretty.contains("tuple.make"), msg=pretty)
}

///|
test "tuple-optimization rewrite keeps overlapping exact copy groups scalar after lowering" {
  let pretty = tuple_optimization_test_pipeline_pretty(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 6 local.set 10 local.set 9 local.get 9 local.get 10 local.get 6 call 1))",
    2U,
  )
  assert_false(pretty.contains("tuple.make"), msg=pretty)
}

///|
test "tuple-optimization analysis links overlapping exact copy groups from a host tee source" {
  let analysis = tuple_optimization_test_analyze(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 6 local.set 10 local.set 9 local.get 9 local.get 10 local.get 6 call 1))",
  )

  assert_eq(analysis.groups.length(), 2)

  let source = analysis.groups[0]
  let copy = analysis.groups[1]
  assert_eq(copy.lane_locals, [9, 10, 6])
  assert_eq(copy.copy_source, Some(0))
  assert_eq(copy.copy_payload_locals, Some([8, 7, 6]))
  assert_false(copy.bad)
  assert_true(tuple_optimization_group_should_rewrite(copy))

  assert_eq(source.lane_locals, [4, 5, 6])
  assert_false(source.bad)
  assert_true(tuple_optimization_group_should_rewrite(source))
}

///|
test "tuple-optimization rewrite stages nested branch-exit source roots through scalar copyback" {
  let source =
    #|(module
    #|  (type (func (result i32 i32 i32)))
    #|  (func (type 0) (result i32 i32 i32)
    #|    (i32.const 10)
    #|    (i32.const 20)
    #|    (i32.const 30))
    #|  (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32)
    #|    (block $exit (result i32)
    #|      (if
    #|        (local.get 0)
    #|        (then
    #|          (call 0)
    #|          (local.set 4)
    #|          (local.set 3)
    #|          (local.set 2)
    #|          (local.set 7 (local.get 4))
    #|          (local.set 6 (local.get 3))
    #|          (local.set 1 (local.get 2))
    #|          (local.set 5 (local.get 7))
    #|          (local.set 0 (local.get 6))
    #|          (br $exit (local.get 5))))
    #|      (i32.const 99))))
  let optimized = match pass_test_run_pipeline(source, ["tuple-optimization"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested branch-exit tuple-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("local.set (Local 11)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 10)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 9)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 11)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 4)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 10)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 3)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 9)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 2)"), msg=pretty)
}

///|
test "tuple-optimization pipeline lowers nested scalar result spill bridges without tuple extracts" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32 i32 i32) block (result i32) block (result i32 i32 i32) i32.const 1 i32.const 2 i32.const 3 end local.set 2 local.set 1 local.set 0 local.get 0 end))",
      ["tuple-optimization"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested scalar result tuple-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("tuple.extract"), msg=pretty)
}

///|
test "tuple-optimization pipeline leaves nested no-host source copy chains scalar" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (type (func (param i32 i64) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32) block (result i32) block block local.get 0 i64.const 1 call 0 local.set 5 local.set 4 local.set 3 end local.get 5 local.set 2 local.get 4 local.set 1 end local.get 3 end))",
      ["tuple-optimization"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested no-host source copy tuple-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("tuple.make"), msg=pretty)
}

///|
test "tuple-optimization pipeline lowers host local.tee scalar result bridges without tuple extracts" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (type (func (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32) block (result i32) call 0 local.set 2 local.set 1 local.tee 0 end))",
      ["tuple-optimization"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected host local.tee tuple-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("tuple.extract"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
}

///|
test "tuple-optimization analysis accepts one-hop scalar forwarding bridges" {
  let analysis = tuple_optimization_test_analyze(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"trim\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.set 4 local.get 6 local.set 0 local.get 5 local.set 1 local.get 4 local.tee 3 local.get 1 local.get 0 call 1 local.set 2 local.get 2))",
  )

  assert_eq(analysis.groups.length(), 2)

  let source = analysis.groups[0]
  assert_eq(source.lane_locals, [4, 5, 6])
  assert_eq(source.copy_source, None)
  assert_eq(source.uses, 2)
  assert_eq(source.valid_uses, 2)
  assert_false(source.bad)
  assert_true(tuple_optimization_group_should_rewrite(source))

  let copy = analysis.groups[1]
  assert_eq(copy.lane_locals, [3, 1, 0])
  assert_eq(copy.copy_source, Some(0))
  assert_eq(copy.uses, 3)
  assert_eq(copy.valid_uses, 3)
  assert_eq(tuple_optimization_group_host_lane(copy), Some(0))
  assert_false(copy.bad)
  assert_true(tuple_optimization_group_should_rewrite(copy))
}

///|
test "tuple-optimization leaves terminal two-hop scalar forwarding copy groups hostless" {
  let analysis = tuple_optimization_test_analyze(
    "(module (type (func (param i64 i64) (result i64 i64))) (import \"env\" \"pair\" (func (type 0))) (func (param i64 i64) (result i64 i64) (local i64 i64 i64 i64 i64 i64) block local.get 0 local.get 1 call 0 local.set 3 local.set 2 local.get 3 local.set 5 end local.get 2 local.tee 4 local.set 6 local.get 5 local.set 7 local.get 6 local.get 7))",
  )

  assert_eq(analysis.groups.length(), 2)

  let source = analysis.groups[0]
  assert_eq(source.lane_locals, [2, 3])
  assert_eq(source.copy_source, None)
  assert_true(tuple_optimization_group_should_rewrite(source))

  let copy = analysis.groups[1]
  assert_eq(copy.lane_locals, [4, 5])
  assert_eq(copy.copy_source, Some(0))
  assert_eq(tuple_optimization_group_host_lane(copy), None)
  assert_false(tuple_optimization_group_should_rewrite(copy))
}

///|
test "tuple-optimization keeps terminal two-hop scalar forwarding copy groups with one live host lane rewriteable" {
  let analysis = tuple_optimization_test_analyze(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.set 6 local.get 7 local.set 5 local.get 8 local.set 4 local.get 6 local.set 3 block (result i32 i32 i32) local.get 3 local.get 5 local.get 4 end local.set 2 local.set 1 local.tee 0 local.get 1 drop local.get 2 drop))",
  )

  assert_eq(analysis.groups.length(), 2)

  let source = analysis.groups[0]
  assert_eq(source.lane_locals, [6, 7, 8])
  assert_true(tuple_optimization_group_should_rewrite(source))

  let terminal = analysis.groups[1]
  assert_eq(terminal.lane_locals, [0, 1, 2])
  assert_eq(terminal.copy_source, Some(0))
  assert_eq(tuple_optimization_group_host_lane(terminal), Some(0))
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.set 6 local.get 7 local.set 5 local.get 8 local.set 4 local.get 6 local.set 3 block (result i32 i32 i32) local.get 3 local.get 5 local.get 4 end local.set 2 local.set 1 local.tee 0 local.get 1 drop local.get 2 drop))",
  )
  let use_def = @ir.use_def_build(fixture.hot_func)
  assert_true(
    tuple_optimization_group_should_rewrite_in_func(
      fixture.hot_func,
      use_def,
      analysis.groups,
      1,
    ),
  )
}

///|
test "tuple-optimization keeps terminal drop-only no-host exact copy groups rewriteable" {
  let analysis = tuple_optimization_test_analyze(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.set 6 block (result i32 i32 i32) local.get 6 local.get 7 local.get 8 end local.set 2 local.set 1 local.set 0 local.get 1 drop local.get 2 drop local.get 0))",
  )

  assert_eq(analysis.groups.length(), 2)

  let source = analysis.groups[0]
  assert_eq(source.lane_locals, [6, 7, 8])
  assert_true(tuple_optimization_group_should_rewrite(source))

  let terminal = analysis.groups[1]
  assert_eq(terminal.lane_locals, [0, 1, 2])
  assert_eq(terminal.copy_source, Some(0))
  assert_eq(tuple_optimization_group_host_lane(terminal), None)
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.set 6 block (result i32 i32 i32) local.get 6 local.get 7 local.get 8 end local.set 2 local.set 1 local.set 0 local.get 1 drop local.get 2 drop local.get 0))",
  )
  let use_def = @ir.use_def_build(fixture.hot_func)
  assert_true(
    tuple_optimization_group_should_rewrite_in_func(
      fixture.hot_func,
      use_def,
      analysis.groups,
      1,
    ),
  )
}

///|
test "tuple-optimization keeps chained terminal drop-only no-host exact copy groups rewriteable" {
  let analysis = tuple_optimization_test_analyze(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.set 6 block (result i32 i32 i32) local.get 6 local.get 7 local.get 8 end local.set 5 local.set 4 local.set 3 block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 2 local.set 1 local.set 0 local.get 1 drop local.get 2 drop local.get 0))",
  )

  assert_eq(analysis.groups.length(), 3)

  let source = analysis.groups[0]
  assert_eq(source.lane_locals, [6, 7, 8])
  assert_true(tuple_optimization_group_should_rewrite(source))

  let first = analysis.groups[1]
  assert_eq(first.lane_locals, [3, 4, 5])
  assert_eq(first.copy_source, Some(0))
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.set 6 block (result i32 i32 i32) local.get 6 local.get 7 local.get 8 end local.set 5 local.set 4 local.set 3 block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 2 local.set 1 local.set 0 local.get 1 drop local.get 2 drop local.get 0))",
  )
  let use_def = @ir.use_def_build(fixture.hot_func)
  assert_true(
    tuple_optimization_group_should_rewrite_in_func(
      fixture.hot_func,
      use_def,
      analysis.groups,
      1,
    ),
  )

  let terminal = analysis.groups[2]
  assert_eq(terminal.lane_locals, [0, 1, 2])
  assert_eq(terminal.copy_source, Some(1))
  assert_eq(tuple_optimization_group_host_lane(terminal), None)
  assert_true(
    tuple_optimization_group_should_rewrite_in_func(
      fixture.hot_func,
      use_def,
      analysis.groups,
      2,
    ),
  )
}

///|
test "tuple-optimization pipeline rewrites one-hop scalar forwarding bridges" {
  let source = "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"trim\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.set 4 local.get 6 local.set 0 local.get 5 local.set 1 local.get 4 local.tee 3 local.get 1 local.get 0 call 1 local.set 2 local.get 2))"
  let input_mod = pass_test_module_from_wat(source)
  let optimized = match pass_test_run_pipeline(source, ["tuple-optimization"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected one-hop scalar forwarding tuple-optimization success, got \{err}",
      )
  }

  assert_not_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
    input_mod.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
}

///|
test "tuple-optimization rewrite keeps a typed source host carrier on raw decoded one-hop input" {
  let fixture = tuple_optimization_test_rewrite(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"trim\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 9 local.set 8 local.tee 7 local.set 11 local.get 8 local.set 10 local.get 9 local.set 6 local.get 10 local.set 5 local.get 11 local.set 4 local.get 6 local.set 0 local.get 5 local.set 1 local.get 4 local.tee 3 local.get 1 local.get 0 call 1 local.set 2 local.get 2))",
  )
  let func = fixture.hot_func

  let mut saw_typed_source_host = false
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    if node.op.to_string() != "LocalTee" ||
      @ir.hot_child_count(func, node_id) != 1 {
      continue
    }
    let source_value = @ir.hot_child_get(func, node_id, 0)
    if @ir.hot_node_get(func, source_value).op.to_string() == "Block" &&
      @ir.hot_node_result_arity(func, source_value) == 1 {
      saw_typed_source_host = true
      break
    }
  }
  assert_true(saw_typed_source_host)
}

///|
test "tuple-optimization rewrite avoids redundant tuple.make carriers in chained host-copy tail-live0 rewrites" {
  let fixture = tuple_optimization_test_rewrite(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.tee 6 local.set 11 local.get 7 local.set 10 block (result i32 i32 i32) local.get 11 local.get 10 local.get 8 end local.set 5 local.set 4 local.tee 3 block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 2 local.set 1 local.tee 0 drop drop local.get 0))",
  )
  let func = fixture.hot_func
  let mut tuple_make_count = 0
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    if node.op.to_string() == "TupleMake" {
      tuple_make_count = tuple_make_count + 1
    }
  }
  assert_eq(tuple_make_count, 0)
}

///|
test "tuple-optimization lowered chained host-copy tail-live0 keeps downstream host tees" {
  let fixture = tuple_optimization_test_rewrite(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.tee 6 local.set 11 local.get 7 local.set 10 block (result i32 i32 i32) local.get 11 local.get 10 local.get 8 end local.set 5 local.set 4 local.tee 3 block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 2 local.set 1 local.tee 0 drop drop local.get 0))",
  )
  let lowered = @ir.ir_test_assert_verify_and_lower(fixture)
  let pretty = lowered.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("local.tee (Local 12)"), msg=pretty)
  assert_true(pretty.contains("local.tee (Local 3)"), msg=pretty)
  assert_true(pretty.contains("local.tee (Local 15)"), msg=pretty)
  assert_true(pretty.contains("local.tee (Local 0)"), msg=pretty)
}

///|
test "tuple-optimization analysis keeps chained host-copy tail-live0 copy groups rewriteable" {
  let source = "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.tee 6 local.set 11 local.get 7 local.set 10 block (result i32 i32 i32) local.get 11 local.get 10 local.get 8 end local.set 5 local.set 4 local.tee 3 block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 2 local.set 1 local.tee 0 drop drop local.get 0))"
  let analysis = tuple_optimization_test_analyze(source)
  assert_eq(analysis.groups.length(), 3)

  let fixture = @ir.ir_test_build_hot_from_wat(source)
  let use_def = @ir.use_def_build(fixture.hot_func)
  assert_true(
    tuple_optimization_group_should_rewrite_in_func(
      fixture.hot_func,
      use_def,
      analysis.groups,
      0,
    ),
  )
  assert_true(
    tuple_optimization_group_should_rewrite_in_func(
      fixture.hot_func,
      use_def,
      analysis.groups,
      1,
    ),
  )
  assert_true(
    tuple_optimization_group_should_rewrite_in_func(
      fixture.hot_func,
      use_def,
      analysis.groups,
      2,
    ),
  )
}

///|
test "tuple-optimization analysis keeps chained host-copy tail-live0 copy groups rewriteable after binary decode" {
  let source = "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.tee 6 local.set 11 local.get 7 local.set 10 block (result i32 i32 i32) local.get 11 local.get 10 local.get 8 end local.set 5 local.set 4 local.tee 3 block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 2 local.set 1 local.tee 0 drop drop local.get 0))"
  let analysis = tuple_optimization_test_analyze_via_binary(source, 1U)
  assert_eq(analysis.groups.length(), 3)

  let mod_ = pass_test_module_from_wat(source)
  let encoded = match @binary.encode_module(mod_) {
    Ok(bytes) => bytes
    Err(err) =>
      abort(
        "unexpected tuple-optimization via-binary suppression fixture encode failure: \{err}",
      )
  }
  let decoded = match @binary.decode_module(encoded) {
    Ok(decoded) => decoded
    Err(err) =>
      abort(
        "unexpected tuple-optimization via-binary suppression fixture decode failure: \{err}",
      )
  }
  let hot_func = @ir.hot_lift_func(decoded, @lib.FuncIdx::new(1U))
  let use_def = @ir.use_def_build(hot_func)
  assert_true(
    tuple_optimization_group_should_rewrite_in_func(
      hot_func,
      use_def,
      analysis.groups,
      0,
    ),
  )
  assert_true(
    tuple_optimization_group_should_rewrite_in_func(
      hot_func,
      use_def,
      analysis.groups,
      1,
    ),
  )
  assert_true(
    tuple_optimization_group_should_rewrite_in_func(
      hot_func,
      use_def,
      analysis.groups,
      2,
    ),
  )
}

///|
test "tuple-optimization analysis links mixed scalar-forward bridges from direct producers" {
  let analysis = tuple_optimization_test_analyze(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 local.get 8 local.get 7 local.get 6 call 1 local.set 0 local.get 0))",
  )

  assert_eq(analysis.groups.length(), 2)

  let source = analysis.groups[0]
  assert_eq(source.lane_locals, [4, 5, 6])
  assert_true(tuple_optimization_group_should_rewrite(source))

  let copy = analysis.groups[1]
  assert_eq(copy.lane_locals, [8, 7, 6])
  assert_eq(copy.copy_source, Some(0))
  assert_eq(tuple_optimization_group_host_lane(copy), Some(0))
  assert_true(tuple_optimization_group_should_rewrite(copy))
}

///|
test "tuple-optimization pipeline rewrites mixed scalar-forward bridges from direct producers" {
  let source = "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 local.get 8 local.get 7 local.get 6 call 1 local.set 0 local.get 0))"
  let input_mod = pass_test_module_from_wat(source)
  let optimized = match pass_test_run_pipeline(source, ["tuple-optimization"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected mixed scalar-forward tuple-optimization success, got \{err}",
      )
  }

  assert_not_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
    input_mod.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
}

///|
test "tuple-optimization analysis links chained mixed scalar-forward bridges" {
  let analysis = tuple_optimization_test_analyze(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 local.get 7 local.set 9 local.get 8 local.get 9 local.get 6 call 1 local.set 0 local.get 0))",
  )

  assert_eq(analysis.groups.length(), 3)

  let source = analysis.groups[0]
  assert_eq(source.lane_locals, [4, 5, 6])
  assert_true(tuple_optimization_group_should_rewrite(source))

  let first = analysis.groups[1]
  assert_eq(first.lane_locals, [8, 7, 6])
  assert_eq(first.copy_source, Some(0))
  assert_eq(tuple_optimization_group_host_lane(first), Some(0))
  assert_false(tuple_optimization_group_should_rewrite(first))

  let second = analysis.groups[2]
  assert_eq(second.lane_locals, [8, 9, 6])
  assert_eq(second.copy_source, Some(1))
  assert_eq(tuple_optimization_group_host_lane(second), Some(0))
  assert_true(tuple_optimization_group_should_rewrite(second))
}

///|
test "tuple-optimization pipeline rewrites chained mixed scalar-forward bridges" {
  let source = "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 local.get 7 local.set 9 local.get 8 local.get 9 local.get 6 call 1 local.set 0 local.get 0))"
  let input_mod = pass_test_module_from_wat(source)
  let optimized = match pass_test_run_pipeline(source, ["tuple-optimization"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected chained scalar-forward tuple-optimization success, got \{err}",
      )
  }

  assert_not_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
    input_mod.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
}
