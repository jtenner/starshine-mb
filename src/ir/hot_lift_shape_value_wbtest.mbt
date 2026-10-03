///|
test "lift node shapes retain direct indices and operand order" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let local_node = hot_lift_impl_build_direct_node(
    func,
    HotOp::LocalGet,
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    [@lib.ValType::i32()],
    [],
  )
  let node = hot_node_get(func, local_node)
  assert_eq(node.op, HotOp::LocalGet)
  assert_eq(node.imm0, 0)
  assert_eq(node.imm1, 0)
  assert_eq(
    hot_type_get(func, node.ty),
    HotTypeInfo::Value(@lib.ValType::i32()),
  )
  let a = hot_build_const_i32(func, @lib.I32(1))
  let b = hot_build_const_i32(func, @lib.I32(2))
  let c = hot_build_const_i32(func, @lib.I32(3))
  let copy = hot_lift_impl_build_direct_node3(
    func,
    HotOp::MemoryCopy,
    @lib.Instruction::memory_copy(@lib.MemIdx::new(2U), @lib.MemIdx::new(3U)),
    [],
    a,
    b,
    c,
  )
  let node = hot_node_get(func, copy)
  assert_eq(node.imm0, 2)
  assert_eq(node.imm1, 3)
  assert_eq(hot_child_span(func, copy), [a, b, c])
  assert_eq(hot_type_get(func, node.ty), HotTypeInfo::VoidType)
}

///|
test "lift node shapes retain constant and call signature payload identity" {
  let func = HotFunc::new()
  let constant = hot_lift_impl_build_direct_node(
    func,
    HotOp::Const,
    @lib.Instruction::i64_const(@lib.I64(17)),
    [@lib.ValType::i64()],
    [],
  )
  let node = hot_node_get(func, constant)
  assert_eq(
    hot_const_get(func, node.imm0),
    HotConstPayload::i64_const(@lib.I64(17)),
  )
  let arg = hot_build_const_i32(func, @lib.I32(0))
  let call = hot_lift_impl_build_direct_node2(
    func,
    HotOp::CallIndirect,
    @lib.Instruction::call_indirect(
      @lib.TypeIdx::new(2U),
      @lib.TableIdx::new(1U),
    ),
    [@lib.ValType::i32(), @lib.ValType::i64()],
    arg,
    constant,
  )
  let node = hot_node_get(func, call)
  assert_eq(
    hot_call_sig_get(func, node.imm0),
    HotCallSig::new(
      @lib.TypeIdx::new(2U),
      table_idx=Some(@lib.TableIdx::new(1U)),
    ),
  )
  assert_eq(hot_child_span(func, call), [arg, constant])
  assert_eq(
    hot_type_get(func, node.ty),
    HotTypeInfo::Results([@lib.ValType::i32(), @lib.ValType::i64()]),
  )
  assert_eq(func.consts.length(), 2)
  assert_eq(func.call_sigs.length(), 1)
}

///|
test "lift exact shapes retain memory and instruction payload mapping" {
  let func = HotFunc::new()
  let arg = hot_build_const_i32(func, @lib.I32(0))
  let memarg = @lib.MemArg::new(3U, Some(@lib.MemIdx::new(2U)), 13UL)
  let instruction = @lib.Instruction::i64_load(memarg)
  let load = hot_lift_impl_build_exact_node1(
    func,
    HotOp::Load,
    instruction,
    [@lib.ValType::i64()],
    arg,
  )
  let node = hot_node_get(func, load)
  assert_eq(hot_memarg_get(func, node.imm0).memarg, memarg)
  assert_eq(hot_instr_payload_get(func, node.imm1).instr, instruction)
  assert_eq(hot_child_span(func, load), [arg])
  assert_eq(func.memargs.length(), 1)
  assert_eq(func.instr_payloads.length(), 1)
  let simd = @lib.Instruction::i32x4_abs()
  let exact = hot_lift_impl_build_exact_node1(
    func,
    HotOp::Simd,
    simd,
    [@lib.ValType::v128()],
    arg,
  )
  let node = hot_node_get(func, exact)
  assert_eq(node.imm0, 1)
  assert_eq(node.imm1, 0)
  assert_eq(hot_instr_payload_get(func, node.imm0).instr, simd)
  assert_eq(func.memargs.length(), 1)
  assert_eq(func.instr_payloads.length(), 2)
}
