///|
test "Binaryen 133 fast-math constraint analysis folds a known local float equality" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (export \"run\") (local f64) (if (f64.eq (local.get 0) (local.get 0)) (then (nop)))))",
  )
  let wasm = encode_module_bytes(input)
  let writes : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "input.wasm" },
    list_candidates=fn() { ["input.wasm"] },
    read_file=fn(path) {
      if path == "input.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, bytes) {
      writes.push(bytes)
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      [
        "--fast-math", "--constraint-analysis", "--out", "out.wasm", "input.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("Binaryen 133 fast-math constraint option is unavailable: \{err}")
  }
  assert_eq(writes.length(), 1)
  let output = decode_module_bytes(writes[0])
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_false(body.contains(@lib.Instruction::f64_eq()))
}
