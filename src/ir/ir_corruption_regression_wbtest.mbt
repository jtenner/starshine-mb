///|
struct IrCorruptionRegionWalk {
  holders : Array[NodeId]
} derive(Eq, Debug)

///|
fn ir_corruption_collect_region(
  state : IrCorruptionRegionWalk,
  _control_id : NodeId,
  _slot : HotControlRegionSlotInfo,
  holder : NodeId,
) -> HotVisitCtl[IrCorruptionRegionWalk, String] {
  let holders = state.holders.copy()
  holders.push(holder)
  hot_visit_continue({ holders, })
}

///|
test "loop builder separates result arity from entry branch arity" {
  let func = HotFunc::new()
  let value = hot_build_const_i32(func, @lib.I32(1))
  let loop_id = hot_build_loop(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [value],
  )
  let label = hot_control_node_label(func, loop_id)
  assert_eq(hot_label_branch_arity(func, label), 0)
  assert_eq(
    hot_region_result_arity(func, hot_region_body_ref(func, loop_id)),
    1,
  )
}

///|
test "hot functions own local metadata arrays independently" {
  let caller_locals = [@lib.ValType::i32()]
  let metadata = HotLocals::new(locals=caller_locals)
  let first = HotFunc::new(locals=metadata)
  let second = HotFunc::new(locals=metadata)

  caller_locals[0] = @lib.ValType::i64()
  assert_eq(hot_local_type(first, 0), Some(@lib.ValType::i32()))
  ignore(hot_append_body_local(first, @lib.ValType::f32()))
  assert_eq(hot_local_count(first), 2)
  assert_eq(hot_local_count(second), 1)
}

///|
test "hot type getters do not expose interned result arrays" {
  let func = HotFunc::new()
  let result_id = hot_type_intern_results(func, [@lib.ValType::i32()])
  match hot_type_get(func, result_id) {
    Results(values) => values[0] = @lib.ValType::i64()
    _ => fail("expected results type")
  }
  assert_eq(hot_type_results(func, result_id), [@lib.ValType::i32()])

  let resolved_id = hot_type_intern_resolved_block_result(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [@lib.ValType::i32()],
    [@lib.ValType::i64()],
  )
  match hot_type_get(func, resolved_id) {
    BlockResultResolved(_, params, results) => {
      params[0] = @lib.ValType::f32()
      results[0] = @lib.ValType::f64()
    }
    _ => fail("expected resolved block type")
  }
  match hot_type_get(func, resolved_id) {
    BlockResultResolved(_, params, results) => {
      assert_eq(params, [@lib.ValType::i32()])
      assert_eq(results, [@lib.ValType::i64()])
    }
    _ => fail("expected resolved block type")
  }
}

///|
test "exact instruction payloads own and protect array fields" {
  let func = HotFunc::new()
  let types = [@lib.ValType::i32()]
  let select_id = hot_alloc_instr_payload(
    func,
    HotInstrPayload::new(@lib.Instruction::select(types=Some(types))),
  )
  types[0] = @lib.ValType::i64()
  match hot_instr_payload_get(func, select_id).instr {
    @lib.Select(Some(stored)) => {
      assert_eq(stored, [@lib.ValType::i32()])
      stored[0] = @lib.ValType::f32()
    }
    _ => fail("expected typed select")
  }
  match hot_instr_payload_get(func, select_id).instr {
    @lib.Select(Some(stored)) => assert_eq(stored, [@lib.ValType::i32()])
    _ => fail("expected typed select")
  }

  let handlers = [@lib.ResumeHandler::on_switch(@lib.TagIdx::new(0U))]
  let resume_id = hot_alloc_instr_payload(
    func,
    HotInstrPayload::new(
      @lib.Instruction::resume_(@lib.TypeIdx::new(0U), handlers),
    ),
  )
  handlers[0] = @lib.ResumeHandler::on_switch(@lib.TagIdx::new(1U))
  match hot_instr_payload_get(func, resume_id).instr {
    @lib.Resume(_, stored) =>
      assert_eq(stored, [@lib.ResumeHandler::on_switch(@lib.TagIdx::new(0U))])
    _ => fail("expected resume")
  }
}

///|
test "loop region result arity uses results rather than branch parameters" {
  let func = HotFunc::new()
  let ty = hot_type_intern_resolved_block_result(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [@lib.ValType::i64()],
  )
  let first_entry = hot_build_const_i32(func, @lib.I32(1))
  let second_entry = hot_build_const_i32(func, @lib.I32(2))
  let result = hot_build_const_i64(func, @lib.I64(3L))
  let loop_id = hot_build_node(func, HotOp::Loop, ty, children=[
    first_entry, second_entry, result,
  ])
  let label = hot_label_alloc(func, HotLabelKind::LoopLabel, ty, loop_id, 2)
  hot_node_set(func, loop_id, { ..hot_node_get(func, loop_id), imm0: label, })
  assert_eq(
    hot_region_result_arity(func, hot_region_body_ref(func, loop_id)),
    1,
  )
}

///|
test "control region walker reports direct block and loop holders" {
  let func = HotFunc::new()
  let block = hot_build_block(func, @lib.BlockType::void_(), [])
  let loop_ = hot_build_loop(func, @lib.BlockType::void_(), [])
  for control in [block, loop_] {
    let walked = hot_walk_control_regions(
      func,
      control,
      { holders: [], },
      ir_corruption_collect_region,
    ).unwrap()
    assert_eq(walked.holders, [control])
  }
}

///|
test "unsupported simple values never compare equal" {
  let func = HotFunc::new()
  let left = hot_build_global_get(func, 0, @lib.ValType::i32())
  let right = hot_build_global_get(func, 1, @lib.ValType::i32())
  assert_false(hot_nodes_match_simple_value(func, left, right))
  assert_false(hot_nodes_match_simple_value(func, left, left))
}

///|
test "control verifier rejects missing typed try entry operands" {
  for use_table in [false, true] {
    let func = HotFunc::new()
    let control = if use_table {
      hot_build_try_table(func, @lib.BlockType::void_(), [], [])
    } else {
      hot_build_try(func, @lib.BlockType::void_(), [])
    }
    let old = hot_child_span(func, control)
    let ty = hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [@lib.ValType::i32()],
      [],
    )
    hot_node_set(func, control, { ..hot_node_get(func, control), ty, })
    ignore(
      hot_replace_child_span(func, control, [old[0], old[1], HOT_NONE_NODE]),
    )
    match hot_verify_control(func) {
      Err(HotVerifyError::InvalidControlChild(node, 2, HOT_NONE_NODE)) =>
        assert_eq(node, control)
      other => fail("expected invalid typed entry operand, got {other}")
    }
  }
}

///|
test "bitset word count does not overflow at the maximum size" {
  assert_eq(bitset_word_count(2147483647), 33554432)
}
