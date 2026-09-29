///|
test "NaN input reuse preserves required encoding cleanup after an inactive named main pass" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (export \"value\") (result f32) nop block f32.const nan:0x400001 return end unreachable))",
  )
  let original = @binary.encode_module(input).unwrap()
  let expected = encode_module_for_pipeline(CmdIO::new(), "input.wasm", input).unwrap()
  assert_true(expected.length() < original.length())
  let writes : Array[Bytes] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["input.wasm"] },
    file_exists=fn(path) { path == "input.wasm" },
    read_file=fn(_) { Ok(original) },
    write_file=fn(_, bytes) {
      writes.push(bytes)
      Ok(())
    },
  )
  let _ = run_cmd_with_adapter(
    ["--inline-main", "--out", "out.wasm", "input.wasm"],
    io,
  ).unwrap()
  assert_eq(writes, [expected])
  let output = @binary.decode_module(writes[0]).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body.length(), 3)
  assert_true(body[0] is @lib.F32Const(_))
  assert_true(body[1] is @lib.Return)
  assert_true(body[2] is @lib.Unreachable)
}

///|
test "NaN identity admission retains nested and terminal encoding cleanup" {
  for
    body in [
      "f32.const nan:0x400001 return", "block nop end f32.const nan:0x400001", "loop nop end f32.const nan:0x400001",
      "i32.const 1 if nop else nop end f32.const nan:0x400001", "try_table nop end f32.const nan:0x400001",
    ] {
    let input = @passes.pass_test_module_from_wat(
      "(module (func (export \"value\") (result f32) \{body}))",
    )
    let original = @binary.encode_module(input).unwrap()
    let expected = encode_module_for_pipeline(CmdIO::new(), "input.wasm", input).unwrap()
    assert_true(expected.length() < original.length())
    assert_false(
      should_reuse_input_wasm_bytes(
        CliInputFormat::wasm(),
        1,
        false,
        input,
        input,
      ),
    )
    @validate.validate_module(@binary.decode_module(expected).unwrap()).unwrap()
  }
  let clean = @passes.pass_test_module_from_wat(
    "(module (func (result f32) f32.const nan:0x400001))",
  )
  let empty_data = clean
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(0U)))
    .with_data_sec(@lib.DataSec::new([]))
  let original = @binary.encode_module(empty_data).unwrap()
  let expected = encode_module_for_pipeline(
    CmdIO::new(),
    "input.wasm",
    empty_data,
  ).unwrap()
  assert_true(expected.length() < original.length())
  assert_false(
    should_reuse_input_wasm_bytes(
      CliInputFormat::wasm(),
      1,
      false,
      empty_data,
      empty_data,
    ),
  )
  @validate.validate_module(@binary.decode_module(expected).unwrap()).unwrap()
}
