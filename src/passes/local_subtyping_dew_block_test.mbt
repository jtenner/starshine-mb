///|
test "local-subtyping narrows heap type but preserves nullable storage across a result block" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x09\x02\x5f\x01\x7f\x00\x60\x00\x01\x7f\x03\x02\x01\x01\x07\x07\x01\x03\x72\x75\x6e\x00\x00\x0a\x1c\x01\x1a\x01\x01\x6d\x02\x7f\x41\x2a\xfb\x00\x00\x21\x00\x41\x07\x0b\x1a\x20\x00\xfb\x16\x00\xfb\x02\x00\x00\x0b\x00\x0d\x04\x6e\x61\x6d\x65\x04\x06\x01\x00\x03\x62\x6f\x78",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "local-subtyping",
  ]).unwrap()
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(
    locals[0],
    @lib.ValType::ref_type(
      @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
    ),
  )
  let @lib.Func(original_locals, _) = input.code_sec.unwrap().0[0]
  assert_true(locals[0] != original_locals[0])
}
