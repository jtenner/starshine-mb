///|
test "audit optimize instructions retains later fixed array operand writes" {
  let input = pass_test_module_from_wat(
    "(module (type $a (array (mut i32))) (func (param i32) (result i32) local.get 0))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(0),
          @lib.Instruction::i32_const(0),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
          @lib.Instruction::array_new_fixed(
            @lib.TypeIdx::new(0U),
            @lib.U32::new(2U),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "optimize-instructions")
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.LocalTee(_) || i is @lib.LocalSet(_)
    }) >
    0,
  )
}
