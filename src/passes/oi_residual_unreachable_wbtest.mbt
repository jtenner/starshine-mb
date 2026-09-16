///|
test "OI residual unreachable case 2" {
  let input = @binary.decode_module(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x04, 0x01, 0x60, 0x00,
      0x00, 0x03, 0x02, 0x01, 0x00, 0x0a, 0x2f, 0x01, 0x2d, 0x00, 0xd0, 0x6e, 0xd1,
      0x1a, 0xd0, 0x71, 0xd1, 0x1a, 0xd0, 0x6e, 0xfb, 0x15, 0x6e, 0x1a, 0xd0, 0x6e,
      0xfb, 0x17, 0x6e, 0x1a, 0xd0, 0x6e, 0xfb, 0x14, 0x6e, 0x1a, 0xd0, 0x6e, 0xfb,
      0x16, 0x6e, 0x1a, 0xd0, 0x6d, 0xd0, 0x6d, 0xd3, 0x1a, 0x41, 0x1f, 0xfb, 0x1c,
      0x1a, 0x0b,
    ]),
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body.last(), Some(@lib.Instruction::unreachable_()))
}

///|
test "OI residual unreachable preserves prefix effects and surviving label names" {
  let input = pass_test_module_from_wat(
    "(module (global (mut i32) (i32.const 0)) (func (param i32) block local.get 0 br_if 0 end i32.const 7 global.set 0 unreachable block nop end))",
  ).with_name_sec(
    @lib.NameSec::new(
      label_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            0U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("live")),
              @lib.NameAssoc::new(1U, @lib.Name::from_string("dead")),
            ]),
          ),
        ]),
      ),
    ),
  )
  let output = oi_cleanup_module_encoding(input)
  let @lib.Func(_, @lib.Expr(before)) = input.code_sec.unwrap().0[0]
  let @lib.Func(_, @lib.Expr(after)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(after, before[0:4].to_array())
  @debug.assert_eq(
    output.name_sec.unwrap().label_names.unwrap().0[0].1.0.length(),
    1,
  )
}

///|
test "OI residual unreachable preserves conditional fallthrough" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 if unreachable end i32.const 7))",
  )
  let output = oi_cleanup_module_encoding(input)
  @debug.assert_eq(output.code_sec, input.code_sec)
}
