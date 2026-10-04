///|
test "unsigned decode keeps multibyte indices through active pass commands" {
  let text = StringBuilder::new()
  text.write_string("(module ")
  // Exactly cross the ULEB128 boundary; this is a small deterministic fixture.
  for _ in 0..<128 {
    text.write_string("(import \"host\" \"f\" (func)) ")
  }
  text.write_string("(func $callee (param i32 i64) (result i32) (local ")
  for _ in 0..<129 {
    text.write_string("i32 ")
  }
  text.write_string(
    ") local.get 0 local.set 130 local.get 130 i32.const 3 i32.const 4 i32.add i32.add) (func (export \"run\") (param i32) (result i32) local.get 0 i64.const 99 call $callee))",
  )
  let input = @wast.wast_to_binary_module(text.to_string()).unwrap()
  let bytes = @binary.encode_module(input).unwrap()
  for
    pass in [
      "dae2", "dae2-optimizing", "coalesce-locals", "optimize-instructions",
    ] {
    let writes : Array[Bytes] = []
    let io = CmdIO::new(
      list_candidates=fn() { ["input.wasm"] },
      file_exists=fn(path) { path == "input.wasm" },
      read_file=fn(path) {
        if path == "input.wasm" {
          Ok(bytes)
        } else {
          Err("missing fixture")
        }
      },
      write_file=fn(_, data) {
        writes.push(data)
        Ok(())
      },
    )
    let summary = run_cmd_with_adapter(
      ["--\{pass}", "--out", "out.wasm", "input.wasm"],
      io,
    ).unwrap()
    assert_eq(summary.output_files, ["out.wasm"])
    assert_eq(writes.length(), 1)
    let output = @binary.decode_module(writes[0]).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    if pass == "dae2" || pass == "dae2-optimizing" {
      assert_eq(
        @validate.Env::new()
        .with_module(output)
        .get_functype_by_funcidx(@lib.FuncIdx::new(128U)),
        Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
      )
    } else if pass == "coalesce-locals" {
      assert_true(locals.length() < 129)
    } else {
      assert_eq(
        cmd_deep_audit_count(body, fn(instr) {
          instr is @lib.I32Const(@lib.I32(7))
        }),
        1,
      )
    }
    assert_eq(@binary.encode_module(input).unwrap(), bytes)
  }
}
