///|
fn o4z_legacy_try_local_read(local : @lib.LocalIdx) -> @lib.Instruction {
  @lib.Instruction::try_(
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @lib.Expr::new([@lib.Instruction::throw_(@lib.TagIdx::new(0U))]),
    [
      @lib.LegacyCatch::all(
        @lib.Expr::new([@lib.Instruction::local_get(local)]),
      ),
    ],
  )
}

///|
test "O4z dead tee treats legacy try as a local-read boundary" {
  let local = @lib.LocalIdx::new(0U)
  let input = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_tee(local),
    @lib.Instruction::drop(),
    o4z_legacy_try_local_read(local),
    @lib.Instruction::drop(),
  ]
  let (output, changed) = o4z_canonicalize_final_size_dead_local_tees(input)
  assert_false(changed)
  assert_true(output.any(fn(instr) { instr is @lib.LocalTee(_) }))
}

///|
test "O4z local access scan descends into legacy try catches" {
  let local = @lib.LocalIdx::new(0U)
  assert_true(
    o4z_canonicalize_final_size_instrs_have_local_access([
      o4z_legacy_try_local_read(local),
    ]),
  )
}
