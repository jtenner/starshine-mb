///|
test "type index rewrite visits legacy exception bodies and catches" {
  let old_type = @lib.TypeIdx::new(3U)
  let next_type = @lib.TypeIdx::new(1U)
  let old_ref = @lib.RefType::new(true, @lib.HeapType::new(old_type))
  let next_ref = @lib.RefType::new(true, @lib.HeapType::new(next_type))
  let body = @lib.Expr::new([@lib.Instruction::ref_null_type(old_ref)])
  let next_body = @lib.Expr::new([@lib.Instruction::ref_null_type(next_ref)])
  let tag = @lib.TagIdx::new(5U)
  let input = @lib.Instruction::try_(@lib.BlockType::type_idx(old_type), body, [
    @lib.LegacyCatch::tagged(tag, body),
    @lib.LegacyCatch::all(body),
  ])
  let expected = @lib.Instruction::try_(
    @lib.BlockType::type_idx(next_type),
    next_body,
    [@lib.LegacyCatch::tagged(tag, next_body), @lib.LegacyCatch::all(next_body)],
  )
  let remap = { 3U: 1U }
  @debug.assert_eq(dfe_rewrite_instruction_type_idxs(input, remap), expected)
  @debug.assert_eq(
    dfe_try_rewrite_instruction_type_idxs(input, remap),
    Some(expected),
  )
  @debug.assert_eq(
    dfe_try_rewrite_instruction_type_idxs(input, { 7U: 1U }),
    None,
  )
  let delegated = @lib.Instruction::try_(
    @lib.BlockType::void_(),
    body,
    [],
    delegate=Some(@lib.LabelIdx::new(2U)),
  )
  let next_delegated = @lib.Instruction::try_(
    @lib.BlockType::void_(),
    next_body,
    [],
    delegate=Some(@lib.LabelIdx::new(2U)),
  )
  @debug.assert_eq(
    dfe_try_rewrite_instruction_type_idxs(delegated, remap),
    Some(next_delegated),
  )
}

///|
test "type index rewrite changes a catch-only reference without mutating input" {
  let old_ref = @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(3U)))
  let next_ref = @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U)))
  let old_body = @lib.Expr::new([@lib.Instruction::ref_null_type(old_ref), @lib.Instruction::drop()])
  let next_body = @lib.Expr::new([@lib.Instruction::ref_null_type(next_ref), @lib.Instruction::drop()])
  let untouched = @lib.Expr::new([@lib.Instruction::nop()])
  let catches = [@lib.LegacyCatch::tagged(@lib.TagIdx::new(5U), untouched), @lib.LegacyCatch::all(old_body)]
  let saved = catches.copy()
  let input = @lib.Instruction::try_(@lib.BlockType::void_(), untouched, catches)
  let expected = @lib.Instruction::try_(@lib.BlockType::void_(), untouched, [@lib.LegacyCatch::tagged(@lib.TagIdx::new(5U), untouched), @lib.LegacyCatch::all(next_body)])
  @debug.assert_eq(dfe_try_rewrite_instruction_type_idxs(input, { 3U: 1U }), Some(expected))
  @debug.assert_eq(catches, saved)
}
