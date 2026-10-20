///|
test "code folding treats a branch to a block's own label as fallthrough" {
  let func = @ir.HotFunc::new()
  let block = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let label = @ir.hot_control_node_label(func, block)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block), [
    @ir.hot_build_br(func, label),
  ])
  let label_used = @bitset.BitSet::new(label + 1)
  label_used[label] = true
  let index = CodeFoldingExitIndex::new(
    @ir.hot_node_count(func),
    true,
    true,
    label_used,
  )
  assert_true(code_folding_node_exits_to_own_block_label(func, block))
  assert_false(
    code_folding_node_prevents_fallthrough_with_index(func, block, index),
  )
}

///|
test "raw unreachable cleanup preserves a block around rethrow" {
  let wrapped = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([@lib.Instruction::rethrow(@lib.LabelIdx::new(1U))]),
  )
  assert_true(
    pass_raw_instr_is_branch_control(
      @lib.Instruction::rethrow(@lib.LabelIdx::new(1U)),
    ),
  )
  let (cleaned, changed) = pass_raw_remove_dropped_unreachable_debris([
    wrapped,
    @lib.Instruction::unreachable_(),
  ])
  assert_false(changed)
  assert_eq(cleaned.length(), 2)
  assert_true(cleaned[0] is @lib.Block(_, _))
}

///|
test "optimize casts does not reuse a cast across a resume handler exit" {
  let input = @binary.decode_module(
    Bytes::from_array([
      0, 97, 115, 109, 1, 0, 0, 0, 1, 17, 4, 95, 1, 127, 0, 96, 0, 0, 93, 1, 96,
      2, 100, 2, 110, 1, 127, 3, 2, 1, 3, 13, 3, 1, 0, 1, 10, 28, 1, 26, 0, 2, 100,
      2, 32, 0, 227, 2, 1, 0, 0, 0, 32, 1, 251, 22, 0, 26, 32, 0, 11, 26, 32, 1,
      209, 11,
    ]),
  ).unwrap()
  ignore(@validate.validate_module(input).unwrap())
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-casts",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_eq(
    locals.length(),
    0,
    msg="the pass must not capture a cast that a resume handler can bypass",
  )
}
