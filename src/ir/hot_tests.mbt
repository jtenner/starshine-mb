///|
fn hot_test_roundtrip_body() -> Array[TypedInstr] {
  [
    TypedInstr::block(BlockType::void_(), [
      TypedInstr::if_(
        BlockType::void_(),
        TypedInstr::local_get(LocalIdx::new(0)),
        [TypedInstr::return_([])],
        Some([TypedInstr::nop()]),
      ),
    ]),
    TypedInstr::return_([TypedInstr::i32_const(I32(7))]),
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
    [TypedInstr::nop()],
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
  assert_eq(lowered, [TypedInstr::return_([])])
}

///|
test "hot block children mutate by slot" {
  let func = hot_lift_body(
    [TypedInstr::block(BlockType::void_(), [TypedInstr::nop()])],
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
  assert_eq(lowered, [
    TypedInstr::block(BlockType::void_(), [TypedInstr::return_([])]),
  ])
}
