///|
test "command simplify-locals retains an interleaved write between tuple publications" {
  for additional_parameter_reads in [0, 4] {
    let mut extra_reads = ""
    for _ in 0..<additional_parameter_reads {
      extra_reads += "local.get 0 i32.add "
    }
    let input = @passes.pass_test_module_from_wat(
      "(module (type $pair (func (result i32 i32))) " +
      "(func (export \"run\") (param i32) (result i32) (local i32 i32 i32) " +
      "local.get 0 local.set 1 " +
      "block (type $pair) " +
      "local.get 1 i32.const 1 i32.add " +
      "local.get 1 i32.const 2 i32.add end " +
      "local.set 2 i32.const 99 local.set 1 " +
      "local.set 3 local.get 1 local.get 2 i32.add local.get 3 i32.add " +
      extra_reads +
      "))",
    )
    ignore(@validate.validate_module(input).unwrap())
    for pass in ["simplify-locals", "simplify-locals-nostructure"] {
      let output = cmd_deep_audit_run_module(input, pass)
      let output = decode_module_bytes(encode_module_bytes(output))
      ignore(@validate.validate_module(output).unwrap())
      for argument in [10, -7] {
        let expected = (additional_parameter_reads + 2) * argument + 102
        assert_eq(
          sl_multivalue_source_cmd_execute(
            input.code_sec.unwrap().0[0],
            argument,
          ),
          expected,
        )
        assert_eq(
          sl_multivalue_source_cmd_execute(
            output.code_sec.unwrap().0[0],
            argument,
          ),
          expected,
        )
      }
    }
  }
}
