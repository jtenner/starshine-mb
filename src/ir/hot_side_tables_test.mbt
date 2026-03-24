///|
test "typed side tables roundtrip payloads and classify opcode families" {
  let func = HotFunc::new()

  let const_id = hot_alloc_const(func, HotConstPayload::i32_const(@lib.I32(7)))
  let f32_const_id = hot_alloc_const(
    func,
    HotConstPayload::f32_const(@lib.F32(3.5)),
  )
  let f64_const_id = hot_alloc_const(
    func,
    HotConstPayload::f64_const(@lib.F64(7.25)),
  )
  let memarg_id = hot_alloc_memarg(
    func,
    HotMemArg::new(@lib.MemArg::new(@lib.U32(2), None, @lib.U64(8))),
  )
  let call_sig_id = hot_alloc_call_sig(
    func,
    HotCallSig::new(
      @lib.TypeIdx::new(3U),
      table_idx=Some(@lib.TableIdx::new(1U)),
    ),
  )
  let instr_payload_id = hot_alloc_instr_payload(
    func,
    HotInstrPayload::new(@lib.Instruction::i32_add()),
  )

  assert_eq(
    hot_const_get(func, const_id),
    HotConstPayload::i32_const(@lib.I32(7)),
  )
  assert_eq(
    hot_const_get(func, f32_const_id),
    HotConstPayload::f32_const(@lib.F32(3.5)),
  )
  assert_eq(
    hot_const_get(func, f64_const_id),
    HotConstPayload::f64_const(@lib.F64(7.25)),
  )
  assert_eq(
    hot_memarg_get(func, memarg_id),
    HotMemArg::new(@lib.MemArg::new(@lib.U32(2), None, @lib.U64(8))),
  )
  assert_eq(
    hot_call_sig_get(func, call_sig_id),
    HotCallSig::new(
      @lib.TypeIdx::new(3U),
      table_idx=Some(@lib.TableIdx::new(1U)),
    ),
  )
  assert_eq(
    hot_instr_payload_get(func, instr_payload_id),
    HotInstrPayload::new(@lib.Instruction::i32_add()),
  )
}

///|
test "exact instruction payload helpers expose opcode identity for generic families" {
  let func = HotFunc::new()
  let ref_null = hot_build_ref_null(
    func,
    @lib.RefType::abs(@lib.AbsHeapType::extern_()),
  )
  let heap = hot_build_heap(
    func,
    [@lib.ValType::i32()],
    @lib.Instruction::array_len(),
    [ref_null],
  )
  assert_eq(
    hot_node_exact_instr(func, heap),
    Some(@lib.Instruction::array_len()),
  )
}

///|
test "branch table and catch side tables expose typed target metadata" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::nop()],
            Some([@lib.Instruction::nop()]),
          ),
          @lib.Instruction::loop_(
            @lib.BlockType::void_(),
            @lib.Expr::new([@lib.Instruction::nop()]),
          ),
        ]),
      ),
    ]),
    HotLocals::new(),
  )
  let block = hot_root_get(func, 0)
  let if_ = hot_child_get(func, block, 0)
  let loop_ = hot_child_get(func, block, 1)
  let label0 = hot_control_node_label(func, block)
  let label1 = hot_control_node_label(func, loop_)
  let label2 = hot_control_node_label(func, if_)

  let branch_table_id = hot_alloc_branch_table(
    func,
    HotBranchTable::new([label0, label1], label2),
  )
  let catch_info_id = hot_alloc_catch_info(
    func,
    HotCatchInfo::new([
      HotCatchArm::catch_(@lib.TagIdx::new(4U), label1),
      HotCatchArm::all(label2),
    ]),
  )

  assert_eq(hot_branch_table_targets(func, branch_table_id), [label0, label1])
  assert_eq(hot_branch_table_default_target(func, branch_table_id), label2)
  assert_eq(
    hot_catch_info_get(func, catch_info_id),
    HotCatchInfo::new([
      HotCatchArm::catch_(@lib.TagIdx::new(4U), label1),
      HotCatchArm::all(label2),
    ]),
  )
}
