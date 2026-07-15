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

///|
test "flatten admits exclusively tuple-made try-to-loop table preflight" {
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
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    @ir.hot_build_const_i32(func, @lib.I32(7)),
    @ir.hot_build_const_i64(func, @lib.I64(9L)),
  ])
  let try_label = @ir.hot_control_node_label(func, try_id)
  let loop_label = @ir.hot_control_node_label(func, loop_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [try_label, loop_label],
    try_label,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[tuple_id, tuple_id],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
  ])
  let loop_ref = @ir.hot_region_body_ref(func, loop_id)
  let root_count = @ir.hot_region_root_count(func, loop_ref)
  ignore(@ir.hot_region_set(func, loop_ref, root_count - 2, try_id))
  ignore(@ir.hot_region_set(func, loop_ref, root_count - 1, try_id))
  assert_true(flatten_multivalue_legacy_try_is_supported(func, try_id))
  assert_true(flatten_inputful_loop_is_supported(func, loop_id))
  assert_true(
    flatten_tuple_mixed_try_table_is_supported(func, table_id, result_types, [
      try_label, loop_label,
    ]),
  )
  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected tuple try-to-loop table admission")
  }
}

///|
test "flatten admits only unreachable roots after a legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    @ir.hot_build_unreachable(func),
    @ir.hot_build_unreachable(func),
  ])
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned pure drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_value = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_drop = @ir.hot_build_drop(func, dead_value)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  let use_def = @ir.use_def_build_node_uses(func)
  @debug.assert_eq(@ir.node_use_count(use_def, dead_drop), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, dead_value), 1)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, dead_value]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes exactly two exclusively owned direct drop-const try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
    table_id, first_drop, second_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([first_drop, first_value, second_drop, second_value]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps two drop-const suffix roots gated when their child is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_value = @ir.hot_build_const_i32(func, @lib.I32(9))
  let first_drop = @ir.hot_build_drop(func, shared_value)
  let second_drop = @ir.hot_build_drop(func, shared_value)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, first_drop, second_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a repeated drop-const suffix root gated" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let repeated_drop = @ir.hot_build_drop(
    func,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, repeated_drop, repeated_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes three exclusively owned direct drop-const try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
    table_id, first_drop, second_drop, third_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      first_drop, first_value, second_drop, second_value, third_drop, third_value,
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one direct drop-const then unreachable try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
    table_id, dead_drop, dead_unreachable,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, dead_value, dead_unreachable]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one direct unreachable then drop-const try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
    table_id, dead_unreachable, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_unreachable, dead_drop, dead_value]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one direct add-drop then unreachable try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
    table_id, dead_drop, dead_unreachable,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, add, add_left, add_right, dead_unreachable]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one direct unreachable then add-drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
    table_id, dead_unreachable, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_unreachable, dead_drop, add, add_left, add_right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes add-drop followed by two unreachable try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let add = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, add),
    @ir.hot_build_unreachable(func),
    @ir.hot_build_unreachable(func),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes unreachable add-drop unreachable try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let add = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_unreachable(func),
    @ir.hot_build_drop(func, add),
    @ir.hot_build_unreachable(func),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes three-root mixed drop-const unreachable try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(9))),
    @ir.hot_build_unreachable(func),
    @ir.hot_build_unreachable(func),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes exactly two independently owned add-drop try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
    table_id, first_drop, second_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      first_drop, first_add, first_left, first_right, second_drop, second_add, second_left,
      second_right,
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps two add-drop suffix roots unsupported when a descendant is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let first_add = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, first_add, @lib.Instruction::i32_add())
  let second_add = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(func, second_add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, first_add),
    @ir.hot_build_drop(func, second_add),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a repeated add-drop suffix root unsupported" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let add = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let repeated_drop = @ir.hot_build_drop(func, add)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, repeated_drop, repeated_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes three independently owned add-drop try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let first = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let second = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    11,
    12,
  )
  let third = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    13,
    14,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    first[0],
    second[0],
    third[0],
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      first[0],
      first[1],
      first[2],
      first[3],
      second[0],
      second[1],
      second[2],
      second[3],
      third[0],
      third[1],
      third[2],
      third[3],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes exactly two independently owned multiply-drop try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
    table_id, first_drop, second_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      first_drop, first_multiply, first_left, first_right, second_drop, second_multiply,
      second_left, second_right,
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps two multiply-drop suffix roots unsupported when a descendant is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let first_multiply = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    first_multiply,
    @lib.Instruction::i32_mul(),
  )
  let second_multiply = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_multiply,
    @lib.Instruction::i32_mul(),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, first_multiply),
    @ir.hot_build_drop(func, second_multiply),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a repeated multiply-drop suffix root unsupported" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let multiply = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let repeated_drop = @ir.hot_build_drop(func, multiply)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, repeated_drop, repeated_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes three independently owned multiply-drop try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let first = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    9,
    10,
  )
  let second = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    11,
    12,
  )
  let third = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    13,
    14,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    first[0],
    second[0],
    third[0],
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      first[0],
      first[1],
      first[2],
      first[3],
      second[0],
      second[1],
      second[2],
      second[3],
      third[0],
      third[1],
      third[2],
      third[3],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned scalar-argument void call try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_arg = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_call = @ir.hot_build_call(func, 99, [], [dead_arg])
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_call])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_call, dead_arg]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned add-argument void call try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_call])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_call, argument, left, right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps an add-argument call suffix gated when a descendant is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let argument = @ir.hot_build_binary(func, i32_type, shared_left, right)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_add())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_left))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes a three-constant-argument call try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let first_arg = @ir.hot_build_const_i32(func, @lib.I32(9))
  let second_arg = @ir.hot_build_const_i32(func, @lib.I32(10))
  let third_arg = @ir.hot_build_const_i32(func, @lib.I32(11))
  let dead_call = @ir.hot_build_call(func, 99, [], [
    first_arg, second_arg, third_arg,
  ])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a scalar-argument call try-table suffix gated when its argument is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_arg = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_call = @ir.hot_build_call(func, 99, [], [shared_arg])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_arg))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a result-carrying call try-table suffix gated" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_call = @ir.hot_build_call(func, 99, [i32_type], [])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned nested add-multiply drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, add, add_left, multiply, multiply_left, multiply_right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a nested add-multiply try-table suffix unsupported when a descendant is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let add_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let shared = @ir.hot_build_const_i32(func, @lib.I32(10))
  let multiply_right = @ir.hot_build_const_i32(func, @lib.I32(11))
  let multiply = @ir.hot_build_binary(func, i32_type, shared, multiply_right)
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let add = @ir.hot_build_binary(func, i32_type, add_left, multiply)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps repeated nested add-multiply descendants unsupported" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let add_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let repeated = @ir.hot_build_const_i32(func, @lib.I32(10))
  let multiply = @ir.hot_build_binary(func, i32_type, repeated, repeated)
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let add = @ir.hot_build_binary(func, i32_type, add_left, multiply)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, add),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned nested multiply-add drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, add, multiply, add_right, multiply_left, multiply_right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a nested multiply-add try-table suffix unsupported when a descendant is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let add = @ir.hot_build_binary(
    func,
    i32_type,
    multiply,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, add),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps repeated nested multiply-add descendants unsupported" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let repeated = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply = @ir.hot_build_binary(func, i32_type, repeated, repeated)
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let add = @ir.hot_build_binary(
    func,
    i32_type,
    multiply,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, add),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned add-of-two-multiplies drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      dead_drop, add, left_multiply, right_multiply, left_left, left_right, right_left,
      right_right,
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps an add-of-two-multiplies suffix unsupported when the multiply trees share a descendant" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let left_multiply = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, left_multiply, @lib.Instruction::i32_mul())
  let right_multiply = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    right_multiply,
    @lib.Instruction::i32_mul(),
  )
  let add = @ir.hot_build_binary(func, i32_type, left_multiply, right_multiply)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, add),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps repeated descendants inside an add-of-two-multiplies suffix unsupported" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let repeated = @ir.hot_build_const_i32(func, @lib.I32(9))
  let left_multiply = @ir.hot_build_binary(func, i32_type, repeated, repeated)
  @ir.hot_node_exact_instr_set(func, left_multiply, @lib.Instruction::i32_mul())
  let right_multiply = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    right_multiply,
    @lib.Instruction::i32_mul(),
  )
  let add = @ir.hot_build_binary(func, i32_type, left_multiply, right_multiply)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, add),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes two add-of-two-multiplies suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let drops : Array[Int] = []
  for base in [9, 13] {
    let left_multiply = @ir.hot_build_binary(
      func,
      i32_type,
      @ir.hot_build_const_i32(func, @lib.I32(base)),
      @ir.hot_build_const_i32(func, @lib.I32(base + 1)),
    )
    @ir.hot_node_exact_instr_set(
      func,
      left_multiply,
      @lib.Instruction::i32_mul(),
    )
    let right_multiply = @ir.hot_build_binary(
      func,
      i32_type,
      @ir.hot_build_const_i32(func, @lib.I32(base + 2)),
      @ir.hot_build_const_i32(func, @lib.I32(base + 3)),
    )
    @ir.hot_node_exact_instr_set(
      func,
      right_multiply,
      @lib.Instruction::i32_mul(),
    )
    let add = @ir.hot_build_binary(
      func, i32_type, left_multiply, right_multiply,
    )
    @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
    drops.push(@ir.hot_build_drop(func, add))
  }
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    drops[0],
    drops[1],
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned subtract-const-multiply drop try-table suffix" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let outer_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_mul(),
    10,
    11,
  )
  let subtract = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    outer_left,
    multiply[0],
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  let dead_drop = @ir.hot_build_drop(func, subtract)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      dead_drop,
      subtract,
      outer_left,
      multiply[0],
      multiply[1],
      multiply[2],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps subtract-const-multiply suffix unsupported when a descendant is shared" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let subtract = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    shared,
    multiply,
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, subtract),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned subtract-multiply-const drop try-table suffix" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let multiply = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_mul(),
    9,
    10,
  )
  let outer_right = @ir.hot_build_const_i32(func, @lib.I32(11))
  let subtract = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    multiply[0],
    outer_right,
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  let dead_drop = @ir.hot_build_drop(func, subtract)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      dead_drop,
      subtract,
      multiply[0],
      outer_right,
      multiply[1],
      multiply[2],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps subtract-multiply-const suffix unsupported when a descendant is shared" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let subtract = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    multiply,
    shared,
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, subtract),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps subtract-add-const suffix unsupported" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let add = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let subtract = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    add[0],
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, subtract),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes two subtract-multiply-const suffix roots" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let drops : Array[Int] = []
  for base in [9, 12] {
    let multiply = flatten_test_build_direct_binary(
      func,
      @lib.Instruction::i32_mul(),
      base,
      base + 1,
    )
    let subtract = @ir.hot_build_binary(
      func,
      @lib.ValType::i32(),
      multiply[0],
      @ir.hot_build_const_i32(func, @lib.I32(base + 2)),
    )
    @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
    drops.push(@ir.hot_build_drop(func, subtract))
  }
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    drops[0],
    drops[1],
  ])
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps subtract-const-add suffix unsupported" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let outer_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let add = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_add(),
    10,
    11,
  )
  let subtract = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    outer_left,
    add[0],
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, subtract),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes two subtract-const-multiply suffix roots" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let drops : Array[Int] = []
  for base in [9, 12] {
    let multiply = flatten_test_build_direct_binary(
      func,
      @lib.Instruction::i32_mul(),
      base + 1,
      base + 2,
    )
    let subtract = @ir.hot_build_binary(
      func,
      @lib.ValType::i32(),
      @ir.hot_build_const_i32(func, @lib.I32(base)),
      multiply[0],
    )
    @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
    drops.push(@ir.hot_build_drop(func, subtract))
  }
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    drops[0],
    drops[1],
  ])
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned subtract-of-two-multiplies drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
  let subtract = @ir.hot_build_binary(
    func, i32_type, left_multiply, right_multiply,
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  let dead_drop = @ir.hot_build_drop(func, subtract)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      dead_drop, subtract, left_multiply, right_multiply, left_left, left_right,
      right_left, right_right,
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a subtract-of-two-multiplies suffix unsupported when the multiply trees share a descendant" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let left_multiply = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, left_multiply, @lib.Instruction::i32_mul())
  let right_multiply = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    right_multiply,
    @lib.Instruction::i32_mul(),
  )
  let subtract = @ir.hot_build_binary(
    func, i32_type, left_multiply, right_multiply,
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, subtract),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps subtract of multiply and add suffix trees unsupported" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let left = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_mul(),
    9,
    10,
  )
  let right = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_add(),
    11,
    12,
  )
  let subtract = @ir.hot_build_binary(func, i32_type, left[0], right[0])
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, subtract),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a deeper subtract-of-two-multiplies suffix unsupported" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let left = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_mul(),
    9,
    10,
  )
  let nested = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
    @ir.hot_build_const_i32(func, @lib.I32(12)),
  )
  @ir.hot_node_exact_instr_set(func, nested, @lib.Instruction::i32_add())
  let right = @ir.hot_build_binary(
    func,
    i32_type,
    nested,
    @ir.hot_build_const_i32(func, @lib.I32(13)),
  )
  @ir.hot_node_exact_instr_set(func, right, @lib.Instruction::i32_mul())
  let subtract = @ir.hot_build_binary(func, i32_type, left[0], right)
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, subtract),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes two subtract-of-two-multiplies suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let drops : Array[Int] = []
  for base in [9, 13] {
    let left = flatten_test_build_direct_binary(
      func,
      @lib.Instruction::i32_mul(),
      base,
      base + 1,
    )
    let right = flatten_test_build_direct_binary(
      func,
      @lib.Instruction::i32_mul(),
      base + 2,
      base + 3,
    )
    let subtract = @ir.hot_build_binary(func, i32_type, left[0], right[0])
    @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
    drops.push(@ir.hot_build_drop(func, subtract))
  }
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    drops[0],
    drops[1],
  ])
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned pure binary drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let add = @ir.hot_build_binary(func, i32_type, left, right)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, add, left, right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned subtract drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, subtract, left, right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned multiply drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, multiply, left, right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned bitwise-and drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, bitwise_and, left, right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps repeated bitwise-and operands gated after a try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let repeated = @ir.hot_build_const_i32(func, @lib.I32(9))
  let bitwise_and = @ir.hot_build_binary(func, i32_type, repeated, repeated)
  @ir.hot_node_exact_instr_set(func, bitwise_and, @lib.Instruction::i32_and())
  let dead_drop = @ir.hot_build_drop(func, bitwise_and)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a bitwise-and try-table suffix gated when one operand is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let bitwise_and = @ir.hot_build_binary(func, i32_type, shared_left, right)
  @ir.hot_node_exact_instr_set(func, bitwise_and, @lib.Instruction::i32_and())
  let dead_drop = @ir.hot_build_drop(func, bitwise_and)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_left))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps structured dead suffix roots gated until label-owner deletion is representable" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_const = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_drop = @ir.hot_build_drop(func, dead_const)
  let dead_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    dead_drop,
  ])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_block,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a pure binary try-table suffix gated when one operand is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let add = @ir.hot_build_binary(func, i32_type, shared_left, right)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_left))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned unary drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let clz = @ir.hot_build_unary(func, i32_type, input)
  @ir.hot_node_exact_instr_set(func, clz, @lib.Instruction::i32_clz())
  let dead_drop = @ir.hot_build_drop(func, clz)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, clz, input]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a unary try-table suffix gated when its input is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let clz = @ir.hot_build_unary(func, i32_type, shared_input)
  @ir.hot_node_exact_instr_set(func, clz, @lib.Instruction::i32_clz())
  let dead_drop = @ir.hot_build_drop(func, clz)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_input))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned conversion drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let conversion = @ir.hot_build_convert(func, i64_type, input)
  @ir.hot_node_exact_instr_set(
    func,
    conversion,
    @lib.Instruction::i64_extend_i32s(),
  )
  let dead_drop = @ir.hot_build_drop(func, conversion)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, conversion, input]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a conversion try-table suffix gated when its input is shared" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let conversion = @ir.hot_build_convert(func, i64_type, shared_input)
  @ir.hot_node_exact_instr_set(
    func,
    conversion,
    @lib.Instruction::i64_extend_i32s(),
  )
  let dead_drop = @ir.hot_build_drop(func, conversion)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_input))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps other conversion opcodes gated after a try table" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let conversion = @ir.hot_build_convert(func, i64_type, input)
  @ir.hot_node_exact_instr_set(
    func,
    conversion,
    @lib.Instruction::i64_extend_i32u(),
  )
  let dead_drop = @ir.hot_build_drop(func, conversion)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a trapping try-table suffix gated when its binary is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let trap = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
  )
  @ir.hot_node_exact_instr_set(func, trap, @lib.Instruction::i32_div_s())
  let dead_drop = @ir.hot_build_drop(func, trap)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, trap))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a pure try-table suffix gated when its value is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_value = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_drop = @ir.hot_build_drop(func, shared_value)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_value))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned conversion-argument void call try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_call])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_call, argument, input]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a conversion-argument call suffix gated when its input is shared" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let argument = @ir.hot_build_convert(func, i64_type, shared_input)
  @ir.hot_node_exact_instr_set(
    func,
    argument,
    @lib.Instruction::i64_extend_i32s(),
  )
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_input))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps unsigned conversion-argument call suffixes gated" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
    @lib.Instruction::i64_extend_i32u(),
  )
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned unary-argument void call try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_call])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_call, argument, input]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a unary-argument call suffix gated when its input is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let argument = @ir.hot_build_unary(func, i32_type, shared_input)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_clz())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_input))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps other unary-argument call suffix opcodes gated" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let argument = @ir.hot_build_unary(func, i32_type, input)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_ctz())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned trapping-binary-argument void call try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
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
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_call])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_call, argument, dividend, divisor]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a trapping-binary-argument call suffix gated when a descendant is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_dividend = @ir.hot_build_const_i32(func, @lib.I32(1))
  let divisor = @ir.hot_build_const_i32(func, @lib.I32(0))
  let argument = @ir.hot_build_binary(func, i32_type, shared_dividend, divisor)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_div_s())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_dividend))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps other trapping-binary-argument call opcodes gated" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dividend = @ir.hot_build_const_i32(func, @lib.I32(1))
  let divisor = @ir.hot_build_const_i32(func, @lib.I32(0))
  let argument = @ir.hot_build_binary(func, i32_type, dividend, divisor)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_div_u())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
fn flatten_test_build_scalar_try_table_suffix_fixture(
  func : @ir.HotFunc,
) -> Array[Int] {
  let i32_type = @lib.ValType::i32()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  [try_id, label_id, table_id]
}

///|
fn flatten_test_build_direct_binary(
  func : @ir.HotFunc,
  instr : @lib.Instruction,
  left_value : Int,
  right_value : Int,
) -> Array[Int] {
  let left = @ir.hot_build_const_i32(func, @lib.I32(left_value))
  let right = @ir.hot_build_const_i32(func, @lib.I32(right_value))
  let binary = @ir.hot_build_binary(func, @lib.ValType::i32(), left, right)
  @ir.hot_node_exact_instr_set(func, binary, instr)
  [binary, left, right]
}

///|
fn flatten_test_build_direct_binary_drop(
  func : @ir.HotFunc,
  instr : @lib.Instruction,
  left_value : Int,
  right_value : Int,
) -> Array[Int] {
  let binary = flatten_test_build_direct_binary(
    func, instr, left_value, right_value,
  )
  [@ir.hot_build_drop(func, binary[0]), binary[0], binary[1], binary[2]]
}

///|
test "flatten recognizes one add-drop then multiply-drop try-table suffix" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let multiply = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    11,
    12,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, add[0], multiply[0]])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      add[0],
      add[1],
      add[2],
      add[3],
      multiply[0],
      multiply[1],
      multiply[2],
      multiply[3],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one multiply-drop then add-drop try-table suffix" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let multiply = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    9,
    10,
  )
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    11,
    12,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, multiply[0], add[0]])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      multiply[0],
      multiply[1],
      multiply[2],
      multiply[3],
      add[0],
      add[1],
      add[2],
      add[3],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps add-drop then multiply-drop suffix unsupported when a descendant is shared" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let add = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let multiply = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, add),
    @ir.hot_build_drop(func, multiply),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a repeated multiply root after an add-multiply suffix pair unsupported" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let multiply = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    11,
    12,
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    add[0],
    multiply[0],
    multiply[0],
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-multiply-add try-table suffix sequence" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let multiply = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    11,
    12,
  )
  let third = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    13,
    14,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    add[0],
    multiply[0],
    third[0],
  ])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      add[0],
      add[1],
      add[2],
      add[3],
      multiply[0],
      multiply[1],
      multiply[2],
      multiply[3],
      third[0],
      third[1],
      third[2],
      third[3],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps an add-xor-multiply suffix sequence unsupported" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let xor = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_xor(),
    11,
    12,
  )
  let multiply = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    13,
    14,
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    add[0],
    xor[0],
    multiply[0],
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps multiply-add suffix roots unsupported when a descendant is shared" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let add = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, multiply),
    @ir.hot_build_drop(func, add),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a repeated add root after a multiply-add suffix pair unsupported" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let multiply = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    9,
    10,
  )
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    11,
    12,
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    multiply[0],
    add[0],
    add[0],
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes a multiply-add-multiply try-table suffix sequence" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let multiply = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    9,
    10,
  )
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    11,
    12,
  )
  let third = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    13,
    14,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    multiply[0],
    add[0],
    third[0],
  ])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      multiply[0],
      multiply[1],
      multiply[2],
      multiply[3],
      add[0],
      add[1],
      add[2],
      add[3],
      third[0],
      third[1],
      third[2],
      third[3],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
fn flatten_test_recognize_four_direct_binary_suffix_roots(
  reverse : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let instructions = if reverse {
    [
      @lib.Instruction::i32_and(),
      @lib.Instruction::i32_mul(),
      @lib.Instruction::i32_sub(),
      @lib.Instruction::i32_add(),
    ]
  } else {
    [
      @lib.Instruction::i32_add(),
      @lib.Instruction::i32_sub(),
      @lib.Instruction::i32_mul(),
      @lib.Instruction::i32_and(),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root_index = 0
      root_index < instructions.length()
      root_index = root_index + 1 {
    let value = 9 + root_index * 2
    let root = flatten_test_build_direct_binary_drop(
      func,
      instructions[root_index],
      value,
      value + 1,
    )
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-subtract-multiply-and try-table suffix sequence" {
  flatten_test_recognize_four_direct_binary_suffix_roots(false)
}

///|
test "flatten recognizes an and-multiply-subtract-add try-table suffix sequence" {
  flatten_test_recognize_four_direct_binary_suffix_roots(true)
}

///|
fn flatten_wbtest_build_direct_unary_drop(
  func : @ir.HotFunc,
  instr : @lib.Instruction,
  input_value : Int,
  result_type : @lib.ValType,
  convert : Bool,
) -> Array[Int] {
  let input = @ir.hot_build_const_i32(func, @lib.I32(input_value))
  let value = if convert {
    @ir.hot_build_convert(func, result_type, input)
  } else {
    @ir.hot_build_unary(func, result_type, input)
  }
  @ir.hot_node_exact_instr_set(func, value, instr)
  let drop = @ir.hot_build_drop(func, value)
  [drop, value, input]
}

///|
fn flatten_wbtest_recognize_mixed_nontrapping_suffix_roots(
  reverse : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let roots = if reverse {
    [
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        9,
        @lib.ValType::i64(),
        true,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_mul(),
        10,
        11,
      ),
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i32_clz(),
        12,
        @lib.ValType::i32(),
        false,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_sub(),
        13,
        14,
      ),
    ]
  } else {
    [
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_add(),
        9,
        10,
      ),
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i32_clz(),
        11,
        @lib.ValType::i32(),
        false,
      ),
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        12,
        @lib.ValType::i64(),
        true,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_and(),
        13,
        14,
      ),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in roots {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-clz-extend-and try-table suffix sequence" {
  flatten_wbtest_recognize_mixed_nontrapping_suffix_roots(false)
}

///|
test "flatten recognizes an extend-multiply-clz-subtract try-table suffix sequence" {
  flatten_wbtest_recognize_mixed_nontrapping_suffix_roots(true)
}

///|
test "flatten keeps a sequence with i32 ctz unsupported after a try table" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let ctz = flatten_wbtest_build_direct_unary_drop(
    func,
    @lib.Instruction::i32_ctz(),
    9,
    @lib.ValType::i32(),
    false,
  )
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    10,
    11,
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    ctz[0],
    add[0],
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a sequence with unsigned i32 extension unsupported after a try table" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let conversion = flatten_wbtest_build_direct_unary_drop(
    func,
    @lib.Instruction::i64_extend_i32u(),
    9,
    @lib.ValType::i64(),
    true,
  )
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    10,
    11,
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    conversion[0],
    add[0],
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
fn flatten_wbtest_recognize_middle_divzero_suffix_roots(
  conversion_first : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let roots = if conversion_first {
    [
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        9,
        @lib.ValType::i64(),
        true,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_div_s(),
        10,
        0,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_and(),
        11,
        12,
      ),
    ]
  } else {
    [
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_add(),
        9,
        10,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_div_s(),
        11,
        0,
      ),
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i32_clz(),
        12,
        @lib.ValType::i32(),
        false,
      ),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in roots {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-divzero-clz try-table suffix sequence" {
  flatten_wbtest_recognize_middle_divzero_suffix_roots(false)
}

///|
test "flatten recognizes an extend-divzero-and try-table suffix sequence" {
  flatten_wbtest_recognize_middle_divzero_suffix_roots(true)
}

///|
test "flatten keeps a sequence with unsigned division unsupported after a try table" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let division = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_div_u(),
    11,
    0,
  )
  let clz = flatten_wbtest_build_direct_unary_drop(
    func,
    @lib.Instruction::i32_clz(),
    12,
    @lib.ValType::i32(),
    false,
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    add[0],
    division[0],
    clz[0],
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
fn flatten_wbtest_recognize_sequence_with_unreachable_root(
  unreachable_first : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let unreachable_root = @ir.hot_build_unreachable(func)
  let roots = if unreachable_first {
    [
      [unreachable_root],
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_add(),
        9,
        10,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_div_s(),
        11,
        0,
      ),
    ]
  } else {
    [
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        9,
        @lib.ValType::i64(),
        true,
      ),
      [unreachable_root],
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_and(),
        10,
        11,
      ),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in roots {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an unreachable-add-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_unreachable_root(true)
}

///|
test "flatten recognizes an extend-unreachable-and try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_unreachable_root(false)
}

///|
fn flatten_wbtest_recognize_sequence_with_direct_call(
  call_has_argument : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let roots = if call_has_argument {
    let argument = @ir.hot_build_const_i32(func, @lib.I32(10))
    let call = @ir.hot_build_call(func, 99, [], [argument])
    [
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        9,
        @lib.ValType::i64(),
        true,
      ),
      [call, argument],
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_and(),
        11,
        12,
      ),
    ]
  } else {
    let call = @ir.hot_build_call(func, 99, [], [])
    [
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_add(),
        9,
        10,
      ),
      [call],
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i32_clz(),
        11,
        @lib.ValType::i32(),
        false,
      ),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in roots {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-call0-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_direct_call(false)
}

///|
test "flatten recognizes an extend-callarg-and try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_direct_call(true)
}

///|
fn flatten_wbtest_recognize_sequence_with_binary_argument_call(
  argument_instr : @lib.Instruction,
  right_value : Int,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let argument = flatten_test_build_direct_binary(
    func, argument_instr, 11, right_value,
  )
  let call = @ir.hot_build_call(func, 99, [], [argument[0]])
  let last = flatten_wbtest_build_direct_unary_drop(
    func,
    @lib.Instruction::i32_clz(),
    13,
    @lib.ValType::i32(),
    false,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    first[0],
    call,
    last[0],
  ])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      first[0],
      first[1],
      first[2],
      first[3],
      call,
      argument[0],
      argument[1],
      argument[2],
      last[0],
      last[1],
      last[2],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-calladd-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_argument_call(
    @lib.Instruction::i32_add(),
    12,
  )
}

///|
test "flatten recognizes an add-calldivzero-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_argument_call(
    @lib.Instruction::i32_div_s(),
    0,
  )
}

///|
fn flatten_wbtest_recognize_sequence_with_unary_or_conversion_argument_call(
  conversion : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = flatten_test_build_direct_binary_drop(
    func,
    if conversion {
      @lib.Instruction::i32_and()
    } else {
      @lib.Instruction::i32_add()
    },
    9,
    10,
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(11))
  let argument = if conversion {
    @ir.hot_build_convert(func, @lib.ValType::i64(), input)
  } else {
    @ir.hot_build_unary(func, @lib.ValType::i32(), input)
  }
  @ir.hot_node_exact_instr_set(
    func,
    argument,
    if conversion {
      @lib.Instruction::i64_extend_i32s()
    } else {
      @lib.Instruction::i32_clz()
    },
  )
  let call = @ir.hot_build_call(func, 99, [], [argument])
  let last = if conversion {
    [@ir.hot_build_unreachable(func)]
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_div_s(),
      12,
      0,
    )
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    first[0],
    call,
    last[0],
  ])
  let expected : Array[Int] = [
    first[0],
    first[1],
    first[2],
    first[3],
    call,
    argument,
    input,
  ]
  for node_id in last {
    expected.push(node_id)
  }
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-callclz-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_unary_or_conversion_argument_call(
    false,
  )
}

///|
test "flatten recognizes an and-callextend-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_unary_or_conversion_argument_call(true)
}

///|
fn flatten_wbtest_recognize_sequence_with_two_constant_argument_call(
  reverse_types : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if reverse_types {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  }
  let first_argument = if reverse_types {
    @ir.hot_build_const_i64(func, @lib.I64(10L))
  } else {
    @ir.hot_build_const_i32(func, @lib.I32(11))
  }
  let second_argument = if reverse_types {
    @ir.hot_build_const_i32(func, @lib.I32(11))
  } else {
    @ir.hot_build_const_i64(func, @lib.I64(12L))
  }
  let call = @ir.hot_build_call(func, 99, [], [first_argument, second_argument])
  let last = if reverse_types {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_div_s(),
      12,
      0,
    )
  } else {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i32_clz(),
      13,
      @lib.ValType::i32(),
      false,
    )
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in [first, [call, first_argument, second_argument], last] {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-call2-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_constant_argument_call(false)
}

///|
test "flatten recognizes an extend-call2-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_constant_argument_call(true)
}

///|
fn flatten_wbtest_recognize_sequence_with_constant_argument_vector(
  four_arguments : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if four_arguments {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  }
  let arguments : Array[Int] = if four_arguments {
    [
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
      @ir.hot_build_const_i32(func, @lib.I32(13)),
    ]
  } else {
    [
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
      @ir.hot_build_const_i32(func, @lib.I32(13)),
    ]
  }
  let call = @ir.hot_build_call(func, 99, [], arguments)
  let last = if four_arguments {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_div_s(),
      14,
      0,
    )
  } else {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i32_clz(),
      14,
      @lib.ValType::i32(),
      false,
    )
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  body.push(first[0])
  for node_id in first {
    expected.push(node_id)
  }
  body.push(call)
  expected.push(call)
  for argument in arguments {
    expected.push(argument)
  }
  body.push(last[0])
  for node_id in last {
    expected.push(node_id)
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-call3-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_constant_argument_vector(false)
}

///|
test "flatten recognizes an extend-call4-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_constant_argument_vector(true)
}

///|
fn flatten_wbtest_recognize_sequence_with_binary_and_constant_arguments(
  rich_first : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if rich_first {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  } else {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  }
  let rich = flatten_test_build_direct_binary(
    func,
    if rich_first {
      @lib.Instruction::i32_add()
    } else {
      @lib.Instruction::i32_div_s()
    },
    11,
    if rich_first {
      12
    } else {
      0
    },
  )
  let constant = @ir.hot_build_const_i64(
    func,
    if rich_first {
      @lib.I64(13L)
    } else {
      @lib.I64(10L)
    },
  )
  let call = @ir.hot_build_call(
    func,
    99,
    [],
    if rich_first {
      [rich[0], constant]
    } else {
      [constant, rich[0]]
    },
  )
  let last = if rich_first {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i32_clz(),
      14,
      @lib.ValType::i32(),
      false,
    )
  } else {
    [@ir.hot_build_unreachable(func)]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  let call_nodes = if rich_first {
    [call, rich[0], constant, rich[1], rich[2]]
  } else {
    [call, constant, rich[0], rich[1], rich[2]]
  }
  for root in [first, call_nodes, last] {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-calladdconst-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_and_constant_arguments(true)
}

///|
test "flatten recognizes an extend-callconstdiv-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_and_constant_arguments(false)
}

///|
fn flatten_wbtest_recognize_sequence_with_unary_or_conversion_and_constant_arguments(
  conversion : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = flatten_test_build_direct_binary_drop(
    func,
    if conversion {
      @lib.Instruction::i32_and()
    } else {
      @lib.Instruction::i32_add()
    },
    9,
    10,
  )
  let rich = flatten_wbtest_build_direct_unary_drop(
    func,
    if conversion {
      @lib.Instruction::i64_extend_i32s()
    } else {
      @lib.Instruction::i32_clz()
    },
    if conversion {
      12
    } else {
      11
    },
    if conversion {
      @lib.ValType::i64()
    } else {
      @lib.ValType::i32()
    },
    conversion,
  )
  let constant = if conversion {
    @ir.hot_build_const_i32(func, @lib.I32(11))
  } else {
    @ir.hot_build_const_i64(func, @lib.I64(12L))
  }
  let call = @ir.hot_build_call(
    func,
    99,
    [],
    if conversion {
      [constant, rich[1]]
    } else {
      [rich[1], constant]
    },
  )
  let last = if conversion {
    [@ir.hot_build_unreachable(func)]
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_div_s(),
      13,
      0,
    )
  }
  let call_nodes = if conversion {
    [call, constant, rich[1], rich[2]]
  } else {
    [call, rich[1], constant, rich[2]]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in [first, call_nodes, last] {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @ir.hot_delete_node(func, rich[0])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-callclzconst-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_unary_or_conversion_and_constant_arguments(
    false,
  )
}

///|
test "flatten recognizes an and-callconstextend-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_unary_or_conversion_and_constant_arguments(
    true,
  )
}

///|
test "flatten keeps a two-argument call sequence gated when arguments repeat" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let argument = @ir.hot_build_const_i32(func, @lib.I32(9))
  let call = @ir.hot_build_call(func, 99, [], [argument, argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    call,
    @ir.hot_build_unreachable(func),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
fn flatten_wbtest_recognize_sequence_with_one_rich_argument_vector(
  conversion : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if conversion {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  }
  let rich = if conversion {
    let input = @ir.hot_build_const_i32(func, @lib.I32(13))
    let argument = @ir.hot_build_convert(func, @lib.ValType::i64(), input)
    @ir.hot_node_exact_instr_set(
      func,
      argument,
      @lib.Instruction::i64_extend_i32s(),
    )
    [argument, input]
  } else {
    flatten_test_build_direct_binary(func, @lib.Instruction::i32_add(), 12, 13)
  }
  let arguments : Array[Int] = if conversion {
    [
      @ir.hot_build_const_i32(func, @lib.I32(10)),
      @ir.hot_build_const_i64(func, @lib.I64(11L)),
      @ir.hot_build_const_i32(func, @lib.I32(12)),
      rich[0],
    ]
  } else {
    [
      @ir.hot_build_const_i64(func, @lib.I64(11L)),
      rich[0],
      @ir.hot_build_const_i32(func, @lib.I32(14)),
    ]
  }
  let call = @ir.hot_build_call(func, 99, [], arguments)
  let last = if conversion {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_div_s(),
      14,
      0,
    )
  } else {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i32_clz(),
      15,
      @lib.ValType::i32(),
      false,
    )
  }
  let body : Array[Int] = [table_id, first[0], call, last[0]]
  let expected : Array[Int] = []
  for node_id in first {
    expected.push(node_id)
  }
  expected.push(call)
  for argument in arguments {
    expected.push(argument)
  }
  for node_idx = 1; node_idx < rich.length(); node_idx = node_idx + 1 {
    expected.push(rich[node_idx])
  }
  for node_id in last {
    expected.push(node_id)
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-callconstaddconst-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_one_rich_argument_vector(false)
}

///|
test "flatten recognizes an extend-call3constextend-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_one_rich_argument_vector(true)
}

///|
fn flatten_wbtest_recognize_sequence_with_binary_and_unary_arguments(
  unary_first : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if unary_first {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  }
  let binary = flatten_test_build_direct_binary(
    func,
    if unary_first {
      @lib.Instruction::i32_div_s()
    } else {
      @lib.Instruction::i32_add()
    },
    11,
    if unary_first {
      0
    } else {
      12
    },
  )
  let unary_input = @ir.hot_build_const_i32(
    func,
    @lib.I32(if unary_first { 10 } else { 13 }),
  )
  let unary = @ir.hot_build_unary(func, @lib.ValType::i32(), unary_input)
  @ir.hot_node_exact_instr_set(func, unary, @lib.Instruction::i32_clz())
  let call = @ir.hot_build_call(
    func,
    99,
    [],
    if unary_first {
      [unary, binary[0]]
    } else {
      [binary[0], unary]
    },
  )
  let last = if unary_first {
    [@ir.hot_build_unreachable(func)]
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_div_s(),
      14,
      0,
    )
  }
  let call_nodes = if unary_first {
    [call, unary, binary[0], unary_input, binary[1], binary[2]]
  } else {
    [call, binary[0], unary, binary[1], binary[2], unary_input]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in [first, call_nodes, last] {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-calladdclz-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_and_unary_arguments(false)
}

///|
test "flatten recognizes an extend-callclzdiv-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_and_unary_arguments(true)
}

///|
fn flatten_wbtest_recognize_sequence_with_binary_and_conversion_arguments(
  conversion_first : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if conversion_first {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  }
  let binary = flatten_test_build_direct_binary(
    func,
    if conversion_first {
      @lib.Instruction::i32_div_s()
    } else {
      @lib.Instruction::i32_add()
    },
    11,
    if conversion_first {
      0
    } else {
      12
    },
  )
  let conversion_input = @ir.hot_build_const_i32(
    func,
    @lib.I32(if conversion_first { 10 } else { 13 }),
  )
  let conversion = @ir.hot_build_convert(
    func,
    @lib.ValType::i64(),
    conversion_input,
  )
  @ir.hot_node_exact_instr_set(
    func,
    conversion,
    @lib.Instruction::i64_extend_i32s(),
  )
  let call = @ir.hot_build_call(
    func,
    99,
    [],
    if conversion_first {
      [conversion, binary[0]]
    } else {
      [binary[0], conversion]
    },
  )
  let last = if conversion_first {
    [@ir.hot_build_unreachable(func)]
  } else {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i32_clz(),
      14,
      @lib.ValType::i32(),
      false,
    )
  }
  let call_nodes = if conversion_first {
    [call, conversion, binary[0], conversion_input, binary[1], binary[2]]
  } else {
    [call, binary[0], conversion, binary[1], binary[2], conversion_input]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in [first, call_nodes, last] {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-calladdextend-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_and_conversion_arguments(false)
}

///|
test "flatten recognizes an extend-callextenddiv-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_and_conversion_arguments(true)
}

///|
fn flatten_wbtest_recognize_sequence_with_two_binary_arguments(
  division_first : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if division_first {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  }
  let add = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_add(),
    11,
    12,
  )
  let division = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_div_s(),
    if division_first {
      10
    } else {
      13
    },
    0,
  )
  let call = @ir.hot_build_call(
    func,
    99,
    [],
    if division_first {
      [division[0], add[0]]
    } else {
      [add[0], division[0]]
    },
  )
  let last = if division_first {
    [@ir.hot_build_unreachable(func)]
  } else {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i32_clz(),
      14,
      @lib.ValType::i32(),
      false,
    )
  }
  let call_nodes = if division_first {
    [call, division[0], add[0], division[1], division[2], add[1], add[2]]
  } else {
    [call, add[0], division[0], add[1], add[2], division[1], division[2]]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in [first, call_nodes, last] {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-calladddiv-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_binary_arguments(false)
}

///|
test "flatten recognizes an extend-calldivadd-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_binary_arguments(true)
}

///|
test "flatten keeps a binary-rich call pair gated when one opcode is outside the roster" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first_add = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let bit_or = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_or(),
    11,
    12,
  )
  let call = @ir.hot_build_call(func, 99, [], [first_add[0], bit_or[0]])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    call,
    @ir.hot_build_unreachable(func),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
fn flatten_wbtest_recognize_sequence_with_two_unary_or_conversion_arguments(
  first_conversion : Bool,
  second_conversion : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if first_conversion {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  }
  let first_input = @ir.hot_build_const_i32(func, @lib.I32(11))
  let first_argument = if first_conversion {
    @ir.hot_build_convert(func, @lib.ValType::i64(), first_input)
  } else {
    @ir.hot_build_unary(func, @lib.ValType::i32(), first_input)
  }
  @ir.hot_node_exact_instr_set(
    func,
    first_argument,
    if first_conversion {
      @lib.Instruction::i64_extend_i32s()
    } else {
      @lib.Instruction::i32_clz()
    },
  )
  let second_input = @ir.hot_build_const_i32(func, @lib.I32(12))
  let second_argument = if second_conversion {
    @ir.hot_build_convert(func, @lib.ValType::i64(), second_input)
  } else {
    @ir.hot_build_unary(func, @lib.ValType::i32(), second_input)
  }
  @ir.hot_node_exact_instr_set(
    func,
    second_argument,
    if second_conversion {
      @lib.Instruction::i64_extend_i32s()
    } else {
      @lib.Instruction::i32_clz()
    },
  )
  let call = @ir.hot_build_call(func, 99, [], [first_argument, second_argument])
  let last = if first_conversion {
    [@ir.hot_build_unreachable(func)]
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_div_s(),
      13,
      0,
    )
  }
  let call_nodes = [
    call, first_argument, second_argument, first_input, second_input,
  ]
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in [first, call_nodes, last] {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-callclzextend-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_unary_or_conversion_arguments(
    false, true,
  )
}

///|
test "flatten recognizes an extend-callextendclz-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_unary_or_conversion_arguments(
    true, false,
  )
}

///|
test "flatten recognizes an add-callclzclz-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_unary_or_conversion_arguments(
    false, false,
  )
}

///|
test "flatten recognizes an extend-callextendextend-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_unary_or_conversion_arguments(
    true, true,
  )
}

///|
test "flatten keeps a three-rich call gated when one opcode is outside the roster" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let binary = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let unary_input = @ir.hot_build_const_i32(func, @lib.I32(11))
  let unary = @ir.hot_build_unary(func, @lib.ValType::i32(), unary_input)
  @ir.hot_node_exact_instr_set(func, unary, @lib.Instruction::i32_ctz())
  let conversion_input = @ir.hot_build_const_i32(func, @lib.I32(12))
  let conversion = @ir.hot_build_convert(
    func,
    @lib.ValType::i64(),
    conversion_input,
  )
  @ir.hot_node_exact_instr_set(
    func,
    conversion,
    @lib.Instruction::i64_extend_i32s(),
  )
  let call = @ir.hot_build_call(func, 99, [], [binary[0], unary, conversion])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    call,
    @ir.hot_build_unreachable(func),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
fn flatten_wbtest_sequence_with_other_unary_or_conversion_argument_is_gated(
  conversion : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(11))
  let argument = if conversion {
    @ir.hot_build_convert(func, @lib.ValType::i64(), input)
  } else {
    @ir.hot_build_unary(func, @lib.ValType::i32(), input)
  }
  @ir.hot_node_exact_instr_set(
    func,
    argument,
    if conversion {
      @lib.Instruction::i64_extend_i32u()
    } else {
      @lib.Instruction::i32_ctz()
    },
  )
  let call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    add[0],
    call,
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a sequence with another unary-argument call unsupported" {
  flatten_wbtest_sequence_with_other_unary_or_conversion_argument_is_gated(
    false,
  )
}

///|
test "flatten keeps a sequence with another conversion-argument call unsupported" {
  flatten_wbtest_sequence_with_other_unary_or_conversion_argument_is_gated(true)
}

///|
fn flatten_wbtest_build_one_multiply_child_drop(
  func : @ir.HotFunc,
  outer_instr : @lib.Instruction,
  multiply_on_left : Bool,
  base : Int,
) -> Array[Int] {
  let multiply_left = @ir.hot_build_const_i32(func, @lib.I32(base))
  let multiply_right = @ir.hot_build_const_i32(func, @lib.I32(base + 1))
  let multiply = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    multiply_left,
    multiply_right,
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let outer_const = @ir.hot_build_const_i32(func, @lib.I32(base + 2))
  let outer = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    if multiply_on_left {
      multiply
    } else {
      outer_const
    },
    if multiply_on_left {
      outer_const
    } else {
      multiply
    },
  )
  @ir.hot_node_exact_instr_set(func, outer, outer_instr)
  [
    @ir.hot_build_drop(func, outer),
    outer,
    if multiply_on_left {
      multiply
    } else {
      outer_const
    },
    if multiply_on_left {
      outer_const
    } else {
      multiply
    },
    multiply_left,
    multiply_right,
  ]
}

///|
fn flatten_wbtest_recognize_sequence_with_one_multiply_child_drop(
  subtract_tree : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let roots = if subtract_tree {
    [
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        9,
        @lib.ValType::i64(),
        true,
      ),
      flatten_wbtest_build_one_multiply_child_drop(
        func,
        @lib.Instruction::i32_sub(),
        true,
        10,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_and(),
        13,
        14,
      ),
    ]
  } else {
    [
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_add(),
        9,
        10,
      ),
      flatten_wbtest_build_one_multiply_child_drop(
        func,
        @lib.Instruction::i32_add(),
        false,
        11,
      ),
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i32_clz(),
        14,
        @lib.ValType::i32(),
        false,
      ),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in roots {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-nested-addmul-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_one_multiply_child_drop(false)
}

///|
test "flatten recognizes an extend-nested-submul-and try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_one_multiply_child_drop(true)
}

///|
fn flatten_wbtest_build_two_multiply_children_drop(
  func : @ir.HotFunc,
  outer_instr : @lib.Instruction,
  base : Int,
) -> Array[Int] {
  let left = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_mul(),
    base,
    base + 1,
  )
  let right = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_mul(),
    base + 2,
    base + 3,
  )
  let outer = @ir.hot_build_binary(func, @lib.ValType::i32(), left[0], right[0])
  @ir.hot_node_exact_instr_set(func, outer, outer_instr)
  [
    @ir.hot_build_drop(func, outer),
    outer,
    left[0],
    right[0],
    left[1],
    left[2],
    right[1],
    right[2],
  ]
}

///|
fn flatten_wbtest_recognize_sequence_with_two_multiply_children_drop(
  subtract_tree : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let roots = if subtract_tree {
    [
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        9,
        @lib.ValType::i64(),
        true,
      ),
      flatten_wbtest_build_two_multiply_children_drop(
        func,
        @lib.Instruction::i32_sub(),
        10,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_and(),
        14,
        15,
      ),
    ]
  } else {
    [
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_add(),
        9,
        10,
      ),
      flatten_wbtest_build_two_multiply_children_drop(
        func,
        @lib.Instruction::i32_add(),
        11,
      ),
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i32_clz(),
        15,
        @lib.ValType::i32(),
        false,
      ),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in roots {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-tworichadd-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_multiply_children_drop(false)
}

///|
test "flatten recognizes an extend-tworichsub-and try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_multiply_children_drop(true)
}

///|
fn flatten_wbtest_build_deeper_two_multiply_children_drop(
  func : @ir.HotFunc,
  subtract_tree : Bool,
  base : Int,
) -> Array[Int] {
  let rich = flatten_wbtest_build_two_multiply_children_drop(
    func,
    if subtract_tree {
      @lib.Instruction::i32_sub()
    } else {
      @lib.Instruction::i32_add()
    },
    base,
  )
  let constant = @ir.hot_build_const_i32(func, @lib.I32(base + 4))
  let outer = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    if subtract_tree {
      constant
    } else {
      rich[1]
    },
    if subtract_tree {
      rich[1]
    } else {
      constant
    },
  )
  @ir.hot_node_exact_instr_set(
    func,
    outer,
    if subtract_tree {
      @lib.Instruction::i32_sub()
    } else {
      @lib.Instruction::i32_add()
    },
  )
  [
    @ir.hot_build_drop(func, outer),
    outer,
    if subtract_tree {
      constant
    } else {
      rich[1]
    },
    if subtract_tree {
      rich[1]
    } else {
      constant
    },
    rich[2],
    rich[3],
    rich[4],
    rich[5],
    rich[6],
    rich[7],
  ]
}

///|
fn flatten_wbtest_recognize_sequence_with_deeper_two_multiply_children_drop(
  subtract_tree : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let roots = if subtract_tree {
    [
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        9,
        @lib.ValType::i64(),
        true,
      ),
      flatten_wbtest_build_deeper_two_multiply_children_drop(func, true, 10),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_div_s(),
        16,
        0,
      ),
    ]
  } else {
    [
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_and(),
        9,
        10,
      ),
      flatten_wbtest_build_deeper_two_multiply_children_drop(func, false, 11),
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i32_clz(),
        16,
        @lib.ValType::i32(),
        false,
      ),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in roots {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an and-deepadd-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_deeper_two_multiply_children_drop(
    false,
  )
}

///|
test "flatten recognizes an extend-deepsub-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_deeper_two_multiply_children_drop(true)
}

///|
test "flatten keeps a sequence with an alternate deeper two-rich-child root unsupported" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let direct = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let rich = flatten_wbtest_build_two_multiply_children_drop(
    func,
    @lib.Instruction::i32_add(),
    11,
  )
  let outer_const = @ir.hot_build_const_i32(func, @lib.I32(15))
  let deeper = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    rich[1],
    outer_const,
  )
  @ir.hot_node_exact_instr_set(func, deeper, @lib.Instruction::i32_mul())
  @ir.hot_delete_node(func, rich[0])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    direct[0],
    @ir.hot_build_drop(func, deeper),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes a submul-dropconst-and try-table suffix sequence" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let rich = flatten_wbtest_build_one_multiply_child_drop(
    func,
    @lib.Instruction::i32_sub(),
    true,
    9,
  )
  let constant = @ir.hot_build_const_i32(func, @lib.I32(12))
  let drop_const = @ir.hot_build_drop(func, constant)
  let last = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_and(),
    13,
    14,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    rich[0],
    drop_const,
    last[0],
  ])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      rich[0],
      rich[1],
      rich[2],
      rich[3],
      rich[4],
      rich[5],
      drop_const,
      constant,
      last[0],
      last[1],
      last[2],
      last[3],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}
