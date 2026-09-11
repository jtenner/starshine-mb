///|
test "local-subtyping uses the declared result type of a widened tee" {
  // A struct assignment is carried through tee 0 into tee 1. An array
  // assignment later keeps local 0 at eqref, so tee 0 also returns eqref.
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x0c\x03\x5f\x01\x7f\x00\x5e\x7f\x01\x60\x00\x01\x7f\x03\x02\x01\x02\x07\x07\x01\x03\x72\x75\x6e\x00\x00\x0a\x20\x01\x1e\x01\x02\x6d\x41\x2a\xfb\x00\x00\x22\x00\x22\x01\x1a\x41\x01\xfb\x07\x01\x21\x00\x20\x01\xfb\x16\x00\xfb\x02\x00\x00\x0b\x00\x14\x04\x6e\x61\x6d\x65\x04\x0d\x02\x00\x03\x62\x6f\x78\x01\x05\x61\x72\x72\x61\x79",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "local-subtyping",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(locals[0], locals[1])
  assert_true(output.code_sec != input.code_sec)
}
