///|
test "command vacuum sinks drops into both concrete if arms" {
  for result_type in ["i32", "f64", "(ref null $S)"] {
    let input = @wast.wast_to_binary_module(
      "(module (type $S (struct (field i32))) (import \"e\" \"cond\" (func $cond (result i32))) (import \"e\" \"left\" (func $left (result \{result_type}))) (import \"e\" \"right\" (func $right (result \{result_type}))) (func (export \"run\") (drop (if (result \{result_type}) (call $cond) (then (call $left)) (else (call $right))))))",
    ).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let output = cmd_deep_audit_run_module(input, "vacuum")
    @validate.validate_module(output).unwrap()
    assert_eq(cmd_deep_audit_body(output, index=0), [
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          @lib.Instruction::drop(),
        ],
        Some([
          @lib.Instruction::call(@lib.FuncIdx::new(2U)),
          @lib.Instruction::drop(),
        ]),
      ),
    ])
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
