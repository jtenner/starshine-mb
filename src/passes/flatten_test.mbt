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
