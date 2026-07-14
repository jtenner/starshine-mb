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

///|
test "flatten extracts direct try target ancestry in structural order" {
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_nop(func)],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [try_id])
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [block_id],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  @debug.assert_eq(
    flatten_direct_enclosing_target_controls(func, try_id, [if_id, block_id]),
    Some([block_id, if_id]),
  )
}

///|
test "flatten rejects skipped direct try target ancestry" {
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_nop(func)],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  let skipped_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id,
  ])
  let outer_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [skipped_block],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  @debug.assert_eq(
    flatten_direct_enclosing_target_controls(func, try_id, [outer_if]),
    None,
  )
}

///|
test "flatten extracts reverse if-inside-block target ancestry in structural order" {
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_nop(func)],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [try_id],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [if_id])
  let chain = flatten_direct_enclosing_target_controls(func, try_id, [
    block_id, if_id,
  ])
  @debug.assert_eq(chain, Some([if_id, block_id]))
}

///|
test "flatten extracts a direct enclosing loop from try target ancestry" {
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_nop(func)],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  let loop_id = @ir.hot_build_loop(func, @lib.BlockType::void_(), [try_id])
  @debug.assert_eq(
    flatten_direct_enclosing_target_controls(func, try_id, [loop_id]),
    Some([loop_id]),
  )
}

///|
test "flatten rejects a skipped enclosing loop from try target ancestry" {
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_nop(func)],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  let loop_id = @ir.hot_build_loop(func, @lib.BlockType::void_(), [try_id])
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [loop_id])
  @debug.assert_eq(
    flatten_direct_enclosing_target_controls(func, try_id, [block_id]),
    None,
  )
}

///|
test "flatten rejects non-root try containment from direct target ancestry" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let drop_id = @ir.hot_build_drop(func, try_id)
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [drop_id])
  @debug.assert_eq(
    flatten_direct_enclosing_target_controls(func, try_id, [block_id]),
    None,
  )
}
