///|
test "ssa destruction reachability continues after a branch out of a block" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
      ),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
    HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let drop_id = hot_root_get(func, 1)
  let get_id = hot_child_get(func, drop_id, 0)
  let reachable = ssa_destroy_reachable_nodes(func)
  assert_true(reachable[get_id])
}
