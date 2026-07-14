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
test "flatten keeps multiple non-unreachable try-table suffix roots gated" {
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
  let first_drop = @ir.hot_build_drop(
    func,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
  )
  let second_drop = @ir.hot_build_drop(
    func,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
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
