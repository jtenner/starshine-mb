///|
fn dfe_wbtest_sparse_sample_func(unique : Bool) -> @lib.Func {
  let instrs : Array[@lib.Instruction] = Array::make(
    24,
    @lib.Instruction::nop(),
  )
  if unique {
    instrs[4] = @lib.Instruction::unreachable_()
  }
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(instrs))
}

///|
test "duplicate-function-elimination hashes full function bodies, not only sampled instructions" {
  let left = dfe_wbtest_sparse_sample_func(false)
  let right = dfe_wbtest_sparse_sample_func(true)
  assert_false(left == right)
  assert_true(
    dfe_function_hash_key_no_annotations(0, left) !=
    dfe_function_hash_key_no_annotations(0, right),
  )
}
