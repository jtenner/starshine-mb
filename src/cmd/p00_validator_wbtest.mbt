///|
fn p00_validator_command(wat : String) -> Result[CmdRunSummary, CmdError] {
  let input = @wast.wast_to_binary_module(wat, filename="p00.wat").unwrap()
  let bytes = encode_module_bytes(input)
  p00_validator_bytes(bytes)
}

///|
fn p00_validator_bytes(bytes : Bytes) -> Result[CmdRunSummary, CmdError] {
  let io = CmdIO::new(
    list_candidates=fn() { ["p00.wasm"] },
    file_exists=fn(path) { path == "p00.wasm" },
    read_file=fn(_) { Ok(bytes) },
    write_file=fn(_, _) { Ok(()) },
  )
  run_cmd_with_adapter(["--validate", "--out", "out.wasm", "p00.wasm"], io)
}

///|
test "command validator rejects invalid nested frames and concrete polymorphic select" {
  for
    wat in [
      "(module (func (result i32) block unreachable end))", "(module (func block (result i32) unreachable end))",
      "(module (func (result f32) block (result i32) unreachable end))", "(module (func unreachable i32.const 1 i64.const 2 i32.const 0 select drop))",
      "(module (func unreachable block i32.add drop end))", "(module (func unreachable loop i32.add drop end))",
      "(module (func unreachable if i32.add drop end))",
    ] {
    assert_true(p00_validator_command(wat).is_err(), msg=wat)
  }
}

///|
test "command validator accepts matching declared nested results after unreachable" {
  for
    wat in [
      "(module (func block unreachable end))", "(module (func (result i32) block (result i32) unreachable end))",
      "(module (func (result f32) block (result f32) unreachable end))", "(module (func unreachable block unreachable end))",
      "(module (func unreachable loop unreachable end))", "(module (func unreachable if unreachable else unreachable end))",
      "(module (func unreachable i32.const 1 i32.const 2 i32.const 0 select drop))",
    ] {
    ignore(p00_validator_command(wat).unwrap())
  }
}

///|
test "command validator rejects the saved invalid MergeBlocks raw output" {
  // Frozen invalid output, sha256 ebf4c77aaf00e0457d34a06f9923816a48a4478f78d175a3970cbf49e74e3538.
  let bytes = Bytes::from_array([
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x04, 0x01, 0x60, 0x00,
    0x00, 0x03, 0x02, 0x01, 0x00, 0x04, 0x04, 0x01, 0x70, 0x00, 0x01, 0x07, 0x05,
    0x01, 0x01, 0x66, 0x00, 0x00, 0x0a, 0x21, 0x01, 0x1f, 0x00, 0x41, 0x00, 0x41,
    0x00, 0x25, 0x00, 0x41, 0x00, 0xfc, 0x11, 0x00, 0x00, 0x43, 0x00, 0x00, 0x20,
    0x40, 0x1a, 0x02, 0x73, 0xd0, 0x73, 0x41, 0x00, 0x0e, 0x01, 0x00, 0x00, 0x0b,
    0x0b,
  ])
  assert_true(p00_validator_bytes(bytes).is_err())
}
