///|
test "command DAE2 modes accept virtual typed block inputs and retain concrete checks" {
  for pass in ["dae2", "dae2-optimizing"] {
    for prefix in ["", "i32.const 7 "] {
      let source = "(module (func (param i32) (result i32) unreachable " +
        prefix +
        "block (param i32 i32) (result i32) i32.div_s end))"
      let output = cmd_deep_audit_run(source, pass)
      @validate.validate_module(output).unwrap()
      let bytes = encode_module_bytes(output)
      @validate.validate_module(decode_module_bytes(bytes)).unwrap()
    }
    for prefix in ["i64.const 7 ", "i32.const 7 i64.const 9 "] {
      let source = "(module (func (param i32) (result i32) unreachable " +
        prefix +
        "block (param i32 i32) (result i32) i32.div_s end))"
      let input = @wast.wast_to_binary_module(source).unwrap()
      assert_true(@validate.validate_module(input).is_err())
      assert_true(
        optimize_module_with_pass_flags(input, [pass], OptimizeOptions::new()).is_err(),
      )
    }
  }
}

///|
test "command DAE2 modes accept virtual inputs for every control kind" {
  for pass in ["dae2", "dae2-optimizing"] {
    for
      control in [
        "loop (param i32 i32) (result i32) i32.div_s end", "if (param i32 i32) (result i32) i32.div_s else i32.div_s end",
        "i32.const 1 if (param i32 i32) (result i32) i32.div_s else i32.div_s end",
        "(try (param i32 i32) (result i32) (do i32.div_s) (catch_all i32.const 7))",
        "try_table (param i32 i32) (result i32) i32.div_s end",
      ] {
      for prefix in ["", "i32.const 9 "] {
        let source = "(module (func (param i32) (result i32) unreachable " +
          prefix +
          control +
          "))"
        let output = cmd_deep_audit_run(source, pass)
        @validate.validate_module(output).unwrap()
        @validate.validate_module(
          decode_module_bytes(encode_module_bytes(output)),
        ).unwrap()
        assert_eq(cmd_deep_audit_body(output), [
          @lib.Instruction::unreachable_(),
        ])
      }
    }
  }
}

///|
test "command DAE2 polymorphic entry retains nested body validation" {
  let input = @wast.wast_to_binary_module(
    "(module (func (result i32) unreachable block (param i32 i32) (result i32) f64.add end))",
  ).unwrap()
  assert_true(@validate.validate_module(input).is_err())
  for pass in ["dae2", "dae2-optimizing"] {
    assert_true(
      optimize_module_with_pass_flags(input, [pass], OptimizeOptions::new()).is_err(),
    )
  }
}
