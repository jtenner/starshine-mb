///|
fn tuple_optimization_test_analyze(
  text : String,
) -> HotTupleOptimizationAnalysis {
  let fixture = @ir.ir_test_build_hot_from_wat(text)
  let use_def = @ir.use_def_build(fixture.hot_func)
  tuple_optimization_analyze(fixture.hot_func, use_def)
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
fn tuple_optimization_assert_tuple_make_root_carrier(
  func : @ir.HotFunc,
  carrier_local : Int,
  expected_local_count : Int,
  remat_lane_locals : Array[Int],
  source_lane_locals : Array[Int],
) -> Unit {
  if @ir.hot_local_count(func) != expected_local_count {
    abort(
      "unexpected local count for tuple.make root carrier \{carrier_local}: \{@ir.hot_local_count(func)} vs \{expected_local_count}",
    )
  }

  let mut copy_root = -1
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    let root = @ir.hot_root_get(func, root_idx)
    if @ir.hot_node_get(func, root).op.to_string() == "LocalSet" &&
      @ir.hot_node_get(func, root).imm0 == carrier_local {
      copy_root = root
      break
    }
  }
  if copy_root < 0 {
    abort(
      "expected rewritten tuple.make root carrier for local \{carrier_local}",
    )
  }

  let copy_value = @ir.hot_child_get(func, copy_root, 0)
  if @ir.hot_node_get(func, copy_value).op.to_string() != "Block" ||
    @ir.hot_node_result_arity(func, copy_value) != 1 {
    abort(
      "expected tuple.make root carrier \{carrier_local} to wrap a typed block",
    )
  }

  let copy_body = @ir.hot_region_body_ref(func, copy_value)
  if @ir.hot_region_root_count(func, copy_body) != 3 {
    abort(
      "expected tuple.make root carrier \{carrier_local} to keep exactly three body roots",
    )
  }

  let lane2 = @ir.hot_region_get(func, copy_body, 0)
  let lane1 = @ir.hot_region_get(func, copy_body, 1)
  let lane0 = @ir.hot_region_get(func, copy_body, 2)
  if @ir.hot_node_get(func, lane2).op.to_string() != "LocalSet" ||
    @ir.hot_node_get(func, lane2).imm0 != remat_lane_locals[2] {
    abort("expected tuple.make root carrier \{carrier_local} lane2 remat")
  }
  if @ir.hot_node_get(func, lane1).op.to_string() != "LocalSet" ||
    @ir.hot_node_get(func, lane1).imm0 != remat_lane_locals[1] {
    abort("expected tuple.make root carrier \{carrier_local} lane1 remat")
  }

  let lane2_value = @ir.hot_child_get(func, lane2, 0)
  let lane1_value = @ir.hot_child_get(func, lane1, 0)
  if @ir.hot_node_get(func, lane2_value).op.to_string() != "TupleMake" ||
    @ir.hot_node_get(func, lane1_value).op.to_string() != "TupleMake" ||
    @ir.hot_node_get(func, lane0).op.to_string() != "TupleMake" {
    abort(
      "expected tuple.make root carrier \{carrier_local} to share a synthetic producer",
    )
  }
  if lane2_value != lane1_value || lane1_value != lane0 {
    abort(
      "expected tuple.make root carrier \{carrier_local} to reuse one producer node",
    )
  }
  if @ir.hot_node_result_arity(func, lane0) != source_lane_locals.length() ||
    @ir.hot_child_count(func, lane0) != source_lane_locals.length() {
    abort(
      "expected tuple.make root carrier \{carrier_local} to preserve source arity",
    )
  }
  for lane_idx = 0
      lane_idx < source_lane_locals.length()
      lane_idx = lane_idx + 1 {
    let child = @ir.hot_child_get(func, lane0, lane_idx)
    if @ir.hot_node_get(func, child).op.to_string() != "LocalGet" ||
      @ir.hot_node_get(func, child).imm0 != source_lane_locals[lane_idx] {
      abort(
        "expected tuple.make root carrier \{carrier_local} child \{lane_idx} to read source lane \{source_lane_locals[lane_idx]}",
      )
    }
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
test "tuple-optimization rewrite forwards good copy groups through original source lanes" {
  let fixture = tuple_optimization_test_rewrite(
    "(module (func (result i32) (local i32 i32 i32 i32 i32 i32) block (result i32 i32 i32) i32.const 1 i32.const 2 i32.const 3 end local.set 2 local.set 1 local.set 0 block (result i32 i32 i32) local.get 0 local.get 1 local.get 2 end local.set 5 local.set 4 local.set 3 local.get 3))",
  )
  let func = fixture.hot_func

  assert_eq(@ir.hot_local_count(func), 6)

  let source_bridge = @ir.hot_root_get(func, 0)
  assert_eq(@ir.hot_node_get(func, source_bridge).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, source_bridge).imm0, 0)
  let source_value = @ir.hot_child_get(func, source_bridge, 0)
  assert_eq(@ir.hot_node_get(func, source_value).op.to_string(), "Block")
  let source_body = @ir.hot_region_body_ref(func, source_value)
  assert_eq(@ir.hot_region_root_count(func, source_body), 3)
  let source_lane2 = @ir.hot_region_get(func, source_body, 0)
  let source_lane1 = @ir.hot_region_get(func, source_body, 1)
  let source_lane0 = @ir.hot_region_get(func, source_body, 2)
  assert_eq(@ir.hot_node_get(func, source_lane2).imm0, 2)
  assert_eq(@ir.hot_node_get(func, source_lane1).imm0, 1)
  assert_eq(@ir.hot_node_get(func, source_lane0).op.to_string(), "Block")

  assert_eq(@ir.hot_root_count(func), 3)

  let copy_bridge = @ir.hot_root_get(func, 1)
  assert_eq(@ir.hot_node_get(func, copy_bridge).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, copy_bridge).imm0, 3)
  let copy_value = @ir.hot_child_get(func, copy_bridge, 0)
  assert_eq(@ir.hot_node_get(func, copy_value).op.to_string(), "Block")
  let copy_body = @ir.hot_region_body_ref(func, copy_value)
  assert_eq(@ir.hot_region_root_count(func, copy_body), 3)
  let copy_lane2 = @ir.hot_region_get(func, copy_body, 0)
  let copy_lane1 = @ir.hot_region_get(func, copy_body, 1)
  let copy_lane0 = @ir.hot_region_get(func, copy_body, 2)
  assert_eq(@ir.hot_node_get(func, copy_lane2).imm0, 5)
  assert_eq(@ir.hot_node_get(func, copy_lane1).imm0, 4)
  assert_eq(@ir.hot_node_get(func, copy_lane0).op.to_string(), "LocalGet")
  assert_eq(@ir.hot_node_get(func, copy_lane0).imm0, 0)

  let copy_read2 = @ir.hot_child_get(func, copy_lane2, 0)
  let copy_read1 = @ir.hot_child_get(func, copy_lane1, 0)
  assert_eq(@ir.hot_node_get(func, copy_read2).op.to_string(), "LocalGet")
  assert_eq(@ir.hot_node_get(func, copy_read2).imm0, 2)
  assert_eq(@ir.hot_node_get(func, copy_read1).op.to_string(), "LocalGet")
  assert_eq(@ir.hot_node_get(func, copy_read1).imm0, 1)

  let old_copy_producer = tuple_optimization_test_analyze(
      "(module (func (result i32) (local i32 i32 i32 i32 i32 i32) block (result i32 i32 i32) i32.const 1 i32.const 2 i32.const 3 end local.set 2 local.set 1 local.set 0 block (result i32 i32 i32) local.get 0 local.get 1 local.get 2 end local.set 5 local.set 4 local.set 3 local.get 3))",
    ).groups[1].producer
  assert_true(@ir.hot_node_is_live(func, old_copy_producer))
  assert_eq(@ir.hot_node_get(func, old_copy_producer).op.to_string(), "Block")
  assert_eq(@ir.hot_node_result_arity(func, old_copy_producer), 0)
  assert_eq(
    @ir.hot_region_root_count(
      func,
      @ir.hot_region_body_ref(func, old_copy_producer),
    ),
    0,
  )

  let forwarded = @ir.hot_root_get(func, 2)
  assert_eq(@ir.hot_node_get(func, forwarded).op.to_string(), "LocalGet")
  assert_eq(@ir.hot_node_get(func, forwarded).imm0, 3)

  let use_def = @ir.use_def_build(func)
  tuple_optimization_assert_local_traffic(use_def, 0, 1, 1)
  tuple_optimization_assert_local_traffic(use_def, 1, 1, 1)
  tuple_optimization_assert_local_traffic(use_def, 2, 1, 1)
  tuple_optimization_assert_local_traffic(use_def, 3, 1, 1)
  tuple_optimization_assert_local_traffic(use_def, 4, 1, 0)
  tuple_optimization_assert_local_traffic(use_def, 5, 1, 0)
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
test "tuple-optimization rewrite reuses original lanes through a root local.set host chain" {
  let fixture = tuple_optimization_test_rewrite(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"trim\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 local.get 6 local.set 3 local.get 7 local.set 2 local.get 8 local.tee 1 local.get 2 local.get 3 call 1 local.set 0 local.get 0))",
  )
  let func = fixture.hot_func

  assert_eq(@ir.hot_local_count(func), 9)

  let source_root = @ir.hot_root_get(func, 0)
  assert_eq(@ir.hot_node_get(func, source_root).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, source_root).imm0, 8)

  let source_host = @ir.hot_child_get(func, source_root, 0)
  assert_eq(@ir.hot_node_get(func, source_host).op.to_string(), "LocalTee")
  assert_eq(@ir.hot_node_get(func, source_host).imm0, 4)

  let source_block = @ir.hot_child_get(func, source_host, 0)
  assert_eq(@ir.hot_node_get(func, source_block).op.to_string(), "Block")

  let source_body = @ir.hot_region_body_ref(func, source_block)
  assert_eq(@ir.hot_region_root_count(func, source_body), 3)

  let lane2 = @ir.hot_region_get(func, source_body, 0)
  let lane1 = @ir.hot_region_get(func, source_body, 1)
  let lane0 = @ir.hot_region_get(func, source_body, 2)
  assert_eq(@ir.hot_node_get(func, lane2).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, lane2).imm0, 6)
  assert_eq(@ir.hot_node_get(func, lane1).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, lane1).imm0, 5)
  assert_eq(@ir.hot_node_get(func, lane0).op.to_string(), "Call")
}

///|
test "tuple-optimization rewrite carries exact copy groups through a root local.set lane" {
  let fixture = tuple_optimization_test_rewrite(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 2 local.set 1 local.set 0 local.get 0 local.get 1 local.get 2 call 1 local.set 9 local.get 9))",
  )
  let func = fixture.hot_func

  let mut copy_root = -1
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    let root = @ir.hot_root_get(func, root_idx)
    if @ir.hot_node_get(func, root).op.to_string() == "LocalSet" &&
      @ir.hot_node_get(func, root).imm0 == 0 {
      copy_root = root
      break
    }
  }
  if copy_root < 0 {
    abort("expected rewritten exact copy root carrier for local 0")
  }
  assert_eq(@ir.hot_node_get(func, copy_root).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, copy_root).imm0, 0)

  let copy_value = @ir.hot_child_get(func, copy_root, 0)
  assert_eq(@ir.hot_node_get(func, copy_value).op.to_string(), "Block")
  assert_eq(@ir.hot_node_result_arity(func, copy_value), 1)

  let copy_body = @ir.hot_region_body_ref(func, copy_value)
  assert_eq(@ir.hot_region_root_count(func, copy_body), 3)

  let lane2 = @ir.hot_region_get(func, copy_body, 0)
  let lane1 = @ir.hot_region_get(func, copy_body, 1)
  let lane0 = @ir.hot_region_get(func, copy_body, 2)
  assert_eq(@ir.hot_node_get(func, lane2).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, lane2).imm0, 2)
  assert_eq(@ir.hot_node_get(func, lane1).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, lane1).imm0, 1)
  assert_eq(@ir.hot_node_get(func, lane0).op.to_string(), "TupleMake")
  assert_true(@ir.hot_node_result_arity(func, lane0) > 1)
}

///|
test "tuple-optimization rewrite scalarizes single-use exact copy groups from a host tee source" {
  let fixture = tuple_optimization_test_rewrite(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 11 local.set 9 local.set 10 local.get 9 local.get 10 local.get 11 call 1))",
  )
  tuple_optimization_assert_tuple_make_root_carrier(
    fixture.hot_func,
    10,
    12,
    [10, 9, 11],
    [8, 7, 6],
  )
}

///|
test "tuple-optimization rewrite stages lane-ordered scrambled exact copy groups through a synthetic tuple.make carrier" {
  let fixture = tuple_optimization_test_rewrite(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 11 local.set 9 local.set 10 local.get 10 local.get 9 local.get 11 call 1))",
  )
  tuple_optimization_assert_tuple_make_root_carrier(
    fixture.hot_func,
    10,
    12,
    [10, 9, 11],
    [8, 7, 6],
  )
}

///|
test "tuple-optimization rewrite scalarizes overlapping exact copy groups from a host tee source" {
  let fixture = tuple_optimization_test_rewrite(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 6 local.set 10 local.set 9 local.get 9 local.get 10 local.get 6 call 1))",
  )
  tuple_optimization_assert_tuple_make_root_carrier(
    fixture.hot_func,
    9,
    11,
    [9, 10, 6],
    [8, 7, 6],
  )
}

///|
test "tuple-optimization rewrite stages overlapping exact copy groups through a synthetic tuple.make carrier" {
  let fixture = tuple_optimization_test_rewrite(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 6 local.set 10 local.set 9 local.get 9 local.get 10 local.get 6 call 1))",
  )
  tuple_optimization_assert_tuple_make_root_carrier(
    fixture.hot_func,
    9,
    11,
    [9, 10, 6],
    [8, 7, 6],
  )
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
test "tuple-optimization rewrite stages nested branch-exit source roots through a tuple carrier" {
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
  assert_true(
    pretty.contains(
      "(call (Func 0))(local.set (Local 11))(local.set (Local 10))(local.set (Local 9))(block I32 (block (Type 0) (local.get (Local 9))(local.get (Local 10))(local.get (Local 11))(end))(local.set (Local 4))(local.set (Local 3))(end))(local.set (Local 2))",
    ),
    msg=pretty,
  )
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
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    let root = @ir.hot_root_get(func, root_idx)
    let node = @ir.hot_node_get(func, root)
    let child = if @ir.hot_child_count(func, root) > 0 {
      Some(@ir.hot_child_get(func, root, 0))
    } else {
      None
    }
    match child {
      Some(source_value) => {
        let direct_block = @ir.hot_node_get(func, source_value).op.to_string() ==
          "Block" &&
          @ir.hot_node_result_arity(func, source_value) == 1
        let wrapped_block = @ir.hot_node_get(func, source_value).op.to_string() ==
          "LocalTee" &&
          @ir.hot_child_count(func, source_value) == 1 &&
          @ir.hot_node_get(func, @ir.hot_child_get(func, source_value, 0)).op.to_string() ==
          "Block" &&
          @ir.hot_node_result_arity(
            func,
            @ir.hot_child_get(func, source_value, 0),
          ) ==
          1
        if (
            node.op.to_string() == "LocalSet" ||
            node.op.to_string() == "LocalTee"
          ) &&
          (direct_block || wrapped_block) {
          saw_typed_source_host = true
        }
      }
      None => ()
    }
  }
  assert_true(saw_typed_source_host)
}
