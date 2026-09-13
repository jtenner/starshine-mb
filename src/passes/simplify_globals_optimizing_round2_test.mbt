///|
test "round2 simplify globals invalidates runtime facts on suspend" {
  let input = pass_test_module_from_wat(
    "(module (tag $t) (global $g (export \"g\") (mut i32) (i32.const 0)) (func (export \"f\") (result i32) unreachable))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::suspend(@lib.TagIdx::new(0U)),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "simplify-globals-optimizing")
  assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.GlobalGet(_) }),
    1,
  )
}
