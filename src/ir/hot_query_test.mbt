///|
test "query helpers classify representative node families and expose node result types" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let local_get = hot_build_local_get(func, 0)
  let global = hot_build_global_get(func, 2, @lib.ValType::i64())
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let load = hot_build_load(func, @lib.ValType::i32(), memarg, local_get)
  let table = hot_build_table_get(func, 1, @lib.ValType::externref(), local_get)
  let numeric = hot_build_binary(
    func,
    @lib.ValType::i32(),
    local_get,
    local_get,
  )
  let tuple = hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i64()],
    [local_get, hot_build_const_i64(func, @lib.I64(2L))],
  )
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
  let throw_ref = hot_build_throw_ref(func, ref_null)
  let call = hot_build_call(func, 5, [@lib.ValType::i32()], [local_get])
  let block = hot_build_block(func, @lib.BlockType::void_(), [
    hot_build_nop(func),
  ])

  assert_true(hot_node_kind_is_local(func, local_get))
  assert_true(hot_node_kind_is_global(func, global))
  assert_true(hot_node_kind_is_memory(func, load))
  assert_true(hot_node_kind_is_table(func, table))
  assert_true(hot_node_kind_is_numeric(func, numeric))
  assert_true(hot_node_kind_is_tuple(func, tuple))
  assert_true(hot_node_kind_is_heap(func, heap))
  assert_true(hot_node_kind_is_exception(func, throw_ref))
  assert_true(hot_node_kind_is_call(func, call))
  assert_true(hot_node_kind_is_control(func, block))

  assert_eq(
    hot_node_type(func, local_get),
    hot_type_intern_value(func, @lib.ValType::i32()),
  )
  assert_eq(hot_node_result_arity(func, local_get), 1)
  assert_eq(hot_node_result_arity(func, tuple), 2)
  assert_eq(
    hot_node_exact_instr(func, heap),
    Some(@lib.Instruction::array_len()),
  )
}

///|
test "branch queries expose single-target and branch-table metadata" {
  let func = HotFunc::new()
  let condition = hot_build_const_i32(func, @lib.I32(1))
  let block = hot_build_block(func, @lib.BlockType::void_(), [
    hot_build_nop(func),
  ])
  let target = hot_control_node_label(func, block)
  let br_if = hot_build_br_if(func, target, condition)
  let br_table = hot_build_br_table(func, [target], target, condition)
  let delegate = hot_build_delegate(func, target)

  assert_eq(hot_branch_target(func, br_if), Some(target))
  assert_eq(hot_branch_target(func, br_table), Some(target))
  assert_eq(hot_branch_target(func, delegate), Some(target))
  assert_eq(hot_branch_table_targets_for_node(func, br_table), [target])
  assert_eq(hot_branch_table_targets_for_node(func, br_if).length(), 0)
}

///|
test "root child local and tombstone queries stay read only" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i64(),
      @lib.ValType::externref(),
    ]),
  )
  let deleted = hot_build_nop(func)
  let first = hot_build_const_i32(func, @lib.I32(7))
  let second = hot_build_const_i32(func, @lib.I32(9))
  let block = hot_build_block(func, @lib.BlockType::void_(), [first, second])
  hot_root_append(func, block)
  hot_delete_node(func, deleted)

  let rev0 = hot_revision_current(func)
  assert_eq(hot_root_span(func), [block])
  assert_eq(hot_child_span(func, block), [first, second])
  assert_eq(hot_local_param_count(func), 1)
  assert_eq(hot_local_body_count(func), 2)
  assert_true(hot_local_is_param(func, 0))
  assert_false(hot_local_is_param(func, 1))
  assert_true(hot_node_is_deleted(func, deleted))
  assert_false(hot_node_is_deleted(func, block))
  assert_eq(hot_revision_current(func), rev0)
}
