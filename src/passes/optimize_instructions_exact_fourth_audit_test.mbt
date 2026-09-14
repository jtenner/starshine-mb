///|
test "fourth audit exact nullable equality cast False" {
  let input = pass_test_module_from_wat(
    "(module (type $s (sub (struct))) (func (param (ref null $s)) (result i32) i32.const 0))",
  )
  let get = @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
  let cast = @lib.Instruction::ref_cast_type(
    @lib.RefType::new(
      true,
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      exact=true,
    ),
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([get, cast, get, @lib.Instruction::ref_eq()]),
      ),
    ]),
  )
  let output = audit_run_module(input, "optimize-instructions")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.RefCast(_, _, _) }),
    1,
  )
}

///|
test "fourth audit exact nullable equality cast True" {
  let input = pass_test_module_from_wat(
    "(module (type $s (sub (struct))) (func (param (ref null $s)) (result i32) i32.const 0))",
  )
  let get = @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
  let cast = @lib.Instruction::ref_cast_type(
    @lib.RefType::new(
      true,
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      exact=true,
    ),
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([get, get, cast, @lib.Instruction::ref_eq()]),
      ),
    ]),
  )
  let output = audit_run_module(input, "optimize-instructions")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.RefCast(_, _, _) }),
    1,
  )
}
