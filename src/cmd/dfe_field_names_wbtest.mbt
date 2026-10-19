///|
test "CLI DFE compacts function types beside named struct fields" {
  let fields = @lib.NameMap::new([
    @lib.NameAssoc::new(0U, @lib.Name::from_string("value")),
  ])
  let input = @passes.pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (type (struct (field i32))) (func (type 0)) (func (type 1)))",
  ).with_name_sec(
    @lib.NameSec::new(
      field_names=Some(
        @lib.IndirectNameMap::new([@lib.IndirectNameAssoc::new(2U, fields)]),
      ),
    ),
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
    ["--duplicate-function-elimination", "input.wasm", "-o", "out.wasm"],
    io,
  ).unwrap()
  |> ignore
  assert_eq(writes.length(), 1)
  let output = decode_module_bytes(writes[0])
  @validate.validate_module(output).unwrap()
  assert_eq(output.type_sec.unwrap().0.length(), 2)
  assert_eq(output.code_sec.unwrap().0.length(), 1)
  // Public DFE removes all names after its internal type remap.
  assert_eq(output.name_sec, None)
}
