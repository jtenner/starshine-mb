///|
fn cl_copy_remap_fixture(count : Int) -> Array[@lib.Instruction] {
  Array::makei(count, fn(_) {
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
      ]),
    )
  })
}

///|
test "coalesce fused remap preserves nested input ownership and parameter slots" {
  let body = cl_copy_remap_fixture(2)
  let original = cl_deep_copy_instrs(body)
  let mapping = [0, 2, 1]
  let reference = cl_deep_copy_instrs(body)
  cl_rewrite_all_local_idxs_in_place(reference, mapping)
  let actual = cl_copy_remap_instrs(body, mapping)
  assert_eq(actual, reference)
  assert_eq(body, original)
  cl_rewrite_all_local_idxs_in_place(actual, [0, 1, 1])
  assert_eq(body, original)
  assert_eq(
    cl_copy_remap_instrs(
      [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))],
      mapping,
    ),
    [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))],
  )
}

///|
test "coalesce fused remap owns legacy catch bodies" {
  let body = [@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]
  let instr = @lib.Instruction::try_(
    @lib.BlockType::void_(),
    @lib.Expr::new([]),
    [@lib.LegacyCatch::all(@lib.Expr::new(body))],
  )
  let output = cl_copy_remap_instrs([instr], [0, 2, 1])
  assert_eq(output, [
    @lib.Instruction::try_(@lib.BlockType::void_(), @lib.Expr::new([]), [
      @lib.LegacyCatch::all(
        @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(2U))]),
      ),
    ]),
  ])
  assert_eq(body, [@lib.Instruction::local_get(@lib.LocalIdx::new(1U))])
}
