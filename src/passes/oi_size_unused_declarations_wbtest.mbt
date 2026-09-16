///|
test "OI size followup unused_declarations saved case 6 passes" {
  let input = @binary.decode_module(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x0a, 0x02, 0x60, 0x00,
      0x00, 0x60, 0x02, 0x7f, 0x7e, 0x01, 0x7e, 0x03, 0x03, 0x02, 0x00, 0x01, 0x07,
      0x07, 0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00, 0x09, 0x05, 0x01, 0x03, 0x00,
      0x01, 0x01, 0x0a, 0x13, 0x02, 0x0c, 0x00, 0x41, 0x29, 0x42, 0xcd, 0x00, 0xd2,
      0x01, 0x14, 0x01, 0x1a, 0x0b, 0x04, 0x00, 0x20, 0x01, 0x0b,
    ]),
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.elem_sec, None)
}

///|
test "OI size followup unused declarations clear removed names and preserve calls" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0) (elem declare func 0) (func (export \"run\") (result i32) i32.const 7 call 0))",
  ).with_name_sec(
    @lib.NameSec::new(
      elem_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("dead")),
        ]),
      ),
      func_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("callee")),
        ]),
      ),
    ),
  )
  let input = input.with_raw_name_sec_payload(b"\x00\x04\x03old")
  let output = oi_cleanup_module_encoding(input)
  @debug.assert_eq(output.elem_sec, None)
  @debug.assert_eq(output.name_sec.unwrap().elem_names, None)
  @debug.assert_eq(
    output.name_sec.unwrap().func_names,
    input.name_sec.unwrap().func_names,
  )
  @debug.assert_eq(output.raw_name_sec_payload, None)
  @debug.assert_eq(output.code_sec, input.code_sec)
  assert_true(@validate.validate_module(output).is_ok())
}
