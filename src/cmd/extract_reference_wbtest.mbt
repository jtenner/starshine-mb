///|
test "extract dispatcher validates mixed-signature reference-only table entries" {
  let input = @wast.wast_to_binary_module(
    "(module (type $void (func)) (type $other (func (param i32))) (table 2 funcref) (func $reference (type $other)) (func $called (type $void)) (func $root (type $void) i32.const 1 call_indirect (type $void)) (export \"root\" (func $root)) (elem (i32.const 0) func $reference $called))",
  ).unwrap()
  let wasm = encode_module_bytes(input)
  let writes : Array[Bytes] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["input.wasm"] },
    file_exists=fn(path) { path == "input.wasm" },
    read_file=fn(_) { Ok(wasm) },
    write_file=fn(_, bytes) {
      writes.push(bytes)
      Ok(())
    },
  )
  let _ = run_cmd_with_adapter(
    ["--extract-functions=2", "--out", "out.wasm", "input.wasm"],
    io,
  ).unwrap()
  assert_eq(writes.length(), 1)
  let output = decode_module_bytes(writes[0])
  @validate.validate_module(output).unwrap()
  assert_eq(output.code_sec.unwrap().0.length(), 3)
  assert_eq(
    match output.elem_sec.unwrap().0[0] {
      @lib.Elem(_, kind) => kind
    },
    @lib.ElemKind::funcs([1U, 2U].map(fn(i) { @lib.FuncIdx::new(i) })),
  )
}
