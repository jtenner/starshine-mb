///|
test "effect summaries distinguish pure arithmetic from memory access" {
  let func = HotFunc::new()
  let lhs = hot_build_const_i32(func, @lib.I32(1))
  let rhs = hot_build_const_i32(func, @lib.I32(2))
  let add = hot_build_binary(func, @lib.ValType::i32(), lhs, rhs)
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let addr = hot_build_const_i32(func, @lib.I32(0))
  let load = hot_build_load(func, @lib.ValType::i32(), memarg, addr)

  assert_true(effects_is_pure(effects_for_node(func, add)))
  assert_true(effects_reads_memory(effects_for_node(func, load)))
  assert_false(effects_is_pure(effects_for_node(func, load)))
}

///|
test "effect summaries expose call throw and exact heap payload categories" {
  let func = HotFunc::new()
  let arg = hot_build_const_i32(func, @lib.I32(7))
  let call = hot_build_call(func, 0, [@lib.ValType::i32()], [arg])
  let throw_ = hot_build_throw(func, @lib.TagIdx::new(0U), [])
  let ref_null = hot_build_ref_null(
    func,
    @lib.RefType::abs(@lib.AbsHeapType::extern_()),
  )
  let array_len = hot_build_heap(
    func,
    [@lib.ValType::i32()],
    @lib.Instruction::array_len(),
    [ref_null],
  )

  assert_true((effects_for_node(func, call) & EFFECT_MASK_CALL) != 0U)
  assert_true(effects_may_throw(effects_for_node(func, call)))
  assert_true((effects_for_node(func, throw_) & EFFECT_MASK_THROW) != 0U)
  assert_true(effects_may_throw(effects_for_node(func, throw_)))
  assert_true(effects_reads_memory(effects_for_node(func, array_len)))
  assert_true((effects_for_node(func, array_len) & EFFECT_MASK_TRAP) != 0U)
}

///|
test "effect summaries aggregate across blocks and regions conservatively" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let condition = hot_build_const_i32(func, @lib.I32(1))
  let ref_null = hot_build_ref_null(
    func,
    @lib.RefType::abs(@lib.AbsHeapType::extern_()),
  )
  let array_len = hot_build_heap(
    func,
    [@lib.ValType::i32()],
    @lib.Instruction::array_len(),
    [ref_null],
  )
  let then_drop = hot_build_drop(func, array_len)
  let else_value = hot_build_const_i32(func, @lib.I32(9))
  let else_set = hot_build_local_set(func, 1, else_value)
  let if_id = hot_build_if(
    func,
    @lib.BlockType::void_(),
    condition,
    [then_drop],
    else_body=Some([else_set]),
  )
  hot_root_append(func, if_id)
  let cfg = cfg_build(func)
  let header_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 0).unwrap()
  let block_mask = effects_for_block(func, cfg, header_block)
  let region_mask = effects_for_region(func, HotRegionRef::root())

  assert_true((block_mask & EFFECT_MASK_CONTROL) != 0U)
  assert_true(effects_reads_memory(block_mask))
  assert_true((block_mask & EFFECT_MASK_LOCAL_STATE) != 0U)
  assert_true((region_mask & EFFECT_MASK_LOCAL_STATE) != 0U)
  assert_true(effects_reads_memory(region_mask))
}

///|
fn effects_shared_dag_fixture(depth : Int) -> (HotFunc, NodeId) {
  let func = HotFunc::new()
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let addr = hot_build_const_i32(func, @lib.I32(0))
  let mut value = hot_build_load(func, @lib.ValType::i32(), memarg, addr)
  for i = 0; i < depth; i = i + 1 {
    let _ = i
    let lhs = hot_build_binary(
      func,
      @lib.ValType::i32(),
      value,
      hot_build_const_i32(func, @lib.I32(1)),
    )
    let rhs = hot_build_binary(
      func,
      @lib.ValType::i32(),
      value,
      hot_build_const_i32(func, @lib.I32(2)),
    )
    value = hot_build_binary(func, @lib.ValType::i32(), lhs, rhs)
  }
  hot_root_append(func, hot_build_drop(func, value))
  (func, value)
}

///|
test "effect cache handles shared dags without changing masks" {
  let (func, value) = effects_shared_dag_fixture(24)
  let node_mask = effects_for_node(func, value)
  let region_mask = effects_for_region(func, HotRegionRef::root())

  assert_true(effects_reads_memory(node_mask))
  assert_true(effects_reads_memory(region_mask))
  assert_eq(node_mask, region_mask)
}
