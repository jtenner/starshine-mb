///|
fn msf_test_large_void_func(instr_count : Int) -> @lib.Func {
  let body : Array[@lib.Instruction] = []
  for idx = 0; idx < instr_count; idx = idx + 1 {
    body.push(@lib.Instruction::nop())
  }
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
}

///|
test "merge-similar-functions admits a profitable 255-parameter helper" {
  assert_true(msf_has_merge_benefit(msf_test_large_void_func(1100), 0, 2, 255))
}

///|
test "merge-similar-functions rejects a 256-parameter helper" {
  assert_false(msf_has_merge_benefit(msf_test_large_void_func(2000), 0, 2, 256))
}
