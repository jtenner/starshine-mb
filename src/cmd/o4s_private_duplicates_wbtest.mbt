///|
test "CLI O4s merges private duplicates while preserving the host export" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func $a (result i32) i32.const 42) (func $b (result i32) i32.const 42) (func (export \"run\") (result i32) call $a call $b i32.add))",
  )
  let wasm = encode_module_bytes(input)
  let writes : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "input.wasm" },
    read_file=fn(_) { Ok(wasm) },
    write_file=fn(_, bytes) {
      writes.push(bytes)
      Ok(())
    },
  )
  run_cmd_with_adapter(
    [
      "--optimize", "--optimize-level", "4", "--shrink-level", "1", "input.wasm",
      "-o", "out.wasm",
    ],
    io,
  ).unwrap()
  |> ignore
  assert_eq(writes.length(), 1)
  let output = decode_module_bytes(writes[0])
  @validate.validate_module(output).unwrap()
  assert_eq(output.code_sec.unwrap().0.length(), 2)
  assert_true(writes[0].length() < wasm.length())
}
