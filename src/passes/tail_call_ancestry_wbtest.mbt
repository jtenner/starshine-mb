///|
test "TailCall restores label ancestry after a child expression" {
  let labels = [true]
  let changed = [false]
  let input = @lib.Expr::new([@lib.Instruction::nop()])
  let rewritten = tail_call_rewrite_with_label(
    input, false, false, labels, false, changed,
  )
  assert_eq(rewritten, input)
  assert_eq(labels.length(), 1)
  assert_true(labels[0])
  assert_false(changed[0])
}
