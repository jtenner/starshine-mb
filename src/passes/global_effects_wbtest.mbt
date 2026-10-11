///|
fn ge_wb_fresh_resume() -> Array[@lib.Instruction] {
  [
    @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
    @lib.Instruction::cont_new(@lib.TypeIdx::new(0U)),
    @lib.Instruction::resume_(@lib.TypeIdx::new(0U), []),
  ]
}

///|
test "global-effects finds resumes in legacy try and try-table regions" {
  let legacy = @lib.Expr::new([
    @lib.Instruction::try_(
      @lib.BlockType::void_(),
      @lib.Expr::new(ge_wb_fresh_resume()),
      [@lib.LegacyCatch::all(@lib.Expr::new(ge_wb_fresh_resume()))],
    ),
  ])
  let table = @lib.Expr::new([
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.Expr::new(ge_wb_fresh_resume()),
    ),
  ])

  assert_true(ge_body_has_rewritable_resume(legacy))
  assert_true(ge_body_has_rewritable_resume(table))
}

///|
test "global-effects rewrites fresh resumes in every legacy try region" {
  let body = @lib.Expr::new([
    @lib.Instruction::try_(
      @lib.BlockType::void_(),
      @lib.Expr::new(ge_wb_fresh_resume()),
      [@lib.LegacyCatch::all(@lib.Expr::new(ge_wb_fresh_resume()))],
    ),
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.Expr::new(ge_wb_fresh_resume()),
    ),
  ])
  let target = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let changed = [false]
  let rewritten = ge_rewrite_fresh_resumes(body, [target], [None], 0, changed)

  assert_true(changed[0])
  match rewritten {
    @lib.Expr(
      [
        @lib.Try(
          _,
          @lib.Expr([@lib.Call(@lib.FuncIdx(0U))]),
          [@lib.LegacyCatchAll(@lib.Expr([@lib.Call(@lib.FuncIdx(0U))]))],
          _
        ),
        @lib.TryTable(_, _, @lib.Expr([@lib.Call(@lib.FuncIdx(0U))])),
      ]
    ) => ()
    other => fail("expected nested resumes to become calls, got \{other}")
  }
}
