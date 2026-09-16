///|
test "OI residual blocks case 20" {
  let input = @binary.decode_module(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x04, 0x01, 0x60, 0x00,
      0x00, 0x03, 0x02, 0x01, 0x00, 0x0a, 0x3d, 0x01, 0x3b, 0x02, 0x01, 0x7f, 0x01,
      0x7e, 0x41, 0xff, 0x00, 0x21, 0x00, 0x20, 0x00, 0xc0, 0x1a, 0x42, 0xff, 0xff,
      0xff, 0xff, 0x07, 0x21, 0x01, 0x20, 0x01, 0xc4, 0x1a, 0x02, 0x7f, 0x41, 0xff,
      0x01, 0x0b, 0x21, 0x00, 0x20, 0x00, 0x41, 0xff, 0x01, 0x71, 0x1a, 0x02, 0x7e,
      0x42, 0xff, 0xff, 0x03, 0x0b, 0x21, 0x01, 0x20, 0x01, 0x42, 0xff, 0xff, 0x03,
      0x83, 0x1a, 0x0b,
    ]),
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_false(body.any(fn(i) { i is @lib.Block(_, _) }))
}

///|
test "OI residual blocks case 5" {
  let input = @binary.decode_module(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x04, 0x01, 0x60, 0x00,
      0x00, 0x03, 0x02, 0x01, 0x00, 0x0a, 0x1a, 0x01, 0x18, 0x01, 0x01, 0x6e, 0xd0,
      0x6e, 0x21, 0x00, 0x20, 0x00, 0xd1, 0x1a, 0x20, 0x00, 0xfb, 0x15, 0x6e, 0x1a,
      0x20, 0x00, 0xfb, 0x17, 0x6e, 0x1a, 0x0b,
    ]),
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_false(body.any(fn(i) { i is @lib.Block(_, _) }))
}

///|
test "OI residual blocks preserve remapped and untouched label names" {
  let input = pass_test_module_from_wat(
    "(module (import \"host\" \"f\" (func)) (func (param i32) block (result i32) i32.const 7 end drop block local.get 0 br_if 0 end) (func block br 0 end))",
  )
  let kept = @lib.NameAssoc::new(0U, @lib.Name::from_string("kept"))
  let input = input.with_name_sec(
    @lib.NameSec::new(
      func_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(1U, @lib.Name::from_string("function")),
        ]),
      ),
      label_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            1U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("removed")),
              @lib.NameAssoc::new(1U, @lib.Name::from_string("kept")),
            ]),
          ),
          @lib.IndirectNameAssoc::new(2U, @lib.NameMap::new([kept])),
        ]),
      ),
    ),
  )
  let input = input.with_raw_name_sec_payload(b"\x00\x04\x03old")
  let output = oi_cleanup_module_encoding(input)
  @debug.assert_eq(output.raw_name_sec_payload, None)
  assert_true(@validate.validate_module(output).is_ok())
  let names = output.name_sec.unwrap()
  @debug.assert_eq(names.func_names, input.name_sec.unwrap().func_names)
  @debug.assert_eq(names.label_names.unwrap().0[0].1, @lib.NameMap::new([kept]))
  @debug.assert_eq(
    names.label_names.unwrap().0[1],
    input.name_sec.unwrap().label_names.unwrap().0[1],
  )
}
