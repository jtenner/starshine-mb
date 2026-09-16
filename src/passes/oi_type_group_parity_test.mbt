///|
test "optimize-instructions type group parity removes unused aggregate definitions" {
  for
    wat in [
      "(module (type (struct (field i32))) (type (array (mut i32))) (func (export \"run\") (result (ref 0)) i32.const 1 struct.new 0))",
      "(module (type (struct (field i32))) (type (array (mut i32))) (func (export \"run\") (result (ref 1)) unreachable))",
    ] {
    let input = pass_test_module_from_wat(wat)
    let input = if wat.contains("unreachable") {
      input.with_code_sec(
        @lib.CodeSec::new([
          @lib.Func::new(
            @lib.Locals::new([]),
            @lib.Expr::new([
              @lib.Instruction::i32_const(1),
              @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(1U), 1U),
            ]),
          ),
        ]),
      )
    } else {
      input
    }
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "optimize-instructions",
    ]).unwrap()
    assert_true(@validate.validate_module(output).is_ok())
    @debug.assert_eq(output.type_sec.unwrap().0.length(), 2)
  }
}
