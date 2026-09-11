///|
test "precompute-propagate follows copies from conditional writes" {
  let input = pass_test_module_from_wat(
    (
      #|(module (func (export "run") (param i32 i32) (result i32) (local i32 i32) block local.get 0 i32.const 0 i32.eq if (result i32) local.get 1 local.set 2 i32.const 1 else i32.const 0 end if local.get 2 local.set 3 br 1 end unreachable end local.get 3))
    ),
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "precompute-propagate",
  ]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  // Both nested writes matter: local 2 receives the parameter in a condition,
  // then local 3 copies it in the selected arm. The result is not entry zero.
  @debug.assert_eq(
    body.last(),
    Some(@lib.Instruction::local_get(@lib.LocalIdx::new(3U))),
  )
  ignore(@validate.validate_module(output).unwrap())
}

///|
test "precompute moves nested constant-if roots out of their old holders" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7f\x01\x7f\x03\x02\x01\x00\x07\x07\x01\x03\x72\x75\x6e\x00\x00\x0a\x1d\x01\x1b\x00\x41\x01\x04\x7f\x02\x7f\x41\x01\x04\x7f\x20\x00\x0f\x05\x41\x00\x0b\x0b\x05\x41\x00\x0b\x1a\x41\x00\x0b",
  ).unwrap()
  for pass_name in ["precompute", "precompute-propagate"] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass_name]).unwrap()
    ignore(@validate.validate_module(output).unwrap())
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_true(
      body.contains(@lib.Instruction::local_get(@lib.LocalIdx::new(0U))),
      msg=body.to_string(),
    )
    assert_true(output.code_sec != input.code_sec)
  }
}
