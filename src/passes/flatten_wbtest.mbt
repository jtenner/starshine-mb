///|
fn flatten_test_build_rich_drop(func : @ir.HotFunc) -> Array[Int] {
  let rich = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    @ir.hot_build_const_i32(func, @lib.I32(2)),
  )
  @ir.hot_node_exact_instr_set(func, rich, @lib.Instruction::i32_add())
  [rich, @ir.hot_build_drop(func, rich)]
}

///|
fn flatten_test_assert_hard_unsupported_no_mutation(
  func : @ir.HotFunc,
  rich : Int,
  drop_id : Int,
  unsupported_id : Int,
) -> Unit raise {
  @ir.hot_root_append(func, drop_id)
  @ir.hot_root_append(func, unsupported_id)
  let before = flatten_classify_hot(func)
  @debug.assert_eq(before.rich_operand_count, 1)
  @debug.assert_eq(before.unsupported_count, 1)
  match flatten_run_admission(func, before) {
    FlattenRunAdmission::UpstreamHardUnsupported => ()
    _ => fail("expected upstream-hard-unsupported flatten admission")
  }
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::unchanged())
  @debug.assert_eq(@ir.hot_local_count(func), 0)
  @debug.assert_eq(@ir.hot_root_count(func), 2)
  @debug.assert_eq(@ir.hot_root_get(func, 0), drop_id)
  @debug.assert_eq(@ir.hot_root_get(func, 1), unsupported_id)
  @debug.assert_eq(@ir.hot_child_get(func, drop_id, 0), rich)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, rich),
    Some(@lib.Instruction::i32_add()),
  )
  let after = flatten_classify_hot(func)
  @debug.assert_eq(after, before)
}

///|
test "flatten hard unsupported admission prevents partial mutation" {
  let unsupported_ops = [
    @ir.HotOp::br_on_null(),
    @ir.HotOp::br_on_non_null(),
    @ir.HotOp::br_on_cast(),
    @ir.HotOp::br_on_cast_fail(),
  ]
  for unsupported_op in unsupported_ops {
    let func = @ir.HotFunc::new()
    let rich_drop = flatten_test_build_rich_drop(func)
    let unsupported_id = @ir.hot_build_node(
      func,
      unsupported_op,
      @ir.hot_type_void(func),
    )
    flatten_test_assert_hard_unsupported_no_mutation(
      func,
      rich_drop[0],
      rich_drop[1],
      unsupported_id,
    )
  }
  let func = @ir.HotFunc::new()
  let rich_drop = flatten_test_build_rich_drop(func)
  let try_table = @ir.hot_build_try_table(func, @lib.BlockType::void_(), [], [
    @ir.hot_build_nop(func),
  ])
  flatten_test_assert_hard_unsupported_no_mutation(
    func,
    rich_drop[0],
    rich_drop[1],
    try_table,
  )
}

///|
test "flatten classifies missing legacy EH repair prerequisites before mutation" {
  let func = @ir.HotFunc::new()
  let empty = flatten_eh_repair_requirement(func)
  assert_true(empty.is_clear())
  @debug.assert_eq(empty.needs_catch_payload_tracking, false)
  @debug.assert_eq(empty.needs_exceptional_transfer_repair, false)
  ignore(@ir.hot_build_node(func, @ir.HotOp::catch_(), @ir.hot_type_void(func)))
  ignore(
    @ir.hot_build_node(func, @ir.HotOp::rethrow(), @ir.hot_type_void(func)),
  )
  let requirement = flatten_eh_repair_requirement(func)
  @debug.assert_eq(requirement.needs_catch_payload_tracking, true)
  @debug.assert_eq(requirement.needs_exceptional_transfer_repair, true)
  assert_false(requirement.is_clear())
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::unchanged())
}
