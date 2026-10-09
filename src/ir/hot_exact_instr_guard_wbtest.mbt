///|
test "exact instruction guard rejects an incompatible numeric result" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func i32.const 1 i32.const 2 i32.add drop))",
  )
  let func = fixture.hot_func
  let add = hot_child_get(func, hot_root_get(func, 0), 0)
  assert_false(
    hot_mutate_exact_instr_matches_node(func, add, @lib.Instruction::i64_add()),
  )
  assert_true(
    hot_mutate_exact_instr_matches_node(func, add, @lib.Instruction::i32_sub()),
  )
  hot_node_exact_instr_set(func, add, @lib.Instruction::i32_sub())
  assert_eq(hot_node_exact_instr(func, add), Some(@lib.Instruction::i32_sub()))
  ignore(ir_test_assert_verify_and_lower(fixture))
}

///|
test "exact instruction guard handles an incomplete binary child" {
  let func = HotFunc::new()
  let lhs = hot_build_const_i32(func, @lib.I32(1))
  let rhs = hot_build_const_i32(func, @lib.I32(2))
  let binary = hot_build_binary(func, @lib.ValType::i32(), lhs, rhs)
  ignore(hot_replace_child_span(func, binary, [HOT_NONE_NODE, rhs]))
  // A staged node is invalid until its child is filled. The guard must
  // inspect that slot without querying a nonexistent node type.
  assert_true(
    hot_mutate_exact_instr_matches_node(
      func,
      binary,
      @lib.Instruction::i32_add(),
    ),
  )
}

///|
test "node setter refreshes exact unary trap flags" {
  let func = HotFunc::new()
  let numeric = hot_build_unary(
    func,
    @lib.ValType::i32(),
    hot_build_const_i32(func, @lib.I32(1)),
  )
  hot_node_exact_instr_set(func, numeric, @lib.Instruction::i32_clz())
  let nullable = @lib.RefType::abs(@lib.AbsHeapType::extern_())
  let nonnull = @lib.RefType::new(
    false,
    @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
  )
  let operand = hot_build_ref_null(func, nullable)
  let checked = hot_build_unary(func, @lib.ValType::ref_type(nonnull), operand)
  hot_node_exact_instr_set(func, checked, @lib.Instruction::ref_as_non_null())
  let other = hot_build_unary(func, @lib.ValType::ref_type(nonnull), operand)
  assert_false(hot_node_has_flag(func, other, HOT_FLAG_MAY_TRAP))
  hot_node_set(func, other, {
    ..hot_node_get(func, other),
    imm0: hot_node_get(func, checked).imm0,
  })
  assert_true(hot_node_has_flag(func, other, HOT_FLAG_MAY_TRAP))
}
