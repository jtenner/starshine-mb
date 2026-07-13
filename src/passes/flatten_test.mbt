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
test "flatten routes branch-free scalar legacy try results inside do and catch" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i32_type]),
  )
  let body_tail = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  @ir.hot_node_exact_instr_set(func, body_tail, @lib.Instruction::i32_add())
  let catch_tail = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i32(func, @lib.I32(2)),
  )
  @ir.hot_node_exact_instr_set(func, catch_tail, @lib.Instruction::i32_sub())
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)), body_tail],
    catch_body=Some([
      @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 0)),
      catch_tail,
    ]),
  )
  let drop_id = @ir.hot_build_drop(func, try_id)
  @ir.hot_root_append(func, drop_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_root_count(func), 2)
  @debug.assert_eq(@ir.hot_root_get(func, 0), try_id)
  @debug.assert_eq(@ir.hot_root_get(func, 1), drop_id)
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, try_id)),
    0,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 2)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  let body_set = @ir.hot_region_get(func, body_ref, 1)
  let catch_set = @ir.hot_region_get(func, catch_ref, 1)
  @debug.assert_eq(@ir.hot_child_get(func, body_set, 0), body_tail)
  @debug.assert_eq(@ir.hot_child_get(func, catch_set, 0), catch_tail)
  let result_local = @ir.hot_node_get(func, body_set).imm0
  @debug.assert_eq(@ir.hot_node_get(func, catch_set).imm0, result_local)
  @debug.assert_eq(@ir.hot_local_type(func, result_local), Some(i32_type))
  let result_get = @ir.hot_child_get(func, drop_id, 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, result_get).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(@ir.hot_node_get(func, result_get).imm0, result_local)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected scalar legacy try routing to verify, got \{err}")
  }
}

///|
test "flatten routes branch-free multivalue legacy try results through typed locals" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type, i64_type]),
  )
  let body_first = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  @ir.hot_node_exact_instr_set(func, body_first, @lib.Instruction::i32_add())
  let body_second = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(2L)),
  )
  @ir.hot_node_exact_instr_set(func, body_second, @lib.Instruction::i64_add())
  let catch_first = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, catch_first, @lib.Instruction::i32_sub())
  let catch_second = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(func, catch_second, @lib.Instruction::i64_sub())
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [body_first, body_second],
    catch_body=Some([catch_first, catch_second]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      [i32_type, i64_type],
    ),
  )
  let return_id = @ir.hot_build_return(func, [try_id, try_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_root_count(func), 2)
  @debug.assert_eq(@ir.hot_root_get(func, 0), try_id)
  @debug.assert_eq(@ir.hot_root_get(func, 1), return_id)
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, try_id)),
    0,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 2)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  let body_first_set = @ir.hot_region_get(func, body_ref, 0)
  let body_second_set = @ir.hot_region_get(func, body_ref, 1)
  let catch_first_set = @ir.hot_region_get(func, catch_ref, 0)
  let catch_second_set = @ir.hot_region_get(func, catch_ref, 1)
  @debug.assert_eq(@ir.hot_child_get(func, body_first_set, 0), body_first)
  @debug.assert_eq(@ir.hot_child_get(func, body_second_set, 0), body_second)
  @debug.assert_eq(@ir.hot_child_get(func, catch_first_set, 0), catch_first)
  @debug.assert_eq(@ir.hot_child_get(func, catch_second_set, 0), catch_second)
  let first_local = @ir.hot_node_get(func, body_first_set).imm0
  let second_local = @ir.hot_node_get(func, body_second_set).imm0
  assert_false(first_local == second_local)
  @debug.assert_eq(@ir.hot_node_get(func, catch_first_set).imm0, first_local)
  @debug.assert_eq(@ir.hot_node_get(func, catch_second_set).imm0, second_local)
  @debug.assert_eq(@ir.hot_local_type(func, first_local), Some(i32_type))
  @debug.assert_eq(@ir.hot_local_type(func, second_local), Some(i64_type))
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, body_first), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, body_second), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, catch_first), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, catch_second), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected multivalue legacy try routing to verify, got \{err}")
  }
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
test "flatten routes a same-type scalar br_if through its block target temp" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (drop (block (result i32) i32.const 7 local.get 0 br_if 0 drop i32.const 9))))",
  )
  let drop_id = @ir.hot_root_get(func, 0)
  let block_id = @ir.hot_child_get(func, drop_id, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let branch = @ir.hot_region_get(func, body_ref, 0)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  let payload_set = @ir.hot_region_get(func, body_ref, 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, payload_set).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 1), branch)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, drop_id, 0)).op.to_string(),
    "LocalGet",
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected same-type scalar br_if routing to verify, got \{err}")
  }
}

///|
test "flatten evaluates rich br_if payloads once before rich conditions" {
  let func = pass_test_lift_first_func(
    "(module (func (drop (block (result i32) call 1 call 2 br_if 0 drop i32.const 9))) (func (result i32) i32.const 7) (func (result i32) i32.const 0))",
  )
  let block_id = @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let branch = @ir.hot_region_get(func, body_ref, 0)
  let payload = @ir.hot_child_get(func, branch, 0)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  let payload_set = @ir.hot_region_get(func, body_ref, 0)
  let condition_set = @ir.hot_region_get(func, body_ref, 1)
  @debug.assert_eq(
    @ir.hot_node_get(func, payload_set).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, condition_set).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(@ir.hot_child_get(func, payload_set, 0), payload)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, condition_set, 0)).op.to_string(),
    "Call",
  )
  let drop_id = @ir.hot_region_get(func, body_ref, 3)
  @debug.assert_eq(@ir.hot_node_get(func, drop_id).op.to_string(), "Drop")
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, drop_id, 0)).op.to_string(),
    "LocalGet",
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected rich br_if routing to verify, got \{err}")
  }
}

///|
test "flatten shares one rich payload origin across chained br_if flow" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32 i32) (drop (block (result i32) call 1 local.get 0 br_if 0 local.get 1 br_if 0 drop i32.const 9))) (func (result i32) i32.const 7))",
  )
  let block_id = @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let first_branch = @ir.hot_region_get(func, body_ref, 0)
  let second_branch = @ir.hot_region_get(func, body_ref, 1)
  let payload = @ir.hot_child_get(func, first_branch, 0)
  @debug.assert_eq(@ir.hot_child_get(func, second_branch, 0), payload)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, first_branch), 1)
  @debug.assert_eq(@ir.hot_child_count(func, second_branch), 1)
  let first_payload_set = @ir.hot_region_get(func, body_ref, 0)
  @debug.assert_eq(@ir.hot_child_get(func, first_payload_set, 0), payload)
  let payload_use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(payload_use_def, payload), 1)
  let drop_id = @ir.hot_region_get(func, body_ref, 4)
  @debug.assert_eq(@ir.hot_node_get(func, drop_id).op.to_string(), "Drop")
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, drop_id, 0)).op.to_string(),
    "LocalGet",
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected chained rich br_if routing to verify, got \{err}")
  }
}

///|
test "flatten uses distinct target and flow temps for mismatched scalar br_if" {
  let func = pass_test_lift_first_func(
    "(module (type $base (sub (struct))) (type $child (sub $base (struct))) (func (param i32) (drop (block (result (ref null $base)) (block (result (ref null $child)) ref.null $child local.get 0 br_if 1)))))",
  )
  let drop_id = @ir.hot_root_get(func, 0)
  let outer_block = @ir.hot_child_get(func, drop_id, 0)
  let outer_body = @ir.hot_region_body_ref(func, outer_block)
  let inner_block = @ir.hot_region_get(func, outer_body, 0)
  let inner_body = @ir.hot_region_body_ref(func, inner_block)
  let branch = @ir.hot_region_get(func, inner_body, 0)
  let payload = @ir.hot_child_get(func, branch, 0)
  let target_type = @ir.hot_type_results(
      func,
      @ir.hot_label_result_type(
        func,
        @ir.hot_control_node_label(func, outer_block),
      ),
    )[0]
  let flow_type = @ir.hot_type_results(func, @ir.hot_node_get(func, payload).ty)[0]
  assert_false(target_type == flow_type)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, outer_block), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, inner_block), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  let flow_set = @ir.hot_region_get(func, inner_body, 0)
  let target_set = @ir.hot_region_get(func, inner_body, 1)
  @debug.assert_eq(@ir.hot_node_get(func, flow_set).op.to_string(), "LocalSet")
  @debug.assert_eq(
    @ir.hot_node_get(func, target_set).op.to_string(),
    "LocalSet",
  )
  let flow_local = @ir.hot_node_get(func, flow_set).imm0
  let target_local = @ir.hot_node_get(func, target_set).imm0
  assert_false(flow_local == target_local)
  @debug.assert_eq(@ir.hot_local_type(func, flow_local), Some(flow_type))
  @debug.assert_eq(@ir.hot_local_type(func, target_local), Some(target_type))
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, target_set, 0)).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(@ir.hot_region_get(func, inner_body, 2), branch)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected mismatched scalar br_if routing to verify, got \{err}")
  }
}

///|
test "flatten routes mixed scalar br and br_if exits through one target temp" {
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
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, direct_branch), 0)
  @debug.assert_eq(@ir.hot_child_count(func, conditional_branch), 1)
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 0)
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected mixed scalar branch target to verify, got \{err}")
  }
}

///|
test "flatten fans one scalar br_table value out to unique target temps" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (drop (block (result i32) (block (result i32) i32.const 7 local.get 0 br_table 0 1 1)))))",
  )
  let drop_id = @ir.hot_root_get(func, 0)
  let outer_block = @ir.hot_child_get(func, drop_id, 0)
  let outer_body = @ir.hot_region_body_ref(func, outer_block)
  let inner_block = @ir.hot_region_get(func, outer_body, 0)
  let inner_body = @ir.hot_region_body_ref(func, inner_block)
  let branch = @ir.hot_region_get(func, inner_body, 0)
  let table_id = @ir.hot_node_get(func, branch).imm0
  @debug.assert_eq(@ir.hot_branch_table_targets(func, table_id).length(), 2)
  @debug.assert_eq(
    @ir.hot_branch_table_default_target(func, table_id),
    @ir.hot_control_node_label(func, outer_block),
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, outer_block), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, inner_block), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_region_root_count(func, inner_body), 4)
  let value_set = @ir.hot_region_get(func, inner_body, 0)
  let first_target_set = @ir.hot_region_get(func, inner_body, 1)
  let second_target_set = @ir.hot_region_get(func, inner_body, 2)
  @debug.assert_eq(@ir.hot_node_get(func, value_set).op.to_string(), "LocalSet")
  @debug.assert_eq(
    @ir.hot_node_get(func, first_target_set).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_target_set).op.to_string(),
    "LocalSet",
  )
  let value_local = @ir.hot_node_get(func, value_set).imm0
  let first_target_local = @ir.hot_node_get(func, first_target_set).imm0
  let second_target_local = @ir.hot_node_get(func, second_target_set).imm0
  assert_false(value_local == first_target_local)
  assert_false(value_local == second_target_local)
  assert_false(first_target_local == second_target_local)
  @debug.assert_eq(@ir.hot_region_get(func, inner_body, 3), branch)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected scalar br_table fanout to verify, got \{err}")
  }
}

///|
test "flatten evaluates rich br_table payloads once before rich selectors" {
  let func = pass_test_lift_first_func(
    "(module (func (drop (block (result i32) (block (result i32) call 1 call 2 br_table 0 1 1)))) (func (result i32) i32.const 7) (func (result i32) i32.const 0))",
  )
  let drop_id = @ir.hot_root_get(func, 0)
  let outer_block = @ir.hot_child_get(func, drop_id, 0)
  let outer_body = @ir.hot_region_body_ref(func, outer_block)
  let inner_block = @ir.hot_region_get(func, outer_body, 0)
  let inner_body = @ir.hot_region_body_ref(func, inner_block)
  let branch = @ir.hot_region_get(func, inner_body, 0)
  let payload = @ir.hot_child_get(func, branch, 0)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, outer_block), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, inner_block), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_region_root_count(func, inner_body), 5)
  let value_set = @ir.hot_region_get(func, inner_body, 0)
  let first_target_set = @ir.hot_region_get(func, inner_body, 1)
  let second_target_set = @ir.hot_region_get(func, inner_body, 2)
  let selector_set = @ir.hot_region_get(func, inner_body, 3)
  @debug.assert_eq(@ir.hot_child_get(func, value_set, 0), payload)
  @debug.assert_eq(
    @ir.hot_node_get(func, first_target_set).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_target_set).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, selector_set, 0)).op.to_string(),
    "Call",
  )
  @debug.assert_eq(@ir.hot_region_get(func, inner_body, 4), branch)
  let payload_use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(payload_use_def, payload), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected rich scalar br_table routing to verify, got \{err}")
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
test "flatten routes a single loop entry and scalar result through locals" {
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
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  @debug.assert_eq(@ir.hot_root_count(func), 3)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(@ir.hot_root_get(func, 1), loop_id)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected inputful scalar loop to verify, got \{err}")
  }
}

///|
test "flatten captures multiple effectful loop entries once in order" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32))) (func call 1 call 2 loop (type $carrier) drop drop i32.const 7 end drop) (func (result i32) i32.const 5) (func (result i64) i64.const 6))",
  )
  let drop_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, drop_id, 0)
  let first_entry = @ir.hot_child_get(func, loop_id, 0)
  let second_entry = @ir.hot_child_get(func, loop_id, 1)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_root_count(func), 4)
  let first_set = @ir.hot_root_get(func, 0)
  let second_set = @ir.hot_root_get(func, 1)
  @debug.assert_eq(@ir.hot_child_get(func, first_set, 0), first_entry)
  @debug.assert_eq(@ir.hot_child_get(func, second_set, 0), second_entry)
  @debug.assert_eq(@ir.hot_root_get(func, 2), loop_id)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_entry), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_entry), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected ordered loop entry capture to verify, got \{err}")
  }
}

///|
test "flatten intentionally leaves nondefaultable loop entries fail closed" {
  let func = pass_test_lift_first_func(
    "(module (type $box (struct)) (type $carrier (func (param (ref $box)) (result i32))) (func struct.new_default $box loop (type $carrier) drop i32.const 7 end drop))",
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
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    1,
  )
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nondefaultable loop entry to remain valid, got \{err}")
  }
}

///|
test "flatten intentionally leaves multivalue loop entry producers fail closed" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32))) (func call 1 loop (type $carrier) drop drop i32.const 7 end drop) (func (result i32 i64) i32.const 5 i64.const 6))",
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
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    2,
  )
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected multivalue loop entry producer to remain valid, got \{err}",
      )
  }
}

///|
test "flatten routes scalar loop results across payloadless backedges" {
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
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected payloadless loop backedge to verify, got \{err}")
  }
}

///|
test "flatten routes an effectful scalar loop br payload through the entry local" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32) (result i32))) (func (param i32) i32.const 0 loop (type $carrier) drop local.get 0 if call 1 br 1 end i32.const 7 end drop) (func (result i32) i32.const 5))",
  )
  let loop_id = @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let if_id = @ir.hot_region_get(func, body_ref, 1)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let branch = @ir.hot_region_get(func, then_ref, 0)
  let payload = @ir.hot_child_get(func, branch, 0)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 0)
  let payload_use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(payload_use_def, payload), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected scalar loop br payload routing to verify, got \{err}")
  }
}

///|
test "flatten routes repeated effectful scalar loop backedge payloads once" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32) (result i32))) (func (param i32 i32) i32.const 0 loop (type $carrier) drop call 1 local.get 0 br_if 0 drop call 1 local.get 1 br_if 0 drop i32.const 7 end drop) (func (result i32) i32.const 5))",
  )
  let drop_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, drop_id, 0)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let first_branch = @ir.hot_region_get(func, body_ref, 1)
  let second_branch = @ir.hot_region_get(func, body_ref, 3)
  let first_payload = @ir.hot_child_get(func, first_branch, 0)
  let second_payload = @ir.hot_child_get(func, second_branch, 0)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, first_branch), 1)
  @debug.assert_eq(@ir.hot_child_count(func, second_branch), 1)
  let entry_set = @ir.hot_root_get(func, 0)
  let first_payload_set = @ir.hot_region_get(func, body_ref, 1)
  let second_payload_set = @ir.hot_region_get(func, body_ref, 4)
  @debug.assert_eq(@ir.hot_child_get(func, first_payload_set, 0), first_payload)
  @debug.assert_eq(
    @ir.hot_child_get(func, second_payload_set, 0),
    second_payload,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, first_payload_set).imm0,
    @ir.hot_node_get(func, entry_set).imm0,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_payload_set).imm0,
    @ir.hot_node_get(func, entry_set).imm0,
  )
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 2), first_branch)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 5), second_branch)
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected scalar loop backedge routing to verify, got \{err}")
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
test "flatten routes scalar br_if flow through a carried if arm" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32 i32) (drop (if (result i32) (local.get 0) (then (br_if 0 (i32.const 7) (local.get 1))) (else (i32.const 9))))))",
  )
  let drop_id = @ir.hot_root_get(func, 0)
  let if_id = @ir.hot_child_get(func, drop_id, 0)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let branch = @ir.hot_region_get(func, then_ref, 0)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 0)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected carried scalar if br_if flow to verify, got \{err}")
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
test "flatten moves nested terminal br_table effects before unreachable placeholders" {
  let func = @ir.HotFunc::new()
  let block_id = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let label_id = @ir.hot_control_node_label(func, block_id)
  let branch = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let select_id = @ir.hot_build_select(
    func,
    @lib.ValType::i32(),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    branch,
  )
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @ir.hot_region_replace_body(func, body_ref, [branch, select_id])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, block_id))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, select_id, 2)).op.to_string(),
    "Unreachable",
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 2), branch)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nested terminal br_table placeholder to verify, got \{err}",
      )
  }
}

///|
test "flatten moves nested terminal br effects before unreachable placeholders" {
  let func = @ir.HotFunc::new()
  let block_id = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let branch = @ir.hot_build_br(
    func,
    @ir.hot_control_node_label(func, block_id),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let select_id = @ir.hot_build_select(
    func,
    @lib.ValType::i32(),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    branch,
  )
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @ir.hot_region_replace_body(func, body_ref, [select_id])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, block_id))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, select_id, 2)).op.to_string(),
    "Unreachable",
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 3)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 1), branch)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nested terminal br placeholder to verify, got \{err}")
  }
}

///|
test "flatten moves nested return effects before unreachable placeholders" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let return_value = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  @ir.hot_node_exact_instr_set(func, return_value, @lib.Instruction::i32_add())
  let return_id = @ir.hot_build_return(func, [return_value])
  let sibling = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
    @ir.hot_build_const_i32(func, @lib.I32(2)),
  )
  @ir.hot_node_exact_instr_set(func, sibling, @lib.Instruction::i32_sub())
  let add_id = @ir.hot_build_binary(func, i32_type, return_id, sibling)
  @ir.hot_node_exact_instr_set(func, add_id, @lib.Instruction::i32_add())
  @ir.hot_root_append(func, add_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  let mut return_root = -1
  let mut return_value_root = -1
  let mut sibling_root = -1
  for idx = 0; idx < @ir.hot_root_count(func); idx = idx + 1 {
    let root_id = @ir.hot_root_get(func, idx)
    if root_id == return_id {
      return_root = idx
    }
    let root = @ir.hot_node_get(func, root_id)
    match root.op {
      @ir.HotOp::LocalSet if @ir.hot_child_count(func, root_id) == 1 => {
        let child_id = @ir.hot_child_get(func, root_id, 0)
        if child_id == return_value {
          return_value_root = idx
        }
        if child_id == sibling {
          sibling_root = idx
        }
      }
      _ => ()
    }
  }
  assert_true(return_value_root >= 0)
  assert_true(return_root > return_value_root)
  assert_true(sibling_root > return_root)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, add_id, 0)).op.to_string(),
    "Unreachable",
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected nested return placeholder to verify, got \{err}")
  }
}

///|
test "flatten moves nested throw effects after ordered argument preludes" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let first_arg = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  @ir.hot_node_exact_instr_set(func, first_arg, @lib.Instruction::i32_add())
  let second_arg = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_const_i64(func, @lib.I64(9L)),
    @ir.hot_build_const_i64(func, @lib.I64(2L)),
  )
  @ir.hot_node_exact_instr_set(func, second_arg, @lib.Instruction::i64_sub())
  let throw_id = @ir.hot_build_throw(func, @lib.TagIdx::new(0U), [
    first_arg, second_arg,
  ])
  let sibling = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, sibling, @lib.Instruction::i32_sub())
  let add_id = @ir.hot_build_binary(func, i32_type, throw_id, sibling)
  @ir.hot_node_exact_instr_set(func, add_id, @lib.Instruction::i32_add())
  @ir.hot_root_append(func, add_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  let mut first_arg_root = -1
  let mut second_arg_root = -1
  let mut throw_root = -1
  let mut sibling_root = -1
  for idx = 0; idx < @ir.hot_root_count(func); idx = idx + 1 {
    let root_id = @ir.hot_root_get(func, idx)
    if root_id == throw_id {
      throw_root = idx
    }
    let root = @ir.hot_node_get(func, root_id)
    match root.op {
      @ir.HotOp::LocalSet if @ir.hot_child_count(func, root_id) == 1 => {
        let child_id = @ir.hot_child_get(func, root_id, 0)
        if child_id == first_arg {
          first_arg_root = idx
        }
        if child_id == second_arg {
          second_arg_root = idx
        }
        if child_id == sibling {
          sibling_root = idx
        }
      }
      _ => ()
    }
  }
  assert_true(first_arg_root >= 0)
  assert_true(second_arg_root > first_arg_root)
  assert_true(throw_root > second_arg_root)
  assert_true(sibling_root > throw_root)
  @debug.assert_eq(@ir.hot_child_count(func, throw_id), 2)
  for slot = 0; slot < 2; slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, throw_id, slot)).op.to_string(),
      "LocalGet",
    )
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, add_id, 0)).op.to_string(),
    "Unreachable",
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_arg), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_arg), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, sibling), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected nested throw placeholder to verify, got \{err}")
  }
}

///|
test "flatten moves nested throw_ref effects before unreachable placeholders" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let exnref = @ir.hot_build_ref_null(
    func,
    @lib.RefType::abs(@lib.AbsHeapType::exn()),
  )
  let throw_ref_id = @ir.hot_build_throw_ref(func, exnref)
  let sibling = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(13)),
    @ir.hot_build_const_i32(func, @lib.I32(5)),
  )
  @ir.hot_node_exact_instr_set(func, sibling, @lib.Instruction::i32_sub())
  let add_id = @ir.hot_build_binary(func, i32_type, throw_ref_id, sibling)
  @ir.hot_node_exact_instr_set(func, add_id, @lib.Instruction::i32_add())
  @ir.hot_root_append(func, add_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  let mut throw_root = -1
  let mut sibling_root = -1
  for idx = 0; idx < @ir.hot_root_count(func); idx = idx + 1 {
    let root_id = @ir.hot_root_get(func, idx)
    if root_id == throw_ref_id {
      throw_root = idx
    }
    let root = @ir.hot_node_get(func, root_id)
    match root.op {
      @ir.HotOp::LocalSet if @ir.hot_child_count(func, root_id) == 1 =>
        if @ir.hot_child_get(func, root_id, 0) == sibling {
          sibling_root = idx
        }
      _ => ()
    }
  }
  assert_true(throw_root >= 0)
  assert_true(sibling_root > throw_root)
  @debug.assert_eq(@ir.hot_child_count(func, throw_ref_id), 1)
  @debug.assert_eq(@ir.hot_child_get(func, throw_ref_id, 0), exnref)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, add_id, 0)).op.to_string(),
    "Unreachable",
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, exnref), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, sibling), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nested throw_ref placeholder to verify, got \{err}")
  }
}

///|
fn flatten_test_nested_tail_call_placeholder(mode : Int) -> Unit raise {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let first_arg = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  @ir.hot_node_exact_instr_set(func, first_arg, @lib.Instruction::i32_add())
  let mut second_origin = -1
  let terminal_id = match mode {
    0 => @ir.hot_build_return_call(func, 1, [first_arg])
    1 => {
      second_origin = @ir.hot_build_binary(
        func,
        i32_type,
        @ir.hot_build_const_i32(func, @lib.I32(0)),
        @ir.hot_build_const_i32(func, @lib.I32(0)),
      )
      @ir.hot_node_exact_instr_set(
        func,
        second_origin,
        @lib.Instruction::i32_add(),
      )
      @ir.hot_build_return_call_indirect(
        func,
        @lib.TypeIdx::new(0U),
        @lib.TableIdx::new(0U),
        [first_arg],
        second_origin,
      )
    }
    _ => {
      second_origin = @ir.hot_build_ref_null(
        func,
        @lib.RefType::abs(@lib.AbsHeapType::func()),
      )
      @ir.hot_build_return_call_ref(
        func,
        @lib.TypeIdx::new(0U),
        [first_arg],
        second_origin,
      )
    }
  }
  let sibling = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
    @ir.hot_build_const_i32(func, @lib.I32(2)),
  )
  @ir.hot_node_exact_instr_set(func, sibling, @lib.Instruction::i32_sub())
  let add_id = @ir.hot_build_binary(func, i32_type, terminal_id, sibling)
  @ir.hot_node_exact_instr_set(func, add_id, @lib.Instruction::i32_add())
  @ir.hot_root_append(func, add_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  let mut first_arg_root = -1
  let mut second_origin_root = -1
  let mut terminal_root = -1
  let mut sibling_root = -1
  for idx = 0; idx < @ir.hot_root_count(func); idx = idx + 1 {
    let root_id = @ir.hot_root_get(func, idx)
    if root_id == terminal_id {
      terminal_root = idx
    }
    let root = @ir.hot_node_get(func, root_id)
    match root.op {
      @ir.HotOp::LocalSet if @ir.hot_child_count(func, root_id) == 1 => {
        let child_id = @ir.hot_child_get(func, root_id, 0)
        if child_id == first_arg {
          first_arg_root = idx
        }
        if child_id == second_origin {
          second_origin_root = idx
        }
        if child_id == sibling {
          sibling_root = idx
        }
      }
      _ => ()
    }
  }
  assert_true(first_arg_root >= 0)
  if mode == 1 {
    assert_true(second_origin_root > first_arg_root)
    assert_true(terminal_root > second_origin_root)
  } else {
    assert_true(terminal_root > first_arg_root)
  }
  assert_true(sibling_root > terminal_root)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, terminal_id, 0)).op.to_string(),
    "LocalGet",
  )
  if mode == 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, terminal_id, 1)).op.to_string(),
      "LocalGet",
    )
  } else if mode == 2 {
    @debug.assert_eq(@ir.hot_child_get(func, terminal_id, 1), second_origin)
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, add_id, 0)).op.to_string(),
    "Unreachable",
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_arg), 1)
  if second_origin >= 0 {
    @debug.assert_eq(@ir.node_use_count(use_def, second_origin), 1)
  }
  @debug.assert_eq(@ir.node_use_count(use_def, sibling), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nested tail-call placeholder to verify, got \{err}")
  }
}

///|
test "flatten moves nested return_call effects before unreachable placeholders" {
  flatten_test_nested_tail_call_placeholder(0)
}

///|
test "flatten moves nested return_call_indirect effects before placeholders" {
  flatten_test_nested_tail_call_placeholder(1)
}

///|
test "flatten moves nested return_call_ref effects before placeholders" {
  flatten_test_nested_tail_call_placeholder(2)
}

///|
test "flatten leaves unsupported nondefaultable root controls unmaterialized" {
  let func = pass_test_lift_first_func(
    "(module (type $box (struct)) (func (result (ref $box)) (if (result (ref $box)) (i32.const 1) (then (br 0 (struct.new_default $box))) (else (struct.new_default $box)))))",
  )
  let if_id = @ir.hot_root_get(func, 0)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::unchanged())
  @debug.assert_eq(@ir.hot_root_count(func), 1)
  @debug.assert_eq(@ir.hot_root_get(func, 0), if_id)
  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 1)
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nondefaultable root control to remain valid, got \{err}")
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
test "flatten routes a carried scalar if label through the arm result temp" {
  let func = pass_test_lift_first_func(
    "(module (func (drop (if (result i32) (i32.const 1) (then (br 0 (i32.const 7))) (else (i32.const 9))))))",
  )
  let drop_id = @ir.hot_root_get(func, 0)
  let if_id = @ir.hot_child_get(func, drop_id, 0)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let branch = @ir.hot_region_get(func, then_ref, 0)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, if_id)),
    0,
  )
  @debug.assert_eq(@ir.hot_child_count(func, branch), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 2)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, then_ref, 0)).op.to_string(),
    "LocalSet",
  )
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, 0)).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, drop_id, 0)).op.to_string(),
    "LocalGet",
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected carried scalar if routing to verify, got \{err}")
  }
}

///|
test "flatten routes ordered two-parameter loop br payloads" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32))) (func (param i32) call 1 call 2 loop (type $carrier) drop drop local.get 0 if call 3 call 4 br 1 end i32.const 7 end drop) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 3) (func (result i64) i64.const 4))",
  )
  let drop_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, drop_id, 0)
  let loop_body = @ir.hot_region_body_ref(func, loop_id)
  let if_id = @ir.hot_region_get(func, loop_body, 2)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let branch = @ir.hot_region_get(func, then_ref, 0)
  let first_payload = @ir.hot_child_get(func, branch, 0)
  let second_payload = @ir.hot_child_get(func, branch, 1)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  let first_entry_set = @ir.hot_root_get(func, 0)
  let second_entry_set = @ir.hot_root_get(func, 1)
  let first_entry_local = @ir.hot_node_get(func, first_entry_set).imm0
  let second_entry_local = @ir.hot_node_get(func, second_entry_set).imm0
  assert_false(first_entry_local == second_entry_local)
  let then_count = @ir.hot_region_root_count(func, then_ref)
  let first_payload_set = @ir.hot_region_get(func, then_ref, then_count - 3)
  let second_payload_set = @ir.hot_region_get(func, then_ref, then_count - 2)
  @debug.assert_eq(
    @ir.hot_node_get(func, first_payload_set).imm0,
    first_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_payload_set).imm0,
    second_entry_local,
  )
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, then_count - 1), branch)
  let result_set = @ir.hot_region_get(
    func,
    loop_body,
    @ir.hot_region_root_count(func, loop_body) - 1,
  )
  let result_local = @ir.hot_node_get(func, result_set).imm0
  assert_false(result_local == first_entry_local)
  assert_false(result_local == second_entry_local)
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected two-parameter loop br routing to verify, got \{err}")
  }
}

///|
test "flatten routes two-parameter loop br_if payloads and false flow" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32))) (func call 1 call 2 loop (type $carrier) drop drop call 3 call 4 call 5 br_if 0 drop drop i32.const 7 end drop) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 3) (func (result i64) i64.const 4) (func (result i32) i32.const 0))",
  )
  let loop_id = @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let branch = @ir.hot_region_get(func, body_ref, 2)
  let first_payload = @ir.hot_child_get(func, branch, 0)
  let second_payload = @ir.hot_child_get(func, branch, 1)
  let condition = @ir.hot_child_get(func, branch, 2)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, branch, 0)).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  let first_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).imm0
  let second_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).imm0
  let first_payload_set = @ir.hot_region_get(func, body_ref, 2)
  let second_payload_set = @ir.hot_region_get(func, body_ref, 3)
  @debug.assert_eq(
    @ir.hot_node_get(func, first_payload_set).imm0,
    first_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_payload_set).imm0,
    second_entry_local,
  )
  let condition_set = @ir.hot_region_get(func, body_ref, 4)
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), condition)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 5), branch)
  let first_false_drop = @ir.hot_region_get(func, body_ref, 6)
  let second_false_drop = @ir.hot_region_get(func, body_ref, 7)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_false_drop, 0)).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_false_drop, 0)).op.to_string(),
    "LocalGet",
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, condition), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected two-parameter loop br_if routing to verify, got \{err}")
  }
}

///|
test "flatten routes ordered two-parameter loop br_table payloads" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32))) (func call 1 call 2 loop (type $carrier) drop drop call 3 call 4 call 5 br_table 0 0 i32.const 7 end drop) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 3) (func (result i64) i64.const 4) (func (result i32) i32.const 0))",
  )
  let loop_id = @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let branch = @ir.hot_region_get(func, body_ref, 2)
  let first_payload = @ir.hot_child_get(func, branch, 0)
  let second_payload = @ir.hot_child_get(func, branch, 1)
  let selector = @ir.hot_child_get(func, branch, 2)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  let first_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).imm0
  let second_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).imm0
  let first_value_set = @ir.hot_region_get(func, body_ref, 2)
  let second_value_set = @ir.hot_region_get(func, body_ref, 3)
  let first_target_set = @ir.hot_region_get(func, body_ref, 4)
  let second_target_set = @ir.hot_region_get(func, body_ref, 5)
  let selector_set = @ir.hot_region_get(func, body_ref, 6)
  @debug.assert_eq(@ir.hot_child_get(func, first_value_set, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_value_set, 0), second_payload)
  assert_false(
    @ir.hot_node_get(func, first_value_set).imm0 == first_entry_local,
  )
  assert_false(
    @ir.hot_node_get(func, second_value_set).imm0 == second_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, first_target_set).imm0,
    first_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_target_set).imm0,
    second_entry_local,
  )
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 7), branch)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 9)
  let result_set = @ir.hot_region_get(func, body_ref, 8)
  let result_local = @ir.hot_node_get(func, result_set).imm0
  assert_false(result_local == first_entry_local)
  assert_false(result_local == second_entry_local)
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected two-parameter loop br_table routing to verify, got \{err}")
  }
}

///|
test "flatten routes branch-free multivalue block results through typed locals" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32 i64) (block (result i32 i64) i32.const 7 i64.const 9) return))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let block_id = @ir.hot_child_get(func, return_id, 0)
  @debug.assert_eq(@ir.hot_child_get(func, return_id, 1), block_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_root_count(func), 2)
  @debug.assert_eq(@ir.hot_root_get(func, 0), block_id)
  @debug.assert_eq(@ir.hot_root_get(func, 1), return_id)
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, block_id)),
    0,
  )
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 2)
  let first_set = @ir.hot_region_get(func, body_ref, 0)
  let second_set = @ir.hot_region_get(func, body_ref, 1)
  @debug.assert_eq(@ir.hot_node_get(func, first_set).op.to_string(), "LocalSet")
  @debug.assert_eq(
    @ir.hot_node_get(func, second_set).op.to_string(),
    "LocalSet",
  )
  let first_local = @ir.hot_node_get(func, first_set).imm0
  let second_local = @ir.hot_node_get(func, second_set).imm0
  assert_false(first_local == second_local)
  @debug.assert_eq(
    @ir.hot_local_type(func, first_local),
    Some(@lib.ValType::i32()),
  )
  @debug.assert_eq(
    @ir.hot_local_type(func, second_local),
    Some(@lib.ValType::i64()),
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_local,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected branch-free multivalue block routing to verify, got \{err}",
      )
  }
}

///|
test "flatten scalarizes one exclusive tuple-made multivalue block tail" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type, i64_type]),
  )
  let first_value = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  @ir.hot_node_exact_instr_set(func, first_value, @lib.Instruction::i32_add())
  let second_value = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(2L)),
  )
  @ir.hot_node_exact_instr_set(func, second_value, @lib.Instruction::i64_add())
  let tuple_id = @ir.hot_build_tuple_make(func, [i32_type, i64_type], [
    first_value, second_value,
  ])
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [tuple_id])
  @ir.hot_control_result_type_set(
    func,
    block_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      [i32_type, i64_type],
    ),
  )
  let return_id = @ir.hot_build_return(func, [block_id, block_id])
  @ir.hot_root_append(func, return_id)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
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
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  let first_value_set = @ir.hot_region_get(func, body_ref, 0)
  let second_value_set = @ir.hot_region_get(func, body_ref, 1)
  let first_result_set = @ir.hot_region_get(func, body_ref, 2)
  let second_result_set = @ir.hot_region_get(func, body_ref, 3)
  @debug.assert_eq(@ir.hot_child_get(func, first_value_set, 0), first_value)
  @debug.assert_eq(@ir.hot_child_get(func, second_value_set, 0), second_value)
  let first_local = @ir.hot_node_get(func, first_result_set).imm0
  let second_local = @ir.hot_node_get(func, second_result_set).imm0
  assert_false(first_local == second_local)
  @debug.assert_eq(
    @ir.hot_local_type(func, first_local),
    Some(@lib.ValType::i32()),
  )
  @debug.assert_eq(
    @ir.hot_local_type(func, second_local),
    Some(@lib.ValType::i64()),
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_local,
  )
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_value), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_value), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple-made multivalue block routing to verify, got \{err}")
  }
}

///|
test "flatten routes branch-free multivalue if results through typed locals" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32 i64) (if (result i32 i64) (i32.eqz (local.get 0)) (then (i32.add (i32.const 1) (i32.const 2)) (i64.add (i64.const 3) (i64.const 4))) (else (i32.sub (i32.const 9) (i32.const 5)) (i64.sub (i64.const 8) (i64.const 6)))) return))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let if_id = @ir.hot_child_get(func, return_id, 0)
  @debug.assert_eq(@ir.hot_child_get(func, return_id, 1), if_id)
  let condition_id = @ir.hot_child_get(func, if_id, 0)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_root_count(func), 3)
  let condition_set = @ir.hot_root_get(func, 0)
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), condition_id)
  @debug.assert_eq(@ir.hot_root_get(func, 1), if_id)
  @debug.assert_eq(@ir.hot_root_get(func, 2), return_id)
  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, if_id)),
    0,
  )
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 2)
  @debug.assert_eq(@ir.hot_region_root_count(func, else_ref), 2)
  let then_first_set = @ir.hot_region_get(func, then_ref, 0)
  let then_second_set = @ir.hot_region_get(func, then_ref, 1)
  let else_first_set = @ir.hot_region_get(func, else_ref, 0)
  let else_second_set = @ir.hot_region_get(func, else_ref, 1)
  let first_local = @ir.hot_node_get(func, then_first_set).imm0
  let second_local = @ir.hot_node_get(func, then_second_set).imm0
  @debug.assert_eq(@ir.hot_node_get(func, else_first_set).imm0, first_local)
  @debug.assert_eq(@ir.hot_node_get(func, else_second_set).imm0, second_local)
  assert_false(first_local == second_local)
  @debug.assert_eq(
    @ir.hot_local_type(func, first_local),
    Some(@lib.ValType::i32()),
  )
  @debug.assert_eq(
    @ir.hot_local_type(func, second_local),
    Some(@lib.ValType::i64()),
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_local,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected branch-free multivalue if routing to verify, got \{err}")
  }
}

///|
test "flatten scalarizes exclusive tuple-made multivalue if arms" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type, i64_type]),
  )
  let then_first = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  @ir.hot_node_exact_instr_set(func, then_first, @lib.Instruction::i32_add())
  let then_second = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(2L)),
  )
  @ir.hot_node_exact_instr_set(func, then_second, @lib.Instruction::i64_add())
  let else_first = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, else_first, @lib.Instruction::i32_sub())
  let else_second = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(func, else_second, @lib.Instruction::i64_sub())
  let then_tuple = @ir.hot_build_tuple_make(func, [i32_type, i64_type], [
    then_first, then_second,
  ])
  let else_tuple = @ir.hot_build_tuple_make(func, [i32_type, i64_type], [
    else_first, else_second,
  ])
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [then_tuple],
    else_body=Some([else_tuple]),
  )
  @ir.hot_control_result_type_set(
    func,
    if_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      [i32_type, i64_type],
    ),
  )
  let return_id = @ir.hot_build_return(func, [if_id, if_id])
  @ir.hot_root_append(func, return_id)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, if_id)),
    0,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 4)
  @debug.assert_eq(@ir.hot_region_root_count(func, else_ref), 4)
  let then_first_result_set = @ir.hot_region_get(func, then_ref, 2)
  let then_second_result_set = @ir.hot_region_get(func, then_ref, 3)
  let else_first_result_set = @ir.hot_region_get(func, else_ref, 2)
  let else_second_result_set = @ir.hot_region_get(func, else_ref, 3)
  let first_local = @ir.hot_node_get(func, then_first_result_set).imm0
  let second_local = @ir.hot_node_get(func, then_second_result_set).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, else_first_result_set).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, else_second_result_set).imm0,
    second_local,
  )
  @debug.assert_eq(@ir.hot_local_type(func, first_local), Some(i32_type))
  @debug.assert_eq(@ir.hot_local_type(func, second_local), Some(i64_type))
  assert_false(@ir.hot_node_is_live(func, then_tuple))
  assert_false(@ir.hot_node_is_live(func, else_tuple))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, then_first), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, then_second), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, else_first), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, else_second), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple-made multivalue if routing to verify, got \{err}")
  }
}

///|
test "flatten routes branch-targeted multivalue if arms through typed locals" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32 i64) (if (result i32 i64) (local.get 0) (then i32.const 7 i64.const 9 br 0) (else i32.const 11 i64.const 13)) return))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let if_id = @ir.hot_child_get(func, return_id, 0)
  @debug.assert_eq(@ir.hot_child_get(func, return_id, 1), if_id)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  let branch_id = @ir.hot_region_get(func, then_ref, 0)
  let first_payload = @ir.hot_child_get(func, branch_id, 0)
  let second_payload = @ir.hot_child_get(func, branch_id, 1)
  let first_fallthrough = @ir.hot_region_get(func, else_ref, 0)
  let second_fallthrough = @ir.hot_region_get(func, else_ref, 1)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, if_id)),
    0,
  )
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
  let branch_first_set = @ir.hot_region_get(func, then_ref, 0)
  let branch_second_set = @ir.hot_region_get(func, then_ref, 1)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 2), branch_id)
  @debug.assert_eq(@ir.hot_child_get(func, branch_first_set, 0), first_payload)
  @debug.assert_eq(
    @ir.hot_child_get(func, branch_second_set, 0),
    second_payload,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, else_ref), 2)
  let fallthrough_first_set = @ir.hot_region_get(func, else_ref, 0)
  let fallthrough_second_set = @ir.hot_region_get(func, else_ref, 1)
  @debug.assert_eq(
    @ir.hot_child_get(func, fallthrough_first_set, 0),
    first_fallthrough,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, fallthrough_second_set, 0),
    second_fallthrough,
  )
  let first_local = @ir.hot_node_get(func, branch_first_set).imm0
  let second_local = @ir.hot_node_get(func, branch_second_set).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, fallthrough_first_set).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, fallthrough_second_set).imm0,
    second_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_fallthrough), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_fallthrough), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected branch-targeted multivalue if routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes same-vector multivalue br_if block payloads once" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32 i64) (block (result i32 i64) call 1 call 2 call 3 br_if 0) return) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let block_id = @ir.hot_child_get(func, return_id, 0)
  @debug.assert_eq(@ir.hot_child_get(func, return_id, 1), block_id)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let branch_id = @ir.hot_region_get(func, body_ref, 0)
  let first_payload = @ir.hot_child_get(func, branch_id, 0)
  let second_payload = @ir.hot_child_get(func, branch_id, 1)
  let condition_id = @ir.hot_child_get(func, branch_id, 2)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_root_count(func), 2)
  @debug.assert_eq(@ir.hot_root_get(func, 0), block_id)
  @debug.assert_eq(@ir.hot_root_get(func, 1), return_id)
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, block_id)),
    0,
  )
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  let first_set = @ir.hot_region_get(func, body_ref, 0)
  let second_set = @ir.hot_region_get(func, body_ref, 1)
  let condition_set = @ir.hot_region_get(func, body_ref, 2)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 3), branch_id)
  @debug.assert_eq(@ir.hot_child_get(func, first_set, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_set, 0), second_payload)
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), condition_id)
  let flattened_condition = @ir.hot_child_get(func, branch_id, 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, flattened_condition).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, flattened_condition).imm0,
    @ir.hot_node_get(func, condition_set).imm0,
  )
  let first_local = @ir.hot_node_get(func, first_set).imm0
  let second_local = @ir.hot_node_get(func, second_set).imm0
  assert_false(first_local == second_local)
  @debug.assert_eq(
    @ir.hot_local_type(func, first_local),
    Some(@lib.ValType::i32()),
  )
  @debug.assert_eq(
    @ir.hot_local_type(func, second_local),
    Some(@lib.ValType::i64()),
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, condition_id), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected same-vector multivalue block br_if routing to verify, got \{err}",
      )
  }
}

///|
test "flatten shares multivalue if locals with same-vector br_if flow" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32 i64) (if (result i32 i64) (local.get 0) (then call 1 call 2 call 3 br_if 0) (else i32.const 11 i64.const 13)) return) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let if_id = @ir.hot_child_get(func, return_id, 0)
  @debug.assert_eq(@ir.hot_child_get(func, return_id, 1), if_id)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  let branch_id = @ir.hot_region_get(func, then_ref, 0)
  let first_payload = @ir.hot_child_get(func, branch_id, 0)
  let second_payload = @ir.hot_child_get(func, branch_id, 1)
  let branch_condition = @ir.hot_child_get(func, branch_id, 2)
  let else_first = @ir.hot_region_get(func, else_ref, 0)
  let else_second = @ir.hot_region_get(func, else_ref, 1)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, if_id)),
    0,
  )
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 4)
  let branch_first_set = @ir.hot_region_get(func, then_ref, 0)
  let branch_second_set = @ir.hot_region_get(func, then_ref, 1)
  let condition_set = @ir.hot_region_get(func, then_ref, 2)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 3), branch_id)
  @debug.assert_eq(@ir.hot_child_get(func, branch_first_set, 0), first_payload)
  @debug.assert_eq(
    @ir.hot_child_get(func, branch_second_set, 0),
    second_payload,
  )
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), branch_condition)
  @debug.assert_eq(@ir.hot_region_root_count(func, else_ref), 2)
  let else_first_set = @ir.hot_region_get(func, else_ref, 0)
  let else_second_set = @ir.hot_region_get(func, else_ref, 1)
  @debug.assert_eq(@ir.hot_child_get(func, else_first_set, 0), else_first)
  @debug.assert_eq(@ir.hot_child_get(func, else_second_set, 0), else_second)
  let first_local = @ir.hot_node_get(func, branch_first_set).imm0
  let second_local = @ir.hot_node_get(func, branch_second_set).imm0
  @debug.assert_eq(@ir.hot_node_get(func, else_first_set).imm0, first_local)
  @debug.assert_eq(@ir.hot_node_get(func, else_second_set).imm0, second_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, branch_condition), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, else_first), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, else_second), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected same-vector multivalue if br_if routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes branch-free multivalue loop results through typed locals" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32 i64) (loop (result i32 i64) (i32.add (i32.const 1) (i32.const 2)) (i64.add (i64.const 3) (i64.const 4))) return))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, return_id, 0)
  @debug.assert_eq(@ir.hot_child_get(func, return_id, 1), loop_id)
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
  @debug.assert_eq(@ir.hot_root_get(func, 1), return_id)
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 2)
  let first_set = @ir.hot_region_get(func, body_ref, 0)
  let second_set = @ir.hot_region_get(func, body_ref, 1)
  let first_local = @ir.hot_node_get(func, first_set).imm0
  let second_local = @ir.hot_node_get(func, second_set).imm0
  assert_false(first_local == second_local)
  @debug.assert_eq(
    @ir.hot_local_type(func, first_local),
    Some(@lib.ValType::i32()),
  )
  @debug.assert_eq(
    @ir.hot_local_type(func, second_local),
    Some(@lib.ValType::i64()),
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_local,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected branch-free multivalue loop routing to verify, got \{err}")
  }
}

///|
test "flatten routes multivalue loop results across payloadless backedges" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32 i64) (loop (result i32 i64) (br_if 0 (local.get 0)) (i32.add (i32.const 1) (i32.const 2)) (i64.add (i64.const 3) (i64.const 4))) return))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, return_id, 0)
  @debug.assert_eq(@ir.hot_child_get(func, return_id, 1), loop_id)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let branch_id = @ir.hot_region_get(func, body_ref, 0)
  let condition_id = @ir.hot_child_get(func, branch_id, 0)
  let first_tail = @ir.hot_region_get(func, body_ref, 1)
  let second_tail = @ir.hot_region_get(func, body_ref, 2)
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
  @debug.assert_eq(@ir.hot_root_get(func, 1), return_id)
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(@ir.hot_child_get(func, branch_id, 0), condition_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 3)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 0), branch_id)
  let first_set = @ir.hot_region_get(func, body_ref, 1)
  let second_set = @ir.hot_region_get(func, body_ref, 2)
  @debug.assert_eq(@ir.hot_child_get(func, first_set, 0), first_tail)
  @debug.assert_eq(@ir.hot_child_get(func, second_set, 0), second_tail)
  let first_local = @ir.hot_node_get(func, first_set).imm0
  let second_local = @ir.hot_node_get(func, second_set).imm0
  assert_false(first_local == second_local)
  @debug.assert_eq(
    @ir.hot_local_type(func, first_local),
    Some(@lib.ValType::i32()),
  )
  @debug.assert_eq(
    @ir.hot_local_type(func, second_local),
    Some(@lib.ValType::i64()),
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, condition_id), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_tail), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_tail), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected payloadless multivalue loop routing to verify, got \{err}")
  }
}

///|
test "flatten routes plain multivalue block br payloads through typed locals" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32 i64) (block (result i32 i64) (br 0 (i32.const 7) (i64.const 9))) return))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let block_id = @ir.hot_child_get(func, return_id, 0)
  @debug.assert_eq(@ir.hot_child_get(func, return_id, 1), block_id)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let branch_id = @ir.hot_region_get(func, body_ref, 0)
  let first_payload = @ir.hot_child_get(func, branch_id, 0)
  let second_payload = @ir.hot_child_get(func, branch_id, 1)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_root_count(func), 2)
  @debug.assert_eq(@ir.hot_root_get(func, 0), block_id)
  @debug.assert_eq(@ir.hot_root_get(func, 1), return_id)
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, block_id)),
    0,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 3)
  let first_set = @ir.hot_region_get(func, body_ref, 0)
  let second_set = @ir.hot_region_get(func, body_ref, 1)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 2), branch_id)
  @debug.assert_eq(@ir.hot_child_get(func, first_set, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_set, 0), second_payload)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 0)
  let first_local = @ir.hot_node_get(func, first_set).imm0
  let second_local = @ir.hot_node_get(func, second_set).imm0
  assert_false(first_local == second_local)
  @debug.assert_eq(
    @ir.hot_local_type(func, first_local),
    Some(@lib.ValType::i32()),
  )
  @debug.assert_eq(
    @ir.hot_local_type(func, second_local),
    Some(@lib.ValType::i64()),
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected plain multivalue block br routing to verify, got \{err}")
  }
}

///|
test "flatten routes mixed multivalue block fallthrough and nested br exits" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32 i64) (block (result i32 i64) local.get 0 if i32.const 7 i64.const 9 br 1 end i32.const 11 i64.const 13) return))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let block_id = @ir.hot_child_get(func, return_id, 0)
  @debug.assert_eq(@ir.hot_child_get(func, return_id, 1), block_id)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let if_id = @ir.hot_region_get(func, body_ref, 0)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let branch_id = @ir.hot_region_get(func, then_ref, 0)
  let first_payload = @ir.hot_child_get(func, branch_id, 0)
  let second_payload = @ir.hot_child_get(func, branch_id, 1)
  let first_fallthrough = @ir.hot_region_get(func, body_ref, 1)
  let second_fallthrough = @ir.hot_region_get(func, body_ref, 2)
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
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
  let branch_first_set = @ir.hot_region_get(func, then_ref, 0)
  let branch_second_set = @ir.hot_region_get(func, then_ref, 1)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 2), branch_id)
  @debug.assert_eq(@ir.hot_child_get(func, branch_first_set, 0), first_payload)
  @debug.assert_eq(
    @ir.hot_child_get(func, branch_second_set, 0),
    second_payload,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 3)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 0), if_id)
  let fallthrough_first_set = @ir.hot_region_get(func, body_ref, 1)
  let fallthrough_second_set = @ir.hot_region_get(func, body_ref, 2)
  @debug.assert_eq(
    @ir.hot_child_get(func, fallthrough_first_set, 0),
    first_fallthrough,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, fallthrough_second_set, 0),
    second_fallthrough,
  )
  let first_local = @ir.hot_node_get(func, branch_first_set).imm0
  let second_local = @ir.hot_node_get(func, branch_second_set).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, fallthrough_first_set).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, fallthrough_second_set).imm0,
    second_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_fallthrough), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_fallthrough), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected mixed multivalue block routing to verify, got \{err}")
  }
}

///|
test "flatten routes scalar loop br_table payloads through entry locals" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32) (result i32))) (func (param i32) call 1 loop (type $carrier) drop local.get 0 if call 2 call 3 br_table 1 1 end i32.const 7 end drop) (func (result i32) i32.const 1) (func (result i32) i32.const 2) (func (result i32) i32.const 0))",
  )
  let loop_id = @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let if_id = @ir.hot_region_get(func, body_ref, 1)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let branch = @ir.hot_region_get(func, then_ref, 0)
  let payload = @ir.hot_child_get(func, branch, 0)
  let selector = @ir.hot_child_get(func, branch, 1)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  let entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).imm0
  let value_set = @ir.hot_region_get(func, then_ref, 0)
  let target_set = @ir.hot_region_get(func, then_ref, 1)
  let selector_set = @ir.hot_region_get(func, then_ref, 2)
  @debug.assert_eq(@ir.hot_child_get(func, value_set, 0), payload)
  assert_false(@ir.hot_node_get(func, value_set).imm0 == entry_local)
  @debug.assert_eq(@ir.hot_node_get(func, target_set).imm0, entry_local)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 3), branch)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 4)
  let result_set = @ir.hot_region_get(
    func,
    body_ref,
    @ir.hot_region_root_count(func, body_ref) - 1,
  )
  assert_false(@ir.hot_node_get(func, result_set).imm0 == entry_local)
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected scalar loop br_table routing to verify, got \{err}")
  }
}

///|
test "flatten deduplicates ordered multivalue br_table block fanout" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32 i64) (block (result i32 i64) call 1 call 2 call 3 br_table 0 0 0) return) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let block_id = @ir.hot_child_get(func, return_id, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let branch = @ir.hot_region_get(func, body_ref, 0)
  let first_payload = @ir.hot_child_get(func, branch, 0)
  let second_payload = @ir.hot_child_get(func, branch, 1)
  let selector = @ir.hot_child_get(func, branch, 2)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, block_id)),
    0,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 6)
  let first_stage = @ir.hot_region_get(func, body_ref, 0)
  let second_stage = @ir.hot_region_get(func, body_ref, 1)
  @debug.assert_eq(@ir.hot_child_get(func, first_stage, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_stage, 0), second_payload)
  let first_stage_local = @ir.hot_node_get(func, first_stage).imm0
  let second_stage_local = @ir.hot_node_get(func, second_stage).imm0
  assert_false(first_stage_local == second_stage_local)
  let first_copy = @ir.hot_region_get(func, body_ref, 2)
  let second_copy = @ir.hot_region_get(func, body_ref, 3)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_copy, 0)).imm0,
    first_stage_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_copy, 0)).imm0,
    second_stage_local,
  )
  let selector_set = @ir.hot_region_get(func, body_ref, 4)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 5), branch)
  let first_target_local = @ir.hot_node_get(func, first_copy).imm0
  let second_target_local = @ir.hot_node_get(func, second_copy).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_target_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_target_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected multivalue block br_table fanout to verify, got \{err}")
  }
}

///|
test "flatten fans ordered multivalue br_table payloads to nested block targets" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32 i64) (block (result i32 i64) (block (result i32 i64) call 1 call 2 call 3 br_table 0 1 1)) return) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let outer_block = @ir.hot_child_get(func, return_id, 0)
  let outer_ref = @ir.hot_region_body_ref(func, outer_block)
  let inner_block = @ir.hot_region_get(func, outer_ref, 0)
  let inner_ref = @ir.hot_region_body_ref(func, inner_block)
  let branch = @ir.hot_region_get(func, inner_ref, 0)
  let first_payload = @ir.hot_child_get(func, branch, 0)
  let second_payload = @ir.hot_child_get(func, branch, 1)
  let selector = @ir.hot_child_get(func, branch, 2)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_node_result_arity(func, inner_block), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, outer_block), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(
      func,
      @ir.hot_control_node_label(func, inner_block),
    ),
    0,
  )
  @debug.assert_eq(
    @ir.hot_label_branch_arity(
      func,
      @ir.hot_control_node_label(func, outer_block),
    ),
    0,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, inner_ref), 8)
  let first_stage = @ir.hot_region_get(func, inner_ref, 0)
  let second_stage = @ir.hot_region_get(func, inner_ref, 1)
  @debug.assert_eq(@ir.hot_child_get(func, first_stage, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_stage, 0), second_payload)
  let first_stage_local = @ir.hot_node_get(func, first_stage).imm0
  let second_stage_local = @ir.hot_node_get(func, second_stage).imm0
  let first_inner_copy = @ir.hot_region_get(func, inner_ref, 2)
  let second_inner_copy = @ir.hot_region_get(func, inner_ref, 3)
  let first_outer_copy = @ir.hot_region_get(func, inner_ref, 4)
  let second_outer_copy = @ir.hot_region_get(func, inner_ref, 5)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_inner_copy, 0)).imm0,
    first_stage_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_inner_copy, 0)).imm0,
    second_stage_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_outer_copy, 0)).imm0,
    first_stage_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_outer_copy, 0)).imm0,
    second_stage_local,
  )
  let selector_set = @ir.hot_region_get(func, inner_ref, 6)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  @debug.assert_eq(@ir.hot_region_get(func, inner_ref, 7), branch)
  let first_inner_local = @ir.hot_node_get(func, first_inner_copy).imm0
  let second_inner_local = @ir.hot_node_get(func, second_inner_copy).imm0
  let first_outer_local = @ir.hot_node_get(func, first_outer_copy).imm0
  let second_outer_local = @ir.hot_node_get(func, second_outer_copy).imm0
  assert_false(first_inner_local == first_outer_local)
  assert_false(second_inner_local == second_outer_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_outer_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_outer_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nested multivalue block br_table fanout to verify, got \{err}",
      )
  }
}

///|
test "flatten routes multivalue loop and block br_table channels" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32 i64))) (func (result i32 i64) block (result i32 i64) call 1 call 2 loop (type $carrier) drop drop call 5 if call 3 call 4 call 6 br_table 1 2 2 end i32.const 11 i64.const 13 end end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 1) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let block_id = @ir.hot_child_get(func, return_id, 0)
  let block_ref = @ir.hot_region_body_ref(func, block_id)
  let loop_id = @ir.hot_region_get(func, block_ref, 0)
  let first_entry = @ir.hot_child_get(func, loop_id, 0)
  let second_entry = @ir.hot_child_get(func, loop_id, 1)
  let loop_ref = @ir.hot_region_body_ref(func, loop_id)
  let mut if_id = -1
  for idx = 0; idx < @ir.hot_region_root_count(func, loop_ref); idx = idx + 1 {
    let candidate = @ir.hot_region_get(func, loop_ref, idx)
    match @ir.hot_node_get(func, candidate).op {
      @ir.HotOp::If => if_id = candidate
      _ => ()
    }
  }
  assert_true(if_id >= 0)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let branch = @ir.hot_region_get(func, then_ref, 0)
  let first_payload = @ir.hot_child_get(func, branch, 0)
  let second_payload = @ir.hot_child_get(func, branch, 1)
  let selector = @ir.hot_child_get(func, branch, 2)
  let initial_loop_root_count = @ir.hot_region_root_count(func, loop_ref)
  let first_fallthrough = @ir.hot_region_get(
    func,
    loop_ref,
    initial_loop_root_count - 2,
  )
  let second_fallthrough = @ir.hot_region_get(
    func,
    loop_ref,
    initial_loop_root_count - 1,
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 0)
  let first_entry_set = @ir.hot_region_get(func, block_ref, 0)
  let second_entry_set = @ir.hot_region_get(func, block_ref, 1)
  @debug.assert_eq(@ir.hot_child_get(func, first_entry_set, 0), first_entry)
  @debug.assert_eq(@ir.hot_child_get(func, second_entry_set, 0), second_entry)
  let first_entry_local = @ir.hot_node_get(func, first_entry_set).imm0
  let second_entry_local = @ir.hot_node_get(func, second_entry_set).imm0
  @debug.assert_eq(
    @ir.hot_local_type(func, first_entry_local),
    Some(@lib.ValType::i32()),
  )
  @debug.assert_eq(
    @ir.hot_local_type(func, second_entry_local),
    Some(@lib.ValType::i64()),
  )
  let loop_root = @ir.hot_region_get(func, block_ref, 2)
  @debug.assert_eq(loop_root, loop_id)
  let first_result_get = @ir.hot_region_get(func, block_ref, 3)
  let second_result_get = @ir.hot_region_get(func, block_ref, 4)
  let first_result_local = @ir.hot_node_get(func, first_result_get).imm0
  let second_result_local = @ir.hot_node_get(func, second_result_get).imm0
  assert_false(first_result_local == first_entry_local)
  assert_false(second_result_local == second_entry_local)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 8)
  let first_stage = @ir.hot_region_get(func, then_ref, 0)
  let second_stage = @ir.hot_region_get(func, then_ref, 1)
  @debug.assert_eq(@ir.hot_child_get(func, first_stage, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_stage, 0), second_payload)
  let first_stage_local = @ir.hot_node_get(func, first_stage).imm0
  let second_stage_local = @ir.hot_node_get(func, second_stage).imm0
  let first_loop_copy = @ir.hot_region_get(func, then_ref, 2)
  let second_loop_copy = @ir.hot_region_get(func, then_ref, 3)
  let first_block_copy = @ir.hot_region_get(func, then_ref, 4)
  let second_block_copy = @ir.hot_region_get(func, then_ref, 5)
  @debug.assert_eq(
    @ir.hot_node_get(func, first_loop_copy).imm0,
    first_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_loop_copy).imm0,
    second_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_loop_copy, 0)).imm0,
    first_stage_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_loop_copy, 0)).imm0,
    second_stage_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_block_copy, 0)).imm0,
    first_stage_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_block_copy, 0)).imm0,
    second_stage_local,
  )
  let selector_set = @ir.hot_region_get(func, then_ref, 6)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 7), branch)
  let first_block_local = @ir.hot_node_get(func, first_block_copy).imm0
  let second_block_local = @ir.hot_node_get(func, second_block_copy).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_block_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_block_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_entry), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_entry), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_fallthrough), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_fallthrough), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected multivalue loop/block table routing to verify, got \{err}")
  }
}

///|
test "flatten routes inputful multivalue loop plain br channels" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32 i64))) (func (result i32 i64) call 1 call 2 loop $loop (type $carrier) drop drop call 5 if call 3 call 4 br $loop end i32.const 11 i64.const 13 end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, return_id, 0)
  @debug.assert_eq(@ir.hot_child_get(func, return_id, 1), loop_id)
  let first_entry = @ir.hot_child_get(func, loop_id, 0)
  let second_entry = @ir.hot_child_get(func, loop_id, 1)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let if_id = @ir.hot_region_get(func, body_ref, 2)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let branch = @ir.hot_region_get(func, then_ref, 0)
  let first_payload = @ir.hot_child_get(func, branch, 0)
  let second_payload = @ir.hot_child_get(func, branch, 1)
  let first_fallthrough = @ir.hot_region_get(
    func,
    body_ref,
    @ir.hot_region_root_count(func, body_ref) - 2,
  )
  let second_fallthrough = @ir.hot_region_get(
    func,
    body_ref,
    @ir.hot_region_root_count(func, body_ref) - 1,
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
  let first_entry_set = @ir.hot_root_get(func, 0)
  let second_entry_set = @ir.hot_root_get(func, 1)
  @debug.assert_eq(@ir.hot_child_get(func, first_entry_set, 0), first_entry)
  @debug.assert_eq(@ir.hot_child_get(func, second_entry_set, 0), second_entry)
  @debug.assert_eq(@ir.hot_root_get(func, 2), loop_id)
  @debug.assert_eq(@ir.hot_root_get(func, 3), return_id)
  let first_entry_local = @ir.hot_node_get(func, first_entry_set).imm0
  let second_entry_local = @ir.hot_node_get(func, second_entry_set).imm0
  @debug.assert_eq(@ir.hot_child_count(func, branch), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 5)
  let first_payload_stage = @ir.hot_region_get(func, then_ref, 0)
  let second_payload_stage = @ir.hot_region_get(func, then_ref, 1)
  @debug.assert_eq(
    @ir.hot_child_get(func, first_payload_stage, 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, second_payload_stage, 0),
    second_payload,
  )
  let first_payload_set = @ir.hot_region_get(func, then_ref, 2)
  let second_payload_set = @ir.hot_region_get(func, then_ref, 3)
  @debug.assert_eq(
    @ir.hot_node_get(func, first_payload_set).imm0,
    first_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_payload_set).imm0,
    second_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_payload_set, 0)).imm0,
    @ir.hot_node_get(func, first_payload_stage).imm0,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_payload_set, 0)).imm0,
    @ir.hot_node_get(func, second_payload_stage).imm0,
  )
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 4), branch)
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  let first_result_local = @ir.hot_node_get(
      func,
      @ir.hot_child_get(func, return_id, 0),
    ).imm0
  let second_result_local = @ir.hot_node_get(
      func,
      @ir.hot_child_get(func, return_id, 1),
    ).imm0
  assert_false(first_result_local == first_entry_local)
  assert_false(second_result_local == second_entry_local)
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_entry), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_entry), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_fallthrough), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_fallthrough), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected inputful multivalue loop br routing to verify, got \{err}")
  }
}

///|
test "flatten routes exact inputful multivalue loop br_if flow" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32 i64))) (func (result i32 i64) call 1 call 2 loop $loop (type $carrier) drop drop call 3 call 4 call 5 br_if $loop drop drop i32.const 11 i64.const 13 end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, return_id, 0)
  let first_entry = @ir.hot_child_get(func, loop_id, 0)
  let second_entry = @ir.hot_child_get(func, loop_id, 1)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let branch = @ir.hot_region_get(func, body_ref, 2)
  let first_payload = @ir.hot_child_get(func, branch, 0)
  let second_payload = @ir.hot_child_get(func, branch, 1)
  let condition = @ir.hot_child_get(func, branch, 2)
  let first_fallthrough = @ir.hot_region_get(
    func,
    body_ref,
    @ir.hot_region_root_count(func, body_ref) - 2,
  )
  let second_fallthrough = @ir.hot_region_get(
    func,
    body_ref,
    @ir.hot_region_root_count(func, body_ref) - 1,
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  let first_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).imm0
  let second_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).imm0
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 10)
  let first_payload_set = @ir.hot_region_get(func, body_ref, 2)
  let second_payload_set = @ir.hot_region_get(func, body_ref, 3)
  let condition_set = @ir.hot_region_get(func, body_ref, 4)
  @debug.assert_eq(@ir.hot_child_get(func, first_payload_set, 0), first_payload)
  @debug.assert_eq(
    @ir.hot_child_get(func, second_payload_set, 0),
    second_payload,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, first_payload_set).imm0,
    first_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_payload_set).imm0,
    second_entry_local,
  )
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), condition)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 5), branch)
  for idx = 6; idx < 8; idx = idx + 1 {
    let drop_id = @ir.hot_region_get(func, body_ref, idx)
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, drop_id, 0)).op.to_string(),
      "LocalGet",
    )
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  let first_result_local = @ir.hot_node_get(
      func,
      @ir.hot_child_get(func, return_id, 0),
    ).imm0
  let second_result_local = @ir.hot_node_get(
      func,
      @ir.hot_child_get(func, return_id, 1),
    ).imm0
  assert_false(first_result_local == first_entry_local)
  assert_false(second_result_local == second_entry_local)
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_entry), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_entry), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, condition), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_fallthrough), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_fallthrough), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected exact inputful multivalue loop br_if to verify, got \{err}",
      )
  }
}

///|
test "flatten routes exact multivalue loop br_if expression consumers" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32 i64))) (func (result i32 i64) call 1 call 2 loop $loop (type $carrier) drop drop call 3 call 4 call 5 br_if $loop i64.const 0 i64.div_s drop i32.const 2 i32.add drop i32.const 11 i64.const 13 end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, return_id, 0)
  let first_entry = @ir.hot_child_get(func, loop_id, 0)
  let second_entry = @ir.hot_child_get(func, loop_id, 1)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let branch = @ir.hot_region_get(func, body_ref, 2)
  let first_payload = @ir.hot_child_get(func, branch, 0)
  let second_payload = @ir.hot_child_get(func, branch, 1)
  let condition = @ir.hot_child_get(func, branch, 2)
  let first_consumer = @ir.hot_region_get(func, body_ref, 3)
  let second_consumer = @ir.hot_region_get(func, body_ref, 4)
  @debug.assert_eq(
    @ir.hot_node_get(func, first_consumer).op.to_string(),
    "Drop",
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_consumer).op.to_string(),
    "Drop",
  )
  let first_consumer_value = @ir.hot_child_get(func, first_consumer, 0)
  let second_consumer_value = @ir.hot_child_get(func, second_consumer, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, first_consumer_value),
    Some(@lib.Instruction::i64_div_s()),
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, first_consumer_value, 0),
    second_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, second_consumer_value, 0),
    first_payload,
  )
  let first_fallthrough = @ir.hot_region_get(
    func,
    body_ref,
    @ir.hot_region_root_count(func, body_ref) - 2,
  )
  let second_fallthrough = @ir.hot_region_get(
    func,
    body_ref,
    @ir.hot_region_root_count(func, body_ref) - 1,
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  let first_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).imm0
  let second_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).imm0
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 12)
  let first_payload_set = @ir.hot_region_get(func, body_ref, 2)
  let second_payload_set = @ir.hot_region_get(func, body_ref, 3)
  let condition_set = @ir.hot_region_get(func, body_ref, 4)
  @debug.assert_eq(@ir.hot_child_get(func, first_payload_set, 0), first_payload)
  @debug.assert_eq(
    @ir.hot_child_get(func, second_payload_set, 0),
    second_payload,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, first_payload_set).imm0,
    first_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_payload_set).imm0,
    second_entry_local,
  )
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), condition)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 5), branch)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_consumer_value, 0)).imm0,
    second_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_consumer_value, 0)).imm0,
    first_entry_local,
  )
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 7), first_consumer)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, first_consumer_value),
    Some(@lib.Instruction::i64_div_s()),
  )
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 9), second_consumer)
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  let first_result_local = @ir.hot_node_get(
      func,
      @ir.hot_child_get(func, return_id, 0),
    ).imm0
  let second_result_local = @ir.hot_node_get(
      func,
      @ir.hot_child_get(func, return_id, 1),
    ).imm0
  assert_false(first_result_local == first_entry_local)
  assert_false(second_result_local == second_entry_local)
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_entry), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_entry), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, condition), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_fallthrough), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_fallthrough), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected multivalue loop br_if consumers to verify, got \{err}")
  }
}

///|
test "flatten intentionally leaves shared multivalue loop br_if flow fail closed" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32 i64))) (func (param i32 i64 i32) (result i32 i64) local.get 0 local.get 1 loop $loop (type $carrier) drop drop local.get 0 local.get 1 local.get 2 br_if $loop drop drop i32.const 11 i64.const 13 end return))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, return_id, 0)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let branch = @ir.hot_region_get(func, body_ref, 2)
  let first_payload = @ir.hot_child_get(func, branch, 0)
  let root_count = @ir.hot_region_root_count(func, body_ref)
  let roots : Array[Int] = []
  for idx = 0; idx < root_count; idx = idx + 1 {
    roots.push(@ir.hot_region_get(func, body_ref, idx))
    if idx == 2 {
      roots.push(@ir.hot_build_drop(func, first_payload))
    }
  }
  @ir.hot_region_replace_body(func, body_ref, roots)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::unchanged())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 3)
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 2)
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected shared multivalue loop br_if boundary to verify, got \{err}",
      )
  }
}

///|
test "flatten routes mixed multivalue loop and if table channels" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32 i64))) (func (result i32 i64) call 1 call 2 loop $loop (type $carrier) drop drop call 5 if $choice (result i32 i64) call 3 call 4 call 6 br_table $loop $choice $choice else i32.const 11 i64.const 13 end end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 1) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, return_id, 0)
  @debug.assert_eq(@ir.hot_child_get(func, return_id, 1), loop_id)
  let first_entry = @ir.hot_child_get(func, loop_id, 0)
  let second_entry = @ir.hot_child_get(func, loop_id, 1)
  let loop_ref = @ir.hot_region_body_ref(func, loop_id)
  let if_id = @ir.hot_region_get(func, loop_ref, 2)
  @debug.assert_eq(@ir.hot_region_get(func, loop_ref, 3), if_id)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  let branch = @ir.hot_region_get(func, then_ref, 0)
  let first_payload = @ir.hot_child_get(func, branch, 0)
  let second_payload = @ir.hot_child_get(func, branch, 1)
  let selector = @ir.hot_child_get(func, branch, 2)
  let first_else = @ir.hot_region_get(func, else_ref, 0)
  let second_else = @ir.hot_region_get(func, else_ref, 1)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_root_count(func), 4)
  let first_entry_set = @ir.hot_root_get(func, 0)
  let second_entry_set = @ir.hot_root_get(func, 1)
  @debug.assert_eq(@ir.hot_child_get(func, first_entry_set, 0), first_entry)
  @debug.assert_eq(@ir.hot_child_get(func, second_entry_set, 0), second_entry)
  @debug.assert_eq(@ir.hot_root_get(func, 2), loop_id)
  @debug.assert_eq(@ir.hot_root_get(func, 3), return_id)
  let first_entry_local = @ir.hot_node_get(func, first_entry_set).imm0
  let second_entry_local = @ir.hot_node_get(func, second_entry_set).imm0
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 8)
  let first_stage = @ir.hot_region_get(func, then_ref, 0)
  let second_stage = @ir.hot_region_get(func, then_ref, 1)
  @debug.assert_eq(@ir.hot_child_get(func, first_stage, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_stage, 0), second_payload)
  let first_loop_copy = @ir.hot_region_get(func, then_ref, 2)
  let second_loop_copy = @ir.hot_region_get(func, then_ref, 3)
  let first_if_copy = @ir.hot_region_get(func, then_ref, 4)
  let second_if_copy = @ir.hot_region_get(func, then_ref, 5)
  @debug.assert_eq(
    @ir.hot_node_get(func, first_loop_copy).imm0,
    first_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_loop_copy).imm0,
    second_entry_local,
  )
  let first_if_local = @ir.hot_node_get(func, first_if_copy).imm0
  let second_if_local = @ir.hot_node_get(func, second_if_copy).imm0
  assert_false(first_if_local == first_entry_local)
  assert_false(second_if_local == second_entry_local)
  let selector_set = @ir.hot_region_get(func, then_ref, 6)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 7), branch)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, 0)).imm0,
    first_if_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, 1)).imm0,
    second_if_local,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, loop_ref), 6)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, loop_ref, 2)).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(@ir.hot_region_get(func, loop_ref, 3), if_id)
  let first_result_set = @ir.hot_region_get(func, loop_ref, 4)
  let second_result_set = @ir.hot_region_get(func, loop_ref, 5)
  let first_result_local = @ir.hot_node_get(func, first_result_set).imm0
  let second_result_local = @ir.hot_node_get(func, second_result_set).imm0
  assert_false(first_result_local == first_entry_local)
  assert_false(first_result_local == first_if_local)
  assert_false(second_result_local == second_entry_local)
  assert_false(second_result_local == second_if_local)
  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, if_id)),
    0,
  )
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_entry), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_entry), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_else), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_else), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected mixed loop/if table routing to verify, got \{err}")
  }
}

///|
test "flatten routes a block tail across mixed loop and block table channels" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32 i64))) (func (result i32 i64) block $exit (result i32 i64) call 1 call 2 loop $loop (type $carrier) drop drop block $choice (result i32 i64) call 3 call 4 call 5 br_table $loop $choice $exit end end end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let outer_block = @ir.hot_child_get(func, return_id, 0)
  @debug.assert_eq(@ir.hot_child_get(func, return_id, 1), outer_block)
  let outer_ref = @ir.hot_region_body_ref(func, outer_block)
  let loop_id = @ir.hot_region_get(func, outer_ref, 0)
  let first_entry = @ir.hot_child_get(func, loop_id, 0)
  let second_entry = @ir.hot_child_get(func, loop_id, 1)
  let loop_ref = @ir.hot_region_body_ref(func, loop_id)
  let inner_block = @ir.hot_region_get(func, loop_ref, 2)
  @debug.assert_eq(@ir.hot_region_get(func, loop_ref, 3), inner_block)
  let inner_ref = @ir.hot_region_body_ref(func, inner_block)
  let branch = @ir.hot_region_get(func, inner_ref, 0)
  let first_payload = @ir.hot_child_get(func, branch, 0)
  let second_payload = @ir.hot_child_get(func, branch, 1)
  let selector = @ir.hot_child_get(func, branch, 2)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_node_result_arity(func, inner_block), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, outer_block), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(
      func,
      @ir.hot_control_node_label(func, inner_block),
    ),
    0,
  )
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  @debug.assert_eq(
    @ir.hot_label_branch_arity(
      func,
      @ir.hot_control_node_label(func, outer_block),
    ),
    0,
  )
  let first_entry_set = @ir.hot_region_get(func, outer_ref, 0)
  let second_entry_set = @ir.hot_region_get(func, outer_ref, 1)
  @debug.assert_eq(@ir.hot_child_get(func, first_entry_set, 0), first_entry)
  @debug.assert_eq(@ir.hot_child_get(func, second_entry_set, 0), second_entry)
  let first_entry_local = @ir.hot_node_get(func, first_entry_set).imm0
  let second_entry_local = @ir.hot_node_get(func, second_entry_set).imm0
  @debug.assert_eq(@ir.hot_region_root_count(func, inner_ref), 10)
  let first_stage = @ir.hot_region_get(func, inner_ref, 0)
  let second_stage = @ir.hot_region_get(func, inner_ref, 1)
  @debug.assert_eq(@ir.hot_child_get(func, first_stage, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_stage, 0), second_payload)
  let first_stage_local = @ir.hot_node_get(func, first_stage).imm0
  let second_stage_local = @ir.hot_node_get(func, second_stage).imm0
  let first_loop_copy = @ir.hot_region_get(func, inner_ref, 2)
  let second_loop_copy = @ir.hot_region_get(func, inner_ref, 3)
  let first_inner_copy = @ir.hot_region_get(func, inner_ref, 4)
  let second_inner_copy = @ir.hot_region_get(func, inner_ref, 5)
  let first_outer_copy = @ir.hot_region_get(func, inner_ref, 6)
  let second_outer_copy = @ir.hot_region_get(func, inner_ref, 7)
  @debug.assert_eq(
    @ir.hot_node_get(func, first_loop_copy).imm0,
    first_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_loop_copy).imm0,
    second_entry_local,
  )
  for copy_id in [first_loop_copy, first_inner_copy, first_outer_copy] {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, copy_id, 0)).imm0,
      first_stage_local,
    )
  }
  for copy_id in [second_loop_copy, second_inner_copy, second_outer_copy] {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, copy_id, 0)).imm0,
      second_stage_local,
    )
  }
  let first_inner_local = @ir.hot_node_get(func, first_inner_copy).imm0
  let second_inner_local = @ir.hot_node_get(func, second_inner_copy).imm0
  let first_outer_local = @ir.hot_node_get(func, first_outer_copy).imm0
  let second_outer_local = @ir.hot_node_get(func, second_outer_copy).imm0
  assert_false(first_inner_local == first_entry_local)
  assert_false(first_outer_local == first_entry_local)
  assert_false(first_outer_local == first_inner_local)
  assert_false(second_inner_local == second_entry_local)
  assert_false(second_outer_local == second_entry_local)
  assert_false(second_outer_local == second_inner_local)
  let selector_set = @ir.hot_region_get(func, inner_ref, 8)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  @debug.assert_eq(@ir.hot_region_get(func, inner_ref, 9), branch)
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_entry), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_entry), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected mixed loop/block tail table routing to verify, got \{err}")
  }
}
