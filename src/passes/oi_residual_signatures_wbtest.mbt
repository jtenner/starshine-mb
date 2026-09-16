///|
test "OI residual signatures case 7" {
  let input = @binary.decode_module(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x07, 0x02, 0x60, 0x00,
      0x00, 0x60, 0x00, 0x00, 0x03, 0x03, 0x02, 0x00, 0x01, 0x07, 0x07, 0x01, 0x03,
      0x72, 0x75, 0x6e, 0x00, 0x00, 0x09, 0x05, 0x01, 0x03, 0x00, 0x01, 0x01, 0x0a,
      0x0f, 0x02, 0x0a, 0x00, 0x02, 0x63, 0x01, 0xd2, 0x01, 0x0b, 0x15, 0x01, 0x0b,
      0x02, 0x00, 0x0b,
    ]),
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(output.func_sec.unwrap().0, [
    @lib.TypeIdx::new(0U),
    @lib.TypeIdx::new(0U),
  ])
  @debug.assert_eq(output.export_sec, input.export_sec)
}

///|
test "OI residual signatures preserve imported and indirect call contracts" {
  let input = pass_test_module_from_wat(
    "(module (type (func (param i32) (result i32))) (type (func (param i32) (result i32))) (import \"host\" \"f\" (func (type 1))) (table 1 funcref) (elem (i32.const 0) func 0) (func (export \"run\") (type 0) local.get 0 i32.const 0 call_indirect (type 1)))",
  )
  let output = oi_cleanup_module_encoding(input)
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(output.func_sec.unwrap().0[0], @lib.TypeIdx::new(0U))
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(
    body.last(),
    Some(
      @lib.Instruction::call_indirect(
        @lib.TypeIdx::new(0U),
        @lib.TableIdx::new(0U),
      ),
    ),
  )
}
