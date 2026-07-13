///|
fn flatten_test_classify(text : String) -> FlattenFlatnessReport {
  flatten_classify_hot(pass_test_lift_first_func(text))
}

///|
test "flatten classifier accepts explicit returns with simple operands" {
  let report = flatten_test_classify(
    "(module (func (param i32) (result i32) local.get 0 return))",
  )
  @debug.assert_eq(report, FlattenFlatnessReport::empty())
  assert_true(report.is_flat())
}

///|
test "flatten classifier reports rich operands tees and implicit body values" {
  let report = flatten_test_classify(
    "(module (func (param i32) (result i32) (local i32) local.get 0 i32.const 1 i32.add local.tee 1))",
  )
  @debug.assert_eq(report.rich_operand_count, 1)
  @debug.assert_eq(report.local_tee_count, 1)
  @debug.assert_eq(report.body_value_flow_count, 1)
  assert_false(report.is_flat())
}

///|
test "flatten classifier reports value carrying control" {
  let report = flatten_test_classify(
    "(module (func (param i32) (result i32) local.get 0 if (result i32) i32.const 1 else i32.const 2 end))",
  )
  @debug.assert_eq(report.value_control_count, 1)
  @debug.assert_eq(report.body_value_flow_count, 1)
  assert_false(report.is_flat())
}

///|
test "flatten classifier reports upstream unsupported try-table" {
  let func = @ir.HotFunc::new()
  let try_table = @ir.hot_build_try_table(func, @lib.BlockType::void_(), [], [])
  @ir.hot_root_append(func, try_table)
  let report = flatten_classify_hot(func)
  @debug.assert_eq(report.unsupported_count, 1)
  assert_false(report.is_flat())
}

///|
test "flatten lowers a root local tee before materializing the function result" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32) (local i32) i32.const 7 local.tee 0))",
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_local_count(func), 2)
  @debug.assert_eq(@ir.hot_root_count(func), 3)
  let original_set = @ir.hot_root_get(func, 0)
  let result_set = @ir.hot_root_get(func, 1)
  let return_id = @ir.hot_root_get(func, 2)
  @debug.assert_eq(
    @ir.hot_node_get(func, original_set).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(@ir.hot_node_get(func, original_set).imm0, 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, result_set).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(@ir.hot_node_get(func, result_set).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, return_id).op.to_string(), "Return")
  assert_true(flatten_classify_hot(func).is_flat())
}

///|
test "flatten drops a root tee shell around unreachable" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let tee = @ir.hot_build_local_tee(func, 0, @ir.hot_build_unreachable(func))
  @ir.hot_root_append(func, tee)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_root_count(func), 1)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op.to_string(),
    "Unreachable",
  )
  @debug.assert_eq(@ir.hot_local_count(func), 1)
  assert_true(flatten_classify_hot(func).is_flat())
}

///|
test "flatten materializes an implicit scalar function result before return" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32) i32.const 1 i32.const 2 i32.add))",
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_local_count(func), 1)
  @debug.assert_eq(@ir.hot_root_count(func), 2)
  let set_id = @ir.hot_root_get(func, 0)
  let return_id = @ir.hot_root_get(func, 1)
  @debug.assert_eq(@ir.hot_node_get(func, set_id).op.to_string(), "LocalSet")
  @debug.assert_eq(@ir.hot_node_get(func, return_id).op.to_string(), "Return")
  let get_id = @ir.hot_child_get(func, return_id, 0)
  @debug.assert_eq(@ir.hot_node_get(func, get_id).op.to_string(), "LocalGet")
  @debug.assert_eq(@ir.hot_node_get(func, set_id).imm0, 0)
  @debug.assert_eq(@ir.hot_node_get(func, get_id).imm0, 0)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected flattened body to verify, got \{err}")
  }
}

///|
test "flatten spills sibling operand preludes in left to right order" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32) (i32.mul (i32.add (local.get 0) (i32.const 1)) (i32.sub (local.get 0) (i32.const 2)))))",
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_local_count(func), 4)
  @debug.assert_eq(@ir.hot_root_count(func), 4)
  let add_set = @ir.hot_root_get(func, 0)
  let sub_set = @ir.hot_root_get(func, 1)
  let result_set = @ir.hot_root_get(func, 2)
  @debug.assert_eq(@ir.hot_node_get(func, add_set).op.to_string(), "LocalSet")
  @debug.assert_eq(@ir.hot_node_get(func, sub_set).op.to_string(), "LocalSet")
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, @ir.hot_child_get(func, add_set, 0)),
    Some(@lib.Instruction::i32_add()),
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, @ir.hot_child_get(func, sub_set, 0)),
    Some(@lib.Instruction::i32_sub()),
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, @ir.hot_child_get(func, result_set, 0)),
    Some(@lib.Instruction::i32_mul()),
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected ordered operand preludes to verify, got \{err}")
  }
}

///|
test "flatten places nested operand preludes in their owning block region" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32) (block (result i32) (i32.add (i32.mul (local.get 0) (i32.const 2)) (i32.const 1)))))",
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  let block_id = @ir.hot_root_get(func, 0)
  @debug.assert_eq(@ir.hot_node_get(func, block_id).op.to_string(), "Block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 2)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 0)).op.to_string(),
    "LocalSet",
  )
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected region-owned operand preludes to verify, got \{err}")
  }
}

///|
test "flatten routes a scalar value block through a fresh local" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32) (block (result i32) (i32.const 7))))",
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_local_count(func), 2)
  @debug.assert_eq(@ir.hot_root_count(func), 3)
  let block_id = @ir.hot_root_get(func, 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 0)
  let block_body = @ir.hot_region_body_ref(func, block_id)
  let block_tail = @ir.hot_region_get(
    func,
    block_body,
    @ir.hot_region_root_count(func, block_body) - 1,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, block_tail).op.to_string(),
    "LocalSet",
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected scalar block routing to verify, got \{err}")
  }
}

///|
test "flatten hoists a nested scalar value block to its owning prelude" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32) (i32.add (block (result i32) (i32.const 7)) (i32.const 1))))",
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_root_count(func), 3)
  let block_id = @ir.hot_root_get(func, 0)
  @debug.assert_eq(@ir.hot_node_get(func, block_id).op.to_string(), "Block")
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 0)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nested scalar block routing to verify, got \{err}")
  }
}

///|
test "flatten routes a carried scalar br through its block target temp" {
  let func = pass_test_lift_first_func(
    "(module (func (drop (block (result i32) (br 0 (i32.const 7))))))",
  )
  let drop_id = @ir.hot_root_get(func, 0)
  let block_id = @ir.hot_child_get(func, drop_id, 0)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, block_id)),
    0,
  )
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 2)
  let payload_set = @ir.hot_region_get(func, body_ref, 0)
  let branch = @ir.hot_region_get(func, body_ref, 1)
  @debug.assert_eq(
    @ir.hot_node_get(func, payload_set).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(@ir.hot_node_get(func, branch).op.to_string(), "Br")
  @debug.assert_eq(@ir.hot_child_count(func, branch), 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, drop_id, 0)).op.to_string(),
    "LocalGet",
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected carried scalar br routing to verify, got \{err}")
  }
}

///|
test "flatten leaves scalar br_if payloads until flowing values are repaired" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (drop (block (result i32) i32.const 7 local.get 0 br_if 0 drop i32.const 9))))",
  )
  let block_id = @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let branch = @ir.hot_region_get(func, body_ref, 0)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::unchanged())
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 1)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 2)
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected deferred scalar br_if to remain valid, got \{err}")
  }
}

///|
test "flatten does not partially route a block with br and deferred br_if exits" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32 i32) (drop (block (result i32) local.get 0 if i32.const 7 br 1 end i32.const 8 local.get 1 br_if 0 drop i32.const 9))))",
  )
  let block_id = @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let if_id = @ir.hot_region_get(func, body_ref, 0)
  let direct_branch = @ir.hot_region_get(
    func,
    @ir.hot_region_then_ref(func, if_id),
    0,
  )
  let conditional_branch = @ir.hot_region_get(func, body_ref, 1)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::unchanged())
  @debug.assert_eq(@ir.hot_child_count(func, direct_branch), 1)
  @debug.assert_eq(@ir.hot_child_count(func, conditional_branch), 2)
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 1)
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected mixed branch target to remain valid, got \{err}")
  }
}

///|
test "flatten routes a branch-free scalar loop result through a fresh local" {
  let func = pass_test_lift_first_func(
    "(module (func (drop (loop (result i32) (i32.const 7)))))",
  )
  let drop_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, drop_id, 0)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_root_count(func), 2)
  @debug.assert_eq(@ir.hot_root_get(func, 0), loop_id)
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 1)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 0)).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, drop_id, 0)).op.to_string(),
    "LocalGet",
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected scalar loop result routing to verify, got \{err}")
  }
}

///|
test "flatten intentionally leaves inputful scalar loops for parameter repair" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32) (result i32))) (func i32.const 5 (loop (type $carrier) drop i32.const 7) drop))",
  )
  let drop_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, drop_id, 0)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::unchanged())
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 1)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    1,
  )
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected deferred inputful loop to remain valid, got \{err}")
  }
}

///|
test "flatten leaves scalar loops with backedges for loop channel repair" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (drop (loop (result i32) local.get 0 br_if 0 i32.const 7))))",
  )
  let loop_id = @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::unchanged())
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 1)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected deferred loop backedge to remain valid, got \{err}")
  }
}

///|
test "flatten routes scalar if arms through one fresh local" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32) local.get 0 if (result i32) i32.const 7 else i32.const 9 end))",
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_local_count(func), 3)
  @debug.assert_eq(@ir.hot_root_count(func), 3)
  let if_id = @ir.hot_root_get(func, 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 0)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  let then_set = @ir.hot_region_get(func, then_ref, 0)
  let else_set = @ir.hot_region_get(func, else_ref, 0)
  @debug.assert_eq(@ir.hot_node_get(func, then_set).op.to_string(), "LocalSet")
  @debug.assert_eq(@ir.hot_node_get(func, else_set).op.to_string(), "LocalSet")
  @debug.assert_eq(
    @ir.hot_node_get(func, then_set).imm0,
    @ir.hot_node_get(func, else_set).imm0,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected scalar if routing to verify, got \{err}")
  }
}

///|
test "flatten keeps condition preludes outside and arm work inside scalar if" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32) (if (result i32) (i32.add (local.get 0) (i32.const 1)) (then (i32.add (local.get 0) (i32.const 2))) (else (i32.sub (local.get 0) (i32.const 3))))))",
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_root_count(func), 4)
  let condition_set = @ir.hot_root_get(func, 0)
  let if_id = @ir.hot_root_get(func, 1)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, @ir.hot_child_get(func, condition_set, 0)),
    Some(@lib.Instruction::i32_add()),
  )
  @debug.assert_eq(@ir.hot_node_get(func, if_id).op.to_string(), "If")
  let then_set = @ir.hot_region_get(
    func,
    @ir.hot_region_then_ref(func, if_id),
    0,
  )
  let else_set = @ir.hot_region_get(
    func,
    @ir.hot_region_else_ref(func, if_id).unwrap(),
    0,
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, @ir.hot_child_get(func, then_set, 0)),
    Some(@lib.Instruction::i32_add()),
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, @ir.hot_child_get(func, else_set, 0)),
    Some(@lib.Instruction::i32_sub()),
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected scalar if prelude placement to verify, got \{err}")
  }
}

///|
test "flatten lowers a nested tee in operand prelude order" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32) (local i32) (i32.add (local.tee 1 (i32.mul (local.get 0) (i32.const 2))) (i32.sub (local.get 0) (i32.const 3)))))",
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_root_count(func), 5)
  let tee_value_set = @ir.hot_root_get(func, 0)
  let tee_target_set = @ir.hot_root_get(func, 1)
  let sibling_set = @ir.hot_root_get(func, 2)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, @ir.hot_child_get(func, tee_value_set, 0)),
    Some(@lib.Instruction::i32_mul()),
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, tee_target_set).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(@ir.hot_node_get(func, tee_target_set).imm0, 1)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, @ir.hot_child_get(func, sibling_set, 0)),
    Some(@lib.Instruction::i32_sub()),
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nested tee operand lowering to verify, got \{err}")
  }
}

///|
test "flatten preserves an unreachable nested tee as an ordered prelude" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let tee = @ir.hot_build_local_tee(func, 0, @ir.hot_build_unreachable(func))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, tee))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_root_count(func), 2)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op.to_string(),
    "Unreachable",
  )
  let drop_id = @ir.hot_root_get(func, 1)
  @debug.assert_eq(@ir.hot_node_get(func, drop_id).op.to_string(), "Drop")
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, drop_id, 0)).op.to_string(),
    "Unreachable",
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected unreachable nested tee lowering to verify, got \{err}")
  }
}

///|
test "flatten lowers a tee rooted in a structured region" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32) (local i32) (block (result i32) (local.tee 0 (i32.const 7)))))",
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  let block_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 2)
  let tee_target_set = @ir.hot_region_get(func, body_ref, 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, tee_target_set).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(@ir.hot_node_get(func, tee_target_set).imm0, 0)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected structured-region tee lowering to verify, got \{err}")
  }
}

///|
test "flatten leaves carried scalar if labels for branch payload routing" {
  let func = pass_test_lift_first_func(
    "(module (func (drop (if (result i32) (i32.const 1) (then (br 0 (i32.const 7))) (else (i32.const 9))))))",
  )
  let if_id = @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::unchanged())
  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 1)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, if_id)),
    1,
  )
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected deferred carried if to remain valid, got \{err}")
  }
}
