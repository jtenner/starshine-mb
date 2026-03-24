///|
fn hot_test_roundtrip_body() -> Array[TInstr] {
  [
    TInstr::block(
      BlockType::void_(),
      [
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          [TInstr::return_([])],
          Some([TInstr::nop()]),
        ),
      ],
    ),
    TInstr::return_([TInstr::i32_const(I32(7))]),
  ]
}

///|
test "hot lift and lower roundtrip typed bodies" {
  let func = hot_lift_body(
    hot_test_roundtrip_body(),
    HotLocals::new(param_count=1, locals=[]),
  )
  let lowered = hot_lower_body(func)
  assert_eq(lowered, hot_test_roundtrip_body())
}

///|
test "hot root slots can be replaced directly" {
  let func = hot_lift_body(
    [TInstr::nop()],
    HotLocals::new(param_count=0, locals=[]),
  )
  let root = hot_alloc_node(
    func,
    hot_make_simple_node(
      HotOp::Return,
      hot_type_void(func),
      HOT_FLAG_TERMINATOR,
      0,
      0,
      [],
    ),
  )
  hot_root_set(func, 0, root)
  let lowered = hot_lower_body(func)
  assert_eq(lowered, [TInstr::return_([])])
}

///|
test "hot block children mutate by slot" {
  let func = hot_lift_body(
    [TInstr::block(BlockType::void_(), [TInstr::nop()])],
    HotLocals::new(param_count=0, locals=[]),
  )
  let block = hot_root_get(func, 0)
  let child = hot_alloc_node(
    func,
    hot_make_simple_node(
      HotOp::Return,
      hot_type_void(func),
      HOT_FLAG_TERMINATOR,
      0,
      0,
      [],
    ),
  )
  hot_child_set(func, block, 0, child)
  let lowered = hot_lower_body(func)
  assert_eq(
    lowered,
    [TInstr::block(BlockType::void_(), [TInstr::return_([])])],
  )
}
