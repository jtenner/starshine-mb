///|
test "parity followup RSE interns duplicate plain tag and function signatures" {
  let input = @binary.decode_module(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x07, 0x02, 0x60, 0x00,
      0x00, 0x60, 0x00, 0x00, 0x03, 0x02, 0x01, 0x01, 0x0d, 0x03, 0x01, 0x00, 0x00,
      0x0a, 0x1b, 0x01, 0x19, 0x01, 0x01, 0x7f, 0x41, 0x05, 0x21, 0x00, 0x41, 0x05,
      0x21, 0x00, 0x02, 0x40, 0x1f, 0x40, 0x01, 0x00, 0x00, 0x00, 0x01, 0x0b, 0x0b,
      0x08, 0x00, 0x0b,
    ]),
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "redundant-set-elimination",
  ]).unwrap()
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_eq(output.type_sec.unwrap().0.length(), 1)
  assert_eq(output.func_sec.unwrap().0[0], @lib.TypeIdx::new(0U))
  assert_eq(
    output.tag_sec.unwrap().0[0],
    @lib.TagType::new(@lib.TypeIdx::new(0U)),
  )
  // Default encoding retains the source nop; interning removes three bytes.
  assert_eq(@binary.encode_module(output).unwrap().length(), 51)
}

///|
test "RSE signature interning intentionally excludes grouped GC and indexed-reference types" {
  let signature = @lib.SubType::comp_type(@lib.CompType::func([], []))
  let plain = @lib.RecType::new(signature)
  for
    special in [
      @lib.RecType::group([signature]),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(
            [@lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(0U)))],
            [],
          ),
        ),
      ),
    ] {
    let original = @lib.Module::new().with_type_sec(
      @lib.TypeSec::new([plain, plain, special]),
    )
    assert_true(@validate.validate_module(original) is Ok(_))
    let output = rse_canonicalize_plain_signatures(original)
    assert_eq(output.type_sec, original.type_sec)
  }
}
