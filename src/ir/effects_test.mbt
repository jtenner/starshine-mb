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
test "SIMD memory nodes retain read write and trap effects" {
  let load_fixture = ir_test_build_hot_from_wat(
    "(module (memory 1) (func (local v128) i32.const 0 v128.load local.set 0))",
  )
  let load_func = load_fixture.hot_func
  let load = hot_child_get(load_func, hot_root_get(load_func, 0), 0)
  let load_mask = effects_for_node(load_func, load)
  assert_true((load_mask & EFFECT_MASK_MEMORY_READ) != 0U)
  assert_true((load_mask & EFFECT_MASK_TRAP) != 0U)

  let store_fixture = ir_test_build_hot_from_wat(
    "(module (memory 1) (func i32.const 0 v128.const i32x4 1 2 3 4 v128.store))",
  )
  let store_func = store_fixture.hot_func
  let store_mask = effects_for_node(store_func, hot_root_get(store_func, 0))
  assert_true((store_mask & EFFECT_MASK_MEMORY_WRITE) != 0U)
  assert_true((store_mask & EFFECT_MASK_TRAP) != 0U)
  assert_false(
    hot_node_has_flag(store_func, hot_root_get(store_func, 0), HOT_FLAG_VALUE),
  )
}

///|
test "string array encoding retains memory write and null trap effects" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (type $u8 (array (mut i8))) (func (result i32) ref.null noextern ref.null $u8 i32.const 0 string.encode_utf8_array))",
  )
  let func = fixture.hot_func
  let encode = hot_root_get(func, 0)
  let mask = effects_for_node(func, encode)
  assert_true((mask & EFFECT_MASK_MEMORY_WRITE) != 0U)
  assert_true((mask & EFFECT_MASK_TRAP) != 0U)
  assert_true(hot_has_side_effect(func, encode))
}

///|
test "synthesized ref.as_non_null retains its trap effect" {
  let func = HotFunc::new()
  let nullable = @lib.RefType::abs(@lib.AbsHeapType::extern_())
  let nonnull = @lib.RefType::new(
    false,
    @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
  )
  let operand = hot_build_ref_null(func, nullable)
  let checked = hot_build_unary(func, @lib.ValType::ref_type(nonnull), operand)
  hot_node_exact_instr_set(func, checked, @lib.Instruction::ref_as_non_null())
  assert_true((effects_for_node(func, checked) & EFFECT_MASK_TRAP) != 0U)
}

///|
test "string.eq accepts null operands without a trap effect" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (result i32) ref.null noextern ref.null noextern string.eq))",
  )
  let func = fixture.hot_func
  let eq = hot_root_get(func, 0)
  assert_true(effects_is_pure(effects_for_node(func, eq)))
  assert_false(hot_may_trap(func, eq))
}

///|
test "effect summaries mark exact trapping numeric instructions" {
  let div_func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_div_s(),
      @lib.Instruction::drop(),
    ]),
    HotLocals::new(),
  )
  let div_drop = hot_root_get(div_func, 0)
  let div = hot_child_get(div_func, div_drop, 0)
  assert_true((effects_for_node(div_func, div) & EFFECT_MASK_TRAP) != 0U)

  let trunc_func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::f32_const(@lib.F32(0.0)),
      @lib.Instruction::i32_trunc_f32s(),
      @lib.Instruction::drop(),
    ]),
    HotLocals::new(),
  )
  let trunc_drop = hot_root_get(trunc_func, 0)
  let trunc = hot_child_get(trunc_func, trunc_drop, 0)
  assert_true((effects_for_node(trunc_func, trunc) & EFFECT_MASK_TRAP) != 0U)
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
  @debug.assert_eq(node_mask, region_mask)
}
