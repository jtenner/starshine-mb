///|
test "campaign optimize casts respects equivalent exact heap aliases" {
  let pass = "optimize-casts"
  let input = pass_test_module_from_wat(
    "(module (type $a (struct)) (type $b (struct)) (func (param (ref (exact $a))) (result i32) i32.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::ref_test_type(
            @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
          ),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, pass)
  assert_false(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Const(@lib.I32(0)) }) >
    0,
  )
}

///|
test "campaign optimize instructions respects equivalent exact heap aliases" {
  let pass = "optimize-instructions"
  let input = pass_test_module_from_wat(
    "(module (type $a (struct)) (type $b (struct)) (func (param (ref (exact $a))) (result i32) i32.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::ref_test_type(
            @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
          ),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, pass)
  assert_false(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Const(@lib.I32(0)) }) >
    0,
  )
}
