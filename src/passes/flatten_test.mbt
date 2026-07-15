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
test "flatten routes a carried scalar br to its legacy try result channel" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let catch_tail = @ir.hot_build_const_i32(func, @lib.I32(11))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([catch_tail]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(3)),
    @ir.hot_build_const_i32(func, @lib.I32(4)),
  )
  @ir.hot_node_exact_instr_set(func, payload, @lib.Instruction::i32_add())
  let branch = @ir.hot_build_br(func, label_id, values=[payload])
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch])
  @ir.hot_delete_node(func, body_fallback)
  let drop_id = @ir.hot_build_drop(func, try_id)
  @ir.hot_root_append(func, drop_id)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 3)
  let staging_set = @ir.hot_region_get(func, body_ref, 0)
  let payload_set = @ir.hot_region_get(func, body_ref, 1)
  @debug.assert_eq(@ir.hot_child_get(func, staging_set, 0), payload)
  let staged_get = @ir.hot_child_get(func, payload_set, 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, staged_get).imm0,
    @ir.hot_node_get(func, staging_set).imm0,
  )
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 2), branch)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 1)
  let catch_set = @ir.hot_region_get(func, catch_ref, 0)
  let result_local = @ir.hot_node_get(func, payload_set).imm0
  @debug.assert_eq(@ir.hot_node_get(func, catch_set).imm0, result_local)
  @debug.assert_eq(@ir.hot_child_get(func, catch_set, 0), catch_tail)
  @debug.assert_eq(@ir.hot_local_type(func, result_local), Some(i32_type))
  let result_get = @ir.hot_child_get(func, drop_id, 0)
  @debug.assert_eq(@ir.hot_node_get(func, result_get).imm0, result_local)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected branch-targeted scalar legacy try to verify, got \{err}")
  }
}

///|
test "flatten routes an exact scalar br_if to its legacy try result channel" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let catch_tail = @ir.hot_build_const_i32(func, @lib.I32(11))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([catch_tail]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(3)),
    @ir.hot_build_const_i32(func, @lib.I32(4)),
  )
  @ir.hot_node_exact_instr_set(func, payload, @lib.Instruction::i32_add())
  let condition = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, condition, @lib.Instruction::i32_sub())
  let branch = @ir.hot_build_br_if(func, label_id, condition, values=[payload])
  let false_drop = @ir.hot_build_drop(func, payload)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch, false_drop, body_fallback,
  ])
  let result_drop = @ir.hot_build_drop(func, try_id)
  @ir.hot_root_append(func, result_drop)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  let payload_set = @ir.hot_region_get(func, body_ref, 0)
  let condition_set = @ir.hot_region_get(func, body_ref, 1)
  @debug.assert_eq(@ir.hot_child_get(func, payload_set, 0), payload)
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), condition)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 2), branch)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  let result_local = @ir.hot_node_get(func, payload_set).imm0
  let flattened_condition = @ir.hot_child_get(func, branch, 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, flattened_condition).imm0,
    @ir.hot_node_get(func, condition_set).imm0,
  )
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 3), false_drop)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, false_drop, 0)).imm0,
    result_local,
  )
  let fallback_set = @ir.hot_region_get(func, body_ref, 4)
  @debug.assert_eq(@ir.hot_node_get(func, fallback_set).imm0, result_local)
  @debug.assert_eq(@ir.hot_child_get(func, fallback_set, 0), body_fallback)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 1)
  let catch_set = @ir.hot_region_get(func, catch_ref, 0)
  @debug.assert_eq(@ir.hot_node_get(func, catch_set).imm0, result_local)
  @debug.assert_eq(@ir.hot_child_get(func, catch_set, 0), catch_tail)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, result_drop, 0)).imm0,
    result_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, condition), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected scalar try br_if routing to verify, got \{err}")
  }
}

///|
test "flatten preserves unary and conversion false flow from scalar try br_if" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let catch_tail = @ir.hot_build_const_i32(func, @lib.I32(11))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([catch_tail]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let first_condition = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(4)),
    @ir.hot_build_const_i32(func, @lib.I32(5)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    first_condition,
    @lib.Instruction::i32_sub(),
  )
  let first_branch = @ir.hot_build_br_if(func, label_id, first_condition, values=[
    first_payload,
  ])
  let unary = @ir.hot_build_unary(func, i32_type, first_payload)
  @ir.hot_node_exact_instr_set(func, unary, @lib.Instruction::i32_clz())
  let unary_drop = @ir.hot_build_drop(func, unary)
  let second_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i32_mul(),
  )
  let second_condition = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
    @ir.hot_build_const_i32(func, @lib.I32(8)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_condition,
    @lib.Instruction::i32_add(),
  )
  let second_branch = @ir.hot_build_br_if(func, label_id, second_condition, values=[
    second_payload,
  ])
  let conversion = @ir.hot_build_convert(func, i64_type, second_payload)
  @ir.hot_node_exact_instr_set(
    func,
    conversion,
    @lib.Instruction::i64_extend_i32s(),
  )
  let conversion_drop = @ir.hot_build_drop(func, conversion)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    first_branch, unary_drop, second_branch, conversion_drop, body_fallback,
  ])
  let result_drop = @ir.hot_build_drop(func, try_id)
  @ir.hot_root_append(func, result_drop)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 11)
  let first_payload_set = @ir.hot_region_get(func, body_ref, 0)
  let first_condition_set = @ir.hot_region_get(func, body_ref, 1)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 2), first_branch)
  let unary_set = @ir.hot_region_get(func, body_ref, 3)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 4), unary_drop)
  let second_payload_set = @ir.hot_region_get(func, body_ref, 5)
  let second_condition_set = @ir.hot_region_get(func, body_ref, 6)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 7), second_branch)
  let conversion_set = @ir.hot_region_get(func, body_ref, 8)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 9), conversion_drop)
  let fallback_set = @ir.hot_region_get(func, body_ref, 10)
  let result_local = @ir.hot_node_get(func, first_payload_set).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, second_payload_set).imm0,
    result_local,
  )
  @debug.assert_eq(@ir.hot_node_get(func, fallback_set).imm0, result_local)
  @debug.assert_eq(@ir.hot_child_get(func, first_payload_set, 0), first_payload)
  @debug.assert_eq(
    @ir.hot_child_get(func, second_payload_set, 0),
    second_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, first_condition_set, 0),
    first_condition,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, second_condition_set, 0),
    second_condition,
  )
  @debug.assert_eq(@ir.hot_child_count(func, first_branch), 1)
  @debug.assert_eq(@ir.hot_child_count(func, second_branch), 1)
  @debug.assert_eq(@ir.hot_child_get(func, unary_set, 0), unary)
  @debug.assert_eq(@ir.hot_child_get(func, conversion_set, 0), conversion)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, unary, 0)).imm0,
    result_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, conversion, 0)).imm0,
    result_local,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 1)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    result_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, result_drop, 0)).imm0,
    result_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_condition), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_condition), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected scalar try unary/conversion false flow to verify, got \{err}",
      )
  }
}

///|
test "flatten preserves a trapping binary false flow from scalar try br_if" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let catch_tail = @ir.hot_build_const_i32(func, @lib.I32(11))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([catch_tail]),
  )
  let payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(21)),
  )
  @ir.hot_node_exact_instr_set(func, payload, @lib.Instruction::i32_add())
  let condition = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, condition, @lib.Instruction::i32_sub())
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch = @ir.hot_build_br_if(func, label_id, condition, values=[payload])
  let divisor = @ir.hot_build_const_i32(func, @lib.I32(0))
  let binary = @ir.hot_build_binary(func, i32_type, payload, divisor)
  @ir.hot_node_exact_instr_set(func, binary, @lib.Instruction::i32_div_s())
  let binary_drop = @ir.hot_build_drop(func, binary)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch, binary_drop, body_fallback,
  ])
  let result_drop = @ir.hot_build_drop(func, try_id)
  @ir.hot_root_append(func, result_drop)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 6)
  let payload_set = @ir.hot_region_get(func, body_ref, 0)
  let condition_set = @ir.hot_region_get(func, body_ref, 1)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 2), branch)
  let binary_set = @ir.hot_region_get(func, body_ref, 3)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 4), binary_drop)
  let fallback_set = @ir.hot_region_get(func, body_ref, 5)
  @debug.assert_eq(@ir.hot_child_get(func, payload_set, 0), payload)
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), condition)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_child_get(func, binary_set, 0), binary)
  let result_local = @ir.hot_node_get(func, payload_set).imm0
  @debug.assert_eq(@ir.hot_node_get(func, fallback_set).imm0, result_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, binary, 0)).imm0,
    result_local,
  )
  @debug.assert_eq(@ir.hot_child_get(func, binary, 1), divisor)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 1)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    result_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, result_drop, 0)).imm0,
    result_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, condition), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected scalar try binary false flow to verify, got \{err}")
  }
}

///|
test "flatten preserves a reversed trapping binary false flow from scalar try br_if" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let catch_tail = @ir.hot_build_const_i32(func, @lib.I32(11))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([catch_tail]),
  )
  let payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(21)),
  )
  @ir.hot_node_exact_instr_set(func, payload, @lib.Instruction::i32_add())
  let condition = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, condition, @lib.Instruction::i32_sub())
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch = @ir.hot_build_br_if(func, label_id, condition, values=[payload])
  let dividend = @ir.hot_build_const_i32(func, @lib.I32(42))
  let binary = @ir.hot_build_binary(func, i32_type, dividend, payload)
  @ir.hot_node_exact_instr_set(func, binary, @lib.Instruction::i32_div_s())
  let binary_drop = @ir.hot_build_drop(func, binary)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch, binary_drop, body_fallback,
  ])
  let result_drop = @ir.hot_build_drop(func, try_id)
  @ir.hot_root_append(func, result_drop)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 6)
  let payload_set = @ir.hot_region_get(func, body_ref, 0)
  let condition_set = @ir.hot_region_get(func, body_ref, 1)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 2), branch)
  let binary_set = @ir.hot_region_get(func, body_ref, 3)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 4), binary_drop)
  let fallback_set = @ir.hot_region_get(func, body_ref, 5)
  @debug.assert_eq(@ir.hot_child_get(func, payload_set, 0), payload)
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), condition)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_child_get(func, binary_set, 0), binary)
  let result_local = @ir.hot_node_get(func, payload_set).imm0
  @debug.assert_eq(@ir.hot_node_get(func, fallback_set).imm0, result_local)
  @debug.assert_eq(@ir.hot_child_get(func, binary, 0), dividend)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, binary, 1)).imm0,
    result_local,
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, binary),
    Some(@lib.Instruction::i32_div_s()),
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 1)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    result_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, result_drop, 0)).imm0,
    result_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, condition), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected reversed scalar try binary false flow to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one repeated-target scalar br_table to a legacy try" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let catch_tail = @ir.hot_build_const_i32(func, @lib.I32(11))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([catch_tail]),
  )
  let payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, payload, @lib.Instruction::i32_add())
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch = @ir.hot_build_br_table(
    func,
    [label_id, label_id],
    label_id,
    selector,
    values=[payload],
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch])
  @ir.hot_delete_node(func, body_fallback)
  let result_drop = @ir.hot_build_drop(func, try_id)
  @ir.hot_root_append(func, result_drop)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  let stage_set = @ir.hot_region_get(func, body_ref, 0)
  let result_set = @ir.hot_region_get(func, body_ref, 1)
  let selector_set = @ir.hot_region_get(func, body_ref, 2)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 3), branch)
  @debug.assert_eq(@ir.hot_child_get(func, stage_set, 0), payload)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  let result_local = @ir.hot_node_get(func, result_set).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, result_set, 0)).imm0,
    @ir.hot_node_get(func, stage_set).imm0,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 1)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    result_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, result_drop, 0)).imm0,
    result_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repeated-target scalar try table to verify, got \{err}")
  }
}

///|
test "flatten routes one scalar br_table to legacy try and enclosing block channels" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type]),
  )
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let catch_tail = @ir.hot_build_const_i32(func, @lib.I32(11))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([catch_tail]),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::val_type(i32_type), [
    try_id,
  ])
  let try_label = @ir.hot_control_node_label(func, try_id)
  let block_label = @ir.hot_control_node_label(func, block_id)
  let payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, payload, @lib.Instruction::i32_add())
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, block_label],
    try_label,
    selector,
    values=[payload],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  @ir.hot_delete_node(func, body_fallback)
  let return_id = @ir.hot_build_return(func, [block_id])
  @ir.hot_root_append(func, return_id)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let block_body = @ir.hot_region_body_ref(func, block_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, try_label), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, block_label), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 5)
  let stage_set = @ir.hot_region_get(func, try_body, 0)
  let try_set = @ir.hot_region_get(func, try_body, 1)
  let block_set = @ir.hot_region_get(func, try_body, 2)
  let selector_set = @ir.hot_region_get(func, try_body, 3)
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 4), branch)
  @debug.assert_eq(@ir.hot_child_get(func, stage_set, 0), payload)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  let try_local = @ir.hot_node_get(func, try_set).imm0
  let block_local = @ir.hot_node_get(func, block_set).imm0
  assert_false(try_local == block_local)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 1)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    try_local,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, block_body), 2)
  @debug.assert_eq(@ir.hot_region_get(func, block_body, 0), try_id)
  let fallthrough_set = @ir.hot_region_get(func, block_body, 1)
  @debug.assert_eq(@ir.hot_node_get(func, fallthrough_set).imm0, block_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, fallthrough_set, 0)).imm0,
    try_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    block_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected mixed-target scalar try table to verify, got \{err}")
  }
}

///|
test "flatten routes one scalar br_table to a legacy try and directly enclosing if channels" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type]),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(9))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(i32_type),
    @ir.hot_build_local_get(func, 0),
    [try_id],
    else_body=Some([@ir.hot_build_const_i32(func, @lib.I32(13))]),
  )
  let payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, payload, @lib.Instruction::i32_add())
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let if_label = @ir.hot_control_node_label(func, if_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, if_label],
    try_label,
    selector,
    values=[payload],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [if_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, try_label), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, if_label), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 5)
  let stage_set = @ir.hot_region_get(func, try_body, 0)
  let try_set = @ir.hot_region_get(func, try_body, 1)
  let if_set = @ir.hot_region_get(func, try_body, 2)
  let selector_set = @ir.hot_region_get(func, try_body, 3)
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 4), branch)
  @debug.assert_eq(@ir.hot_child_get(func, stage_set, 0), payload)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  let try_local = @ir.hot_node_get(func, try_set).imm0
  let if_local = @ir.hot_node_get(func, if_set).imm0
  assert_false(try_local == if_local)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    try_local,
  )
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 2)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 0), try_id)
  let then_set = @ir.hot_region_get(func, then_ref, 1)
  @debug.assert_eq(@ir.hot_node_get(func, then_set).imm0, if_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, then_set, 0)).imm0,
    try_local,
  )
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, 0)).imm0,
    if_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    if_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected scalar try-plus-if table routing to verify, got \{err}")
  }
}

///|
test "flatten routes one scalar br_table through a legacy try and two directly enclosing if channels" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type]),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(9))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let inner_id = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(i32_type),
    @ir.hot_build_local_get(func, 0),
    [try_id],
    else_body=Some([@ir.hot_build_const_i32(func, @lib.I32(13))]),
  )
  let outer_id = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(i32_type),
    @ir.hot_build_local_get(func, 0),
    [inner_id],
    else_body=Some([@ir.hot_build_const_i32(func, @lib.I32(15))]),
  )
  let payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, payload, @lib.Instruction::i32_add())
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, inner_label, outer_label],
    try_label,
    selector,
    values=[payload],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outer_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, inner_id, outer_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in [try_label, inner_label, outer_label] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 6)
  let stage_set = @ir.hot_region_get(func, try_body, 0)
  let try_set = @ir.hot_region_get(func, try_body, 1)
  let inner_set = @ir.hot_region_get(func, try_body, 2)
  let outer_set = @ir.hot_region_get(func, try_body, 3)
  let selector_set = @ir.hot_region_get(func, try_body, 4)
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 5), branch)
  @debug.assert_eq(@ir.hot_child_get(func, stage_set, 0), payload)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  let target_locals = [
    @ir.hot_node_get(func, try_set).imm0,
    @ir.hot_node_get(func, inner_set).imm0,
    @ir.hot_node_get(func, outer_set).imm0,
  ]
  assert_false(target_locals[0] == target_locals[1])
  assert_false(target_locals[0] == target_locals[2])
  assert_false(target_locals[1] == target_locals[2])
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    target_locals[0],
  )
  let controls = [inner_id, outer_id]
  let children = [try_id, inner_id]
  for control_index = 0
      control_index < controls.length()
      control_index = control_index + 1 {
    let then_ref = @ir.hot_region_then_ref(func, controls[control_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 2)
    @debug.assert_eq(
      @ir.hot_region_get(func, then_ref, 0),
      children[control_index],
    )
    let copy_set = @ir.hot_region_get(func, then_ref, 1)
    @debug.assert_eq(
      @ir.hot_node_get(func, copy_set).imm0,
      target_locals[control_index + 1],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
      target_locals[control_index],
    )
    let else_ref = @ir.hot_region_else_ref(func, controls[control_index]).unwrap()
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, 0)).imm0,
      target_locals[control_index + 1],
    )
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    target_locals[2],
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected scalar try-plus-two-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one multivalue br_table through a legacy try and two directly enclosing if vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let inner_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [try_id, try_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  let outer_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [inner_id, inner_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(15)),
      @ir.hot_build_const_i64(func, @lib.I64(16L)),
    ]),
  )
  for entry in [[inner_id, 1], [outer_id, 2]] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, inner_label, outer_label],
    try_label,
    selector,
    values=[first_payload, second_payload],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outer_id, outer_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, inner_id, outer_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in [try_label, inner_label, outer_label] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 10)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 3; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 2 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 3 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    assert_false(target_locals[0][slot] == target_locals[1][slot])
    assert_false(target_locals[0][slot] == target_locals[2][slot])
    assert_false(target_locals[1][slot] == target_locals[2][slot])
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 8), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 9), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let controls = [inner_id, outer_id]
  let children = [try_id, inner_id]
  for control_index = 0
      control_index < controls.length()
      control_index = control_index + 1 {
    let then_ref = @ir.hot_region_then_ref(func, controls[control_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, then_ref, 0),
      children[control_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, then_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[control_index + 1][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[control_index][slot],
      )
    }
    let else_ref = @ir.hot_region_else_ref(func, controls[control_index]).unwrap()
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
        target_locals[control_index + 1][slot],
      )
    }
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[2][slot],
    )
  }
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected multivalue try-plus-two-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one scalar br_table through a legacy try enclosing block and if" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type]),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(9))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::val_type(i32_type), [
    try_id,
  ])
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(i32_type),
    @ir.hot_build_local_get(func, 0),
    [block_id],
    else_body=Some([@ir.hot_build_const_i32(func, @lib.I32(13))]),
  )
  let payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, payload, @lib.Instruction::i32_add())
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let block_label = @ir.hot_control_node_label(func, block_id)
  let if_label = @ir.hot_control_node_label(func, if_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, block_label, if_label],
    try_label,
    selector,
    values=[payload],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [if_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, block_id, if_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in [try_label, block_label, if_label] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 6)
  let stage_set = @ir.hot_region_get(func, try_body, 0)
  let try_set = @ir.hot_region_get(func, try_body, 1)
  let block_set = @ir.hot_region_get(func, try_body, 2)
  let if_set = @ir.hot_region_get(func, try_body, 3)
  let selector_set = @ir.hot_region_get(func, try_body, 4)
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 5), branch)
  @debug.assert_eq(@ir.hot_child_get(func, stage_set, 0), payload)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  let try_local = @ir.hot_node_get(func, try_set).imm0
  let block_local = @ir.hot_node_get(func, block_set).imm0
  let if_local = @ir.hot_node_get(func, if_set).imm0
  assert_false(try_local == block_local)
  assert_false(try_local == if_local)
  assert_false(block_local == if_local)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    try_local,
  )
  let block_body = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, block_body), 2)
  @debug.assert_eq(@ir.hot_region_get(func, block_body, 0), try_id)
  let block_fallthrough = @ir.hot_region_get(func, block_body, 1)
  @debug.assert_eq(@ir.hot_node_get(func, block_fallthrough).imm0, block_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, block_fallthrough, 0)).imm0,
    try_local,
  )
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 2)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 0), block_id)
  let if_fallthrough = @ir.hot_region_get(func, then_ref, 1)
  @debug.assert_eq(@ir.hot_node_get(func, if_fallthrough).imm0, if_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, if_fallthrough, 0)).imm0,
    block_local,
  )
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, 0)).imm0,
    if_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    if_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected scalar try-block-if table routing to verify, got \{err}")
  }
}

///|
test "flatten routes one scalar br_table through a legacy try two enclosing blocks and if" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type]),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(9))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let inner_id = @ir.hot_build_block(func, @lib.BlockType::val_type(i32_type), [
    try_id,
  ])
  let outer_id = @ir.hot_build_block(func, @lib.BlockType::val_type(i32_type), [
    inner_id,
  ])
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(i32_type),
    @ir.hot_build_local_get(func, 0),
    [outer_id],
    else_body=Some([@ir.hot_build_const_i32(func, @lib.I32(13))]),
  )
  let payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, payload, @lib.Instruction::i32_add())
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let if_label = @ir.hot_control_node_label(func, if_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, inner_label, outer_label, if_label],
    try_label,
    selector,
    values=[payload],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [if_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, inner_id, outer_id, if_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in [try_label, inner_label, outer_label, if_label] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 7)
  let stage_set = @ir.hot_region_get(func, try_body, 0)
  let target_locals : Array[Int] = []
  for target_index = 0; target_index < 4; target_index = target_index + 1 {
    target_locals.push(
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, target_index + 1),
      ).imm0,
    )
  }
  for left = 0; left < target_locals.length(); left = left + 1 {
    for right = left + 1; right < target_locals.length(); right = right + 1 {
      assert_false(target_locals[left] == target_locals[right])
    }
  }
  let selector_set = @ir.hot_region_get(func, try_body, 5)
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 6), branch)
  @debug.assert_eq(@ir.hot_child_get(func, stage_set, 0), payload)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    target_locals[0],
  )
  let controls = [inner_id, outer_id]
  let children = [try_id, inner_id]
  for control_index = 0
      control_index < controls.length()
      control_index = control_index + 1 {
    let body_ref = @ir.hot_region_body_ref(func, controls[control_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 2)
    @debug.assert_eq(
      @ir.hot_region_get(func, body_ref, 0),
      children[control_index],
    )
    let copy_set = @ir.hot_region_get(func, body_ref, 1)
    @debug.assert_eq(
      @ir.hot_node_get(func, copy_set).imm0,
      target_locals[control_index + 1],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
      target_locals[control_index],
    )
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 2)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 0), outer_id)
  let if_copy = @ir.hot_region_get(func, then_ref, 1)
  @debug.assert_eq(@ir.hot_node_get(func, if_copy).imm0, target_locals[3])
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, if_copy, 0)).imm0,
    target_locals[2],
  )
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, 0)).imm0,
    target_locals[3],
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    target_locals[3],
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected scalar try-two-block-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one multivalue br_table through a legacy try two enclosing blocks and if" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let inner_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  let outer_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    inner_id, inner_id,
  ])
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [outer_id, outer_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  for entry in [[inner_id, 1], [outer_id, 2], [if_id, 3]] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let if_label = @ir.hot_control_node_label(func, if_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, inner_label, outer_label, if_label],
    try_label,
    selector,
    values=[first_payload, second_payload],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [if_id, if_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, inner_id, outer_id, if_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in [try_label, inner_label, outer_label, if_label] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 12)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 4; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 2 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 3 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    for left = 0; left < target_locals.length(); left = left + 1 {
      for right = left + 1; right < target_locals.length(); right = right + 1 {
        assert_false(target_locals[left][slot] == target_locals[right][slot])
      }
    }
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 10), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 11), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let controls = [inner_id, outer_id]
  let children = [try_id, inner_id]
  for control_index = 0
      control_index < controls.length()
      control_index = control_index + 1 {
    let body_ref = @ir.hot_region_body_ref(func, controls[control_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, body_ref, 0),
      children[control_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, body_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[control_index + 1][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[control_index][slot],
      )
    }
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 0), outer_id)
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let if_copy = @ir.hot_region_get(func, then_ref, slot + 1)
    @debug.assert_eq(
      @ir.hot_node_get(func, if_copy).imm0,
      target_locals[3][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, if_copy, 0)).imm0,
      target_locals[2][slot],
    )
  }
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
      target_locals[3][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[3][slot],
    )
  }
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected multivalue try-two-block-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try two enclosing blocks and if" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let inner_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  let outer_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    inner_id, inner_id,
  ])
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [outer_id, outer_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  for entry in [[inner_id, 1], [outer_id, 2], [if_id, 3]] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let if_label = @ir.hot_control_node_label(func, if_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, inner_label, outer_label, if_label],
    try_label,
    selector,
    values=[tuple_id, tuple_id],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [if_id, if_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, inner_id, outer_id, if_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in [try_label, inner_label, outer_label, if_label] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 14)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 4; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 4 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 5 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    for left = 0; left < target_locals.length(); left = left + 1 {
      for right = left + 1; right < target_locals.length(); right = right + 1 {
        assert_false(target_locals[left][slot] == target_locals[right][slot])
      }
    }
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 12), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 13), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let controls = [inner_id, outer_id]
  let children = [try_id, inner_id]
  for control_index = 0
      control_index < controls.length()
      control_index = control_index + 1 {
    let body_ref = @ir.hot_region_body_ref(func, controls[control_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, body_ref, 0),
      children[control_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, body_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[control_index + 1][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[control_index][slot],
      )
    }
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 0), outer_id)
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let if_copy = @ir.hot_region_get(func, then_ref, slot + 1)
    @debug.assert_eq(
      @ir.hot_node_get(func, if_copy).imm0,
      target_locals[3][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, if_copy, 0)).imm0,
      target_locals[2][slot],
    )
  }
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
      target_locals[3][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[3][slot],
    )
  }
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue try-two-block-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one multivalue br_table through a legacy try enclosing block and if" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [block_id, block_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  for entry in [[block_id, 1], [if_id, 2]] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let branch = @ir.hot_build_br_table(
    func,
    [
      @ir.hot_control_node_label(func, try_id),
      @ir.hot_control_node_label(func, block_id),
      @ir.hot_control_node_label(func, if_id),
    ],
    @ir.hot_control_node_label(func, try_id),
    selector,
    values=[first_payload, second_payload],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    branch,
  ])
  let return_id = @ir.hot_build_return(func, [if_id, if_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, block_id, if_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  let try_label = @ir.hot_control_node_label(func, try_id)
  let block_label = @ir.hot_control_node_label(func, block_id)
  let if_label = @ir.hot_control_node_label(func, if_id)
  for label_id in [try_label, block_label, if_label] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 10)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 3; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 2 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 3 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    assert_false(target_locals[0][slot] == target_locals[1][slot])
    assert_false(target_locals[0][slot] == target_locals[2][slot])
    assert_false(target_locals[1][slot] == target_locals[2][slot])
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 8), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 9), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let block_body = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, block_body), 3)
  @debug.assert_eq(@ir.hot_region_get(func, block_body, 0), try_id)
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let block_set = @ir.hot_region_get(func, block_body, slot + 1)
    @debug.assert_eq(
      @ir.hot_node_get(func, block_set).imm0,
      target_locals[1][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, block_set, 0)).imm0,
      target_locals[0][slot],
    )
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 0), block_id)
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let if_set = @ir.hot_region_get(func, then_ref, slot + 1)
    @debug.assert_eq(
      @ir.hot_node_get(func, if_set).imm0,
      target_locals[2][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, if_set, 0)).imm0,
      target_locals[1][slot],
    )
  }
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
      target_locals[2][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[2][slot],
    )
  }
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected multivalue try-block-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try enclosing block and if" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [block_id, block_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  for entry in [[block_id, 1], [if_id, 2]] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let branch = @ir.hot_build_br_table(
    func,
    [
      @ir.hot_control_node_label(func, try_id),
      @ir.hot_control_node_label(func, block_id),
      @ir.hot_control_node_label(func, if_id),
    ],
    @ir.hot_control_node_label(func, try_id),
    selector,
    values=[tuple_id, tuple_id],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    branch,
  ])
  let return_id = @ir.hot_build_return(func, [if_id, if_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, block_id, if_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  let try_label = @ir.hot_control_node_label(func, try_id)
  let block_label = @ir.hot_control_node_label(func, block_id)
  let if_label = @ir.hot_control_node_label(func, if_id)
  for label_id in [try_label, block_label, if_label] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 12)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 3; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 4 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 5 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    assert_false(target_locals[0][slot] == target_locals[1][slot])
    assert_false(target_locals[0][slot] == target_locals[2][slot])
    assert_false(target_locals[1][slot] == target_locals[2][slot])
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 10), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 11), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let block_body = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, block_body), 3)
  @debug.assert_eq(@ir.hot_region_get(func, block_body, 0), try_id)
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let block_set = @ir.hot_region_get(func, block_body, slot + 1)
    @debug.assert_eq(
      @ir.hot_node_get(func, block_set).imm0,
      target_locals[1][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, block_set, 0)).imm0,
      target_locals[0][slot],
    )
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 0), block_id)
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let if_set = @ir.hot_region_get(func, then_ref, slot + 1)
    @debug.assert_eq(
      @ir.hot_node_get(func, if_set).imm0,
      target_locals[2][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, if_set, 0)).imm0,
      target_locals[1][slot],
    )
  }
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
      target_locals[2][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[2][slot],
    )
  }
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue try-block-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one multivalue br_table to a legacy try and directly enclosing if vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [try_id, try_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    if_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [],
      result_types,
    ),
  )
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let if_label = @ir.hot_control_node_label(func, if_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, if_label],
    try_label,
    selector,
    values=[first_payload, second_payload],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [if_id, if_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, try_label), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, if_label), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 8)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let try_locals = [
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 2)).imm0,
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 3)).imm0,
  ]
  let if_locals = [
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 4)).imm0,
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 5)).imm0,
  ]
  assert_false(try_locals[0] == if_locals[0])
  assert_false(try_locals[1] == if_locals[1])
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 6), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 7), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      try_locals[slot],
    )
    let then_set = @ir.hot_region_get(func, then_ref, slot + 1)
    @debug.assert_eq(@ir.hot_node_get(func, then_set).imm0, if_locals[slot])
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, then_set, 0)).imm0,
      try_locals[slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
      if_locals[slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      if_locals[slot],
    )
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 0), try_id)
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected multivalue try-plus-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one tuple-made multivalue br_table to a legacy try and directly enclosing if vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [try_id, try_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    if_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [],
      result_types,
    ),
  )
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let if_label = @ir.hot_control_node_label(func, if_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, if_label],
    try_label,
    selector,
    values=[tuple_id, tuple_id],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [if_id, if_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, try_label), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, if_label), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 10)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let try_locals = [
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 4)).imm0,
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 5)).imm0,
  ]
  let if_locals = [
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 6)).imm0,
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 7)).imm0,
  ]
  assert_false(try_locals[0] == if_locals[0])
  assert_false(try_locals[1] == if_locals[1])
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 8), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 9), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      try_locals[slot],
    )
    let then_set = @ir.hot_region_get(func, then_ref, slot + 1)
    @debug.assert_eq(@ir.hot_node_get(func, then_set).imm0, if_locals[slot])
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, then_set, 0)).imm0,
      try_locals[slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
      if_locals[slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      if_locals[slot],
    )
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 0), try_id)
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue try-plus-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try and two directly enclosing if vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let inner_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [try_id, try_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  let outer_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [inner_id, inner_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(15)),
      @ir.hot_build_const_i64(func, @lib.I64(16L)),
    ]),
  )
  for entry in [[inner_id, 1], [outer_id, 2]] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, inner_label, outer_label],
    try_label,
    selector,
    values=[tuple_id, tuple_id],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outer_id, outer_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, inner_id, outer_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in [try_label, inner_label, outer_label] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 12)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 3; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 4 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 5 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    for left = 0; left < target_locals.length(); left = left + 1 {
      for right = left + 1; right < target_locals.length(); right = right + 1 {
        assert_false(target_locals[left][slot] == target_locals[right][slot])
      }
    }
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 10), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 11), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let controls = [inner_id, outer_id]
  let children = [try_id, inner_id]
  for control_index = 0
      control_index < controls.length()
      control_index = control_index + 1 {
    let then_ref = @ir.hot_region_then_ref(func, controls[control_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, then_ref, 0),
      children[control_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, then_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[control_index + 1][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[control_index][slot],
      )
    }
    let else_ref = @ir.hot_region_else_ref(func, controls[control_index]).unwrap()
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
        target_locals[control_index + 1][slot],
      )
    }
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[2][slot],
    )
  }
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue try-plus-two-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try and three directly enclosing if vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let inner_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [try_id, try_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  let middle_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [inner_id, inner_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(15)),
      @ir.hot_build_const_i64(func, @lib.I64(16L)),
    ]),
  )
  let outer_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [middle_id, middle_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(17)),
      @ir.hot_build_const_i64(func, @lib.I64(18L)),
    ]),
  )
  for entry in [[inner_id, 1], [middle_id, 2], [outer_id, 3]] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let middle_label = @ir.hot_control_node_label(func, middle_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, inner_label, middle_label, outer_label],
    try_label,
    selector,
    values=[tuple_id, tuple_id],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outer_id, outer_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, inner_id, middle_id, outer_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in [try_label, inner_label, middle_label, outer_label] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 14)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 4; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 4 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 5 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    for left = 0; left < target_locals.length(); left = left + 1 {
      for right = left + 1; right < target_locals.length(); right = right + 1 {
        assert_false(target_locals[left][slot] == target_locals[right][slot])
      }
    }
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 12), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 13), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let controls = [inner_id, middle_id, outer_id]
  let children = [try_id, inner_id, middle_id]
  for control_index = 0
      control_index < controls.length()
      control_index = control_index + 1 {
    let then_ref = @ir.hot_region_then_ref(func, controls[control_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, then_ref, 0),
      children[control_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, then_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[control_index + 1][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[control_index][slot],
      )
    }
    let else_ref = @ir.hot_region_else_ref(func, controls[control_index]).unwrap()
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
        target_locals[control_index + 1][slot],
      )
    }
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[3][slot],
    )
  }
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue try-plus-three-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try and four directly enclosing if vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let inner_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [try_id, try_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  let middle_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [inner_id, inner_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(15)),
      @ir.hot_build_const_i64(func, @lib.I64(16L)),
    ]),
  )
  let outer_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [middle_id, middle_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(17)),
      @ir.hot_build_const_i64(func, @lib.I64(18L)),
    ]),
  )
  let outermost_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [outer_id, outer_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(19)),
      @ir.hot_build_const_i64(func, @lib.I64(20L)),
    ]),
  )
  for entry in [[inner_id, 1], [middle_id, 2], [outer_id, 3], [outermost_id, 4]] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let middle_label = @ir.hot_control_node_label(func, middle_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let outermost_label = @ir.hot_control_node_label(func, outermost_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, inner_label, middle_label, outer_label, outermost_label],
    try_label,
    selector,
    values=[tuple_id, tuple_id],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outermost_id, outermost_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, inner_id, middle_id, outer_id, outermost_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for
    label_id in [
      try_label, inner_label, middle_label, outer_label, outermost_label,
    ] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 16)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 5; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 4 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 5 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    for left = 0; left < target_locals.length(); left = left + 1 {
      for right = left + 1; right < target_locals.length(); right = right + 1 {
        assert_false(target_locals[left][slot] == target_locals[right][slot])
      }
    }
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 14), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 15), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let controls = [inner_id, middle_id, outer_id, outermost_id]
  let children = [try_id, inner_id, middle_id, outer_id]
  for control_index = 0
      control_index < controls.length()
      control_index = control_index + 1 {
    let then_ref = @ir.hot_region_then_ref(func, controls[control_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, then_ref, 0),
      children[control_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, then_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[control_index + 1][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[control_index][slot],
      )
    }
    let else_ref = @ir.hot_region_else_ref(func, controls[control_index]).unwrap()
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
        target_locals[control_index + 1][slot],
      )
    }
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[4][slot],
    )
  }
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue try-plus-four-if table routing to verify, got \{err}",
      )
  }
}

///|
fn flatten_assert_tuple_try_table_block_if_chain(
  block_count : Int,
  if_count : Int,
  expect_changed : Bool,
) -> Unit raise {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let controls : Array[Int] = [try_id]
  let labels : Array[Int] = [@ir.hot_control_node_label(func, try_id)]
  let blocks : Array[Int] = []
  let ifs : Array[Int] = []
  let mut child_id = try_id
  for block_index = 0; block_index < block_count; block_index = block_index + 1 {
    let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
      child_id, child_id,
    ])
    @ir.hot_control_result_type_set(
      func,
      block_id,
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(controls.length().to_uint())),
        [],
        result_types,
      ),
    )
    blocks.push(block_id)
    controls.push(block_id)
    labels.push(@ir.hot_control_node_label(func, block_id))
    child_id = block_id
  }
  for if_index = 0; if_index < if_count; if_index = if_index + 1 {
    let else_base = 13 + if_index * 2
    let if_id = @ir.hot_build_if(
      func,
      @lib.BlockType::void_(),
      @ir.hot_build_local_get(func, 2),
      [child_id, child_id],
      else_body=Some([
        @ir.hot_build_const_i32(func, @lib.I32(else_base)),
        @ir.hot_build_const_i64(func, @lib.I64((else_base + 1).to_int64())),
      ]),
    )
    @ir.hot_control_result_type_set(
      func,
      if_id,
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(controls.length().to_uint())),
        [],
        result_types,
      ),
    )
    ifs.push(if_id)
    controls.push(if_id)
    labels.push(@ir.hot_control_node_label(func, if_id))
    child_id = if_id
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let branch = @ir.hot_build_br_table(func, labels, labels[0], selector, values=[
    tuple_id, tuple_id,
  ])
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [child_id, child_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let result = flatten_run(ctx, func)
  if !expect_changed {
    @debug.assert_eq(result, HotPassResult::unchanged())
    @debug.assert_eq(@ir.hot_child_count(func, branch), 3)
    assert_true(@ir.hot_node_is_live(func, tuple_id))
    for control_id in controls {
      @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 2)
    }
    for label_id in labels {
      @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 2)
    }
    match pass_verify_before_after(ctx, func) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "expected deferred tuple-made try table chain to verify, got \{err}",
        )
    }
    return
  }
  @debug.assert_eq(result, HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in controls {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in labels {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  let target_count = controls.length()
  let expected_try_body_count = 6 + target_count * 2
  @debug.assert_eq(
    @ir.hot_region_root_count(func, try_body),
    expected_try_body_count,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0
      target_index < target_count
      target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 4 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 5 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    for left = 0; left < target_count; left = left + 1 {
      for right = left + 1; right < target_count; right = right + 1 {
        assert_false(target_locals[left][slot] == target_locals[right][slot])
      }
    }
  }
  @debug.assert_eq(
    @ir.hot_child_get(
      func,
      @ir.hot_region_get(func, try_body, expected_try_body_count - 2),
      0,
    ),
    selector,
  )
  @debug.assert_eq(
    @ir.hot_region_get(func, try_body, expected_try_body_count - 1),
    branch,
  )
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  for block_index = 0
      block_index < blocks.length()
      block_index = block_index + 1 {
    let body_ref = @ir.hot_region_body_ref(func, blocks[block_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, body_ref, 0),
      controls[block_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, body_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[block_index + 1][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[block_index][slot],
      )
    }
  }
  for if_index = 0; if_index < ifs.length(); if_index = if_index + 1 {
    let target_index = block_count + if_index + 1
    let then_ref = @ir.hot_region_then_ref(func, ifs[if_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, then_ref, 0),
      controls[target_index - 1],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, then_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[target_index][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[target_index - 1][slot],
      )
    }
    let else_ref = @ir.hot_region_else_ref(func, ifs[if_index]).unwrap()
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
        target_locals[target_index][slot],
      )
    }
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[target_count - 1][slot],
    )
  }
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple-made try table chain to verify, got \{err}")
  }
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try and five directly enclosing if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(0, 5, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try and six directly enclosing if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(0, 6, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try and seven directly enclosing if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(0, 7, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try enclosing block and seven if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(1, 7, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try two enclosing blocks and seven if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(2, 7, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try and eight directly enclosing if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(0, 8, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try enclosing block and eight if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(1, 8, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try two enclosing blocks and eight if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(2, 8, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try and nine directly enclosing if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(0, 9, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try enclosing block and nine if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(1, 9, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try two enclosing blocks and nine if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(2, 9, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try and ten directly enclosing if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(0, 10, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try enclosing block and ten if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(1, 10, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try two enclosing blocks and ten if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(2, 10, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try and eleven directly enclosing if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(0, 11, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try three enclosing blocks and thirty-two if vectors without a count cap" {
  flatten_assert_tuple_try_table_block_if_chain(3, 32, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try two enclosing blocks and six if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(2, 6, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try enclosing block and six if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(1, 6, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try two enclosing blocks and five if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(2, 5, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try enclosing block and five if vectors" {
  flatten_assert_tuple_try_table_block_if_chain(1, 5, true)
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try enclosing block and two if vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  let inner_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [block_id, block_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  let outer_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [inner_id, inner_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(15)),
      @ir.hot_build_const_i64(func, @lib.I64(16L)),
    ]),
  )
  for entry in [[block_id, 1], [inner_id, 2], [outer_id, 3]] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let block_label = @ir.hot_control_node_label(func, block_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, block_label, inner_label, outer_label],
    try_label,
    selector,
    values=[tuple_id, tuple_id],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outer_id, outer_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, block_id, inner_id, outer_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in [try_label, block_label, inner_label, outer_label] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 14)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 4; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 4 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 5 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    for left = 0; left < target_locals.length(); left = left + 1 {
      for right = left + 1; right < target_locals.length(); right = right + 1 {
        assert_false(target_locals[left][slot] == target_locals[right][slot])
      }
    }
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 12), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 13), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let block_body = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, block_body), 3)
  @debug.assert_eq(@ir.hot_region_get(func, block_body, 0), try_id)
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let copy_set = @ir.hot_region_get(func, block_body, slot + 1)
    @debug.assert_eq(
      @ir.hot_node_get(func, copy_set).imm0,
      target_locals[1][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
      target_locals[0][slot],
    )
  }
  let controls = [inner_id, outer_id]
  let children = [block_id, inner_id]
  for control_index = 0
      control_index < controls.length()
      control_index = control_index + 1 {
    let then_ref = @ir.hot_region_then_ref(func, controls[control_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, then_ref, 0),
      children[control_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, then_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[control_index + 2][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[control_index + 1][slot],
      )
    }
    let else_ref = @ir.hot_region_else_ref(func, controls[control_index]).unwrap()
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
        target_locals[control_index + 2][slot],
      )
    }
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[3][slot],
    )
  }
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue try-block-two-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try enclosing block and three if vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  let inner_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [block_id, block_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  let middle_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [inner_id, inner_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(15)),
      @ir.hot_build_const_i64(func, @lib.I64(16L)),
    ]),
  )
  let outer_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [middle_id, middle_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(17)),
      @ir.hot_build_const_i64(func, @lib.I64(18L)),
    ]),
  )
  for entry in [[block_id, 1], [inner_id, 2], [middle_id, 3], [outer_id, 4]] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let block_label = @ir.hot_control_node_label(func, block_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let middle_label = @ir.hot_control_node_label(func, middle_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, block_label, inner_label, middle_label, outer_label],
    try_label,
    selector,
    values=[tuple_id, tuple_id],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outer_id, outer_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, block_id, inner_id, middle_id, outer_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for
    label_id in [try_label, block_label, inner_label, middle_label, outer_label] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 16)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 5; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 4 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 5 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    for left = 0; left < target_locals.length(); left = left + 1 {
      for right = left + 1; right < target_locals.length(); right = right + 1 {
        assert_false(target_locals[left][slot] == target_locals[right][slot])
      }
    }
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 14), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 15), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let block_body = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, block_body), 3)
  @debug.assert_eq(@ir.hot_region_get(func, block_body, 0), try_id)
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let copy_set = @ir.hot_region_get(func, block_body, slot + 1)
    @debug.assert_eq(
      @ir.hot_node_get(func, copy_set).imm0,
      target_locals[1][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
      target_locals[0][slot],
    )
  }
  let controls = [inner_id, middle_id, outer_id]
  let children = [block_id, inner_id, middle_id]
  for control_index = 0
      control_index < controls.length()
      control_index = control_index + 1 {
    let then_ref = @ir.hot_region_then_ref(func, controls[control_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, then_ref, 0),
      children[control_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, then_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[control_index + 2][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[control_index + 1][slot],
      )
    }
    let else_ref = @ir.hot_region_else_ref(func, controls[control_index]).unwrap()
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
        target_locals[control_index + 2][slot],
      )
    }
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[4][slot],
    )
  }
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue try-block-three-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try enclosing block and four if vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  let inner_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [block_id, block_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  let middle_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [inner_id, inner_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(15)),
      @ir.hot_build_const_i64(func, @lib.I64(16L)),
    ]),
  )
  let outer_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [middle_id, middle_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(17)),
      @ir.hot_build_const_i64(func, @lib.I64(18L)),
    ]),
  )
  let outermost_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [outer_id, outer_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(19)),
      @ir.hot_build_const_i64(func, @lib.I64(20L)),
    ]),
  )
  for
    entry in [
      [block_id, 1],
      [inner_id, 2],
      [middle_id, 3],
      [outer_id, 4],
      [outermost_id, 5],
    ] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let block_label = @ir.hot_control_node_label(func, block_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let middle_label = @ir.hot_control_node_label(func, middle_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let outermost_label = @ir.hot_control_node_label(func, outermost_id)
  let branch = @ir.hot_build_br_table(
    func,
    [
      try_label, block_label, inner_label, middle_label, outer_label, outermost_label,
    ],
    try_label,
    selector,
    values=[tuple_id, tuple_id],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outermost_id, outermost_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for
    control_id in [
      try_id, block_id, inner_id, middle_id, outer_id, outermost_id,
    ] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for
    label_id in [
      try_label, block_label, inner_label, middle_label, outer_label, outermost_label,
    ] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 18)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 6; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 4 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 5 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    for left = 0; left < target_locals.length(); left = left + 1 {
      for right = left + 1; right < target_locals.length(); right = right + 1 {
        assert_false(target_locals[left][slot] == target_locals[right][slot])
      }
    }
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 16), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 17), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let block_body = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, block_body), 3)
  @debug.assert_eq(@ir.hot_region_get(func, block_body, 0), try_id)
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let copy_set = @ir.hot_region_get(func, block_body, slot + 1)
    @debug.assert_eq(
      @ir.hot_node_get(func, copy_set).imm0,
      target_locals[1][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
      target_locals[0][slot],
    )
  }
  let controls = [inner_id, middle_id, outer_id, outermost_id]
  let children = [block_id, inner_id, middle_id, outer_id]
  for control_index = 0
      control_index < controls.length()
      control_index = control_index + 1 {
    let then_ref = @ir.hot_region_then_ref(func, controls[control_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, then_ref, 0),
      children[control_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, then_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[control_index + 2][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[control_index + 1][slot],
      )
    }
    let else_ref = @ir.hot_region_else_ref(func, controls[control_index]).unwrap()
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
        target_locals[control_index + 2][slot],
      )
    }
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[5][slot],
    )
  }
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue try-block-four-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try two enclosing blocks and two if vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let inner_block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  let outer_block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    inner_block_id, inner_block_id,
  ])
  let inner_if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [outer_block_id, outer_block_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  let outer_if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [inner_if_id, inner_if_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(15)),
      @ir.hot_build_const_i64(func, @lib.I64(16L)),
    ]),
  )
  for
    entry in [
      [inner_block_id, 1],
      [outer_block_id, 2],
      [inner_if_id, 3],
      [outer_if_id, 4],
    ] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_block_label = @ir.hot_control_node_label(func, inner_block_id)
  let outer_block_label = @ir.hot_control_node_label(func, outer_block_id)
  let inner_if_label = @ir.hot_control_node_label(func, inner_if_id)
  let outer_if_label = @ir.hot_control_node_label(func, outer_if_id)
  let branch = @ir.hot_build_br_table(
    func,
    [
      try_label, inner_block_label, outer_block_label, inner_if_label, outer_if_label,
    ],
    try_label,
    selector,
    values=[tuple_id, tuple_id],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outer_if_id, outer_if_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for
    control_id in [
      try_id, inner_block_id, outer_block_id, inner_if_id, outer_if_id,
    ] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for
    label_id in [
      try_label, inner_block_label, outer_block_label, inner_if_label, outer_if_label,
    ] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 16)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 5; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 4 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 5 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    for left = 0; left < target_locals.length(); left = left + 1 {
      for right = left + 1; right < target_locals.length(); right = right + 1 {
        assert_false(target_locals[left][slot] == target_locals[right][slot])
      }
    }
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 14), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 15), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let blocks = [inner_block_id, outer_block_id]
  let block_children = [try_id, inner_block_id]
  for block_index = 0
      block_index < blocks.length()
      block_index = block_index + 1 {
    let body_ref = @ir.hot_region_body_ref(func, blocks[block_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, body_ref, 0),
      block_children[block_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, body_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[block_index + 1][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[block_index][slot],
      )
    }
  }
  let ifs = [inner_if_id, outer_if_id]
  let if_children = [outer_block_id, inner_if_id]
  for if_index = 0; if_index < ifs.length(); if_index = if_index + 1 {
    let then_ref = @ir.hot_region_then_ref(func, ifs[if_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, then_ref, 0),
      if_children[if_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, then_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[if_index + 3][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[if_index + 2][slot],
      )
    }
    let else_ref = @ir.hot_region_else_ref(func, ifs[if_index]).unwrap()
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
        target_locals[if_index + 3][slot],
      )
    }
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[4][slot],
    )
  }
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue try-two-block-two-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try two enclosing blocks and three if vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let inner_block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  let outer_block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    inner_block_id, inner_block_id,
  ])
  let inner_if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [outer_block_id, outer_block_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  let middle_if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [inner_if_id, inner_if_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(15)),
      @ir.hot_build_const_i64(func, @lib.I64(16L)),
    ]),
  )
  let outer_if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [middle_if_id, middle_if_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(17)),
      @ir.hot_build_const_i64(func, @lib.I64(18L)),
    ]),
  )
  for
    entry in [
      [inner_block_id, 1],
      [outer_block_id, 2],
      [inner_if_id, 3],
      [middle_if_id, 4],
      [outer_if_id, 5],
    ] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_block_label = @ir.hot_control_node_label(func, inner_block_id)
  let outer_block_label = @ir.hot_control_node_label(func, outer_block_id)
  let inner_if_label = @ir.hot_control_node_label(func, inner_if_id)
  let middle_if_label = @ir.hot_control_node_label(func, middle_if_id)
  let outer_if_label = @ir.hot_control_node_label(func, outer_if_id)
  let branch = @ir.hot_build_br_table(
    func,
    [
      try_label, inner_block_label, outer_block_label, inner_if_label, middle_if_label,
      outer_if_label,
    ],
    try_label,
    selector,
    values=[tuple_id, tuple_id],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outer_if_id, outer_if_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for
    control_id in [
      try_id, inner_block_id, outer_block_id, inner_if_id, middle_if_id, outer_if_id,
    ] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for
    label_id in [
      try_label, inner_block_label, outer_block_label, inner_if_label, middle_if_label,
      outer_if_label,
    ] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 18)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 6; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 4 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 5 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    for left = 0; left < target_locals.length(); left = left + 1 {
      for right = left + 1; right < target_locals.length(); right = right + 1 {
        assert_false(target_locals[left][slot] == target_locals[right][slot])
      }
    }
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 16), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 17), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let blocks = [inner_block_id, outer_block_id]
  let block_children = [try_id, inner_block_id]
  for block_index = 0
      block_index < blocks.length()
      block_index = block_index + 1 {
    let body_ref = @ir.hot_region_body_ref(func, blocks[block_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, body_ref, 0),
      block_children[block_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, body_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[block_index + 1][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[block_index][slot],
      )
    }
  }
  let ifs = [inner_if_id, middle_if_id, outer_if_id]
  let if_children = [outer_block_id, inner_if_id, middle_if_id]
  for if_index = 0; if_index < ifs.length(); if_index = if_index + 1 {
    let then_ref = @ir.hot_region_then_ref(func, ifs[if_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, then_ref, 0),
      if_children[if_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, then_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[if_index + 3][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[if_index + 2][slot],
      )
    }
    let else_ref = @ir.hot_region_else_ref(func, ifs[if_index]).unwrap()
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
        target_locals[if_index + 3][slot],
      )
    }
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[5][slot],
    )
  }
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue try-two-block-three-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one tuple-made multivalue br_table through a legacy try two enclosing blocks and four if vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let inner_block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  let outer_block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    inner_block_id, inner_block_id,
  ])
  let inner_if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [outer_block_id, outer_block_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  let middle_if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [inner_if_id, inner_if_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(15)),
      @ir.hot_build_const_i64(func, @lib.I64(16L)),
    ]),
  )
  let outer_if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [middle_if_id, middle_if_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(17)),
      @ir.hot_build_const_i64(func, @lib.I64(18L)),
    ]),
  )
  let outermost_if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [outer_if_id, outer_if_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(19)),
      @ir.hot_build_const_i64(func, @lib.I64(20L)),
    ]),
  )
  for
    entry in [
      [inner_block_id, 1],
      [outer_block_id, 2],
      [inner_if_id, 3],
      [middle_if_id, 4],
      [outer_if_id, 5],
      [outermost_if_id, 6],
    ] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_block_label = @ir.hot_control_node_label(func, inner_block_id)
  let outer_block_label = @ir.hot_control_node_label(func, outer_block_id)
  let inner_if_label = @ir.hot_control_node_label(func, inner_if_id)
  let middle_if_label = @ir.hot_control_node_label(func, middle_if_id)
  let outer_if_label = @ir.hot_control_node_label(func, outer_if_id)
  let outermost_if_label = @ir.hot_control_node_label(func, outermost_if_id)
  let branch = @ir.hot_build_br_table(
    func,
    [
      try_label, inner_block_label, outer_block_label, inner_if_label, middle_if_label,
      outer_if_label, outermost_if_label,
    ],
    try_label,
    selector,
    values=[tuple_id, tuple_id],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outermost_if_id, outermost_if_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for
    control_id in [
      try_id, inner_block_id, outer_block_id, inner_if_id, middle_if_id, outer_if_id,
      outermost_if_id,
    ] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for
    label_id in [
      try_label, inner_block_label, outer_block_label, inner_if_label, middle_if_label,
      outer_if_label, outermost_if_label,
    ] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 20)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 7; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 4 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 5 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    for left = 0; left < target_locals.length(); left = left + 1 {
      for right = left + 1; right < target_locals.length(); right = right + 1 {
        assert_false(target_locals[left][slot] == target_locals[right][slot])
      }
    }
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 18), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 19), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let blocks = [inner_block_id, outer_block_id]
  let block_children = [try_id, inner_block_id]
  for block_index = 0
      block_index < blocks.length()
      block_index = block_index + 1 {
    let body_ref = @ir.hot_region_body_ref(func, blocks[block_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, body_ref, 0),
      block_children[block_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, body_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[block_index + 1][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[block_index][slot],
      )
    }
  }
  let ifs = [inner_if_id, middle_if_id, outer_if_id, outermost_if_id]
  let if_children = [outer_block_id, inner_if_id, middle_if_id, outer_if_id]
  for if_index = 0; if_index < ifs.length(); if_index = if_index + 1 {
    let then_ref = @ir.hot_region_then_ref(func, ifs[if_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, then_ref, 0),
      if_children[if_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let copy_set = @ir.hot_region_get(func, then_ref, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, copy_set).imm0,
        target_locals[if_index + 3][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
        target_locals[if_index + 2][slot],
      )
    }
    let else_ref = @ir.hot_region_else_ref(func, ifs[if_index]).unwrap()
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
        target_locals[if_index + 3][slot],
      )
    }
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[6][slot],
    )
  }
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue try-two-block-four-if table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one scalar br_table to legacy try and two enclosing block channels" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type]),
  )
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let inner_id = @ir.hot_build_block(func, @lib.BlockType::val_type(i32_type), [
    try_id,
  ])
  let outer_id = @ir.hot_build_block(func, @lib.BlockType::val_type(i32_type), [
    inner_id,
  ])
  let payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, payload, @lib.Instruction::i32_add())
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, inner_label, outer_label],
    try_label,
    selector,
    values=[payload],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  @ir.hot_delete_node(func, body_fallback)
  let return_id = @ir.hot_build_return(func, [outer_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, inner_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, outer_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, try_label), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, inner_label), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, outer_label), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 6)
  let stage_set = @ir.hot_region_get(func, try_body, 0)
  let try_set = @ir.hot_region_get(func, try_body, 1)
  let inner_set = @ir.hot_region_get(func, try_body, 2)
  let outer_set = @ir.hot_region_get(func, try_body, 3)
  let selector_set = @ir.hot_region_get(func, try_body, 4)
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 5), branch)
  @debug.assert_eq(@ir.hot_child_get(func, stage_set, 0), payload)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  let try_local = @ir.hot_node_get(func, try_set).imm0
  let inner_local = @ir.hot_node_get(func, inner_set).imm0
  let outer_local = @ir.hot_node_get(func, outer_set).imm0
  assert_false(try_local == inner_local)
  assert_false(try_local == outer_local)
  assert_false(inner_local == outer_local)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 1)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    try_local,
  )
  let inner_body = @ir.hot_region_body_ref(func, inner_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, inner_body), 2)
  @debug.assert_eq(@ir.hot_region_get(func, inner_body, 0), try_id)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, inner_body, 1)).imm0,
    inner_local,
  )
  let outer_body = @ir.hot_region_body_ref(func, outer_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, outer_body), 2)
  @debug.assert_eq(@ir.hot_region_get(func, outer_body, 0), inner_id)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, outer_body, 1)).imm0,
    outer_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    outer_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected three-target scalar try table to verify, got \{err}")
  }
}

///|
test "flatten routes one scalar br_table to legacy try and three enclosing block channels" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type]),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(9))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let inner_id = @ir.hot_build_block(func, @lib.BlockType::val_type(i32_type), [
    try_id,
  ])
  let middle_id = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(i32_type),
    [inner_id],
  )
  let outer_id = @ir.hot_build_block(func, @lib.BlockType::val_type(i32_type), [
    middle_id,
  ])
  let payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, payload, @lib.Instruction::i32_add())
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let middle_label = @ir.hot_control_node_label(func, middle_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, inner_label, middle_label, outer_label],
    try_label,
    selector,
    values=[payload],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outer_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, inner_id, middle_id, outer_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in [try_label, inner_label, middle_label, outer_label] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 7)
  let stage_set = @ir.hot_region_get(func, try_body, 0)
  let try_set = @ir.hot_region_get(func, try_body, 1)
  let inner_set = @ir.hot_region_get(func, try_body, 2)
  let middle_set = @ir.hot_region_get(func, try_body, 3)
  let outer_set = @ir.hot_region_get(func, try_body, 4)
  let selector_set = @ir.hot_region_get(func, try_body, 5)
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 6), branch)
  @debug.assert_eq(@ir.hot_child_get(func, stage_set, 0), payload)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  let try_local = @ir.hot_node_get(func, try_set).imm0
  let inner_local = @ir.hot_node_get(func, inner_set).imm0
  let middle_local = @ir.hot_node_get(func, middle_set).imm0
  let outer_local = @ir.hot_node_get(func, outer_set).imm0
  assert_false(try_local == inner_local)
  assert_false(try_local == middle_local)
  assert_false(try_local == outer_local)
  assert_false(inner_local == middle_local)
  assert_false(inner_local == outer_local)
  assert_false(middle_local == outer_local)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 1)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    try_local,
  )
  let inner_body = @ir.hot_region_body_ref(func, inner_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, inner_body), 2)
  @debug.assert_eq(@ir.hot_region_get(func, inner_body, 0), try_id)
  let inner_fallthrough = @ir.hot_region_get(func, inner_body, 1)
  @debug.assert_eq(@ir.hot_node_get(func, inner_fallthrough).imm0, inner_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, inner_fallthrough, 0)).imm0,
    try_local,
  )
  let middle_body = @ir.hot_region_body_ref(func, middle_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, middle_body), 2)
  @debug.assert_eq(@ir.hot_region_get(func, middle_body, 0), inner_id)
  let middle_fallthrough = @ir.hot_region_get(func, middle_body, 1)
  @debug.assert_eq(
    @ir.hot_node_get(func, middle_fallthrough).imm0,
    middle_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, middle_fallthrough, 0)).imm0,
    inner_local,
  )
  let outer_body = @ir.hot_region_body_ref(func, outer_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, outer_body), 2)
  @debug.assert_eq(@ir.hot_region_get(func, outer_body, 0), middle_id)
  let outer_fallthrough = @ir.hot_region_get(func, outer_body, 1)
  @debug.assert_eq(@ir.hot_node_get(func, outer_fallthrough).imm0, outer_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, outer_fallthrough, 0)).imm0,
    middle_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    outer_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected four-target scalar try table to verify, got \{err}")
  }
}

///|
test "flatten routes one multivalue br_table to legacy try and enclosing block vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let body_first_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let body_second_fallback = @ir.hot_build_const_i64(func, @lib.I64(10L))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [body_first_fallback, body_second_fallback],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  @ir.hot_control_result_type_set(
    func,
    block_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [],
      result_types,
    ),
  )
  let try_label = @ir.hot_control_node_label(func, try_id)
  let block_label = @ir.hot_control_node_label(func, block_id)
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, block_label],
    try_label,
    selector,
    values=[first_payload, second_payload],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  @ir.hot_delete_node(func, body_first_fallback)
  @ir.hot_delete_node(func, body_second_fallback)
  let return_id = @ir.hot_build_return(func, [block_id, block_id])
  @ir.hot_root_append(func, return_id)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let block_body = @ir.hot_region_body_ref(func, block_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, try_label), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, block_label), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 8)
  let first_stage_set = @ir.hot_region_get(func, try_body, 0)
  let second_stage_set = @ir.hot_region_get(func, try_body, 1)
  let first_try_set = @ir.hot_region_get(func, try_body, 2)
  let second_try_set = @ir.hot_region_get(func, try_body, 3)
  let first_block_set = @ir.hot_region_get(func, try_body, 4)
  let second_block_set = @ir.hot_region_get(func, try_body, 5)
  let selector_set = @ir.hot_region_get(func, try_body, 6)
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 7), branch)
  @debug.assert_eq(@ir.hot_child_get(func, first_stage_set, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_stage_set, 0), second_payload)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  let first_try_local = @ir.hot_node_get(func, first_try_set).imm0
  let second_try_local = @ir.hot_node_get(func, second_try_set).imm0
  let first_block_local = @ir.hot_node_get(func, first_block_set).imm0
  let second_block_local = @ir.hot_node_get(func, second_block_set).imm0
  assert_false(first_try_local == first_block_local)
  assert_false(second_try_local == second_block_local)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    first_try_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 1)).imm0,
    second_try_local,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, block_body), 3)
  @debug.assert_eq(@ir.hot_region_get(func, block_body, 0), try_id)
  let first_fallthrough_set = @ir.hot_region_get(func, block_body, 1)
  let second_fallthrough_set = @ir.hot_region_get(func, block_body, 2)
  @debug.assert_eq(
    @ir.hot_node_get(func, first_fallthrough_set).imm0,
    first_block_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_fallthrough_set).imm0,
    second_block_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_fallthrough_set, 0)).imm0,
    first_try_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_fallthrough_set, 0)).imm0,
    second_try_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_block_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_block_local,
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected mixed-target multivalue try table to verify, got \{err}")
  }
}

///|
test "flatten routes one multivalue br_table to legacy try and two enclosing block vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let inner_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  @ir.hot_control_result_type_set(
    func,
    inner_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [],
      result_types,
    ),
  )
  let outer_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    inner_id, inner_id,
  ])
  @ir.hot_control_result_type_set(
    func,
    outer_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      [],
      result_types,
    ),
  )
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let branch = @ir.hot_build_br_table(
    func,
    [
      @ir.hot_control_node_label(func, try_id),
      @ir.hot_control_node_label(func, inner_id),
      @ir.hot_control_node_label(func, outer_id),
    ],
    @ir.hot_control_node_label(func, try_id),
    selector,
    values=[first_payload, second_payload],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outer_id, outer_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, inner_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, outer_id), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 10)
  let first_stage_set = @ir.hot_region_get(func, try_body, 0)
  let second_stage_set = @ir.hot_region_get(func, try_body, 1)
  let first_try_set = @ir.hot_region_get(func, try_body, 2)
  let second_try_set = @ir.hot_region_get(func, try_body, 3)
  let first_inner_set = @ir.hot_region_get(func, try_body, 4)
  let second_inner_set = @ir.hot_region_get(func, try_body, 5)
  let first_outer_set = @ir.hot_region_get(func, try_body, 6)
  let second_outer_set = @ir.hot_region_get(func, try_body, 7)
  let selector_set = @ir.hot_region_get(func, try_body, 8)
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 9), branch)
  @debug.assert_eq(@ir.hot_child_get(func, first_stage_set, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_stage_set, 0), second_payload)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  let first_try_local = @ir.hot_node_get(func, first_try_set).imm0
  let second_try_local = @ir.hot_node_get(func, second_try_set).imm0
  let first_inner_local = @ir.hot_node_get(func, first_inner_set).imm0
  let second_inner_local = @ir.hot_node_get(func, second_inner_set).imm0
  let first_outer_local = @ir.hot_node_get(func, first_outer_set).imm0
  let second_outer_local = @ir.hot_node_get(func, second_outer_set).imm0
  assert_false(first_try_local == first_inner_local)
  assert_false(first_try_local == first_outer_local)
  assert_false(first_inner_local == first_outer_local)
  assert_false(second_try_local == second_inner_local)
  assert_false(second_try_local == second_outer_local)
  assert_false(second_inner_local == second_outer_local)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    first_try_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 1)).imm0,
    second_try_local,
  )
  let inner_body = @ir.hot_region_body_ref(func, inner_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, inner_body), 3)
  @debug.assert_eq(@ir.hot_region_get(func, inner_body, 0), try_id)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, inner_body, 1)).imm0,
    first_inner_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, inner_body, 2)).imm0,
    second_inner_local,
  )
  let outer_body = @ir.hot_region_body_ref(func, outer_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, outer_body), 3)
  @debug.assert_eq(@ir.hot_region_get(func, outer_body, 0), inner_id)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, outer_body, 1)).imm0,
    first_outer_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, outer_body, 2)).imm0,
    second_outer_local,
  )
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
      fail("expected three-target multivalue try table to verify, got \{err}")
  }
}

///|
test "flatten routes one multivalue br_table to legacy try and three enclosing block vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let inner_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  @ir.hot_control_result_type_set(
    func,
    inner_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [],
      result_types,
    ),
  )
  let middle_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    inner_id, inner_id,
  ])
  @ir.hot_control_result_type_set(
    func,
    middle_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      [],
      result_types,
    ),
  )
  let outer_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    middle_id, middle_id,
  ])
  @ir.hot_control_result_type_set(
    func,
    outer_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
      [],
      result_types,
    ),
  )
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let middle_label = @ir.hot_control_node_label(func, middle_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, inner_label, middle_label, outer_label],
    try_label,
    selector,
    values=[first_payload, second_payload],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outer_id, outer_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, inner_id, middle_id, outer_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in [try_label, inner_label, middle_label, outer_label] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 12)
  let first_stage_set = @ir.hot_region_get(func, try_body, 0)
  let second_stage_set = @ir.hot_region_get(func, try_body, 1)
  @debug.assert_eq(@ir.hot_child_get(func, first_stage_set, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_stage_set, 0), second_payload)
  let try_locals = [
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 2)).imm0,
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 3)).imm0,
  ]
  let inner_locals = [
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 4)).imm0,
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 5)).imm0,
  ]
  let middle_locals = [
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 6)).imm0,
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 7)).imm0,
  ]
  let outer_locals = [
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 8)).imm0,
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 9)).imm0,
  ]
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    assert_false(try_locals[slot] == inner_locals[slot])
    assert_false(try_locals[slot] == middle_locals[slot])
    assert_false(try_locals[slot] == outer_locals[slot])
    assert_false(inner_locals[slot] == middle_locals[slot])
    assert_false(inner_locals[slot] == outer_locals[slot])
    assert_false(middle_locals[slot] == outer_locals[slot])
  }
  let selector_set = @ir.hot_region_get(func, try_body, 10)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 11), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      try_locals[slot],
    )
  }
  let owners = [try_id, inner_id, middle_id]
  let blocks = [inner_id, middle_id, outer_id]
  let from_locals = [try_locals, inner_locals, middle_locals]
  let to_locals = [inner_locals, middle_locals, outer_locals]
  for block_index = 0
      block_index < blocks.length()
      block_index = block_index + 1 {
    let block_body = @ir.hot_region_body_ref(func, blocks[block_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, block_body), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, block_body, 0),
      owners[block_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let fallthrough_set = @ir.hot_region_get(func, block_body, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, fallthrough_set).imm0,
        to_locals[block_index][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, fallthrough_set, 0)).imm0,
        from_locals[block_index][slot],
      )
    }
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    outer_locals[0],
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    outer_locals[1],
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected four-target multivalue try table to verify, got \{err}")
  }
}

///|
test "flatten routes one tuple-made multivalue br_table to legacy try and enclosing block vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  @ir.hot_control_result_type_set(
    func,
    block_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [],
      result_types,
    ),
  )
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let branch = @ir.hot_build_br_table(
    func,
    [
      @ir.hot_control_node_label(func, try_id),
      @ir.hot_control_node_label(func, block_id),
    ],
    @ir.hot_control_node_label(func, try_id),
    selector,
    values=[tuple_id, tuple_id],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [block_id, block_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 10)
  let first_value_set = @ir.hot_region_get(func, try_body, 0)
  let second_value_set = @ir.hot_region_get(func, try_body, 1)
  let first_stage_set = @ir.hot_region_get(func, try_body, 2)
  let second_stage_set = @ir.hot_region_get(func, try_body, 3)
  let first_try_set = @ir.hot_region_get(func, try_body, 4)
  let second_try_set = @ir.hot_region_get(func, try_body, 5)
  let first_block_set = @ir.hot_region_get(func, try_body, 6)
  let second_block_set = @ir.hot_region_get(func, try_body, 7)
  let selector_set = @ir.hot_region_get(func, try_body, 8)
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 9), branch)
  @debug.assert_eq(@ir.hot_child_get(func, first_value_set, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_value_set, 0), second_payload)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  let first_try_local = @ir.hot_node_get(func, first_try_set).imm0
  let second_try_local = @ir.hot_node_get(func, second_try_set).imm0
  let first_block_local = @ir.hot_node_get(func, first_block_set).imm0
  let second_block_local = @ir.hot_node_get(func, second_block_set).imm0
  assert_false(first_try_local == first_block_local)
  assert_false(second_try_local == second_block_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_try_set, 0)).imm0,
    @ir.hot_node_get(func, first_stage_set).imm0,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_try_set, 0)).imm0,
    @ir.hot_node_get(func, second_stage_set).imm0,
  )
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    first_try_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 1)).imm0,
    second_try_local,
  )
  let block_body = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, block_body), 3)
  @debug.assert_eq(@ir.hot_region_get(func, block_body, 0), try_id)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, block_body, 1)).imm0,
    first_block_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, block_body, 2)).imm0,
    second_block_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_block_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_block_local,
  )
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple-made mixed try table routing to verify, got \{err}")
  }
}

///|
test "flatten routes one tuple-made multivalue br_table to legacy try and two enclosing block vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let inner_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  @ir.hot_control_result_type_set(
    func,
    inner_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [],
      result_types,
    ),
  )
  let outer_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    inner_id, inner_id,
  ])
  @ir.hot_control_result_type_set(
    func,
    outer_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      [],
      result_types,
    ),
  )
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, inner_label, outer_label],
    try_label,
    selector,
    values=[tuple_id, tuple_id],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outer_id, outer_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, inner_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, outer_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, try_label), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, inner_label), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, outer_label), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 12)
  let first_value_set = @ir.hot_region_get(func, try_body, 0)
  let second_value_set = @ir.hot_region_get(func, try_body, 1)
  let first_stage_set = @ir.hot_region_get(func, try_body, 2)
  let second_stage_set = @ir.hot_region_get(func, try_body, 3)
  let first_try_set = @ir.hot_region_get(func, try_body, 4)
  let second_try_set = @ir.hot_region_get(func, try_body, 5)
  let first_inner_set = @ir.hot_region_get(func, try_body, 6)
  let second_inner_set = @ir.hot_region_get(func, try_body, 7)
  let first_outer_set = @ir.hot_region_get(func, try_body, 8)
  let second_outer_set = @ir.hot_region_get(func, try_body, 9)
  let selector_set = @ir.hot_region_get(func, try_body, 10)
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 11), branch)
  @debug.assert_eq(@ir.hot_child_get(func, first_value_set, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_value_set, 0), second_payload)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  let first_try_local = @ir.hot_node_get(func, first_try_set).imm0
  let second_try_local = @ir.hot_node_get(func, second_try_set).imm0
  let first_inner_local = @ir.hot_node_get(func, first_inner_set).imm0
  let second_inner_local = @ir.hot_node_get(func, second_inner_set).imm0
  let first_outer_local = @ir.hot_node_get(func, first_outer_set).imm0
  let second_outer_local = @ir.hot_node_get(func, second_outer_set).imm0
  assert_false(first_try_local == first_inner_local)
  assert_false(first_try_local == first_outer_local)
  assert_false(first_inner_local == first_outer_local)
  assert_false(second_try_local == second_inner_local)
  assert_false(second_try_local == second_outer_local)
  assert_false(second_inner_local == second_outer_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_try_set, 0)).imm0,
    @ir.hot_node_get(func, first_stage_set).imm0,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_try_set, 0)).imm0,
    @ir.hot_node_get(func, second_stage_set).imm0,
  )
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    first_try_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 1)).imm0,
    second_try_local,
  )
  let inner_body = @ir.hot_region_body_ref(func, inner_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, inner_body), 3)
  @debug.assert_eq(@ir.hot_region_get(func, inner_body, 0), try_id)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, inner_body, 1)).imm0,
    first_inner_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, inner_body, 2)).imm0,
    second_inner_local,
  )
  let outer_body = @ir.hot_region_body_ref(func, outer_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, outer_body), 3)
  @debug.assert_eq(@ir.hot_region_get(func, outer_body, 0), inner_id)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, outer_body, 1)).imm0,
    first_outer_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, outer_body, 2)).imm0,
    second_outer_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    first_outer_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    second_outer_local,
  )
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple-made three-target try table to verify, got \{err}")
  }
}

///|
test "flatten routes one tuple-made multivalue br_table to legacy try and three enclosing block vectors" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let inner_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id, try_id,
  ])
  let middle_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    inner_id, inner_id,
  ])
  let outer_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    middle_id, middle_id,
  ])
  for entry in [[inner_id, 1], [middle_id, 2], [outer_id, 3]] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  let middle_label = @ir.hot_control_node_label(func, middle_id)
  let outer_label = @ir.hot_control_node_label(func, outer_id)
  let branch = @ir.hot_build_br_table(
    func,
    [try_label, inner_label, middle_label, outer_label],
    try_label,
    selector,
    values=[tuple_id, tuple_id],
  )
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [outer_id, outer_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, inner_id, middle_id, outer_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in [try_label, inner_label, middle_label, outer_label] {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 14)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 4; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 4 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 5 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    for left = 0; left < target_locals.length(); left = left + 1 {
      for right = left + 1; right < target_locals.length(); right = right + 1 {
        assert_false(target_locals[left][slot] == target_locals[right][slot])
      }
    }
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 12), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 13), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let owners = [try_id, inner_id, middle_id]
  let blocks = [inner_id, middle_id, outer_id]
  for block_index = 0
      block_index < blocks.length()
      block_index = block_index + 1 {
    let block_body = @ir.hot_region_body_ref(func, blocks[block_index])
    @debug.assert_eq(@ir.hot_region_root_count(func, block_body), 3)
    @debug.assert_eq(
      @ir.hot_region_get(func, block_body, 0),
      owners[block_index],
    )
    for slot = 0; slot < result_types.length(); slot = slot + 1 {
      let fallthrough_set = @ir.hot_region_get(func, block_body, slot + 1)
      @debug.assert_eq(
        @ir.hot_node_get(func, fallthrough_set).imm0,
        target_locals[block_index + 1][slot],
      )
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, fallthrough_set, 0)).imm0,
        target_locals[block_index][slot],
      )
    }
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    target_locals[3][0],
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 1)).imm0,
    target_locals[3][1],
  )
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple-made four-target try table to verify, got \{err}")
  }
}

///|
test "flatten routes a tuple-made multivalue br to its legacy try result vector" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type, i64_type]),
  )
  let body_first_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let body_second_fallback = @ir.hot_build_const_i64(func, @lib.I64(10L))
  let catch_first = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(func, catch_first, @lib.Instruction::i32_add())
  let catch_second = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(12L)),
  )
  @ir.hot_node_exact_instr_set(func, catch_second, @lib.Instruction::i64_add())
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [body_first_fallback, body_second_fallback],
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
  let body_first = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  @ir.hot_node_exact_instr_set(func, body_first, @lib.Instruction::i32_sub())
  let body_second = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(8L)),
  )
  @ir.hot_node_exact_instr_set(func, body_second, @lib.Instruction::i64_sub())
  let tuple_id = @ir.hot_build_tuple_make(func, [i32_type, i64_type], [
    body_first, body_second,
  ])
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch = @ir.hot_build_br(func, label_id, values=[tuple_id, tuple_id])
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch])
  @ir.hot_delete_node(func, body_first_fallback)
  @ir.hot_delete_node(func, body_second_fallback)
  let return_id = @ir.hot_build_return(func, [try_id, try_id])
  @ir.hot_root_append(func, return_id)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 4), branch)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  let body_first_result_set = @ir.hot_region_get(func, body_ref, 2)
  let body_second_result_set = @ir.hot_region_get(func, body_ref, 3)
  let catch_first_result_set = @ir.hot_region_get(func, catch_ref, 0)
  let catch_second_result_set = @ir.hot_region_get(func, catch_ref, 1)
  let first_local = @ir.hot_node_get(func, body_first_result_set).imm0
  let second_local = @ir.hot_node_get(func, body_second_result_set).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, catch_first_result_set).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, catch_second_result_set).imm0,
    second_local,
  )
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
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, body_first), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, body_second), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, catch_first), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, catch_second), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue try branch routing to verify, got \{err}",
      )
  }
}

///|
test "flatten preserves unary and conversion false flow from scalar multivalue try lanes" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type, i64_type]),
  )
  let body_first_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let body_second_fallback = @ir.hot_build_const_i64(func, @lib.I64(10L))
  let catch_first = @ir.hot_build_const_i32(func, @lib.I32(11))
  let catch_second = @ir.hot_build_const_i64(func, @lib.I64(12L))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [body_first_fallback, body_second_fallback],
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
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let condition = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, condition, @lib.Instruction::i32_sub())
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch = @ir.hot_build_br_if(func, label_id, condition, values=[
    first_payload, second_payload,
  ])
  let unary = @ir.hot_build_unary(func, i64_type, second_payload)
  @ir.hot_node_exact_instr_set(func, unary, @lib.Instruction::i64_clz())
  let unary_drop = @ir.hot_build_drop(func, unary)
  let conversion = @ir.hot_build_convert(func, i64_type, first_payload)
  @ir.hot_node_exact_instr_set(
    func,
    conversion,
    @lib.Instruction::i64_extend_i32s(),
  )
  let conversion_drop = @ir.hot_build_drop(func, conversion)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch, unary_drop, conversion_drop, body_first_fallback, body_second_fallback,
  ])
  let return_id = @ir.hot_build_return(func, [try_id, try_id])
  @ir.hot_root_append(func, return_id)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 10)
  let first_result_set = @ir.hot_region_get(func, body_ref, 0)
  let second_result_set = @ir.hot_region_get(func, body_ref, 1)
  let condition_set = @ir.hot_region_get(func, body_ref, 2)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 3), branch)
  let unary_set = @ir.hot_region_get(func, body_ref, 4)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 5), unary_drop)
  let conversion_set = @ir.hot_region_get(func, body_ref, 6)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 7), conversion_drop)
  let first_fallback_set = @ir.hot_region_get(func, body_ref, 8)
  let second_fallback_set = @ir.hot_region_get(func, body_ref, 9)
  @debug.assert_eq(@ir.hot_child_get(func, first_result_set, 0), first_payload)
  @debug.assert_eq(
    @ir.hot_child_get(func, second_result_set, 0),
    second_payload,
  )
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), condition)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_child_get(func, unary_set, 0), unary)
  @debug.assert_eq(@ir.hot_child_get(func, conversion_set, 0), conversion)
  let first_local = @ir.hot_node_get(func, first_result_set).imm0
  let second_local = @ir.hot_node_get(func, second_result_set).imm0
  @debug.assert_eq(@ir.hot_node_get(func, first_fallback_set).imm0, first_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, second_fallback_set).imm0,
    second_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, unary, 0)).imm0,
    second_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, conversion, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, unary),
    Some(@lib.Instruction::i64_clz()),
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, conversion),
    Some(@lib.Instruction::i64_extend_i32s()),
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 1)).imm0,
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
  @debug.assert_eq(@ir.node_use_count(use_def, condition), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected scalar-lane multivalue try unary/conversion flow to verify, got \{err}",
      )
  }
}

///|
test "flatten preserves exact binary false flow from scalar multivalue try lanes" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type, i64_type]),
  )
  let body_first_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let body_second_fallback = @ir.hot_build_const_i64(func, @lib.I64(10L))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [body_first_fallback, body_second_fallback],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
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
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_sub())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_add(),
  )
  let condition = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, condition, @lib.Instruction::i32_sub())
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch = @ir.hot_build_br_if(func, label_id, condition, values=[
    first_payload, second_payload,
  ])
  let i64_divisor = @ir.hot_build_const_i64(func, @lib.I64(0L))
  let second_binary = @ir.hot_build_binary(
    func, i64_type, second_payload, i64_divisor,
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_binary,
    @lib.Instruction::i64_div_s(),
  )
  let second_drop = @ir.hot_build_drop(func, second_binary)
  let i32_right = @ir.hot_build_const_i32(func, @lib.I32(7))
  let first_binary = @ir.hot_build_binary(
    func, i32_type, first_payload, i32_right,
  )
  @ir.hot_node_exact_instr_set(func, first_binary, @lib.Instruction::i32_add())
  let first_drop = @ir.hot_build_drop(func, first_binary)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch, second_drop, first_drop, body_first_fallback, body_second_fallback,
  ])
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
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 10)
  let first_result_set = @ir.hot_region_get(func, body_ref, 0)
  let second_result_set = @ir.hot_region_get(func, body_ref, 1)
  let condition_set = @ir.hot_region_get(func, body_ref, 2)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 3), branch)
  let second_binary_set = @ir.hot_region_get(func, body_ref, 4)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 5), second_drop)
  let first_binary_set = @ir.hot_region_get(func, body_ref, 6)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 7), first_drop)
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), condition)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_child_get(func, second_binary_set, 0), second_binary)
  @debug.assert_eq(@ir.hot_child_get(func, first_binary_set, 0), first_binary)
  let first_local = @ir.hot_node_get(func, first_result_set).imm0
  let second_local = @ir.hot_node_get(func, second_result_set).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_binary, 0)).imm0,
    second_local,
  )
  @debug.assert_eq(@ir.hot_child_get(func, second_binary, 1), i64_divisor)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_binary, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(@ir.hot_child_get(func, first_binary, 1), i32_right)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, second_binary),
    Some(@lib.Instruction::i64_div_s()),
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, first_binary),
    Some(@lib.Instruction::i32_add()),
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, condition), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected scalar-lane multivalue try binary flow to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one tuple-made multivalue br_if to its legacy try result vector" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type, i64_type]),
  )
  let body_first_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let body_second_fallback = @ir.hot_build_const_i64(func, @lib.I64(10L))
  let catch_first = @ir.hot_build_const_i32(func, @lib.I32(11))
  let catch_second = @ir.hot_build_const_i64(func, @lib.I64(12L))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [body_first_fallback, body_second_fallback],
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
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, [i32_type, i64_type], [
    first_payload, second_payload,
  ])
  let condition = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, condition, @lib.Instruction::i32_sub())
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch = @ir.hot_build_br_if(func, label_id, condition, values=[
    tuple_id, tuple_id,
  ])
  let second_drop = @ir.hot_build_drop(func, tuple_id)
  let first_drop = @ir.hot_build_drop(func, tuple_id)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch, second_drop, first_drop, body_first_fallback, body_second_fallback,
  ])
  let return_id = @ir.hot_build_return(func, [try_id, try_id])
  @ir.hot_root_append(func, return_id)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 10)
  let first_value_set = @ir.hot_region_get(func, body_ref, 0)
  let second_value_set = @ir.hot_region_get(func, body_ref, 1)
  let first_result_set = @ir.hot_region_get(func, body_ref, 2)
  let second_result_set = @ir.hot_region_get(func, body_ref, 3)
  let condition_set = @ir.hot_region_get(func, body_ref, 4)
  @debug.assert_eq(@ir.hot_child_get(func, first_value_set, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_value_set, 0), second_payload)
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), condition)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 5), branch)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  let first_local = @ir.hot_node_get(func, first_result_set).imm0
  let second_local = @ir.hot_node_get(func, second_result_set).imm0
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 6), second_drop)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 7), first_drop)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_drop, 0)).imm0,
    second_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_drop, 0)).imm0,
    first_local,
  )
  let body_first_set = @ir.hot_region_get(func, body_ref, 8)
  let body_second_set = @ir.hot_region_get(func, body_ref, 9)
  @debug.assert_eq(@ir.hot_node_get(func, body_first_set).imm0, first_local)
  @debug.assert_eq(@ir.hot_node_get(func, body_second_set).imm0, second_local)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 1)).imm0,
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
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, condition), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected multivalue try br_if routing to verify, got \{err}")
  }
}

///|
test "flatten preserves unary and conversion false flow from tuple-made multivalue try lanes" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type, i64_type]),
  )
  let body_first_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let body_second_fallback = @ir.hot_build_const_i64(func, @lib.I64(10L))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [body_first_fallback, body_second_fallback],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
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
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, [i32_type, i64_type], [
    first_payload, second_payload,
  ])
  let condition = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, condition, @lib.Instruction::i32_sub())
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch = @ir.hot_build_br_if(func, label_id, condition, values=[
    tuple_id, tuple_id,
  ])
  let unary = @ir.hot_build_unary(func, i64_type, tuple_id)
  @ir.hot_node_exact_instr_set(func, unary, @lib.Instruction::i64_clz())
  let unary_drop = @ir.hot_build_drop(func, unary)
  let conversion = @ir.hot_build_convert(func, i64_type, tuple_id)
  @ir.hot_node_exact_instr_set(
    func,
    conversion,
    @lib.Instruction::i64_extend_i32s(),
  )
  let conversion_drop = @ir.hot_build_drop(func, conversion)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch, unary_drop, conversion_drop, body_first_fallback, body_second_fallback,
  ])
  let return_id = @ir.hot_build_return(func, [try_id, try_id])
  @ir.hot_root_append(func, return_id)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 12)
  let first_value_set = @ir.hot_region_get(func, body_ref, 0)
  let second_value_set = @ir.hot_region_get(func, body_ref, 1)
  let first_result_set = @ir.hot_region_get(func, body_ref, 2)
  let second_result_set = @ir.hot_region_get(func, body_ref, 3)
  let condition_set = @ir.hot_region_get(func, body_ref, 4)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 5), branch)
  let unary_set = @ir.hot_region_get(func, body_ref, 6)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 7), unary_drop)
  let conversion_set = @ir.hot_region_get(func, body_ref, 8)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 9), conversion_drop)
  let first_fallback_set = @ir.hot_region_get(func, body_ref, 10)
  let second_fallback_set = @ir.hot_region_get(func, body_ref, 11)
  @debug.assert_eq(@ir.hot_child_get(func, first_value_set, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_value_set, 0), second_payload)
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), condition)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_child_get(func, unary_set, 0), unary)
  @debug.assert_eq(@ir.hot_child_get(func, conversion_set, 0), conversion)
  let first_local = @ir.hot_node_get(func, first_result_set).imm0
  let second_local = @ir.hot_node_get(func, second_result_set).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, unary, 0)).imm0,
    second_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, conversion, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(@ir.hot_node_get(func, first_fallback_set).imm0, first_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, second_fallback_set).imm0,
    second_local,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
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
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, condition), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue try unary/conversion flow to verify, got \{err}",
      )
  }
}

///|
test "flatten preserves exact binary false flow from tuple-made multivalue try lanes" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type, i32_type]),
  )
  let body_first_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let body_second_fallback = @ir.hot_build_const_i32(func, @lib.I32(10))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [body_first_fallback, body_second_fallback],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i32(func, @lib.I32(12)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      [i32_type, i32_type],
    ),
  )
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i32(func, @lib.I32(4)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i32_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, [i32_type, i32_type], [
    first_payload, second_payload,
  ])
  let condition = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, condition, @lib.Instruction::i32_sub())
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch = @ir.hot_build_br_if(func, label_id, condition, values=[
    tuple_id, tuple_id,
  ])
  let second_binary = @ir.hot_build_binary(
    func,
    i32_type,
    tuple_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_binary,
    @lib.Instruction::i32_div_s(),
  )
  let first_binary = @ir.hot_build_binary(
    func,
    i32_type,
    tuple_id,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
  )
  @ir.hot_node_exact_instr_set(func, first_binary, @lib.Instruction::i32_add())
  let second_drop = @ir.hot_build_drop(func, second_binary)
  let first_drop = @ir.hot_build_drop(func, first_binary)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch, second_drop, first_drop, body_first_fallback, body_second_fallback,
  ])
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
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 12)
  let first_result_set = @ir.hot_region_get(func, body_ref, 2)
  let second_result_set = @ir.hot_region_get(func, body_ref, 3)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 5), branch)
  let second_binary_set = @ir.hot_region_get(func, body_ref, 6)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 7), second_drop)
  let first_binary_set = @ir.hot_region_get(func, body_ref, 8)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 9), first_drop)
  @debug.assert_eq(@ir.hot_child_get(func, second_binary_set, 0), second_binary)
  @debug.assert_eq(@ir.hot_child_get(func, first_binary_set, 0), first_binary)
  let first_local = @ir.hot_node_get(func, first_result_set).imm0
  let second_local = @ir.hot_node_get(func, second_result_set).imm0
  assert_false(first_local == second_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_binary, 0)).imm0,
    second_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_binary, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, second_binary),
    Some(@lib.Instruction::i32_div_s()),
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, first_binary),
    Some(@lib.Instruction::i32_add()),
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
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, condition), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue try binary flow to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one repeated-target tuple-made br_table to a legacy try" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type, i64_type]),
  )
  let body_first_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let body_second_fallback = @ir.hot_build_const_i64(func, @lib.I64(10L))
  let catch_first = @ir.hot_build_const_i32(func, @lib.I32(11))
  let catch_second = @ir.hot_build_const_i64(func, @lib.I64(12L))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [body_first_fallback, body_second_fallback],
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
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, [i32_type, i64_type], [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch = @ir.hot_build_br_table(
    func,
    [label_id, label_id],
    label_id,
    selector,
    values=[tuple_id, tuple_id],
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch])
  @ir.hot_delete_node(func, body_first_fallback)
  @ir.hot_delete_node(func, body_second_fallback)
  let return_id = @ir.hot_build_return(func, [try_id, try_id])
  @ir.hot_root_append(func, return_id)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 8)
  let first_value_set = @ir.hot_region_get(func, body_ref, 0)
  let second_value_set = @ir.hot_region_get(func, body_ref, 1)
  let first_stage_set = @ir.hot_region_get(func, body_ref, 2)
  let second_stage_set = @ir.hot_region_get(func, body_ref, 3)
  let first_result_set = @ir.hot_region_get(func, body_ref, 4)
  let second_result_set = @ir.hot_region_get(func, body_ref, 5)
  let selector_set = @ir.hot_region_get(func, body_ref, 6)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 7), branch)
  @debug.assert_eq(@ir.hot_child_get(func, first_value_set, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_value_set, 0), second_payload)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  let first_local = @ir.hot_node_get(func, first_result_set).imm0
  let second_local = @ir.hot_node_get(func, second_result_set).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_result_set, 0)).imm0,
    @ir.hot_node_get(func, first_stage_set).imm0,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_result_set, 0)).imm0,
    @ir.hot_node_get(func, second_stage_set).imm0,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 1)).imm0,
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
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected repeated-target try br_table routing to verify, got \{err}",
      )
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
test "flatten scalarizes exclusive tuple-made multivalue legacy try tails" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type, i64_type]),
  )
  let body_tuple = @ir.hot_build_tuple_make(func, [i32_type, i64_type], [
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_local_get(func, 1),
  ])
  let catch_tuple = @ir.hot_build_tuple_make(func, [i32_type, i64_type], [
    @ir.hot_build_const_i32(func, @lib.I32(3)),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  ])
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [body_tuple],
    catch_body=Some([catch_tuple]),
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
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, try_id)),
    0,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 2)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  let body_first_set = @ir.hot_region_get(func, body_ref, 0)
  let body_second_set = @ir.hot_region_get(func, body_ref, 1)
  let catch_first_set = @ir.hot_region_get(func, catch_ref, 0)
  let catch_second_set = @ir.hot_region_get(func, catch_ref, 1)
  let first_local = @ir.hot_node_get(func, body_first_set).imm0
  let second_local = @ir.hot_node_get(func, body_second_set).imm0
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
  assert_false(@ir.hot_node_is_live(func, body_tuple))
  assert_false(@ir.hot_node_is_live(func, catch_tuple))
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made multivalue legacy try routing to verify, got \{err}",
      )
  }
}

///|
test "flatten scalarizes rich tuple-made multivalue legacy try tails" {
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
  let body_tuple = @ir.hot_build_tuple_make(func, [i32_type, i64_type], [
    body_first, body_second,
  ])
  let catch_tuple = @ir.hot_build_tuple_make(func, [i32_type, i64_type], [
    catch_first, catch_second,
  ])
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [body_tuple],
    catch_body=Some([catch_tuple]),
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
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 4)
  let body_first_value_set = @ir.hot_region_get(func, body_ref, 0)
  let body_second_value_set = @ir.hot_region_get(func, body_ref, 1)
  let catch_first_value_set = @ir.hot_region_get(func, catch_ref, 0)
  let catch_second_value_set = @ir.hot_region_get(func, catch_ref, 1)
  @debug.assert_eq(@ir.hot_child_get(func, body_first_value_set, 0), body_first)
  @debug.assert_eq(
    @ir.hot_child_get(func, body_second_value_set, 0),
    body_second,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, catch_first_value_set, 0),
    catch_first,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, catch_second_value_set, 0),
    catch_second,
  )
  let body_first_result_set = @ir.hot_region_get(func, body_ref, 2)
  let body_second_result_set = @ir.hot_region_get(func, body_ref, 3)
  let catch_first_result_set = @ir.hot_region_get(func, catch_ref, 2)
  let catch_second_result_set = @ir.hot_region_get(func, catch_ref, 3)
  let first_local = @ir.hot_node_get(func, body_first_result_set).imm0
  let second_local = @ir.hot_node_get(func, body_second_result_set).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, catch_first_result_set).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, catch_second_result_set).imm0,
    second_local,
  )
  @debug.assert_eq(@ir.hot_local_type(func, first_local), Some(i32_type))
  @debug.assert_eq(@ir.hot_local_type(func, second_local), Some(i64_type))
  assert_false(@ir.hot_node_is_live(func, body_tuple))
  assert_false(@ir.hot_node_is_live(func, catch_tuple))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, body_first), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, body_second), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, catch_first), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, catch_second), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected rich tuple-made legacy try routing to verify, got \{err}")
  }
}

///|
test "flatten routes mixed tuple and scalar multivalue legacy try tails" {
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
  let body_tuple = @ir.hot_build_tuple_make(func, [i32_type, i64_type], [
    body_first, body_second,
  ])
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
    [body_tuple],
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
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, body_ref, 0), 0),
    body_first,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, body_ref, 1), 0),
    body_second,
  )
  let body_first_result_set = @ir.hot_region_get(func, body_ref, 2)
  let body_second_result_set = @ir.hot_region_get(func, body_ref, 3)
  let catch_first_result_set = @ir.hot_region_get(func, catch_ref, 0)
  let catch_second_result_set = @ir.hot_region_get(func, catch_ref, 1)
  let first_local = @ir.hot_node_get(func, body_first_result_set).imm0
  let second_local = @ir.hot_node_get(func, body_second_result_set).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, catch_first_result_set).imm0,
    first_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, catch_second_result_set).imm0,
    second_local,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, catch_first_result_set, 0),
    catch_first,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, catch_second_result_set, 0),
    catch_second,
  )
  assert_false(@ir.hot_node_is_live(func, body_tuple))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, body_first), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, body_second), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, catch_first), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, catch_second), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected mixed tuple/scalar legacy try routing to verify, got \{err}",
      )
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
test "flatten scalarizes one exact tuple-made inputful loop entry" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32))) (func (param i32 i64) call 1 loop (type $carrier) drop drop i32.const 7 end drop) (func (result i32 i64) i32.const 5 i64.const 6))",
  )
  let outer_drop = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, outer_drop, 0)
  let old_entry = @ir.hot_child_get(func, loop_id, 0)
  @debug.assert_eq(@ir.hot_child_get(func, loop_id, 1), old_entry)
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
  @ir.hot_child_set(func, loop_id, 0, tuple_id)
  @ir.hot_child_set(func, loop_id, 1, tuple_id)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  for root_idx = 0; root_idx < 2; root_idx = root_idx + 1 {
    let drop_id = @ir.hot_region_get(func, body_ref, root_idx)
    @debug.assert_eq(@ir.hot_node_get(func, drop_id).op.to_string(), "Drop")
    @debug.assert_eq(@ir.hot_child_get(func, drop_id, 0), old_entry)
    @ir.hot_child_set(func, drop_id, 0, tuple_id)
  }
  @ir.hot_delete_node(func, old_entry)
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
  @debug.assert_eq(@ir.hot_child_count(func, loop_id), 3)
  @debug.assert_eq(@ir.hot_root_count(func), 6)
  let first_value_set = @ir.hot_root_get(func, 0)
  let second_value_set = @ir.hot_root_get(func, 1)
  let first_entry_set = @ir.hot_root_get(func, 2)
  let second_entry_set = @ir.hot_root_get(func, 3)
  @debug.assert_eq(@ir.hot_child_get(func, first_value_set, 0), first_value)
  @debug.assert_eq(@ir.hot_child_get(func, second_value_set, 0), second_value)
  let first_local = @ir.hot_node_get(func, first_entry_set).imm0
  let second_local = @ir.hot_node_get(func, second_entry_set).imm0
  @debug.assert_eq(@ir.hot_local_type(func, first_local), Some(i32_type))
  @debug.assert_eq(@ir.hot_local_type(func, second_local), Some(i64_type))
  let first_drop = @ir.hot_region_get(func, body_ref, 0)
  let second_drop = @ir.hot_region_get(func, body_ref, 1)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_drop, 0)).imm0,
    second_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_drop, 0)).imm0,
    first_local,
  )
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_value), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_value), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made inputful loop entry routing to verify, got \{err}",
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
test "flatten scalarizes one exclusively owned tuple-made plain br payload" {
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
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
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
  let branch_id = @ir.hot_build_br(
    func,
    @ir.hot_control_node_label(func, block_id),
    values=[tuple_id, tuple_id],
  )
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id])
  let return_id = @ir.hot_build_return(func, [block_id, block_id])
  @ir.hot_root_append(func, return_id)
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
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  let first_value_set = @ir.hot_region_get(func, body_ref, 0)
  let second_value_set = @ir.hot_region_get(func, body_ref, 1)
  let first_result_set = @ir.hot_region_get(func, body_ref, 2)
  let second_result_set = @ir.hot_region_get(func, body_ref, 3)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 4), branch_id)
  @debug.assert_eq(@ir.hot_child_get(func, first_value_set, 0), first_value)
  @debug.assert_eq(@ir.hot_child_get(func, second_value_set, 0), second_value)
  let first_local = @ir.hot_node_get(func, first_result_set).imm0
  let second_local = @ir.hot_node_get(func, second_result_set).imm0
  assert_false(first_local == second_local)
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
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_value), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_value), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple-made plain br routing to verify, got \{err}")
  }
}

///|
test "flatten scalarizes one exclusively owned tuple-made br_table payload" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
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
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
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
  let label_id = @ir.hot_control_node_label(func, block_id)
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 2),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_add())
  let branch_id = @ir.hot_build_br_table(func, [label_id], label_id, selector, values=[
    tuple_id, tuple_id,
  ])
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id])
  let return_id = @ir.hot_build_return(func, [block_id, block_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, block_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 8)
  let first_value_set = @ir.hot_region_get(func, body_ref, 0)
  let second_value_set = @ir.hot_region_get(func, body_ref, 1)
  let first_stage = @ir.hot_region_get(func, body_ref, 2)
  let second_stage = @ir.hot_region_get(func, body_ref, 3)
  let first_target_set = @ir.hot_region_get(func, body_ref, 4)
  let second_target_set = @ir.hot_region_get(func, body_ref, 5)
  let selector_set = @ir.hot_region_get(func, body_ref, 6)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 7), branch_id)
  @debug.assert_eq(@ir.hot_child_get(func, first_value_set, 0), first_value)
  @debug.assert_eq(@ir.hot_child_get(func, second_value_set, 0), second_value)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_stage, 0)).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_stage, 0)).op.to_string(),
    "LocalGet",
  )
  let first_stage_local = @ir.hot_node_get(func, first_stage).imm0
  let second_stage_local = @ir.hot_node_get(func, second_stage).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_target_set, 0)).imm0,
    first_stage_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_target_set, 0)).imm0,
    second_stage_local,
  )
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector)
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_value), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_value), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple-made br_table routing to verify, got \{err}")
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
test "flatten scalarizes one exclusively owned tuple-made block br_if flow" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32 i64) (block (result i32 i64) call 1 call 2 call 3 br_if 0) return) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let block_id = @ir.hot_child_get(func, return_id, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let branch_id = @ir.hot_region_get(func, body_ref, 0)
  let first_payload = @ir.hot_child_get(func, branch_id, 0)
  let second_payload = @ir.hot_child_get(func, branch_id, 1)
  let condition_id = @ir.hot_child_get(func, branch_id, 2)
  let mut flow_parent = -1
  let mut first_flow_slot = -1
  let mut second_flow_slot = -1
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
      if node_id == branch_id && slot < 2 {
        continue
      }
      let child_id = @ir.hot_child_get(func, node_id, slot)
      if child_id == first_payload {
        flow_parent = node_id
        first_flow_slot = slot
      }
      if child_id == second_payload {
        if flow_parent >= 0 {
          @debug.assert_eq(node_id, flow_parent)
        } else {
          flow_parent = node_id
        }
        second_flow_slot = slot
      }
    }
  }
  @debug.assert_eq(second_flow_slot, first_flow_slot + 1)
  let tuple_id = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i64()],
    [first_payload, second_payload],
  )
  @ir.hot_child_set(func, branch_id, 0, tuple_id)
  @ir.hot_child_set(func, branch_id, 1, tuple_id)
  @ir.hot_child_set(func, flow_parent, first_flow_slot, tuple_id)
  @ir.hot_child_set(func, flow_parent, second_flow_slot, tuple_id)
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
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 6)
  let first_value_set = @ir.hot_region_get(func, body_ref, 0)
  let second_value_set = @ir.hot_region_get(func, body_ref, 1)
  let first_target_set = @ir.hot_region_get(func, body_ref, 2)
  let second_target_set = @ir.hot_region_get(func, body_ref, 3)
  let condition_set = @ir.hot_region_get(func, body_ref, 4)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 5), branch_id)
  @debug.assert_eq(@ir.hot_child_get(func, first_value_set, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_value_set, 0), second_payload)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_target_set, 0)).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_target_set, 0)).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), condition_id)
  let first_local = @ir.hot_node_get(func, first_target_set).imm0
  let second_local = @ir.hot_node_get(func, second_target_set).imm0
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
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, condition_id), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple-made block br_if routing to verify, got \{err}")
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
test "flatten scalarizes one exact tuple-made loop plain br backedge" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result f32 f64))) (func (result f32 f64) call 1 call 2 loop $loop (type $carrier) drop drop call 5 if call 3 call 4 br $loop end f32.const 11 f64.const 13 end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, return_id, 0)
  @debug.assert_eq(
    @ir.hot_type_results(func, @ir.hot_node_get(func, loop_id).ty),
    [@lib.ValType::f32(), @lib.ValType::f64()],
  )
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let if_id = @ir.hot_region_get(func, body_ref, 2)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let branch = @ir.hot_region_get(func, then_ref, 0)
  let first_payload = @ir.hot_child_get(func, branch, 0)
  let second_payload = @ir.hot_child_get(func, branch, 1)
  let tuple_id = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i64()],
    [first_payload, second_payload],
  )
  @ir.hot_child_set(func, branch, 0, tuple_id)
  @ir.hot_child_set(func, branch, 1, tuple_id)
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
  let first_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).imm0
  let second_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).imm0
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
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 4), branch)
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple-made loop plain br routing to verify, got \{err}")
  }
}

///|
test "flatten scalarizes one exact tuple-made loop br_if flow" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result f32 f64))) (func (result f32 f64) call 1 call 2 loop $loop (type $carrier) drop drop call 3 call 4 call 5 br_if $loop drop drop f32.const 11 f64.const 13 end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, return_id, 0)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let branch_id = @ir.hot_region_get(func, body_ref, 2)
  let first_payload = @ir.hot_child_get(func, branch_id, 0)
  let second_payload = @ir.hot_child_get(func, branch_id, 1)
  let condition_id = @ir.hot_child_get(func, branch_id, 2)
  let first_drop = @ir.hot_region_get(func, body_ref, 3)
  let second_drop = @ir.hot_region_get(func, body_ref, 4)
  @debug.assert_eq(@ir.hot_child_get(func, first_drop, 0), second_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_drop, 0), first_payload)
  let tuple_id = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i64()],
    [first_payload, second_payload],
  )
  @ir.hot_child_set(func, branch_id, 0, tuple_id)
  @ir.hot_child_set(func, branch_id, 1, tuple_id)
  @ir.hot_child_set(func, first_drop, 0, tuple_id)
  @ir.hot_child_set(func, second_drop, 0, tuple_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 12)
  let first_value_set = @ir.hot_region_get(func, body_ref, 2)
  let second_value_set = @ir.hot_region_get(func, body_ref, 3)
  let first_payload_set = @ir.hot_region_get(func, body_ref, 4)
  let second_payload_set = @ir.hot_region_get(func, body_ref, 5)
  let condition_set = @ir.hot_region_get(func, body_ref, 6)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 7), branch_id)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 8), first_drop)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 9), second_drop)
  @debug.assert_eq(@ir.hot_child_get(func, first_value_set, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_value_set, 0), second_payload)
  let first_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).imm0
  let second_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, first_payload_set).imm0,
    first_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_payload_set).imm0,
    second_entry_local,
  )
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), condition_id)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_drop, 0)).imm0,
    second_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_drop, 0)).imm0,
    first_entry_local,
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
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, condition_id), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple-made loop br_if routing to verify, got \{err}")
  }
}

///|
test "flatten scalarizes tuple-made loop br_if unary and convert flow" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result f32 f64))) (func (result f32 f64) call 1 call 2 loop $loop (type $carrier) drop drop call 3 call 4 call 5 br_if $loop i64.clz drop i64.extend_i32_s drop f32.const 11 f64.const 13 end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, return_id, 0)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let branch_id = @ir.hot_region_get(func, body_ref, 2)
  let first_payload = @ir.hot_child_get(func, branch_id, 0)
  let second_payload = @ir.hot_child_get(func, branch_id, 1)
  let condition_id = @ir.hot_child_get(func, branch_id, 2)
  let unary_drop = @ir.hot_region_get(func, body_ref, 3)
  let convert_drop = @ir.hot_region_get(func, body_ref, 4)
  let unary_id = @ir.hot_child_get(func, unary_drop, 0)
  let convert_id = @ir.hot_child_get(func, convert_drop, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, unary_id),
    Some(@lib.Instruction::i64_clz()),
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, convert_id),
    Some(@lib.Instruction::i64_extend_i32s()),
  )
  @debug.assert_eq(@ir.hot_child_get(func, unary_id, 0), second_payload)
  @debug.assert_eq(@ir.hot_child_get(func, convert_id, 0), first_payload)
  let tuple_id = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i64()],
    [first_payload, second_payload],
  )
  @ir.hot_child_set(func, branch_id, 0, tuple_id)
  @ir.hot_child_set(func, branch_id, 1, tuple_id)
  @ir.hot_child_set(func, unary_id, 0, tuple_id)
  @ir.hot_child_set(func, convert_id, 0, tuple_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  let first_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).imm0
  let second_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, unary_id, 0)).imm0,
    second_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, convert_id, 0)).imm0,
    first_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, unary_id),
    Some(@lib.Instruction::i64_clz()),
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, convert_id),
    Some(@lib.Instruction::i64_extend_i32s()),
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
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, condition_id), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made unary/convert loop br_if routing to verify, got \{err}",
      )
  }
}

///|
test "flatten scalarizes tuple-made loop br_if binary flow" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result f32 f64))) (func (result f32 f64) call 1 call 2 loop $loop (type $carrier) drop drop call 3 call 4 call 5 br_if $loop i64.const 3 i64.div_s drop i32.const 4 i32.add drop f32.const 11 f64.const 13 end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, return_id, 0)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let branch_id = @ir.hot_region_get(func, body_ref, 2)
  let first_payload = @ir.hot_child_get(func, branch_id, 0)
  let second_payload = @ir.hot_child_get(func, branch_id, 1)
  let condition_id = @ir.hot_child_get(func, branch_id, 2)
  let first_drop = @ir.hot_region_get(func, body_ref, 3)
  let second_drop = @ir.hot_region_get(func, body_ref, 4)
  let i64_binary = @ir.hot_child_get(func, first_drop, 0)
  let i32_binary = @ir.hot_child_get(func, second_drop, 0)
  let i64_rhs = @ir.hot_child_get(func, i64_binary, 1)
  let i32_rhs = @ir.hot_child_get(func, i32_binary, 1)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, i64_binary),
    Some(@lib.Instruction::i64_div_s()),
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, i32_binary),
    Some(@lib.Instruction::i32_add()),
  )
  @debug.assert_eq(@ir.hot_child_get(func, i64_binary, 0), second_payload)
  @debug.assert_eq(@ir.hot_child_get(func, i32_binary, 0), first_payload)
  let tuple_id = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i64()],
    [first_payload, second_payload],
  )
  @ir.hot_child_set(func, branch_id, 0, tuple_id)
  @ir.hot_child_set(func, branch_id, 1, tuple_id)
  @ir.hot_child_set(func, i64_binary, 0, tuple_id)
  @ir.hot_child_set(func, i32_binary, 0, tuple_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  let first_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).imm0
  let second_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).imm0
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, i64_binary, 0)).imm0,
    second_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, i32_binary, 0)).imm0,
    first_entry_local,
  )
  @debug.assert_eq(@ir.hot_child_get(func, i64_binary, 1), i64_rhs)
  @debug.assert_eq(@ir.hot_child_get(func, i32_binary, 1), i32_rhs)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, i64_binary),
    Some(@lib.Instruction::i64_div_s()),
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, i32_binary),
    Some(@lib.Instruction::i32_add()),
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
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, condition_id), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made binary loop br_if routing to verify, got \{err}",
      )
  }
}

///|
test "flatten scalarizes one exclusive tuple-made inputful loop result tail" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result f32 f64))) (func (result f32 f64) call 1 call 2 loop $loop (type $carrier) drop drop call 3 call 4 call 5 br_if $loop drop drop call 6 call 7 end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0) (func (result f32) f32.const 11) (func (result f64) f64.const 13))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, return_id, 0)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let old_root_count = @ir.hot_region_root_count(func, body_ref)
  let first_result = @ir.hot_region_get(func, body_ref, old_root_count - 2)
  let second_result = @ir.hot_region_get(func, body_ref, old_root_count - 1)
  let tuple_id = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::f32(), @lib.ValType::f64()],
    [first_result, second_result],
  )
  let roots : Array[Int] = []
  for root_idx = 0; root_idx < old_root_count - 2; root_idx = root_idx + 1 {
    roots.push(@ir.hot_region_get(func, body_ref, root_idx))
  }
  roots.push(tuple_id)
  @ir.hot_region_replace_body(func, body_ref, roots)
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
  let first_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).imm0
  let second_entry_local = @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).imm0
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
  @debug.assert_eq(
    @ir.hot_local_type(func, first_result_local),
    Some(@lib.ValType::f32()),
  )
  @debug.assert_eq(
    @ir.hot_local_type(func, second_result_local),
    Some(@lib.ValType::f64()),
  )
  let routed_root_count = @ir.hot_region_root_count(func, body_ref)
  let first_result_set = @ir.hot_region_get(
    func,
    body_ref,
    routed_root_count - 2,
  )
  let second_result_set = @ir.hot_region_get(
    func,
    body_ref,
    routed_root_count - 1,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, first_result_set).imm0,
    first_result_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, second_result_set).imm0,
    second_result_local,
  )
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_result), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_result), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-made inputful loop result routing to verify, got \{err}",
      )
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
test "flatten routes exact multivalue loop br_if unary and convert consumers" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32 i64))) (func (result i32 i64) call 1 call 2 loop $loop (type $carrier) drop drop call 3 call 4 call 5 br_if $loop i64.clz drop i64.extend_i32_s drop i32.const 11 i64.const 13 end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0))",
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
  let unary_value = @ir.hot_child_get(func, first_consumer, 0)
  let convert_value = @ir.hot_child_get(func, second_consumer, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, unary_value),
    Some(@lib.Instruction::i64_clz()),
  )
  @debug.assert_eq(@ir.hot_child_get(func, unary_value, 0), second_payload)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, convert_value),
    Some(@lib.Instruction::i64_extend_i32s()),
  )
  @debug.assert_eq(@ir.hot_child_get(func, convert_value, 0), first_payload)
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
  let unary_set = @ir.hot_region_get(func, body_ref, 6)
  let convert_set = @ir.hot_region_get(func, body_ref, 8)
  @debug.assert_eq(@ir.hot_child_get(func, unary_set, 0), unary_value)
  @debug.assert_eq(@ir.hot_child_get(func, convert_set, 0), convert_value)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, unary_value, 0)).imm0,
    second_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, convert_value, 0)).imm0,
    first_entry_local,
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, unary_value),
    Some(@lib.Instruction::i64_clz()),
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, convert_value),
    Some(@lib.Instruction::i64_extend_i32s()),
  )
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
      fail("expected unary/convert loop br_if consumers to verify, got \{err}")
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

///|
test "flatten routes one scalar br_table through a legacy try inside if inside block" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type]),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(9))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(i32_type),
    @ir.hot_build_local_get(func, 0),
    [try_id],
    else_body=Some([@ir.hot_build_const_i32(func, @lib.I32(13))]),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::val_type(i32_type), [
    if_id,
  ])
  let payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, payload, @lib.Instruction::i32_add())
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let labels = [
    @ir.hot_control_node_label(func, try_id),
    @ir.hot_control_node_label(func, if_id),
    @ir.hot_control_node_label(func, block_id),
  ]
  let branch = @ir.hot_build_br_table(func, labels, labels[0], selector, values=[
    payload,
  ])
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [block_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, if_id, block_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in labels {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 6)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    payload,
  )
  let target_locals = [
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 1)).imm0,
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 2)).imm0,
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_body, 3)).imm0,
  ]
  assert_false(target_locals[0] == target_locals[1])
  assert_false(target_locals[0] == target_locals[2])
  assert_false(target_locals[1] == target_locals[2])
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 4), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 5), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).imm0,
    target_locals[0],
  )
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 2)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 0), try_id)
  let if_copy = @ir.hot_region_get(func, then_ref, 1)
  @debug.assert_eq(@ir.hot_node_get(func, if_copy).imm0, target_locals[1])
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, if_copy, 0)).imm0,
    target_locals[0],
  )
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, 0)).imm0,
    target_locals[1],
  )
  let block_body = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, block_body), 2)
  @debug.assert_eq(@ir.hot_region_get(func, block_body, 0), if_id)
  let block_copy = @ir.hot_region_get(func, block_body, 1)
  @debug.assert_eq(@ir.hot_node_get(func, block_copy).imm0, target_locals[2])
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, block_copy, 0)).imm0,
    target_locals[1],
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, 0)).imm0,
    target_locals[2],
  )
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected scalar try-if-block table routing to verify, got \{err}")
  }
}

///|
test "flatten routes one independently scalar multivalue br_table through a legacy try inside if inside block" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [try_id, try_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    if_id, if_id,
  ])
  for entry in [[if_id, 1], [block_id, 2]] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let labels = [
    @ir.hot_control_node_label(func, try_id),
    @ir.hot_control_node_label(func, if_id),
    @ir.hot_control_node_label(func, block_id),
  ]
  let branch = @ir.hot_build_br_table(func, labels, labels[0], selector, values=[
    first_payload, second_payload,
  ])
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [block_id, block_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  for control_id in [try_id, if_id, block_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in labels {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 10)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 3; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 2 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 3 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    assert_false(target_locals[0][slot] == target_locals[1][slot])
    assert_false(target_locals[0][slot] == target_locals[2][slot])
    assert_false(target_locals[1][slot] == target_locals[2][slot])
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 8), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 9), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 0), try_id)
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let copy_set = @ir.hot_region_get(func, then_ref, slot + 1)
    @debug.assert_eq(
      @ir.hot_node_get(func, copy_set).imm0,
      target_locals[1][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
      target_locals[0][slot],
    )
  }
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
      target_locals[1][slot],
    )
  }
  let block_body = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, block_body), 3)
  @debug.assert_eq(@ir.hot_region_get(func, block_body, 0), if_id)
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let copy_set = @ir.hot_region_get(func, block_body, slot + 1)
    @debug.assert_eq(
      @ir.hot_node_get(func, copy_set).imm0,
      target_locals[2][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
      target_locals[1][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[2][slot],
    )
  }
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected independently scalar multivalue try-if-block table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten routes one exclusively tuple-made multivalue br_table through a legacy try inside if inside block" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type, i32_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(9)),
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 2),
    [try_id, try_id],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    if_id, if_id,
  ])
  for entry in [[if_id, 1], [block_id, 2]] {
    @ir.hot_control_result_type_set(
      func,
      entry[0],
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(entry[1].to_uint())),
        [],
        result_types,
      ),
    )
  }
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(6)),
  )
  @ir.hot_node_exact_instr_set(func, selector, @lib.Instruction::i32_sub())
  let labels = [
    @ir.hot_control_node_label(func, try_id),
    @ir.hot_control_node_label(func, if_id),
    @ir.hot_control_node_label(func, block_id),
  ]
  let branch = @ir.hot_build_br_table(func, labels, labels[0], selector, values=[
    tuple_id, tuple_id,
  ])
  let try_body = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_body, [branch])
  let return_id = @ir.hot_build_return(func, [block_id, block_id])
  @ir.hot_root_append(func, return_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch), 1)
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  for control_id in [try_id, if_id, block_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
  }
  for label_id in labels {
    @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  }
  @debug.assert_eq(@ir.hot_region_root_count(func, try_body), 12)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 1), 0),
    second_payload,
  )
  let target_locals : Array[Array[Int]] = []
  for target_index = 0; target_index < 3; target_index = target_index + 1 {
    target_locals.push([
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 4 + target_index * 2),
      ).imm0,
      @ir.hot_node_get(
        func,
        @ir.hot_region_get(func, try_body, 5 + target_index * 2),
      ).imm0,
    ])
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    assert_false(target_locals[0][slot] == target_locals[1][slot])
    assert_false(target_locals[0][slot] == target_locals[2][slot])
    assert_false(target_locals[1][slot] == target_locals[2][slot])
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_body, 10), 0),
    selector,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_body, 11), branch)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      target_locals[0][slot],
    )
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 3)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 0), try_id)
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let copy_set = @ir.hot_region_get(func, then_ref, slot + 1)
    @debug.assert_eq(
      @ir.hot_node_get(func, copy_set).imm0,
      target_locals[1][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
      target_locals[0][slot],
    )
  }
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, else_ref, slot)).imm0,
      target_locals[1][slot],
    )
  }
  let block_body = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, block_body), 3)
  @debug.assert_eq(@ir.hot_region_get(func, block_body, 0), if_id)
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let copy_set = @ir.hot_region_get(func, block_body, slot + 1)
    @debug.assert_eq(
      @ir.hot_node_get(func, copy_set).imm0,
      target_locals[2][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, copy_set, 0)).imm0,
      target_locals[1][slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      target_locals[2][slot],
    )
  }
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple try-if-block table routing to verify, got \{err}")
  }
}

///|
test "flatten routes a scalar legacy try table into an inputful enclosing loop entry channel" {
  let i32_type = @lib.ValType::i32()
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32) (result i32))) (func (result i32) call 1 loop $loop (type $carrier) drop i32.const 11 end return) (func (result i32) i32.const 1))",
  )
  let mut loop_id = -1
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Loop => loop_id = node_id
      _ => ()
    }
  }
  assert_true(loop_id >= 0)
  let entry_id = @ir.hot_child_get(func, loop_id, 0)
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_const_i32(func, @lib.I32(11))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(12))]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_value(func, i32_type),
  )
  let payload_id = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, payload_id, @lib.Instruction::i32_add())
  let selector_id = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(4)),
  )
  @ir.hot_node_exact_instr_set(func, selector_id, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let loop_label = @ir.hot_control_node_label(func, loop_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [try_label, loop_label],
    try_label,
    selector_id,
    values=[payload_id],
  )
  let try_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_ref, [branch_id])
  let loop_ref = @ir.hot_region_body_ref(func, loop_id)
  let loop_tail = @ir.hot_region_root_count(func, loop_ref) - 1
  ignore(@ir.hot_region_set(func, loop_ref, loop_tail, try_id))
  @debug.assert_eq(@ir.hot_region_get(func, loop_ref, loop_tail), try_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, try_id)),
    0,
  )
  @debug.assert_eq(
    @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, loop_id)),
    0,
  )
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 0)
  let entry_set = @ir.hot_root_get(func, 0)
  @debug.assert_eq(@ir.hot_child_get(func, entry_set, 0), entry_id)
  let loop_entry_local = @ir.hot_node_get(func, entry_set).imm0
  @debug.assert_eq(@ir.hot_region_root_count(func, try_ref), 5)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_ref, 0), 0),
    payload_id,
  )
  let payload_stage_local = @ir.hot_node_get(
      func,
      @ir.hot_region_get(func, try_ref, 0),
    ).imm0
  let try_copy = @ir.hot_region_get(func, try_ref, 1)
  let loop_copy = @ir.hot_region_get(func, try_ref, 2)
  assert_false(@ir.hot_node_get(func, try_copy).imm0 == loop_entry_local)
  @debug.assert_eq(@ir.hot_node_get(func, loop_copy).imm0, loop_entry_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, try_copy, 0)).imm0,
    payload_stage_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, loop_copy, 0)).imm0,
    payload_stage_local,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_ref, 3), 0),
    selector_id,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_ref, 4), branch_id)
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, entry_id), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, payload_id), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector_id), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected scalar try-loop table routing to verify, got \{err}")
  }
}

///|
test "flatten routes independently scalar legacy try table lanes into inputful enclosing loop entry channels" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32 i64))) (func (result i32 i64) call 1 call 2 loop $loop (type $carrier) drop drop i32.const 11 i64.const 12 end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2))",
  )
  let mut loop_id = -1
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Loop => loop_id = node_id
      _ => ()
    }
  }
  assert_true(loop_id >= 0)
  let first_entry = @ir.hot_child_get(func, loop_id, 0)
  let second_entry = @ir.hot_child_get(func, loop_id, 1)
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_results(func, result_types),
  )
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_const_i64(func, @lib.I64(9L)),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let selector_id = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(4)),
  )
  @ir.hot_node_exact_instr_set(func, selector_id, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let loop_label = @ir.hot_control_node_label(func, loop_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [try_label, loop_label],
    try_label,
    selector_id,
    values=[first_payload, second_payload],
  )
  let try_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_ref, [branch_id])
  let loop_ref = @ir.hot_region_body_ref(func, loop_id)
  let loop_root_count = @ir.hot_region_root_count(func, loop_ref)
  ignore(@ir.hot_region_set(func, loop_ref, loop_root_count - 2, try_id))
  ignore(@ir.hot_region_set(func, loop_ref, loop_root_count - 1, try_id))
  @debug.assert_eq(
    [
      @ir.hot_region_get(func, loop_ref, loop_root_count - 2),
      @ir.hot_region_get(func, loop_ref, loop_root_count - 1),
    ],
    [try_id, try_id],
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  for control_id in [try_id, loop_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
    @debug.assert_eq(
      @ir.hot_label_branch_arity(
        func,
        @ir.hot_control_node_label(func, control_id),
      ),
      0,
    )
  }
  let first_entry_set = @ir.hot_root_get(func, 0)
  let second_entry_set = @ir.hot_root_get(func, 1)
  @debug.assert_eq(@ir.hot_child_get(func, first_entry_set, 0), first_entry)
  @debug.assert_eq(@ir.hot_child_get(func, second_entry_set, 0), second_entry)
  let entry_locals = [
    @ir.hot_node_get(func, first_entry_set).imm0,
    @ir.hot_node_get(func, second_entry_set).imm0,
  ]
  @debug.assert_eq(@ir.hot_region_root_count(func, try_ref), 8)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_ref, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_ref, 1), 0),
    second_payload,
  )
  let stage_locals = [
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_ref, 0)).imm0,
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_ref, 1)).imm0,
  ]
  for slot = 0; slot < 2; slot = slot + 1 {
    let try_copy = @ir.hot_region_get(func, try_ref, 2 + slot)
    let loop_copy = @ir.hot_region_get(func, try_ref, 4 + slot)
    let try_local = @ir.hot_node_get(func, try_copy).imm0
    assert_false(try_local == entry_locals[slot])
    @debug.assert_eq(@ir.hot_node_get(func, loop_copy).imm0, entry_locals[slot])
    for copy_id in [try_copy, loop_copy] {
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_id, 0)).imm0,
        stage_locals[slot],
      )
    }
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_ref, 6), 0),
    selector_id,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_ref, 7), branch_id)
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_entry), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_entry), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector_id), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected multivalue try-loop table routing to verify, got \{err}")
  }
}

///|
test "flatten scalarizes one exclusively tuple-made legacy try table into inputful loop entry channels" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32 i64))) (func (result i32 i64) call 1 call 2 loop $loop (type $carrier) drop drop i32.const 11 i64.const 12 end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2))",
  )
  let mut loop_id = -1
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Loop => loop_id = node_id
      _ => ()
    }
  }
  assert_true(loop_id >= 0)
  let first_entry = @ir.hot_child_get(func, loop_id, 0)
  let second_entry = @ir.hot_child_get(func, loop_id, 1)
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_results(func, result_types),
  )
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_const_i64(func, @lib.I64(9L)),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector_id = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(4)),
  )
  @ir.hot_node_exact_instr_set(func, selector_id, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let loop_label = @ir.hot_control_node_label(func, loop_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [try_label, loop_label],
    try_label,
    selector_id,
    values=[tuple_id, tuple_id],
  )
  let try_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_ref, [branch_id])
  let loop_ref = @ir.hot_region_body_ref(func, loop_id)
  let loop_root_count = @ir.hot_region_root_count(func, loop_ref)
  ignore(@ir.hot_region_set(func, loop_ref, loop_root_count - 2, try_id))
  ignore(@ir.hot_region_set(func, loop_ref, loop_root_count - 1, try_id))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  for control_id in [try_id, loop_id] {
    @debug.assert_eq(@ir.hot_node_result_arity(func, control_id), 0)
    @debug.assert_eq(
      @ir.hot_label_branch_arity(
        func,
        @ir.hot_control_node_label(func, control_id),
      ),
      0,
    )
  }
  let entry_locals = [
    @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).imm0,
    @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).imm0,
  ]
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0),
    first_entry,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_root_get(func, 1), 0),
    second_entry,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, try_ref), 10)
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_ref, 0), 0),
    first_payload,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_ref, 1), 0),
    second_payload,
  )
  let payload_locals = [
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_ref, 0)).imm0,
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_ref, 1)).imm0,
  ]
  let stage_locals = [
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_ref, 2)).imm0,
    @ir.hot_node_get(func, @ir.hot_region_get(func, try_ref, 3)).imm0,
  ]
  for slot = 0; slot < 2; slot = slot + 1 {
    let stage_set = @ir.hot_region_get(func, try_ref, 2 + slot)
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, stage_set, 0)).imm0,
      payload_locals[slot],
    )
    let try_copy = @ir.hot_region_get(func, try_ref, 4 + slot)
    let loop_copy = @ir.hot_region_get(func, try_ref, 6 + slot)
    assert_false(@ir.hot_node_get(func, try_copy).imm0 == entry_locals[slot])
    @debug.assert_eq(@ir.hot_node_get(func, loop_copy).imm0, entry_locals[slot])
    for copy_id in [try_copy, loop_copy] {
      @debug.assert_eq(
        @ir.hot_node_get(func, @ir.hot_child_get(func, copy_id, 0)).imm0,
        stage_locals[slot],
      )
    }
  }
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_ref, 8), 0),
    selector_id,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_ref, 9), branch_id)
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector_id), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple-made try-loop table routing to verify, got \{err}")
  }
}

///|
test "flatten removes an unreachable-only suffix after a tuple-made legacy try table" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[i32_type, i64_type]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let body_first_fallback = @ir.hot_build_const_i32(func, @lib.I32(9))
  let body_second_fallback = @ir.hot_build_const_i64(func, @lib.I64(10L))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [body_first_fallback, body_second_fallback],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_results(func, result_types),
  )
  let first_payload = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, first_payload, @lib.Instruction::i32_add())
  let second_payload = @ir.hot_build_binary(
    func,
    i64_type,
    @ir.hot_build_local_get(func, 1),
    @ir.hot_build_const_i64(func, @lib.I64(4L)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_payload,
    @lib.Instruction::i64_sub(),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let selector_id = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(4)),
  )
  @ir.hot_node_exact_instr_set(func, selector_id, @lib.Instruction::i32_sub())
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id, label_id],
    label_id,
    selector_id,
    values=[tuple_id, tuple_id],
  )
  let dead_unreachable = @ir.hot_build_unreachable(func)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_unreachable])
  @ir.hot_delete_node(func, body_first_fallback)
  @ir.hot_delete_node(func, body_second_fallback)
  let return_id = @ir.hot_build_return(func, [try_id, try_id])
  @ir.hot_root_append(func, return_id)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  assert_false(@ir.hot_node_is_live(func, dead_unreachable))
  assert_false(@ir.hot_node_is_live(func, tuple_id))
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 8)
  let first_value_set = @ir.hot_region_get(func, body_ref, 0)
  let second_value_set = @ir.hot_region_get(func, body_ref, 1)
  let first_stage_set = @ir.hot_region_get(func, body_ref, 2)
  let second_stage_set = @ir.hot_region_get(func, body_ref, 3)
  let first_result_set = @ir.hot_region_get(func, body_ref, 4)
  let second_result_set = @ir.hot_region_get(func, body_ref, 5)
  let selector_set = @ir.hot_region_get(func, body_ref, 6)
  @debug.assert_eq(@ir.hot_region_get(func, body_ref, 7), branch_id)
  @debug.assert_eq(@ir.hot_child_get(func, first_value_set, 0), first_payload)
  @debug.assert_eq(@ir.hot_child_get(func, second_value_set, 0), second_payload)
  @debug.assert_eq(@ir.hot_child_get(func, selector_set, 0), selector_id)
  let result_locals = [
    @ir.hot_node_get(func, first_result_set).imm0,
    @ir.hot_node_get(func, second_result_set).imm0,
  ]
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_result_set, 0)).imm0,
    @ir.hot_node_get(func, first_stage_set).imm0,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_result_set, 0)).imm0,
    @ir.hot_node_get(func, second_stage_set).imm0,
  )
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  for slot = 0; slot < 2; slot = slot + 1 {
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot)).imm0,
      result_locals[slot],
    )
    @debug.assert_eq(
      @ir.hot_node_get(func, @ir.hot_child_get(func, return_id, slot)).imm0,
      result_locals[slot],
    )
  }
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, first_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, second_payload), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector_id), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected unreachable-suffix try table routing to verify, got \{err}",
      )
  }
}

///|
test "flatten removes one exclusively owned pure drop suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_const = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_drop = @ir.hot_build_drop(func, dead_const)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_drop])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  assert_false(@ir.hot_node_is_live(func, dead_drop))
  assert_false(@ir.hot_node_is_live(func, dead_const))
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected pure-drop suffix routing to verify, got \{err}")
  }
}

///|
test "flatten removes one exclusively owned pure binary drop suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let left = @ir.hot_build_const_i32(func, @lib.I32(1))
  let right = @ir.hot_build_const_i32(func, @lib.I32(2))
  let add = @ir.hot_build_binary(func, i32_type, left, right)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_drop])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_drop, add, left, right] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected pure-binary-drop suffix routing to verify, got \{err}")
  }
}

///|
test "flatten removes one exclusively owned unary drop suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(1))
  let clz = @ir.hot_build_unary(func, i32_type, input)
  @ir.hot_node_exact_instr_set(func, clz, @lib.Instruction::i32_clz())
  let dead_drop = @ir.hot_build_drop(func, clz)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_drop])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_drop, clz, input] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected unary-drop suffix routing to verify, got \{err}")
  }
}

///|
test "flatten removes one exclusively owned trapping drop suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let left = @ir.hot_build_const_i32(func, @lib.I32(1))
  let right = @ir.hot_build_const_i32(func, @lib.I32(0))
  let trap = @ir.hot_build_binary(func, i32_type, left, right)
  @ir.hot_node_exact_instr_set(func, trap, @lib.Instruction::i32_div_s())
  let dead_drop = @ir.hot_build_drop(func, trap)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_drop])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_drop, trap, left, right] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected trapping-drop suffix routing to verify, got \{err}")
  }
}

///|
test "flatten removes one exclusively owned void call suffix from a try-to-loop table" {
  let i32_type = @lib.ValType::i32()
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32) (result i32))) (func (result i32) call 1 loop $loop (type $carrier) drop i32.const 11 end return) (func (result i32) i32.const 1))",
  )
  let mut loop_id = -1
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Loop => loop_id = node_id
      _ => ()
    }
  }
  assert_true(loop_id >= 0)
  let entry_id = @ir.hot_child_get(func, loop_id, 0)
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_const_i32(func, @lib.I32(11))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(12))]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_value(func, i32_type),
  )
  let payload_id = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(func, payload_id, @lib.Instruction::i32_add())
  let selector_id = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
    @ir.hot_build_const_i32(func, @lib.I32(4)),
  )
  @ir.hot_node_exact_instr_set(func, selector_id, @lib.Instruction::i32_sub())
  let try_label = @ir.hot_control_node_label(func, try_id)
  let loop_label = @ir.hot_control_node_label(func, loop_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [try_label, loop_label],
    try_label,
    selector_id,
    values=[payload_id],
  )
  let dead_call = @ir.hot_build_call(func, 99, [], [])
  let try_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, try_ref, [branch_id, dead_call])
  let loop_ref = @ir.hot_region_body_ref(func, loop_id)
  let loop_tail = @ir.hot_region_root_count(func, loop_ref) - 1
  ignore(@ir.hot_region_set(func, loop_ref, loop_tail, try_id))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  assert_false(@ir.hot_node_is_live(func, dead_call))
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, try_label), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, loop_label), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 0)
  let entry_set = @ir.hot_root_get(func, 0)
  @debug.assert_eq(@ir.hot_child_get(func, entry_set, 0), entry_id)
  let loop_entry_local = @ir.hot_node_get(func, entry_set).imm0
  @debug.assert_eq(@ir.hot_region_root_count(func, try_ref), 5)
  let payload_stage_local = @ir.hot_node_get(
      func,
      @ir.hot_region_get(func, try_ref, 0),
    ).imm0
  let try_copy = @ir.hot_region_get(func, try_ref, 1)
  let loop_copy = @ir.hot_region_get(func, try_ref, 2)
  assert_false(@ir.hot_node_get(func, try_copy).imm0 == loop_entry_local)
  @debug.assert_eq(@ir.hot_node_get(func, loop_copy).imm0, loop_entry_local)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, try_copy, 0)).imm0,
    payload_stage_local,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, loop_copy, 0)).imm0,
    payload_stage_local,
  )
  @debug.assert_eq(
    @ir.hot_child_get(func, @ir.hot_region_get(func, try_ref, 3), 0),
    selector_id,
  )
  @debug.assert_eq(@ir.hot_region_get(func, try_ref, 4), branch_id)
  let use_def = @ir.use_def_build(func)
  @debug.assert_eq(@ir.node_use_count(use_def, entry_id), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, payload_id), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, selector_id), 1)
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected call-suffix try-loop routing to verify, got \{err}")
  }
}

///|
test "flatten removes one exclusively owned scalar-argument void call suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_arg = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_call = @ir.hot_build_call(func, 99, [], [dead_arg])
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_call])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_call, dead_arg] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected argument-call suffix routing to verify, got \{err}")
  }
}

///|
test "flatten removes one exclusively owned conversion drop suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(1))
  let conversion = @ir.hot_build_convert(func, i64_type, input)
  @ir.hot_node_exact_instr_set(
    func,
    conversion,
    @lib.Instruction::i64_extend_i32s(),
  )
  let dead_drop = @ir.hot_build_drop(func, conversion)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_drop])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_drop, conversion, input] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected conversion-drop suffix routing to verify, got \{err}")
  }
}

///|
test "flatten removes one exclusively owned add-argument void call suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let argument = @ir.hot_build_binary(func, i32_type, left, right)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_add())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_call])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_call, argument, left, right] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected add-argument call suffix routing to verify, got \{err}")
  }
}

///|
test "flatten removes one exclusively owned subtract drop suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let subtract = @ir.hot_build_binary(func, i32_type, left, right)
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  let dead_drop = @ir.hot_build_drop(func, subtract)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_drop])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_drop, subtract, left, right] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected subtract-drop suffix routing to verify, got \{err}")
  }
}

///|
test "flatten removes one exclusively owned multiply drop suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let multiply = @ir.hot_build_binary(func, i32_type, left, right)
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let dead_drop = @ir.hot_build_drop(func, multiply)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_drop])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_drop, multiply, left, right] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected multiply-drop suffix routing to verify, got \{err}")
  }
}

///|
test "flatten removes one exclusively owned conversion-argument void call suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let argument = @ir.hot_build_convert(func, i64_type, input)
  @ir.hot_node_exact_instr_set(
    func,
    argument,
    @lib.Instruction::i64_extend_i32s(),
  )
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_call])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_call, argument, input] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected conversion-argument call suffix routing to verify, got \{err}",
      )
  }
}

///|
test "flatten removes one exclusively owned unary-argument void call suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let argument = @ir.hot_build_unary(func, i32_type, input)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_clz())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_call])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_call, argument, input] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected unary-argument call suffix routing to verify, got \{err}")
  }
}

///|
test "flatten removes one exclusively owned bitwise-and drop suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let bitwise_and = @ir.hot_build_binary(func, i32_type, left, right)
  @ir.hot_node_exact_instr_set(func, bitwise_and, @lib.Instruction::i32_and())
  let dead_drop = @ir.hot_build_drop(func, bitwise_and)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_drop])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_drop, bitwise_and, left, right] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected bitwise-and drop suffix routing to verify, got \{err}")
  }
}

///|
test "flatten removes one exclusively owned trapping-binary-argument void call suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dividend = @ir.hot_build_const_i32(func, @lib.I32(1))
  let divisor = @ir.hot_build_const_i32(func, @lib.I32(0))
  let argument = @ir.hot_build_binary(func, i32_type, dividend, divisor)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_div_s())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_call])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_call, argument, dividend, divisor] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected trapping-binary-argument call suffix routing to verify, got \{err}",
      )
  }
}

///|
test "flatten removes exactly two exclusively owned direct drop-const roots after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let first_value = @ir.hot_build_const_i32(func, @lib.I32(9))
  let first_drop = @ir.hot_build_drop(func, first_value)
  let second_value = @ir.hot_build_const_i32(func, @lib.I32(10))
  let second_drop = @ir.hot_build_drop(func, second_value)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch_id, first_drop, second_drop,
  ])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [first_drop, first_value, second_drop, second_value] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected two drop-const suffix roots to verify, got \{err}")
  }
}

///|
test "flatten removes three exclusively owned direct drop-const roots after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(12))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let first_value = @ir.hot_build_const_i32(func, @lib.I32(9))
  let first_drop = @ir.hot_build_drop(func, first_value)
  let second_value = @ir.hot_build_const_i32(func, @lib.I32(10))
  let second_drop = @ir.hot_build_drop(func, second_value)
  let third_value = @ir.hot_build_const_i32(func, @lib.I32(11))
  let third_drop = @ir.hot_build_drop(func, third_value)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch_id, first_drop, second_drop, third_drop,
  ])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for
    node_id in [
      first_drop, first_value, second_drop, second_value, third_drop, third_value,
    ] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected three drop-const suffix roots to verify, got \{err}")
  }
}

///|
test "flatten removes one direct drop-const then unreachable suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_value = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_drop = @ir.hot_build_drop(func, dead_value)
  let dead_unreachable = @ir.hot_build_unreachable(func)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch_id, dead_drop, dead_unreachable,
  ])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_drop, dead_value, dead_unreachable] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected drop-const then unreachable suffix to verify, got \{err}")
  }
}

///|
test "flatten removes one direct unreachable then drop-const suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_unreachable = @ir.hot_build_unreachable(func)
  let dead_value = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_drop = @ir.hot_build_drop(func, dead_value)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch_id, dead_unreachable, dead_drop,
  ])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_unreachable, dead_drop, dead_value] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected unreachable then drop-const suffix to verify, got \{err}")
  }
}

///|
test "flatten removes two independently owned add-drop suffix roots after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(13))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let first_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let first_right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let first_add = @ir.hot_build_binary(func, i32_type, first_left, first_right)
  @ir.hot_node_exact_instr_set(func, first_add, @lib.Instruction::i32_add())
  let first_drop = @ir.hot_build_drop(func, first_add)
  let second_left = @ir.hot_build_const_i32(func, @lib.I32(11))
  let second_right = @ir.hot_build_const_i32(func, @lib.I32(12))
  let second_add = @ir.hot_build_binary(
    func, i32_type, second_left, second_right,
  )
  @ir.hot_node_exact_instr_set(func, second_add, @lib.Instruction::i32_add())
  let second_drop = @ir.hot_build_drop(func, second_add)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch_id, first_drop, second_drop,
  ])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for
    node_id in [
      first_drop, first_add, first_left, first_right, second_drop, second_add, second_left,
      second_right,
    ] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected two add-drop suffix roots to verify, got \{err}")
  }
}

///|
test "flatten removes one exclusively owned nested add-multiply drop suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(12))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let add_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply_left = @ir.hot_build_const_i32(func, @lib.I32(10))
  let multiply_right = @ir.hot_build_const_i32(func, @lib.I32(11))
  let multiply = @ir.hot_build_binary(
    func, i32_type, multiply_left, multiply_right,
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let add = @ir.hot_build_binary(func, i32_type, add_left, multiply)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_drop])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for
    node_id in [
      dead_drop, add, add_left, multiply, multiply_left, multiply_right,
    ] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nested add-multiply drop suffix to verify, got \{err}")
  }
}

///|
test "flatten removes one exclusively owned nested multiply-add drop suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(12))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let multiply_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply_right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let multiply = @ir.hot_build_binary(
    func, i32_type, multiply_left, multiply_right,
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let add_right = @ir.hot_build_const_i32(func, @lib.I32(11))
  let add = @ir.hot_build_binary(func, i32_type, multiply, add_right)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_drop])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for
    node_id in [
      dead_drop, add, multiply, add_right, multiply_left, multiply_right,
    ] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nested multiply-add drop suffix to verify, got \{err}")
  }
}

///|
test "flatten removes one direct add-drop then unreachable suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let add_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let add_right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let add = @ir.hot_build_binary(func, i32_type, add_left, add_right)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  let dead_unreachable = @ir.hot_build_unreachable(func)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch_id, dead_drop, dead_unreachable,
  ])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_drop, add, add_left, add_right, dead_unreachable] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected add-drop then unreachable suffix to verify, got \{err}")
  }
}

///|
test "flatten removes two independently owned multiply-drop suffix roots after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(13))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let first_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let first_right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let first_multiply = @ir.hot_build_binary(
    func, i32_type, first_left, first_right,
  )
  @ir.hot_node_exact_instr_set(
    func,
    first_multiply,
    @lib.Instruction::i32_mul(),
  )
  let first_drop = @ir.hot_build_drop(func, first_multiply)
  let second_left = @ir.hot_build_const_i32(func, @lib.I32(11))
  let second_right = @ir.hot_build_const_i32(func, @lib.I32(12))
  let second_multiply = @ir.hot_build_binary(
    func, i32_type, second_left, second_right,
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_multiply,
    @lib.Instruction::i32_mul(),
  )
  let second_drop = @ir.hot_build_drop(func, second_multiply)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch_id, first_drop, second_drop,
  ])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for
    node_id in [
      first_drop, first_multiply, first_left, first_right, second_drop, second_multiply,
      second_left, second_right,
    ] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected two multiply-drop suffix roots to verify, got \{err}")
  }
}

///|
test "flatten removes one exclusively owned add-of-two-multiplies drop suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(13))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let left_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let left_right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let left_multiply = @ir.hot_build_binary(
    func, i32_type, left_left, left_right,
  )
  @ir.hot_node_exact_instr_set(func, left_multiply, @lib.Instruction::i32_mul())
  let right_left = @ir.hot_build_const_i32(func, @lib.I32(11))
  let right_right = @ir.hot_build_const_i32(func, @lib.I32(12))
  let right_multiply = @ir.hot_build_binary(
    func, i32_type, right_left, right_right,
  )
  @ir.hot_node_exact_instr_set(
    func,
    right_multiply,
    @lib.Instruction::i32_mul(),
  )
  let add = @ir.hot_build_binary(func, i32_type, left_multiply, right_multiply)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [branch_id, dead_drop])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for
    node_id in [
      dead_drop, add, left_multiply, right_multiply, left_left, left_right, right_left,
      right_right,
    ] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected add-of-two-multiplies drop suffix to verify, got \{err}")
  }
}

///|
test "flatten removes one direct unreachable then add-drop suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(11))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_unreachable = @ir.hot_build_unreachable(func)
  let add_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let add_right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let add = @ir.hot_build_binary(func, i32_type, add_left, add_right)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch_id, dead_unreachable, dead_drop,
  ])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for node_id in [dead_unreachable, dead_drop, add, add_left, add_right] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected unreachable then add-drop suffix to verify, got \{err}")
  }
}

///|
test "flatten removes one add-drop then multiply-drop suffix after a scalar legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let body_fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [body_fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(13))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let branch_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let add_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let add_right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let add = @ir.hot_build_binary(func, i32_type, add_left, add_right)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let add_drop = @ir.hot_build_drop(func, add)
  let multiply_left = @ir.hot_build_const_i32(func, @lib.I32(11))
  let multiply_right = @ir.hot_build_const_i32(func, @lib.I32(12))
  let multiply = @ir.hot_build_binary(
    func, i32_type, multiply_left, multiply_right,
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let multiply_drop = @ir.hot_build_drop(func, multiply)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    branch_id, add_drop, multiply_drop,
  ])
  @ir.hot_delete_node(func, body_fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  for
    node_id in [
      add_drop, add, add_left, add_right, multiply_drop, multiply, multiply_left,
      multiply_right,
    ] {
    assert_false(@ir.hot_node_is_live(func, node_id))
  }
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_label_branch_arity(func, label_id), 0)
  @debug.assert_eq(@ir.hot_child_count(func, branch_id), 1)
  @debug.assert_eq(
    @ir.hot_region_get(
      func,
      body_ref,
      @ir.hot_region_root_count(func, body_ref) - 1,
    ),
    branch_id,
  )
  assert_true(flatten_classify_hot(func).is_flat())
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected add-drop then multiply-drop suffix to verify, got \{err}")
  }
}
