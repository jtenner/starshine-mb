///|
test "OI residual elements case 108" {
  let input = @binary.decode_module(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x60, 0x00,
      0x00, 0x60, 0x00, 0x01, 0x7f, 0x03, 0x03, 0x02, 0x00, 0x01, 0x04, 0x06, 0x01,
      0x63, 0x01, 0x01, 0x01, 0x01, 0x07, 0x07, 0x01, 0x03, 0x72, 0x75, 0x6e, 0x00,
      0x00, 0x09, 0x10, 0x02, 0x06, 0x00, 0x41, 0x00, 0x0b, 0x63, 0x01, 0x01, 0xd2,
      0x01, 0x0b, 0x03, 0x00, 0x01, 0x01, 0x0a, 0x10, 0x02, 0x09, 0x00, 0x41, 0x00,
      0x25, 0x00, 0x14, 0x01, 0x1a, 0x0b, 0x04, 0x00, 0x41, 0x2a, 0x0b,
    ]),
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let elems = output.elem_sec.unwrap().0
  @debug.assert_eq(elems.length(), 1)
  @debug.assert_eq(elems[0], input.elem_sec.unwrap().0[0])
}

///|
test "OI residual elements remap surviving names and retain distinct declarations" {
  let input = pass_test_module_from_wat(
    "(module (func) (func) (table 1 funcref) (elem declare func 0) (elem (i32.const 0) func 0) (elem declare func 1) (func ref.func 1 drop))",
  ).with_name_sec(
    @lib.NameSec::new(
      elem_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("removed")),
          @lib.NameAssoc::new(1U, @lib.Name::from_string("active")),
          @lib.NameAssoc::new(2U, @lib.Name::from_string("required")),
        ]),
      ),
    ),
  )
  let output = oi_cleanup_module_encoding(input)
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(
    output.elem_sec.unwrap().0,
    input.elem_sec.unwrap().0[1:3].to_array(),
  )
  @debug.assert_eq(
    output.name_sec.unwrap().elem_names,
    Some(
      @lib.NameMap::new([
        @lib.NameAssoc::new(0U, @lib.Name::from_string("active")),
        @lib.NameAssoc::new(1U, @lib.Name::from_string("required")),
      ]),
    ),
  )
}

///|
test "OI residual elements keep one duplicate declaration required by ref func" {
  let input = pass_test_module_from_wat(
    "(module (func) (elem declare func 0) (elem declare func 0) (func ref.func 0 drop))",
  )
  let output = oi_cleanup_module_encoding(input)
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.elem_sec.unwrap().0.length(), 1)
}

///|
test "OI residual elements retain intentionally unsupported indexed segments" {
  // Segment-index rewriting is intentionally outside this bounded cleanup.
  let input = pass_test_module_from_wat(
    "(module (func) (table 1 funcref) (elem (i32.const 0) func 0) (elem declare func 0) (func block elem.drop 1 end))",
  )
  let output = oi_cleanup_module_encoding(input)
  @debug.assert_eq(output.elem_sec, input.elem_sec)
  assert_true(@validate.validate_module(output).is_ok())
}

///|
test "OI residual elements use exports and global initializers as declarations" {
  for
    wat in [
      "(module (func (export \"f\")) (elem declare func 0))", "(module (func) (global funcref (ref.func 0)) (elem declare func 0))",
    ] {
    let input = pass_test_module_from_wat(wat)
    let output = oi_cleanup_module_encoding(input)
    @debug.assert_eq(output.elem_sec, None)
    assert_true(@validate.validate_module(output).is_ok())
  }
}
