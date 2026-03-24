///|
fn hot_test_roundtrip_body() -> Expr {
  Expr::new([
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::local_get(LocalIdx::new(0)),
        Instruction::if_(
          BlockType::void_(),
          [Instruction::nop()],
          Some([Instruction::nop()]),
        ),
      ]),
    ),
    Instruction::i32_const(I32(7)),
    Instruction::return_(),
  ])
}

///|
test "hot lift and lower roundtrip typed bodies" {
  let func = hot_lift_body(
    hot_test_roundtrip_body(),
    HotLocals::new(param_count=1, locals=[]),
    body_result_type=BlockType::val_type(ValType::i32()),
  )
  let lowered = hot_lower_body(func)
  assert_eq(lowered, hot_test_roundtrip_body())
}

///|
test "hot root slots can be replaced directly" {
  let func = hot_lift_body(
    Expr::new([Instruction::nop()]),
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
  assert_eq(lowered, Expr::new([Instruction::return_()]))
}

///|
test "hot block children mutate by slot" {
  let func = hot_lift_body(
    Expr::new([
      Instruction::block(BlockType::void_(), Expr::new([Instruction::nop()])),
    ]),
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
    Expr::new([
      Instruction::block(
        BlockType::void_(),
        Expr::new([Instruction::return_()]),
      ),
    ]),
  )
}
