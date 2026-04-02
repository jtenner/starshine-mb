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
test "tuple-optimization rewrite lowers a direct spill bridge to fresh scalar lanes" {
  let fixture = tuple_optimization_test_rewrite(
    "(module (func (result i32) (local i32 i32 i32) block (result i32 i32 i32) i32.const 10 i32.const 20 i32.const 30 end local.set 2 local.set 1 local.set 0 local.get 0))",
  )
  let func = fixture.hot_func

  assert_eq(@ir.hot_local_count(func), 6)

  let bridge = @ir.hot_root_get(func, 0)
  assert_eq(@ir.hot_node_get(func, bridge).op.to_string(), "Block")
  assert_eq(@ir.hot_node_result_arity(func, bridge), 0)

  let body_ref = @ir.hot_region_body_ref(func, bridge)
  assert_eq(@ir.hot_region_root_count(func, body_ref), 3)
  let split2 = @ir.hot_region_get(func, body_ref, 0)
  let split1 = @ir.hot_region_get(func, body_ref, 1)
  let split0 = @ir.hot_region_get(func, body_ref, 2)
  assert_eq(@ir.hot_node_get(func, split2).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, split2).imm0, 5)
  assert_eq(@ir.hot_node_get(func, split1).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, split1).imm0, 4)
  assert_eq(@ir.hot_node_get(func, split0).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, split0).imm0, 3)

  let producer = @ir.hot_child_get(func, split2, 0)
  assert_eq(@ir.hot_child_get(func, split1, 0), producer)
  assert_eq(@ir.hot_child_get(func, split0, 0), producer)

  assert_eq(
    @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).op.to_string(),
    "Nop",
  )
  assert_eq(
    @ir.hot_node_get(func, @ir.hot_root_get(func, 2)).op.to_string(),
    "Nop",
  )
  let forwarded = @ir.hot_root_get(func, 3)
  assert_eq(@ir.hot_node_get(func, forwarded).op.to_string(), "LocalGet")
  assert_eq(@ir.hot_node_get(func, forwarded).imm0, 3)

  let use_def = @ir.use_def_build(func)
  tuple_optimization_assert_local_traffic(use_def, 0, 0, 0)
  tuple_optimization_assert_local_traffic(use_def, 1, 0, 0)
  tuple_optimization_assert_local_traffic(use_def, 2, 0, 0)
  tuple_optimization_assert_local_traffic(use_def, 3, 1, 1)
  tuple_optimization_assert_local_traffic(use_def, 4, 1, 0)
  tuple_optimization_assert_local_traffic(use_def, 5, 1, 0)
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
test "tuple-optimization rewrite forwards good copy groups through split source lanes" {
  let fixture = tuple_optimization_test_rewrite(
    "(module (func (result i32) (local i32 i32 i32 i32 i32 i32) block (result i32 i32 i32) i32.const 1 i32.const 2 i32.const 3 end local.set 2 local.set 1 local.set 0 block (result i32 i32 i32) local.get 0 local.get 1 local.get 2 end local.set 5 local.set 4 local.set 3 local.get 3))",
  )
  let func = fixture.hot_func

  assert_eq(@ir.hot_local_count(func), 12)

  let source_bridge = @ir.hot_root_get(func, 0)
  assert_eq(@ir.hot_node_get(func, source_bridge).op.to_string(), "Block")
  let source_body = @ir.hot_region_body_ref(func, source_bridge)
  let source_set2 = @ir.hot_region_get(func, source_body, 0)
  let source_set1 = @ir.hot_region_get(func, source_body, 1)
  let source_set0 = @ir.hot_region_get(func, source_body, 2)
  assert_eq(@ir.hot_node_get(func, source_set2).imm0, 8)
  assert_eq(@ir.hot_node_get(func, source_set1).imm0, 7)
  assert_eq(@ir.hot_node_get(func, source_set0).imm0, 6)

  let copy_bridge = @ir.hot_root_get(func, 3)
  assert_eq(@ir.hot_node_get(func, copy_bridge).op.to_string(), "Block")
  let copy_body = @ir.hot_region_body_ref(func, copy_bridge)
  let copy_set2 = @ir.hot_region_get(func, copy_body, 0)
  let copy_set1 = @ir.hot_region_get(func, copy_body, 1)
  let copy_set0 = @ir.hot_region_get(func, copy_body, 2)
  assert_eq(@ir.hot_node_get(func, copy_set2).imm0, 11)
  assert_eq(@ir.hot_node_get(func, copy_set1).imm0, 10)
  assert_eq(@ir.hot_node_get(func, copy_set0).imm0, 9)

  let copy_read2 = @ir.hot_child_get(func, copy_set2, 0)
  let copy_read1 = @ir.hot_child_get(func, copy_set1, 0)
  let copy_read0 = @ir.hot_child_get(func, copy_set0, 0)
  assert_eq(@ir.hot_node_get(func, copy_read2).op.to_string(), "LocalGet")
  assert_eq(@ir.hot_node_get(func, copy_read2).imm0, 8)
  assert_eq(@ir.hot_node_get(func, copy_read1).op.to_string(), "LocalGet")
  assert_eq(@ir.hot_node_get(func, copy_read1).imm0, 7)
  assert_eq(@ir.hot_node_get(func, copy_read0).op.to_string(), "LocalGet")
  assert_eq(@ir.hot_node_get(func, copy_read0).imm0, 6)

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

  let forwarded = @ir.hot_root_get(func, 6)
  assert_eq(@ir.hot_node_get(func, forwarded).op.to_string(), "LocalGet")
  assert_eq(@ir.hot_node_get(func, forwarded).imm0, 9)

  let use_def = @ir.use_def_build(func)
  for local_id = 0; local_id < 6; local_id = local_id + 1 {
    tuple_optimization_assert_local_traffic(use_def, local_id, 0, 0)
  }
  tuple_optimization_assert_local_traffic(use_def, 6, 1, 1)
  tuple_optimization_assert_local_traffic(use_def, 7, 1, 1)
  tuple_optimization_assert_local_traffic(use_def, 8, 1, 1)
  tuple_optimization_assert_local_traffic(use_def, 9, 1, 1)
  tuple_optimization_assert_local_traffic(use_def, 10, 1, 0)
  tuple_optimization_assert_local_traffic(use_def, 11, 1, 0)
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
  let fixture = tuple_optimization_test_rewrite(
    "(module (func (local i32 i32) block (result i32 i32) i32.const 1 i32.const 2 end local.tee 1 drop local.set 0 local.get 0 drop))",
  )
  let func = fixture.hot_func

  assert_eq(@ir.hot_local_count(func), 4)

  let first_drop = @ir.hot_root_get(func, 0)
  assert_eq(@ir.hot_node_get(func, first_drop).op.to_string(), "Drop")
  let scalar_block = @ir.hot_child_get(func, first_drop, 0)
  assert_eq(@ir.hot_node_get(func, scalar_block).op.to_string(), "Block")
  assert_eq(@ir.hot_node_result_arity(func, scalar_block), 1)

  let block_body = @ir.hot_region_body_ref(func, scalar_block)
  assert_eq(@ir.hot_region_root_count(func, block_body), 3)
  let split1 = @ir.hot_region_get(func, block_body, 0)
  let split0 = @ir.hot_region_get(func, block_body, 1)
  let yielded = @ir.hot_region_get(func, block_body, 2)
  assert_eq(@ir.hot_node_get(func, split1).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, split1).imm0, 3)
  assert_eq(@ir.hot_node_get(func, split0).op.to_string(), "LocalSet")
  assert_eq(@ir.hot_node_get(func, split0).imm0, 2)
  assert_eq(@ir.hot_node_get(func, yielded).op.to_string(), "LocalGet")
  assert_eq(@ir.hot_node_get(func, yielded).imm0, 3)

  assert_eq(
    @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).op.to_string(),
    "Nop",
  )
  let second_drop = @ir.hot_root_get(func, 2)
  assert_eq(@ir.hot_node_get(func, second_drop).op.to_string(), "Drop")
  let forwarded = @ir.hot_child_get(func, second_drop, 0)
  assert_eq(@ir.hot_node_get(func, forwarded).op.to_string(), "LocalGet")
  assert_eq(@ir.hot_node_get(func, forwarded).imm0, 2)

  let use_def = @ir.use_def_build(func)
  tuple_optimization_assert_local_traffic(use_def, 0, 0, 0)
  tuple_optimization_assert_local_traffic(use_def, 1, 0, 0)
  tuple_optimization_assert_local_traffic(use_def, 2, 1, 1)
  tuple_optimization_assert_local_traffic(use_def, 3, 1, 1)
}
