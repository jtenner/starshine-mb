///|
fn empty_code_section_fixture() -> @lib.Module {
  @lib.Module::new().with_code_sec(@lib.CodeSec::new([]))
}

///|
test "reorder-locals accepts a valid empty code section" {
  let input = empty_code_section_fixture()
  assert_true(@validate.validate_module(input) is Ok(_))
  @debug.assert_eq(reorder_locals_run_module_pass(input), input)
}

///|
test "coalesce-locals accepts a valid empty code section" {
  let input = empty_code_section_fixture()
  assert_true(@validate.validate_module(input) is Ok(_))
  @debug.assert_eq(coalesce_locals_run_module_pass(input), input)
}

///|
test "local-cse accepts a valid empty code section" {
  let input = empty_code_section_fixture()
  assert_true(@validate.validate_module(input) is Ok(_))
  @debug.assert_eq(local_cse_run_module_pass(input), input)
}

///|
test "reorder-locals dispatcher accepts a valid empty code section" {
  let input = empty_code_section_fixture()
  @debug.assert_eq(audit_run_module(input, "reorder-locals"), input)
}

///|
test "coalesce-locals dispatcher accepts a valid empty code section" {
  let input = empty_code_section_fixture()
  @debug.assert_eq(audit_run_module(input, "coalesce-locals"), input)
}

///|
test "local-cse dispatcher accepts a valid empty code section" {
  let input = empty_code_section_fixture()
  @debug.assert_eq(audit_run_module(input, "local-cse"), input)
}
