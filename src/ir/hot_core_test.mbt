///|
test "hot core allocation exposes predictable dense counts and liveness" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::nop(),
      @lib.Instruction::i32_const(@lib.I32(3)),
    ]),
    HotLocals::new(param_count=0, locals=[]),
  )
  let nop_id = hot_root_get(func, 0)
  let const_id = hot_root_get(func, 1)

  assert_eq(nop_id, 0)
  assert_eq(const_id, 1)
  assert_eq(hot_node_count(func), 2)
  assert_true(hot_node_is_live(func, nop_id))
  assert_true(hot_node_is_live(func, const_id))
  assert_false(hot_node_is_live(func, 2))
}

///|
test "hot core storage counters and body result type roundtrip through accessors" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
      @lib.Instruction::i32_const(@lib.I32(9)),
    ]),
    HotLocals::new(param_count=0, locals=[]),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )

  assert_eq(hot_root_count(func), 2)
  assert_eq(hot_root_storage_count(func), 2)
  assert_eq(hot_node_count(func), 3)
  assert_eq(hot_child_storage_count(func), 1)

  let lifted_result_ty = hot_body_result_type(func)
  let void_ty = hot_type_void(func)
  assert_true(lifted_result_ty != void_ty)
  hot_body_result_type_set(func, void_ty)
  assert_eq(hot_body_result_type(func), void_ty)

  let dump = hot_debug_dump_core(func)
  assert_true(dump.contains("nodes=3"), msg=dump)
  assert_true(dump.contains("children=1"), msg=dump)
  assert_true(dump.contains("roots=2"), msg=dump)
}
