///|
test "typed if builder owns label and region setup" {
  let func = HotFunc::new()
  let condition = hot_build_const_i32(func, @lib.I32(1))
  let then_value = hot_build_const_i32(func, @lib.I32(7))
  let else_value = hot_build_const_i32(func, @lib.I32(9))
  let if_id = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    condition,
    [then_value],
    else_body=Some([else_value]),
  )

  let if_node = hot_node_get(func, if_id)
  match if_node.op {
    If => ()
    _ => fail("expected if node")
  }
  let if_label = hot_control_node_label(func, if_id)
  match hot_label_kind(func, if_label) {
    IfLabel => ()
    _ => fail("expected if label")
  }
  assert_eq(hot_label_owner(func, if_label), if_id)
  assert_eq(hot_label_branch_arity(func, if_label), 1)
  assert_eq(hot_child_count(func, if_id), 3)

  let then_region = hot_child_get(func, if_id, 1)
  let else_region = hot_child_get(func, if_id, 2)
  match hot_label_kind(func, hot_control_node_label(func, then_region)) {
    RegionLabel => ()
    _ => fail("expected then region label")
  }
  match hot_label_kind(func, hot_control_node_label(func, else_region)) {
    RegionLabel => ()
    _ => fail("expected else region label")
  }
  assert_eq(hot_child_get(func, then_region, 0), then_value)
  assert_eq(hot_child_get(func, else_region, 0), else_value)
}

///|
test "branch call and memory builders wire side tables" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let address = hot_build_local_get(func, 0)
  let selector = hot_build_const_i32(func, @lib.I32(3))
  let value = hot_build_const_i32(func, @lib.I32(11))
  let callee_ref = hot_build_ref_null(
    func,
    @lib.RefType::abs(@lib.AbsHeapType::extern_()),
  )
  let memarg = @lib.MemArg::new(@lib.U32(2), None, @lib.U64(16))

  let block_id = hot_build_block(func, @lib.BlockType::void_(), [
    hot_build_unreachable(func),
  ])
  let target = hot_control_node_label(func, block_id)
  let br_if_id = hot_build_br_if(func, target, selector)
  let br_table_id = hot_build_br_table(func, [target], target, selector)
  let load_id = hot_build_load(func, @lib.ValType::i32(), memarg, address)
  let store_id = hot_build_store(func, memarg, address, value)
  let call_indirect_id = hot_build_call_indirect(
    func,
    @lib.TypeIdx::new(3U),
    @lib.TableIdx::new(1U),
    [@lib.ValType::i32()],
    [value],
    selector,
  )
  let call_ref_id = hot_build_call_ref(
    func,
    @lib.TypeIdx::new(5U),
    [@lib.ValType::i32()],
    [value],
    callee_ref,
  )

  assert_eq(hot_node_get(func, br_if_id).imm0, target)
  match hot_node_get(func, load_id).op {
    Load => ()
    _ => fail("expected load node")
  }
  assert_eq(
    hot_memarg_get(func, hot_node_get(func, load_id).imm0),
    HotMemArg::new(memarg),
  )
  assert_eq(
    hot_memarg_get(func, hot_node_get(func, store_id).imm0),
    HotMemArg::new(memarg),
  )
  assert_eq(
    hot_branch_table_targets(func, hot_node_get(func, br_table_id).imm0),
    [target],
  )
  assert_eq(
    hot_call_sig_get(func, hot_node_get(func, call_indirect_id).imm0),
    HotCallSig::new(
      @lib.TypeIdx::new(3U),
      table_idx=Some(@lib.TableIdx::new(1U)),
    ),
  )
  assert_eq(
    hot_call_sig_get(func, hot_node_get(func, call_ref_id).imm0),
    HotCallSig::new(@lib.TypeIdx::new(5U)),
  )
}

///|
test "general family builders create nodes without raw field assembly" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let base = hot_build_const_i32(func, @lib.I32(4))
  let i64_value = hot_build_const_i64(func, @lib.I64(9L))
  let ref_null = hot_build_ref_null(
    func,
    @lib.RefType::abs(@lib.AbsHeapType::extern_()),
  )
  let string_const = hot_build_string_const(func, b"hi")
  let local_set = hot_build_local_set(func, 0, base)
  let local_tee = hot_build_local_tee(func, 0, base)
  let global_get = hot_build_global_get(func, 2, @lib.ValType::i64())
  let global_set = hot_build_global_set(func, 2, i64_value)
  let call_id = hot_build_call(func, 6, [@lib.ValType::i32()], [base])
  let return_call_id = hot_build_return_call(func, 7, [base])
  let unary_id = hot_build_unary(func, @lib.ValType::i32(), base)
  let binary_id = hot_build_binary(func, @lib.ValType::i32(), base, base)
  let compare_id = hot_build_compare(func, base, base)
  let convert_id = hot_build_convert(func, @lib.ValType::i64(), base)
  let tuple_make_id = hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i64()],
    [base, i64_value],
  )
  let tuple_extract_id = hot_build_tuple_extract(
    func,
    @lib.ValType::i64(),
    tuple_make_id,
    1,
  )
  let throw_id = hot_build_throw(func, @lib.TagIdx::new(2U), [base])
  let throw_ref_id = hot_build_throw_ref(func, ref_null)
  let delegate_id = hot_build_delegate(func, 3)

  match hot_node_get(func, local_set).op {
    LocalSet => ()
    _ => fail("expected local_set node")
  }
  match hot_node_get(func, local_tee).op {
    LocalTee => ()
    _ => fail("expected local_tee node")
  }
  match hot_node_get(func, global_get).op {
    GlobalGet => ()
    _ => fail("expected global_get node")
  }
  match hot_node_get(func, global_set).op {
    GlobalSet => ()
    _ => fail("expected global_set node")
  }
  match hot_node_get(func, call_id).op {
    Call => ()
    _ => fail("expected call node")
  }
  match hot_node_get(func, return_call_id).op {
    ReturnCall => ()
    _ => fail("expected return_call node")
  }
  match hot_node_get(func, unary_id).op {
    Unary => ()
    _ => fail("expected unary node")
  }
  match hot_node_get(func, binary_id).op {
    Binary => ()
    _ => fail("expected binary node")
  }
  match hot_node_get(func, compare_id).op {
    Compare => ()
    _ => fail("expected compare node")
  }
  match hot_node_get(func, convert_id).op {
    Convert => ()
    _ => fail("expected convert node")
  }
  match hot_node_get(func, tuple_make_id).op {
    TupleMake => ()
    _ => fail("expected tuple_make node")
  }
  match hot_node_get(func, tuple_extract_id).op {
    TupleExtract => ()
    _ => fail("expected tuple_extract node")
  }
  match hot_node_get(func, throw_id).op {
    Throw => ()
    _ => fail("expected throw node")
  }
  match hot_node_get(func, throw_ref_id).op {
    ThrowRef => ()
    _ => fail("expected throw_ref node")
  }
  match hot_node_get(func, delegate_id).op {
    Delegate => ()
    _ => fail("expected delegate node")
  }
  match hot_node_get(func, string_const).op {
    Const => ()
    _ => fail("expected string const node")
  }
}

///|
test "builder created nodes can replace roots and lower through existing hot lowering" {
  let func = HotFunc::new()
  let first_root = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(7)))
  hot_append_root(func, first_root)

  let replacement = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(9)))
  hot_root_set(func, 0, replacement)

  assert_eq(
    hot_lower_body(func),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(9)),
      @lib.Instruction::drop(),
    ]),
  )
}
