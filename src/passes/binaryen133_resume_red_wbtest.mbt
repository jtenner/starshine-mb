///|
test "Binaryen 133 resumes a fresh non-suspending continuation as a direct call" {
  // Encoded by the verified version_133 wasm-opt from a two-function WAT
  // fixture. The Starshine WAT parser does not yet accept stack-switching text.
  let input = match
    @binary.decode_module(
      Bytes::from_array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x06, 0x02, 0x60, 0x00,
        0x00, 0x5d, 0x00, 0x03, 0x03, 0x02, 0x00, 0x00, 0x07, 0x07, 0x01, 0x03, 0x72,
        0x75, 0x6e, 0x00, 0x01, 0x09, 0x05, 0x01, 0x03, 0x00, 0x01, 0x00, 0x0a, 0x0f,
        0x02, 0x03, 0x00, 0x01, 0x0b, 0x09, 0x00, 0xd2, 0x00, 0xe0, 0x01, 0xe3, 0x01,
        0x00, 0x0b,
      ]),
    ) {
    Ok(input) => input
    Err(err) => fail("Binaryen 133 continuation fixture cannot decode: \{err}")
  }
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), [
      "global-effects", "optimize-instructions",
    ]) {
    Ok(output) => output
    Err(err) => fail("Binaryen 133 resume rewrite is unavailable: \{err}")
  }
  match @validate.validate_module(output) {
    Ok(_) => ()
    Err(err) => fail("Binaryen 133 resume rewrite is invalid: \{err}")
  }
  assert_eq(
    ca_test_opcode_count(output, @lib.Instruction::call(@lib.FuncIdx::new(0U))),
    1,
  )
}

///|
test "Binaryen 133 looks through a block to resume a fresh continuation as a call" {
  // Encoded by the verified version_133 wasm-opt. A typed block carries the
  // fresh continuation directly to resume without an intervening store.
  let input = match
    @binary.decode_module(
      Bytes::from_array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x06, 0x02, 0x60, 0x00,
        0x00, 0x5d, 0x00, 0x03, 0x03, 0x02, 0x00, 0x00, 0x07, 0x07, 0x01, 0x03, 0x72,
        0x75, 0x6e, 0x00, 0x01, 0x09, 0x05, 0x01, 0x03, 0x00, 0x01, 0x00, 0x0a, 0x10,
        0x02, 0x03, 0x00, 0x01, 0x0b, 0x0a, 0x00, 0x01, 0xd2, 0x00, 0xe0, 0x01, 0xe3,
        0x01, 0x00, 0x0b,
      ]),
    ) {
    Ok(input) => input
    Err(err) =>
      fail("Binaryen 133 block-wrapped continuation cannot decode: \{err}")
  }
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), [
      "global-effects", "optimize-instructions",
    ]) {
    Ok(output) => output
    Err(err) =>
      fail("Binaryen 133 block-wrapped resume rewrite is unavailable: \{err}")
  }
  assert_true(@validate.validate_module(output).is_ok())
  assert_eq(
    ca_test_opcode_count(output, @lib.Instruction::call(@lib.FuncIdx::new(0U))),
    1,
  )
}
