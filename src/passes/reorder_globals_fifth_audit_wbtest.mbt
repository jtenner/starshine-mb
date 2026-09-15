///|
test "fifth audit reorder globals shared expressions are remapped once" {
  let body = @lib.Expr::new([
    @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
  ])
  let first = rg_rewrite_expr(body, [1, 0])
  let second = rg_rewrite_expr(body, [1, 0])
  @debug.assert_eq(first, second)
  @debug.assert_eq(
    body,
    @lib.Expr::new([@lib.Instruction::global_get(@lib.GlobalIdx::new(1U))]),
  )
  @debug.assert_eq(
    first,
    @lib.Expr::new([@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))]),
  )
}
