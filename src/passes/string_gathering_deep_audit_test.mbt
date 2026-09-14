///|
test "deep audit string gathering nonnullable result existing False" {
  let nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::string_())),
  )
  let input = pass_test_module_from_wat(
    "(module (func (result stringref) (string.const \"hello\")))",
  )
  let input = input.with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [nonnull])),
      ),
    ]),
  )
  let output = audit_run_module(input, "string-gathering")
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "deep audit string gathering nonnullable global existing False" {
  let nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::string_())),
  )
  let input = pass_test_module_from_wat(
    "(module (func (result stringref) (string.const \"hello\")))",
  )
  let globals = input.global_sec.map(fn(s) { s.0.copy() }).unwrap_or([])
  globals.push(
    @lib.Global::new(
      @lib.GlobalType::new(nonnull, false),
      @lib.Expr::new([@lib.Instruction::string_const(b"hello")]),
    ),
  )
  let input = input.with_global_sec(@lib.GlobalSec::new(globals))
  let output = audit_run_module(input, "string-gathering")
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "deep audit string gathering nonnullable result existing True" {
  let nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::string_())),
  )
  let input = pass_test_module_from_wat(
    "(module (global stringref (string.const \"hello\")) (func (result stringref) (string.const \"hello\")))",
  )
  let input = input.with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [nonnull])),
      ),
    ]),
  )
  let output = audit_run_module(input, "string-gathering")
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "deep audit string gathering nonnullable global existing True" {
  let nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::string_())),
  )
  let input = pass_test_module_from_wat(
    "(module (global stringref (string.const \"hello\")) (func (result stringref) (string.const \"hello\")))",
  )
  let globals = input.global_sec.map(fn(s) { s.0.copy() }).unwrap_or([])
  globals.push(
    @lib.Global::new(
      @lib.GlobalType::new(nonnull, false),
      @lib.Expr::new([@lib.Instruction::string_const(b"hello")]),
    ),
  )
  let input = input.with_global_sec(@lib.GlobalSec::new(globals))
  let output = audit_run_module(input, "string-gathering")
  assert_true(@validate.validate_module(output) is Ok(_))
}
